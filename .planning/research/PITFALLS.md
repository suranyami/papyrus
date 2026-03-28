# Pitfalls Research

**Domain:** Elixir ePaper hardware driver library (Hex.pm package)
**Researched:** 2026-03-28
**Confidence:** HIGH for port/BEAM concerns (well-documented Erlang territory); MEDIUM for ePaper-specific buffer patterns (evidence from Waveshare source + Rust driver ecosystem); MEDIUM for headless browser on Pi (community reports, not benchmarks)

---

## Critical Pitfalls

### Pitfall 1: Port Zombie Processes After VM Crash

**What goes wrong:**
When the BEAM VM crashes hard (kill -9, power loss, OOM killer) rather than shutting down cleanly, the OS process spawned by `Port.open/2` does not receive SIGTERM. Its stdin/stdout file descriptors are closed, but the process stays alive in the OS. On the next Papyrus start the old `epd_port` process still holds the lgpio/SPI device open. The new port open then fails with a device-busy error, and the supervisor restarts loop begins.

**Why it happens:**
Erlang ports are linked to the owning BEAM process, not to the OS process group. Clean VM shutdown closes the port's stdin, which causes well-behaved programs to exit — but only if they are actively reading stdin. If the C port is blocked inside `DEV_ModuleInit()` or an SPI transfer when the BEAM dies, it never reaches another `read()` call and never sees EOF.

**How to avoid:**
The C port must run an explicit stdin-sentinel thread or use a non-blocking poll on stdin alongside its main loop. A minimal approach: after each command response is sent, `select()` on both `STDIN_FILENO` (for the next command) and a self-pipe (for shutdown). If `read()` returns 0 (EOF), call `DEV_ModuleExit()` and exit immediately. This is the canonical Erlang recommendation and covers all termination cases: clean shutdown, brutal kill, and VM crash.

Additionally, in the Elixir `Application` start, check for a stale pid file or use a named port registration to detect and kill any orphan process before opening a new one.

**Warning signs:**
- `mix run` hangs on first `Papyrus.Display.display/2` call after an unclean shutdown
- `lgpio` or SPI open errors appearing immediately at port startup (`DEV_ModuleInit failed`)
- `ps aux | grep epd_port` shows multiple instances

**Phase to address:** Driver abstraction and multi-display refactor (the C port is being rewritten anyway — add the stdin sentinel at that point, not as a later patch).

---

### Pitfall 2: Single `pending_from` Allows Only One In-Flight Command — But Doesn't Enforce It

**What goes wrong:**
`Papyrus.Display` stores exactly one `pending_from` and one `buffer` accumulator. If a caller sends a second command (e.g., `clear/1`) before the first `display/1` has returned, the second `GenServer.call` blocks in the caller, which is correct. However, if the Elixir-side timeout fires on the first call (`:infinity` is used today, so this requires an explicit timeout passed by the caller), the `pending_from` reference becomes stale. When the C port eventually replies, `GenServer.reply(state.pending_from, reply)` delivers the response to the timed-out process's mailbox as an unexpected `{ref, reply}` tuple that it will never match. The GenServer itself is then left with `pending_from: nil` but the next incoming `handle_info` data chunk belongs to the first response, not the second command, leading to a corrupted decode sequence.

**Why it happens:**
The current code passes `:infinity` to all `GenServer.call/3` invocations, which hides this. If any caller ever wraps the call with their own timeout (e.g. `Task.async` + `Task.await(t, 30_000)`), the caller process exits, the reply arrives later, and the GenServer's buffer state machine is off by one response.

**How to avoid:**
Keep `:infinity` as the call timeout — this is correct for hardware that takes up to 30 seconds. Document it clearly. Additionally, add a guard in `send_async/4`: if `state.pending_from != nil` when a new command arrives, return `{:reply, {:error, :command_in_progress}, state}` rather than silently clobbering the previous caller reference. This makes the serialization contract explicit and debuggable.

