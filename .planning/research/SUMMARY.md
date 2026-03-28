# Project Research Summary

**Project:** Papyrus — Elixir ePaper display driver library
**Domain:** Embedded hardware driver library (Hex.pm, Nerves, Waveshare ePaper displays)
**Researched:** 2026-03-28
**Confidence:** MEDIUM — stack and architecture HIGH confidence; dithering API and some ePaper-specific buffer patterns MEDIUM

## Executive Summary

Papyrus is an Elixir/Nerves library for driving Waveshare ePaper displays over SPI/GPIO using a C port process for hardware isolation. The v0.1.0 foundation is architecturally correct — a GenServer owning an OS port process keeps hardware faults from killing the BEAM VM, and the binary wire protocol is a proven pattern in the Nerves ecosystem. The path to a genuinely useful v0.2.0 Hex.pm release requires four parallel tracks: extending the C port to support 40+ display models via a runtime dispatch table, building the `Papyrus.Bitmap` rendering pipeline in pure Elixir, adding a `Papyrus.TestPattern` module for hardware bring-up, and establishing a hardware-free test infrastructure that enables CI without physical hardware.

The recommended approach leans on the `image` hex package (libvips via `vix`) for PNG/image processing, `chromic_pdf` for optional headless HTML rendering, and `Mox` for behaviour-based GenServer testing. The key architectural insight from research is that all image processing must stay in pure Elixir — sending a finished packed binary to the C port is simpler, safer, and more testable than processing in C. Dithering (Floyd-Steinberg) has no suitable library and must be implemented in Elixir bitstring operations after extracting raw grayscale bytes from libvips. This is a deliberate implementation choice, not a gap.

The top risks are: (1) the config-driven C port abstraction breaking down on structurally different display families (3-color dual-plane, partial-refresh LUT tables, multi-chip sub-panel tiling), which must be designed as tiers rather than a flat config; (2) port zombie processes after unclean BEAM shutdown, which requires a stdin-sentinel in the C binary; and (3) false coverage confidence from mock-based CI tests that pass while actual display output is wrong — a two-tier hardware/software test taxonomy must be established at test infrastructure time, not retrofitted.

## Key Findings

### Recommended Stack

The library is already well-founded in Elixir + `elixir_make` for C compilation. The additions for v0.2.0 are the `image` hex package (wraps libvips via `vix`) for all PNG/BMP/colorspace operations, `chromic_pdf` as an optional OTP application for HTML-to-PNG capture, and `Mox` for behaviour-based mocking in tests. The `image` library's libvips bindings are the right choice for image processing: prebuilt binaries are available for `linux-arm64` (Pi 4), the raw pixel buffer extraction path via `Vix.Vips.Image.write_to_binary/1` is confirmed, and performance is dramatically better than ImageMagick. For Nerves minimal rootfs targets where libvips is impractical, `stb_image` is the documented fallback.

**Core technologies:**
- `elixir_make ~> 0.9`: C port compilation — already in use; `make_cwd` and `$MIX_APP_PATH/priv/` pattern required for v0.9
- `image ~> 0.63` (via `vix`/libvips): PNG/BMP load, colorspace conversion, raw pixel extraction — primary image processing
- `chromic_pdf ~> 1.17`: HTML → PNG screenshot via Chrome DevTools Protocol, no Node.js — optional HTML rendering
- `Mox ~> 1.2`: Behaviour-based GenServer mocking — enables concurrent async tests without hardware
- `stb_image ~> 0.6`: Lightweight PNG reader — fallback for Nerves minimal rootfs where libvips unavailable
- `dialyxir ~> 1.4`: Typespec checking — catches behaviour callback mismatches early across 40+ display spec modules

### Expected Features

The research surfaces a clear v0.2.0 scope (table stakes for a useful Hex.pm library) and a v0.3.0 scope (differentiators that require the v0.2.0 foundation to be stable first).

**Must have (v0.2.0 table stakes):**
- Extended `DisplaySpec` with `c_model_id`, `color_buffer_size`, `partial_refresh`, `command_set` fields — foundation for all multi-model work
- Config-driven C port with runtime dispatch table (`epd_registry[]`) — single binary, 40+ models, no per-model recompile
- At least 3 display model configs validating all structural variants (B&W, 3-color, partial-refresh)
- `Papyrus.Bitmap` with PNG/BMP → 1-bit buffer conversion including Floyd-Steinberg and threshold dithering
- `Papyrus.TestPattern` with fill, border, and gray ramp patterns — hardware bring-up tool
- Hardware-free mock port binary for ExUnit — enables CI without physical hardware
- ExDoc getting-started guide, hardware setup instructions, and display model reference
- `examples/hello_papyrus` example Nerves application