**Warning signs:**
- Callers receiving `:ok` for a command they didn't send
- Display showing the wrong image (previous render acknowledged, new one silently dropped)
- GenServer decode errors (`Protocol.decode_response` returning `:incomplete` for valid data)

**Phase to address:** ExUnit test suite phase — write a concurrent-caller test that verifies the busy-guard; also reviewable during the driver refactor.

---

### Pitfall 3: Config-Driven Abstraction Breaks on Structural Display Differences

**What goes wrong:**
The plan is to parameterise the C port so that display constants (resolution, pin assignments, command bytes) are passed at runtime rather than compiled in. This works for the majority of Waveshare displays, which share the same init/display/clear/sleep command structure with different constants. It fails for displays that are structurally different:

- **3-color (red/black/white) displays** — the C driver must clock out *two separate image planes* in sequence: one black/white plane and one red plane. The buffer layout is `[bw_plane | r_plane]`, each half being the same size as a 1-bit B&W buffer. The display command sequence is different: write BW register, write RED register, then trigger refresh. You cannot represent this as "just different constants."

- **Partial-refresh displays** — the init sequence differs fundamentally (different waveform LUT tables), and switching between full-refresh and partial-refresh modes requires an explicit full-refresh init before returning to partial. Some Waveshare V2 displays changed the protocol from V1 entirely.

- **The 12.48" four-chip display** — the panel is physically divided into M1/S1/M2/S2 sub-panels. The C driver currently handles this explicitly; a generic config struct cannot abstract sub-panel tiling without a structural extension to the command set.

**Why it happens:**
The abstraction is designed from the perspective of the easiest cases (B&W, same-structure variants). The harder cases are discovered when porting actual driver sources, not during design.