**Should have (v0.3.0 competitive differentiators):**
- 3-color (red/yellow accent) dual-plane buffer format + at least one validated display module
- 4-gray (2-bit) buffer format + end-to-end bitmap pipeline
- `Papyrus.Renderer.Headless` — HTML → bitmap via headless Chromium (opt-in dependency)
- Remote render path within `Papyrus.Renderer.Headless` for Pi Zero memory-constrained deployments

**Defer (v1.0+):**
- Partial refresh — high implementation complexity, correctness requirements (ghosting, mandatory full-refresh intervals, sleep/init ordering) make it risky without extensive hardware validation
- Community-contributed third-party display modules — ecosystem expansion once abstraction is validated
- Bespoke bitmap font renderer — out of scope; headless browser handles text correctly at zero library cost

### Architecture Approach

The architecture is a clean three-tier separation: a rendering layer (pure Elixir — `Bitmap`, `TestPattern`, `Renderer.Headless`) produces packed binary buffers; a driver layer (`Display` GenServer + `DisplaySpec` behaviour + per-model config modules) validates and forwards those buffers; and a C port process (`epd_port` binary) owns all GPIO/SPI state and hardware interaction. The critical design principle is that nothing crosses tier boundaries in the wrong direction — renderers never touch the port, and the C binary never does image processing. This separation makes most of the library testable without hardware, keeps crash isolation intact, and allows rendering to happen on a separate machine with the buffer pushed over the network.

**Major components:**
1. `Papyrus.DisplaySpec` + `Papyrus.Displays.*` — behaviour + struct defining each display model; the single source of truth for dimensions, color mode, buffer format, and C model ID
2. `Papyrus.Display` (GenServer) + `Papyrus.Protocol` — port lifecycle, command serialization, wire format encode/decode; one process per physical display
3. `epd_port` C binary with `epd_registry[]` dispatch table — runtime model selection; init/display/clear/sleep dispatched via function pointers; all GPIO/SPI/lgpio interactions
4. `Papyrus.Bitmap` — PNG/BMP → packed 1-bit/2-bit binary; dithering in pure Elixir bitstring operations; spec-aware encoding
5. `Papyrus.TestPattern` — pure Elixir known-good buffer generation; no image library dependency; used for hardware bring-up and CI validation
6. `Papyrus.Renderer.Headless` (optional) — headless Chromium via `chromic_pdf`; captures PNG, passes to `Bitmap`; process group lifecycle management

### Critical Pitfalls

1. **Port zombie processes after VM crash** — The C binary must implement a stdin-sentinel: after each command response, `select()` on stdin and exit immediately on EOF (fd closed). Without this, BEAM kill -9 leaves `epd_port` alive with the SPI device open; the next supervisor restart fails with device-busy. Add at the C refactor phase, not later.

2. **Config-driven abstraction breaks on structural display differences** — 3-color displays require two-plane SPI writes; partial-refresh displays use different LUT waveform tables; the 12.48" uses multi-chip sub-panel tiling. A flat config struct cannot represent these. Design three tiers in the wire protocol: `:standard` (different constants, same command structure), `:dual_plane` (3-color, separate BW/red register writes), `:partial_refresh` (alternate init sequence). Choose tiers before porting any additional drivers.

3. **Buffer bit order mismatch between Elixir and C** — Waveshare panels are not uniform: some are MSB-first (bit 7 = leftmost pixel), some LSB-first; 4-gray uses 2 bits/pixel in a chip-specific order. Add `bit_order`, `bits_per_pixel`, and polarity fields to `DisplaySpec`. Write a single-pixel test pattern that validates byte 0 bit 7 is the correct pixel — catches this immediately without a full display cycle.

4. **False coverage confidence from mock-based tests** — Green CI with a mock port binary validates the Elixir protocol layer, not hardware output. A wrong bit order will pass all mock tests and produce garbage on hardware. Establish a two-tier test taxonomy at test infrastructure setup time: Tier 1 (CI-safe, mock port) and Tier 2 (hardware-required, manual checklist per display model). Never mark a display model as supported without a hardware-verified Tier 2 result.

5. **Headless browser process leaks on Raspberry Pi** — Chromium spawns multiple OS processes; renderer children linger as zombies after the parent exits. On Pi Zero 2W (512MB RAM), this causes OOM within hours. Use process group kill (`kill(-pgid, SIGTERM)`), ephemeral temp user-data-dirs per render, `--single-process` flag on-device, and a hard timeout supervisor. Consider making `Renderer.Headless` an off-device design by default with the Pi only writing the received bitmap.

## Implications for Roadmap

Based on the architecture's build-order tiers and the feature dependency graph, the work naturally decomposes into five phases.

### Phase 1: DisplaySpec Extension and C Port Refactor

**Rationale:** Everything else depends on this. The `DisplaySpec` struct (extended with `c_model_id`, `color_buffer_size`, `command_set`, `bit_order`, `bits_per_pixel`) is the contract between Elixir and C. The C port's runtime dispatch table (`epd_registry[]`) must exist before any additional display model can be added. This is also where `buffer_size` should be made a derived computation (eliminating two sources of truth) and the stdin-sentinel added to the C binary (eliminating zombie processes).

**Delivers:** A config-driven C port that supports multiple display models from a single binary; extended `DisplaySpec` struct that is the canonical source for all rendering and protocol decisions; validated with 2-3 hardware models covering all structural variants (B&W, 3-color, partial-refresh-capable).

**Addresses:** Multiple display model support (P1), extended DisplaySpec (P1), config-driven C port (P1)

**Avoids:** Port zombie (Pitfall 1), config abstraction breakdown (Pitfall 3), buffer_size drift (Pitfall 9)

**Needs research:** Yes — the wire protocol extension for `:dual_plane` and `:partial_refresh` command sets needs to be designed carefully before any C coding begins. The Waveshare driver sources for each structural variant should be inspected to confirm the protocol tier model covers them.

### Phase 2: Test Infrastructure and TestPattern

**Rationale:** TestPattern and the mock port binary can be built in parallel with Phase 1's C work. The mock port requires the wire protocol to be stable (Phase 1 output); TestPattern requires only a stable `DisplaySpec` struct. Together they establish the test foundation that all subsequent phases depend on. The two-tier test taxonomy must be defined here, not retrofitted.

**Delivers:** Mock port binary that speaks the full wire protocol; `Papyrus.TestPattern` with fill, border, gray ramp, and single-pixel verification patterns; full ExUnit suite for `Protocol`, `Display` GenServer, and `TestPattern`; two-tier test taxonomy documented in CONTRIBUTING.md.

**Addresses:** Hardware-free mock port (P1), `Papyrus.TestPattern` (P1), ExUnit test suite

**Avoids:** False coverage confidence (Pitfall 7), stale `pending_from` on concurrent callers (Pitfall 2)

**Needs research:** No — mock port binary and ExUnit patterns are well-established in the Nerves ecosystem.

### Phase 3: Bitmap Rendering Pipeline

**Rationale:** `Papyrus.Bitmap` is the central dependency for all rendering features. It requires the extended `DisplaySpec` (Phase 1) to know the target buffer format and encoding. With the test infrastructure in place (Phase 2), the bitmap module can be developed and validated entirely without hardware. This is the largest pure-software milestone.

**Delivers:** `Papyrus.Bitmap` with PNG/BMP → 1-bit packed buffer conversion; Floyd-Steinberg dithering and threshold mode implemented in pure Elixir bitstring operations; spec-aware encoding (bit order, bits-per-pixel, polarity from DisplaySpec); iolist-based buffer construction pattern to avoid binary concat memory pressure.

**Uses:** `image ~> 0.63` (libvips via vix) for PNG load and colorspace conversion; `Vix.Vips.Image.write_to_binary/1` for raw pixel extraction; pure Elixir for dithering (custom implementation, no library covers ePaper-targeted dithering)

**Avoids:** Large binary buffer copies (Pitfall 6), buffer bit order mismatch (Pitfall 4)

**Needs research:** Yes — the exact `image` library API for grayscale conversion and raw buffer extraction should be validated against the current hex version before implementation. The dithering path via libvips quantization needs a code-level spike to confirm whether it is usable or whether pure Elixir is required.