**How to avoid:**
Define the display behaviour in tiers, not as a single flat config struct. Tier 1: simple B&W — config-driven constants only, no C changes needed. Tier 2: 3-color / partial-refresh — requires a `command_variant` field that selects alternate C code paths (add a `COLOR_MODE` enum and `REFRESH_MODE` enum to the wire protocol). Tier 3: multi-chip (12.48" style) — keep as a distinct, explicitly-coded driver; do not attempt to genericise it. Document which Waveshare models fall in each tier before writing any new C code.

Concretely: extend the `Papyrus.DisplaySpec` struct to include `command_set: :standard | :dual_plane | :partial_refresh` and thread this through to the C binary as part of the per-command config init payload.

**Warning signs:**
- Finding yourself adding `if (color_mode == DUAL_PLANE)` branches that are not just different constants
- 3-color display showing all-white red plane (bw buffer sent to both registers)
- Partial refresh leaving "ghosting" artifacts visible after mode switch (full-refresh LUT not re-sent)

**Phase to address:** Driver abstraction and multi-display refactor (design the tier system before porting any additional drivers, not after).

---

### Pitfall 4: Buffer Bit Order Mismatch Between Elixir Rendering and C Driver

**What goes wrong:**
The C driver for the 12.48" panel encodes pixels as 1 bit per pixel, MSB-first within each byte: bit 7 is the leftmost pixel, bit 0 is the rightmost pixel of each 8-pixel group. `1 = white`, `0 = black`. A Bitmap module that gets this wrong produces a display that is correct in layout but has horizontally-mirrored or garbled pixels within each byte — visually it looks like random noise, not a mirror, because the error is within 8-pixel groups.

For 3-color displays the same issue exists independently on both planes. For 4-gray displays, 2 bits per pixel means the encoding is 4 pixels per byte and the order must match the specific chip's register format.

This is not uniform across the Waveshare line. Some panels documented in their API reference use LSB-first. The correct order is in the datasheet, not inferrable from the resolution spec.

**Why it happens:**
The Elixir `Bitmap` module will naturally work with Elixir bitstring syntax, which is big-endian/MSB-first by default — this happens to match the 12.48" driver. But when porting other display drivers, developers test with their existing code and assume the bit order is the same. It often isn't.

**How to avoid:**
For each new display model added to the `DisplaySpec`, record the pixel encoding explicitly: bit order (MSB/LSB first), bits-per-pixel (1, 2, or 4), byte alignment requirements, and polarity (1=white or 1=black). Add this to the spec struct and validate in `Papyrus.Bitmap` that the conversion uses the spec's encoding rather than hardcoded assumptions.

Write a deterministic test pattern that renders a single black pixel at position (0,0) and verifies the first byte of the output buffer has exactly one specific bit set. This catches bit-order bugs immediately.

**Warning signs:**
- Display shows a pattern that looks like static or random dots when rendering a simple solid rectangle
- Pattern is pixel-accurate within 8-pixel blocks but appears horizontally scrambled across each block
- Test pattern produces correct shape but wrong fill intensity (4-gray issue)

**Phase to address:** Test patterns phase — the checkerboard and single-pixel test patterns are exactly the tool for catching this. Also enforce spec-aware encoding in `Papyrus.Bitmap` during the rendering pipeline phase.

---

### Pitfall 5: Headless Browser Process Leaks on Raspberry Pi

**What goes wrong:**
Chromium on Linux is a multi-process application: one browser process, one GPU process, and separate renderer processes per tab. When Papyrus spawns a headless Chromium render job and the render completes (or times out), the browser process exits but renderer child processes may linger as zombies if the parent did not `wait()` for them. In a long-running Nerves system, these accumulate. On a Raspberry Pi 4 with 4GB RAM this causes gradual memory exhaustion over days; on a Pi Zero 2W with 512MB it causes OOM within hours.

A separate failure mode: if Chromium is killed mid-render (OOM killer, timeout), the user data directory (`--user-data-dir`) is left locked. The next render attempt fails immediately with a "profile already in use" error until the lock file is manually cleared.

**Why it happens:**
Most documentation for headless Chromium assumes a server environment with ample RAM and shows `--no-sandbox --disable-dev-shm-usage` flags for Docker. These suppress failures but do not reduce memory footprint. The zombie accumulation is a known Chromium issue where the multi-process architecture leaves orphaned renderer processes when the parent exits abnormally.

**How to avoid:**
- Use a process group approach: spawn Chromium as a process group leader (set `pgid` in the port options or via a wrapper script) so that `kill(-pgid, SIGTERM)` terminates the entire tree, not just the browser process.
- Use ephemeral temp directories for `--user-data-dir` (create a fresh tempdir per render, delete it after). This eliminates the profile-lock failure mode.
- Set `--memory-pressure-off --renderer-process-limit=1 --single-process` for on-device rendering. `--single-process` collapses the multi-process model, which eliminates zombie renderers at the cost of less crash isolation.
- Add a hard timeout in the Elixir supervisor for the renderer port: if no response within N seconds, kill the process group and return `{:error, :render_timeout}` rather than blocking indefinitely.
- Consider making `Papyrus.Renderer.Headless` an optional dependency path designed to run *off-device* (a desktop or CI machine pushes rendered bitmaps over the network) rather than on the Pi itself.

**Warning signs:**
- `ps aux | grep -c chrome` count grows over time on the device
- `/tmp` filling up with `chromium-*` profile directories after crashes
- Render calls succeeding but device RAM continuously decreasing (no floor)
- OOM killer logs in `dmesg` mentioning chromium renderer processes

**Phase to address:** Headless renderer phase — design the process management model before writing the first line of Elixir port code for Chromium.

---

### Pitfall 6: Large Binary Buffer Copies in GenServer State

**What goes wrong:**
The 12.48" display uses a 160KB image buffer. Elixir binaries over 64 bytes are stored in a shared binary heap with reference counting (RefcBin). When a binary is stored in GenServer state, it keeps the full 160KB alive even if the GenServer only needs to reference a small portion. More critically: if the display buffer is built by concatenation (e.g., `buf <> new_chunk`), each intermediate result is a separate heap allocation. Building the full 160KB buffer via repeated `<>` operations allocates roughly `O(n²)` bytes temporarily.

For `Papyrus.Bitmap`, which may work with PNG source images that are decoded to full RGBA before converting to 1-bit, the peak memory usage on a rendering host can be 4× the final buffer size (RGBA → grayscale intermediate → 1-bit intermediate → final 1-bit). On Raspberry Pi this is 2.5MB peak for a 12.48" render, which is manageable but becomes a problem at higher resolutions.

**Why it happens:**
Elixir's binary model is excellent for building binaries in a single pass using `IO.iodata_to_binary/1` or `Enum.reduce` into an iolist. But developers often default to `<>` concatenation in a loop because it is natural Elixir syntax.

**How to avoid:**
- Build image buffers as iolists (lists of binaries) and call `IO.iodata_to_binary/1` once at the end. This allocates exactly one final binary.
- In GenServer state, store the buffer as a transient field that is cleared after the port command is sent. The C port needs the bytes during the SPI transfer; the GenServer does not need to retain the buffer afterward.
- For the `Papyrus.Bitmap` pipeline: process source images in scanline-sized chunks using `Image` library's streaming facilities where available, rather than decoding the full image at once.

**Warning signs:**
- `:observer.start()` shows `binary_memory` growing for the display GenServer process
- Render operations triggering full GC pauses visible as increased display response latency
- OOM errors during bitmap conversion of large PNG source images

**Phase to address:** Rendering pipeline phase — establish the iolist pattern as a requirement in `Papyrus.Bitmap` from the start.

---

### Pitfall 7: ExUnit Tests With No Hardware Give False Coverage Confidence

**What goes wrong:**
A mock port binary (substituting for the real `epd_port` executable) can verify that:
- `Papyrus.Protocol` encodes/decodes correctly
- `Papyrus.Display` handles `{:ok, _}` and `{:error, _}` responses
- The GenServer supervises and restarts on port exit

It cannot verify:
- Whether the C binary correctly drives GPIO for a specific display model
- Whether the display buffer format is correct (wrong bit order will show on hardware, not in tests)
- Whether the timing between init/display/sleep satisfies the display's busy-pin polling requirements
- Whether `DEV_ModuleInit` succeeds with the wired hardware

Every developer who only runs `mix test` will see 100% Elixir-side pass rate and ship a library that may be completely broken on specific hardware combinations. This is especially dangerous when adding new display models, where the only verification is flashing the hardware.

**Why it happens:**
Hardware testing is slow and requires physical setup. The mock-based tests are fast and catch genuine regressions in the Elixir protocol layer. The temptation is to treat a green CI as sufficient validation.

**How to avoid:**
Maintain a strict two-tier test taxonomy and document it explicitly:

- **Tier 1 (CI-safe):** ExUnit tests against a mock port binary. Covers: protocol encoding, buffer size validation, GenServer lifecycle, DisplaySpec data, Bitmap pixel math, TestPattern buffer correctness.
- **Tier 2 (hardware-required):** Manual or hardware-CI tests. Covers: correct display output for each model, timing/busy-pin behavior, GPIO permissions, SPI speed, partial refresh cycle correctness.

For each new display model added, require a tier-2 hardware test checklist entry in the PR description: what visual outputs were observed, on what hardware revision. Make this explicit in `CONTRIBUTING.md`.

Never mark a display model as "supported" in documentation without a hardware-verified tier-2 result.

**Warning signs:**
- PR adds a new `DisplaySpec` module with no mention of hardware testing
- CI passes for a display model no contributor owns hardware for
- User bug reports of blank/corrupted display for a "supported" model

**Phase to address:** ExUnit test suite phase — define the test taxonomy at test infrastructure setup time. Display model phase — enforce checklist in PR template.

---

### Pitfall 8: Hex Package Compilation Fails Silently on User Machines

**What goes wrong:**
When a user runs `mix deps.get && mix deps.compile` on a machine that lacks `liblgpio-dev` (the required C library), `make` fails with a linker error. By default, `elixir_make` surfaces this as a raw `make` error with no guidance. The user sees a wall of C compiler output and no clear next step. On non-Raspberry Pi hosts (macOS, CI, Docker), the failure is expected but still confusing.

A more subtle failure: if `liblgpio` is installed but at a non-standard path (e.g., a Nerves cross-compilation sysroot), the default `LDFLAGS` in the Makefile will not find it. The library compiles but linking fails, and the error message says nothing about where to look.

**Why it happens:**
`elixir_make` provides a `:make_error_message` configuration option specifically for this, but it is not set by default and most library authors overlook it. The Makefile also uses `$(LDFLAGS) += -llgpio` with no fallback or detection.

**How to avoid:**
1. Set `:make_error_message` in `mix.exs` to a human-readable install guide: `"Papyrus requires liblgpio. On Raspberry Pi OS: sudo apt install liblgpio-dev"`.
2. Add a `./configure`-style check in the Makefile: use `pkg-config --libs lgpio 2>/dev/null || echo "-llgpio"` to locate the library.
3. Add a `MIX_ENV=test` code path that compiles a stub port binary (one that always returns `{ok, "stub"}`) for all commands. This allows `mix test` to run on macOS/CI without lgpio present.
4. Document clearly in README which platforms can compile (Linux/Raspberry Pi with lgpio) and which can only run tests (any platform with the stub port).

**Warning signs:**
- GitHub issues from users whose first line is "I just ran mix deps.compile and got..."
- CI failing on the library's own repo (it should fail gracefully with the stub, not hard)
- Users asking "does this work on macOS?" — they will try before reading docs

**Phase to address:** Hex.pm readiness / ExUnit test suite phase — the stub port and error message should be in place before any public release.

---

### Pitfall 9: DisplaySpec Buffer Size Is a Derived Value That Can Drift

**What goes wrong:**
`Papyrus.DisplaySpec` currently stores `buffer_size` as an explicit field set by each display module. For the 12.48" display this is `163 * 984`. If a new display module author calculates this incorrectly, or rounds the width differently (e.g., `ceil(1304/8)` vs `1304 div 8 + 1`), the Elixir-side `buffer_size` will not match what the C port expects. The C port validates `payload_len != BUFFER_SIZE` and returns an error — but the error message says "display: wrong buffer size" with no indication of what the correct size is or why there is a mismatch.

For 3-color displays this problem doubles: the Elixir layer needs to know `bw_plane_size + red_plane_size`, and if only one plane size is stored, the split point is ambiguous.

**Why it happens:**
Buffer size is currently manually specified rather than derived from `width` and `height` according to encoding rules. Two sources of truth (Elixir struct field, C constant) that must agree.

**How to avoid:**
Make `buffer_size` a computed field derived from `width`, `height`, `bits_per_pixel`, and `byte_alignment` in the `DisplaySpec` struct. Remove it as a user-specified field. The struct constructor validates that the derived size matches what the C port expects (checked at startup via a `CMD_INFO` handshake or compile-time assertion).

For multi-plane displays, store `planes: [{:black_white, size}, {:red, size}]` rather than a single `buffer_size`.

**Warning signs:**
- `{:error, "display: wrong buffer size"}` on first display attempt after adding a new display model
- New display module with `buffer_size` that is not derivable from the stated `width` and `height` with any standard encoding rule

**Phase to address:** Driver abstraction and multi-display refactor — when the struct is being extended for multi-display support, fix the derivation at that point.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding `BUFFER_SIZE = (163 * 984)` in C | Works for 12.48" | Every new display needs a separate C binary; config-driven approach impossible | Never — the refactor is planned for milestone 2 |
| `pending_from` without busy-guard | Simple state model | Silent data corruption when callers race (even unlikely callers) | Never — add the guard during test suite phase |
| `buffer_size` as explicit spec field | Obvious to read | Two sources of truth that can drift; calculation errors go undetected | Only for v0.1.0; fix during display abstraction phase |
| Mocking port binary in all tests | Fast CI | False confidence — green CI does not validate hardware output | Acceptable if tier-2 hardware test checklist is maintained alongside |
| Headless Chromium on-device | Simpler deployment | Memory pressure on Pi; zombie process accumulation | Acceptable for development/demo; not for production IoT deployment |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| lgpio / liblgpio | Assuming it is always available at `/usr/lib/liblgpio.so` | Use `pkg-config lgpio` in Makefile; document install step; provide graceful error message |
| Waveshare driver C sources | Copying driver source files as-is with their `printf` debug statements | Strip `printf`/`Debug_Printf` calls from the C sources before integrating; they write to stdout and corrupt the binary port protocol |
| Waveshare 3-color displays | Sending a single full-frame buffer | Must send BW plane to BW register, then RED plane to RED register, with separate SPI write commands per plane |
| Headless Chromium (Playwright/Puppeteer) | Not setting `--user-data-dir` to a temp path | Profile directory gets locked on crash; next render fails until lock file is manually deleted |
| elixir_make cross-compile (Nerves) | Relying on host `gcc` | Nerves sets `CC` to the cross-compiler; the Makefile must not hardcode `gcc` and must respect `$(CC)` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Binary concatenation in buffer build loop | High GC pressure; latency spikes before renders | Build buffers as iolists, call `IO.iodata_to_binary/1` once | Any buffer larger than ~16KB built by loop concat |
| Decoding full PNG to RGBA before 1-bit conversion | 4× peak memory per render | Process in scanline chunks or use `Image.thumbnail/3` to downsample before decode | 12.48" source image: ~5MB RGBA peak for 1304×984 |
| Retaining render buffer in GenServer state post-send | RefcBin keeps 160KB+ alive per display process | Clear `:buffer` field after `Port.command/2` returns | Always — no benefit to retaining the sent frame |
| Starting Chromium per render request | 3–8 second cold-start per render on Pi | Keep a persistent Chromium process; send new URLs to the existing page | Any render interval under 60 seconds |

---

## "Looks Done But Isn't" Checklist

- [ ] **Mock port tests pass:** Verify tier-2 hardware test checklist exists alongside the green CI result — mock tests do not validate actual display output.
- [ ] **New display model added:** Confirm `buffer_size` is derivable from `width × height × bits_per_pixel` and matches what the C constant expects. Confirm hardware-verified output documented in PR.
- [ ] **3-color display "supported":** Confirm dual-plane buffer split is implemented in both C port and `Papyrus.Bitmap`, not just one layer.
- [ ] **Partial refresh display "supported":** Confirm full-refresh init is called after partial-refresh mode before the next full refresh cycle; missing this causes ghosting that looks like correct operation until prolonged use.
- [ ] **Hex package published:** Confirm `c_src/` is listed in `package: [files: ...]`; confirm `:make_error_message` is set; confirm stub port compiles and `mix test` passes on macOS.
- [ ] **Port binary stdin sentinel:** Verify the C binary exits cleanly when stdin closes (test by killing the BEAM mid-operation and checking `ps` for lingering `epd_port` processes).
- [ ] **Headless renderer deployed on-device:** Confirm process group kill is implemented; confirm temp user-data-dir cleanup; confirm memory floor is stable over 24 hours.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Zombie port after VM crash | LOW | Add stdin sentinel to C port in next commit; add process cleanup to `Application.start/2` as interim |
| Buffer bit-order wrong for new display | LOW | Add `bit_order` field to `DisplaySpec`; fix `Papyrus.Bitmap` encoder; re-verify with hardware |
| Config-driven abstraction fails for 3-color | MEDIUM | Add `command_set: :dual_plane` tier to wire protocol; extend C binary with dual-plane write path; update all affected display modules |
| `buffer_size` drift in DisplaySpec | LOW | Make `buffer_size` a derived computation; add a startup assertion comparing Elixir-derived value to C-reported value via `CMD_INFO` |
| Chromium zombie accumulation | MEDIUM | Refactor renderer port to use process group kill; switch to ephemeral temp dirs; re-test on Pi over 24-hour run |
| Hex package fails to compile for users | LOW | Add `:make_error_message`; test from a clean Raspberry Pi OS Docker image before publishing |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Zombie port process after VM crash | Driver abstraction (C refactor) | Kill BEAM with `kill -9`; verify `ps` shows no lingering `epd_port`; verify clean restart |
| Stale `pending_from` on concurrent callers | ExUnit test suite | Add concurrent-caller test; verify `{:error, :command_in_progress}` returned correctly |
| Config abstraction breaks on 3-color/partial | Driver abstraction (design tier system before porting) | Port one 3-color driver; verify dual-plane buffer reaches display correctly |
| Bit order mismatch | Test patterns + Bitmap rendering phases | Single-pixel test pattern verifies byte 0 bit 7 is correct pixel |
| Chromium zombie processes | Headless renderer phase | 24-hour soak test on Pi; `ps` count stable; `/tmp` cleaned up |
| Large binary buffer copies | Rendering pipeline phase | Benchmark with `:observer`; verify no GC spike during render |
| False confidence from mocks | ExUnit test suite (define taxonomy) | Hardware test checklist in PR template; CI does not block on hardware tests |
| Hex compilation failure | Hex.pm readiness phase | `mix deps.compile` from clean macOS + clean Raspberry Pi OS Docker image |
| `buffer_size` derivation drift | Driver abstraction (multi-display refactor) | Derived value assertion fires at GenServer init if C and Elixir disagree |

---

## Sources

- [Erlang Ports documentation](https://www.erlang.org/doc/system/ports.html) — stdin-close behavior and port lifecycle
- [Elixir Port documentation](https://hexdocs.pm/elixir/Port.html) — port ownership and exit_status handling
- [open_port and zombie processes — Erlang Forums](https://erlangforums.com/t/open-port-and-zombie-processes/3111) — community confirmation of the VM-crash zombie issue
- [saleyn/erlexec](https://github.com/saleyn/erlexec) — the standard reference for OS process cleanup from Erlang
- [elixir_make precompilation guide](https://hexdocs.pm/elixir_make/precompilation_guide.html) — `:make_error_message` and precompiler options
- [epd-waveshare Rust crate](https://github.com/rust-embedded-community/epd-waveshare) — display version skew documented in issues (V2 protocol change)
- [Waveshare E-Paper API Analysis](https://www.waveshare.com/wiki/E-Paper_API_Analysis) — dual-plane buffer layout for 3-color displays
- [Ben Krasnow: Fast partial refresh on 4.2" e-paper](https://benkrasnow.blogspot.com/2017/10/fast-partial-refresh-on-42-e-paper.html) — LUT waveform and partial/full refresh mode switching
- [Chromium memory management best practices](https://webscraping.ai/faq/headless-chromium/what-are-the-best-practices-for-managing-memory-usage-in-headless-chromium) — launch flags for resource-constrained environments
- [Chromium Raspberry Pi memory thread](https://forums.raspberrypi.com/viewtopic.php?t=326222) — community confirmation of Pi memory pressure
- [Puppeteer zombie process RAM leak pattern](https://devforth.io/blog/how-to-simply-workaround-ram-leaking-libraries-like-puppeteer-universal-way-to-fix-ram-leaks-once-and-forever/) — RAM leak workaround patterns for Chromium wrappers
- [Elixir binary memory internals](https://www.honeybadger.io/blog/elixir-memory-structure/) — RefcBin heap sharing and GC implications
- [Using e-paper displays on resource-constrained MCUs](https://bitbanksoftware.blogspot.com/2022/10/using-e-paper-displays-on-resource.html) — bit order and byte packing for ePaper displays
- Waveshare C driver source (`EPD_12in48b.c`, `GUI_Paint.c`) — direct inspection of MSB-first pixel encoding, dual-plane structure for 3-color, printf debug pollution

---
*Pitfalls research for: Elixir ePaper hardware driver library (Papyrus)*
*Researched: 2026-03-28*