### Phase 4: Documentation and Hex.pm Readiness

**Rationale:** With Phases 1-3 complete, the library covers all v0.2.0 table stakes. Before publishing to Hex.pm, the package must compile cleanly from a fresh Raspberry Pi OS Docker image and on macOS (with stub port), documentation must guide first-time users through hardware setup, and the example app must demonstrate a complete Nerves firmware.

**Delivers:** ExDoc documentation with getting-started guide, hardware wiring instructions, and display model reference; `examples/hello_papyrus` example Nerves application; `:make_error_message` set in `mix.exs` with install guidance; stub port binary that compiles on macOS/CI (allowing `mix test` without lgpio); stub port binary confirmed in `package: [files: ...]`.

**Uses:** `ex_doc ~> 0.40` with `groups_for_modules` for display model reference

**Avoids:** Hex compilation failure on user machines (Pitfall 8)

**Needs research:** No — ExDoc and Hex packaging are well-documented with established patterns.

### Phase 5: Color Modes and HTML Renderer (v0.3.0)

**Rationale:** These features depend on the stable foundation from Phases 1-3. 3-color and 4-gray extend the bitmap pipeline with additional buffer formats; the headless renderer builds on top of `Papyrus.Bitmap`. All are higher-complexity features that benefit from having the full test infrastructure in place.

**Delivers:** 3-color (dual-plane) buffer format and at least one validated display module; 4-gray (2-bit) buffer format and pipeline; `Papyrus.Renderer.Headless` with `chromic_pdf`, process group lifecycle management, ephemeral temp dirs, and hard timeout supervisor; remote render path (off-device rendering, bitmap over network).

**Uses:** `chromic_pdf ~> 1.17` (optional dep); process group kill pattern for Chromium child processes

**Avoids:** Headless browser process leaks (Pitfall 5), config abstraction breakdown on dual-plane displays (Pitfall 3)

**Needs research:** Yes — `chromic_pdf` process lifecycle management, Chromium memory flags for Pi, and the remote render transport design all benefit from a dedicated research phase before implementation.

### Phase Ordering Rationale

- DisplaySpec and C port must come first because they are the contract that everything else implements against. No other phase can be finalized without a stable struct and protocol.
- TestPattern and mock infrastructure can overlap with Phase 1 C work but must follow the protocol design — this keeps CI green throughout and enables the bitmap phase to move fast.
- Bitmap follows DisplaySpec stability — the encoding must be known before building the converter.
- Documentation follows the feature-complete core — packaging a half-built library wastes effort on examples that will change.
- Color modes and the headless renderer defer to v0.3.0 because they require the v0.2.0 foundation to be stable and hardware-validated before adding additional complexity.
- Partial refresh deliberately sits outside this roadmap — it has hard correctness requirements (LUT waveforms, ghosting prevention, sleep/init ordering) that make it a v1.0+ feature after the abstraction is proven stable.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (C Port Refactor):** Wire protocol extension for `:dual_plane` and `:partial_refresh` tiers needs design validation against actual Waveshare C driver sources before any C coding. One wrong protocol assumption here breaks all 3-color and partial-refresh work downstream.
- **Phase 3 (Bitmap Pipeline):** The `image` library's API for grayscale extraction and the libvips dithering path need a code-level spike. If libvips dithering via quantization is not accessible at the current hex version, the fallback is pure Elixir — this is known viable but changes the implementation plan.
- **Phase 5 (HTML Renderer):** `chromic_pdf` process lifecycle on Raspberry Pi (memory pressure, zombie renderer processes, temp dir cleanup) needs research before writing any port code. The remote render transport design also needs an API decision.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Test Infrastructure):** Mock port binary and ExUnit patterns are idiomatic Nerves ecosystem; well-documented via `elixir-circuits` test backend pattern and existing Papyrus `:port_binary` option.
- **Phase 4 (Hex.pm Readiness):** ExDoc, `elixir_make` packaging, and stub port are standard Hex library patterns with high-confidence documentation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Core choices (image, chromic_pdf, Mox) verified against hexdocs; dithering API gap is the main uncertainty — libvips dithering for ePaper 1-bit conversion not confirmed via API docs, only via GitHub issues |
| Features | MEDIUM | Table stakes well-understood from hardware behavior and Python ecosystem; Elixir ecosystem is sparse so competitor comparison is limited; MVP scope recommendations are opinionated but grounded |
| Architecture | HIGH | Based on existing codebase inspection + confirmed patterns from Nerves ecosystem, epd-waveshare Rust crate, and Elixir Circuits; the tier system for display structural variants is design reasoning, not a documented external pattern |
| Pitfalls | HIGH for BEAM/port concerns; MEDIUM for ePaper-specific | Port zombie, GenServer concurrent caller, and binary memory pitfalls are well-documented Erlang territory; bit order and config abstraction breakdown are evidence-based from Waveshare source inspection and Rust driver issues |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Dithering API validation:** Before committing to the `image` library path for dithering, run a spike: load a PNG, convert to grayscale, extract bytes via `Vix.Vips.Image.write_to_binary/1`, confirm format is 8-bit single-channel HWC binary. If yes, the pure Elixir Floyd-Steinberg is straightforward. If the format differs, handle in Phase 3 planning.
- **`image.to_colorspace` API:** STACK.md notes that `:bw` may be `:VIPS_INTERPRETATION_B_W` — verify the exact atom before writing `Papyrus.Bitmap`.
- **Wire protocol tier system:** The `:dual_plane` and `:partial_refresh` command set tiers are design reasoning, not validated against all Waveshare C driver variants. Inspect representative drivers from each tier before finalizing the protocol extension in Phase 1.
- **libvips on Pi 3 (armv7):** `vix` ships prebuilt binaries for `linux-arm64` but not `linux-armv7`. If Pi 3 support is required, `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIB` must be documented and tested.

## Sources

### Primary (HIGH confidence)
- `hexdocs.pm/vix/Vix.Vips.Image.html` — `write_to_binary/1` confirmed
- `hexdocs.pm/chromic_pdf/ChromicPDF.html` — `capture_screenshot/2` PNG support confirmed, v1.17.1
- `hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html` — v0.9.0 configuration options
- `hexdocs.pm/mox/Mox.html` — Mox v1.2.0 concurrent mock patterns
- `hexdocs.pm/stb_image/StbImage.html` — StbImage v0.6.10 PNG/BMP/grayscale support
- `hexdocs.pm/ex_doc/readme.html` — ExDoc v0.40.1
- `hex.pm/docs/publish` — Hex publishing requirements
- `github.com/libvips/libvips/issues/3010` — libvips dithering limitation confirmed
- `hexdocs.pm/nerves/compiling-non-beam-code.html` — ports preferred over NIFs for hardware
- `github.com/rust-embedded-community/epd-waveshare` — model-per-struct + trait dispatch pattern; V2 protocol change issues
- Papyrus v0.1.0 codebase — direct inspection of `display.ex`, `epd_port.c`, `epd12in48/`
- Waveshare C driver source — `EPD_12in48b.c`, dual-plane structure, MSB-first encoding, printf debug pollution
- `erlang.org/doc/system/ports.html` + `hexdocs.pm/elixir/Port.html` — port lifecycle
- `erlangforums.com/t/open-port-and-zombie-processes` — VM-crash zombie confirmation

### Secondary (MEDIUM confidence)
- `hexdocs.pm/image/Image.html` — v0.63.0 API surface; dithering not confirmed via API docs
- `waveshare.com/wiki/E-Paper_API_Analysis` — dual-plane buffer layout for 3-color displays
- `github.com/elixir-circuits/circuits_spi` — test backend / mock backend pattern
- `thoughts.gohu.org/posts/2025/epaper-partial-updates/` — partial refresh pitfalls
- `good-display.com/news/194.html` + `waveshare.com/wiki/E-Paper_Floyd-Steinberg` — dithering recommendations
- `github.com/pappersverk/inky` + Underjord blog — Elixir eInk competitor analysis
- Community threads: Pi memory pressure with Chromium, zombie process workarounds

### Tertiary (LOW confidence)
- `benkrasnow.blogspot.com/2017/10/fast-partial-refresh-on-42-e-paper.html` — partial refresh LUT waveform and mode switching (older hardware, principles likely still apply)
- `webscraping.ai` + Raspberry Pi forums — Chromium memory management flags (community reports, not benchmarks)

---
*Research completed: 2026-03-28*
*Ready for roadmap: yes*
