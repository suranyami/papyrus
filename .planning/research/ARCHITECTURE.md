# Architecture Research

**Domain:** Elixir ePaper hardware driver library with rendering pipeline
**Researched:** 2026-03-28
**Confidence:** HIGH (based on existing codebase inspection + verified ecosystem patterns)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Consumer Application                         │
│           (Nerves firmware, Phoenix dashboard, etc.)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Elixir API calls
┌──────────────────────────▼──────────────────────────────────────┐
│                    Rendering Layer (pure Elixir)                  │
├──────────────────┬────────────────────┬─────────────────────────┤
│ Papyrus.Bitmap   │ Papyrus.TestPattern│ Papyrus.Renderer.       │
│ (PNG/BMP → buf) │ (built-in patterns)│ Headless (HTML → buf)   │
└──────────────────┴────────────────────┴─────────────────────────┘
         │ raw binary buffer (display-model-specific format)
┌────────▼────────────────────────────────────────────────────────┐
│                   Driver Layer (Elixir + C)                       │
├──────────────────────────┬──────────────────────────────────────┤
│   Papyrus.Display        │   Papyrus.DisplaySpec behaviour       │
│   (GenServer, 1 per      │   + display config modules            │
│    display instance)     │   (Waveshare12in48, etc.)             │
└──────────────────────────┴──────────────────────────────────────┘
         │ length-prefixed binary protocol over stdin/stdout
         │ (Port.open, :spawn_executable)
┌────────▼────────────────────────────────────────────────────────┐
│                   C Port Binary (epd_port)                        │
│   - Reads config/init payload from Elixir on startup             │
│   - Runtime dispatch: routes commands to correct EPD driver       │
│   - Links: liblgpio (GPIO/SPI), per-model Waveshare C sources     │
├────────────────────────────────────────────────────────────────-─┤
│  waveshare/epd12in48/   waveshare/epd2in13/   waveshare/epd7in5/ │
│  (EPD_xxx.c + DEV_Config.c per family)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Papyrus.Display` | GenServer owning the OS port; serializes all commands; crash isolation | `epd_port` C binary via stdin/stdout |
| `Papyrus.DisplaySpec` | Behaviour + struct describing a display model (dimensions, color_mode, buffer_size) | Used by `Display` to validate buffers; used by `Bitmap` to produce correct format |
| `Papyrus.Displays.*` | One module per supported display model; returns a `%DisplaySpec{}` | Consumed by `Display.start_link/1` |
| `Papyrus.Protocol` | Binary encode/decode for the port wire format | Used by `Display` internally |
| `epd_port` (C) | Dispatches init/display/clear/sleep to correct hardware driver; owns all GPIO/SPI state | Hardware via liblgpio |
| `Papyrus.Bitmap` | Converts PNG/BMP → display buffer binary; applies dithering | `Papyrus.DisplaySpec` for target format |
| `Papyrus.TestPattern` | Generates known-good buffers (checkerboard, fill, gray ramp, color layer) | `Papyrus.DisplaySpec` for dimensions |
| `Papyrus.Renderer.Headless` | Drives headless Chromium to render HTML → PNG → display buffer | `Papyrus.Bitmap` for final conversion |

## Recommended Project Structure

```
papyrus/
├── lib/papyrus/
│   ├── display.ex              # GenServer; port lifecycle; API surface
│   ├── display_spec.ex         # Behaviour + struct
│   ├── protocol.ex             # Wire format encode/decode
│   ├── displays/               # One module per supported model
│   │   ├── waveshare_12in48.ex
│   │   ├── waveshare_7in5.ex
│   │   ├── waveshare_2in13.ex
│   │   └── ...
│   ├── bitmap.ex               # Image → buffer conversion + dithering
│   ├── test_pattern.ex         # Built-in verification patterns
│   └── renderer/
│       └── headless.ex         # Optional: HTML → bitmap via Chromium
├── c_src/
│   ├── epd_port.c              # Main port binary; dispatch loop
│   ├── epd_registry.c/.h       # Driver dispatch table (model ID → fn ptrs)
│   ├── waveshare/
│   │   ├── epd12in48/          # EPD_12in48.c, DEV_Config.c, headers
│   │   ├── epd7in5/
│   │   ├── epd2in13/
│   │   └── ...
│   └── Makefile
├── test/
│   ├── papyrus/
│   │   ├── display_test.exs    # Uses mock port binary
│   │   ├── protocol_test.exs   # Pure binary encode/decode
│   │   ├── bitmap_test.exs     # Pure Elixir, no hardware
│   │   └── test_pattern_test.exs
│   └── support/
│       └── mock_port/          # Simple C binary for test stubs
│           └── mock_epd_port.c
└── priv/
    └── epd_port                # Built by elixir_make
```

### Structure Rationale

- **`lib/papyrus/displays/`:** One module per model enforces single source of truth for dimensions, buffer math, and color mode. Adding a display model means adding exactly one file.
- **`c_src/epd_registry.c`:** A single dispatch table in C (model ID → init/display/clear/sleep function pointers) means `epd_port.c` stays simple and model support is additive, not a branch cascade.
- **`test/support/mock_port/`:** A standalone C binary that speaks the same protocol but writes garbage-safe responses — allows `Papyrus.Display` GenServer logic to be tested without hardware.

## Architectural Patterns

### Pattern 1: Config-as-Init-Payload (Recommended for multi-model C port)

**What:** The Elixir `Display` GenServer sends a structured init message to `epd_port` *before* the normal command loop. The payload contains a model identifier (integer) and any model-specific parameters. The C binary uses this to select the correct driver at runtime.

**When to use:** When a single binary must support 40+ models with different command sequences but a shared protocol and GPIO stack.

**Trade-offs:** One binary, simple supervision. Adds a new command (`0x00: init_with_config`) to the protocol. The C binary must link all driver sources, increasing binary size. For Nerves (where binary size matters less), this is acceptable.

**Concrete design:**

```
Protocol addition:
  0x00  configure  [4 bytes: model_id][optional model params]

C side:
  typedef struct {
    int  (*init)(void);
    void (*display)(const uint8_t *bw_buf, const uint8_t *color_buf);
    void (*clear)(void);
    void (*sleep)(void);
    uint32_t buffer_size;
  } EPDDriver;

  static const EPDDriver epd_registry[] = {
    [MODEL_12IN48]    = { EPD_12in48_Init, epd_display_bw,  ... },
    [MODEL_12IN48B]   = { EPD_12in48B_Init, epd_display_bw_red, ... },
    [MODEL_7IN5_V2]   = { EPD_7in5V2_Init, epd_display_bw, ... },
    ...
  };
```

The `display` function pointer signature uses two buffers (`bw_buf`, `color_buf`). For B&W displays, `color_buf` is NULL and the driver ignores it. For 3-color displays, both are used. This unifies the wire protocol: the `display` command always sends two buffers; B&W displays simply send zero bytes for the second.

**Alternative considered and rejected:** Separate binary per model. Simpler C, but requires one supervised port process per model family and a registry in Elixir. Increases complexity when a single device is in play. The single-binary approach matches the existing v0.1.0 design intent.

### Pattern 2: Behaviour + Config Struct (Elixir display abstraction)

**What:** Extend `Papyrus.DisplaySpec` to carry all variant dimensions needed by Elixir-side components (rendering, validation, test pattern generation). The C model ID is included in the struct so `Display` can send it on init.

**When to use:** Always — this is the existing pattern to extend, not replace.

**Extended struct:**

```elixir
defstruct [
  :model,          # atom, human name
  :c_model_id,     # integer, index into epd_registry[] in C
  :width,
  :height,
  :buffer_size,    # bytes for primary (B&W) buffer
  :color_buffer_size,  # bytes for accent (red/yellow) buffer; 0 for B&W
  color_mode: :black_white,    # :black_white | :three_color | :four_gray
  partial_refresh: false,
  refresh_seconds: 15,         # typical full refresh time, informational
]
```

**Trade-offs:** Minimal. The struct is data — adding fields is backward-compatible. Display modules remain one file each, easy to add.

### Pattern 3: Rendering Pipeline as Pure Elixir (separated from hardware)

**What:** All image processing (PNG decode, dithering, buffer packing) lives entirely in Elixir, producing a raw binary that `Display.display/2` accepts. `Papyrus.Bitmap` and `Papyrus.TestPattern` have no knowledge of the port.

**When to use:** Always for Papyrus. This is the correct separation.

**Why this matters:**
- Bitmap and TestPattern modules can be tested entirely without hardware using ordinary ExUnit.
- The rendering pipeline can run on a dev machine and the buffer can be sent over the network to a Raspberry Pi (the headless renderer remote-push use case from PROJECT.md).
- Adding a new rendering source (e.g., a custom drawing API) does not touch the C layer.

**Trade-offs:** Dithering in pure Elixir is slower than C, but for ePaper displays (which refresh in 1-30s and use small-to-moderate buffers) the performance is not a bottleneck. The 12.48" panel's buffer is ~160KB; Floyd-Steinberg on that in Elixir should complete in well under a second.

**Image library recommendation:** Use the `image` hex package (wraps libvips via `vix`). Libvips supports Floyd-Steinberg dithering via its quantization pipeline, and `Image.to_nx/2` or `Image.to_list/1` can extract raw pixel data. This is MEDIUM confidence — the `image` library exposes most of libvips's capabilities but the exact dithering API needs validation against the current hex version before committing to it. Pure Elixir fallback using Nx directly is viable if libvips dithering is not accessible via the `image` wrapper.

### Pattern 4: Mock Port Binary for ExUnit

**What:** A minimal C program (`test/support/mock_port/mock_epd_port.c`) that speaks the same stdin/stdout protocol as the real `epd_port` but always responds `:ok` without touching hardware. `Papyrus.Display` already accepts a `:port_binary` option — the test suite uses this to point at the mock binary.

**When to use:** All `Papyrus.Display` GenServer tests.

**Concrete setup:**

```elixir
# In test/support/mock_port/mock_epd_port.c:
# Reads any command, responds 0x00 (ok) + 4-byte zero + empty msg.
# Compiled by a test helper or by a separate make target.

# In test:
start_supervised!({Papyrus.Display, [
  display_module: Papyrus.Displays.Waveshare12in48,
  port_binary: "test/support/mock_port/mock_epd_port",
  name: :test_display
]})
```

**Trade-offs:** Requires compiling the mock binary. This is acceptable — it is a trivial C program (~50 lines) and can be compiled by the test setup or a Mix task. The alternative (Mox + behaviour injection) is more complex and loses coverage of the actual port communication logic.

## Data Flow

### Flow 1: Normal Image Display

```
Consumer
  │  Papyrus.Bitmap.from_png(path, spec)
  ▼
Papyrus.Bitmap
  │  1. Decode PNG via `image` library (libvips)
  │  2. Resize to spec.width × spec.height
  │  3. Apply dithering (Floyd-Steinberg via libvips quantization)
  │  4. Pack pixels into 1-bit (B&W) or 2-bit (4-gray) binary
  │  5. Return {:ok, {bw_buffer, color_buffer}} | {:error, reason}
  ▼
Consumer
  │  Papyrus.Display.display(display_pid, bw_buf, color_buf)
  ▼
Papyrus.Display (GenServer)
  │  1. Validate buffer sizes against spec
  │  2. Protocol.encode_request(:display, <<bw_buf::binary, color_buf::binary>>)
  │  3. Port.command(port, encoded)
  │  4. {:noreply, %{pending_from: caller}}
  ▼
epd_port (OS process)
  │  1. Read header + payload
  │  2. Dispatch to epd_registry[model_id].display(bw_ptr, color_ptr)
  │  3. Hardware refresh (1-30s)
  │  4. write_exact(ok_response)
  ▼
Papyrus.Display (handle_info)
  │  Protocol.decode_response(chunk) → {:ok, _}
  │  GenServer.reply(pending_from, :ok)
  ▼
Consumer ← :ok
```

### Flow 2: HTML → Display (Headless Renderer)

```
Consumer
  │  Papyrus.Renderer.Headless.render(url_or_html, display_pid)
  ▼
Papyrus.Renderer.Headless
  │  1. Get spec from Papyrus.Display.spec(display_pid)
  │  2. Launch Chromium via System.cmd or Port (viewport = spec dimensions)
  │  3. Capture PNG screenshot
  │  4. Pass PNG binary to Papyrus.Bitmap.from_png_binary(png, spec)
  │  5. Call Papyrus.Display.display(display_pid, bw_buf, color_buf)
  ▼
(same as Flow 1 from Display onward)
```

### Flow 3: Display Initialization (startup)

```
Consumer / Supervisor
  │  Papyrus.Display.start_link([display_module: Waveshare12in48, ...])
  ▼
Papyrus.Display.init/1
  │  1. Call display_module.spec() → %DisplaySpec{}
  │  2. Port.open(:spawn_executable, port_binary_path, [:binary, :exit_status, :use_stdio])
  │  3. send_command(state, :configure, <<spec.c_model_id::32>>)
  │  4. Wait for ok response (synchronous in init)
  │  5. send_command(state, :init, <<>>)
  │  6. Wait for ok response
  ▼
{:ok, state} or {:stop, reason}
```

### Flow 4: Test Pattern Generation

```
Consumer
  │  Papyrus.TestPattern.checkerboard(spec)
  ▼
Papyrus.TestPattern (pure Elixir)
  │  1. Use spec.width, spec.height, spec.color_mode
  │  2. Generate packed binary directly (no image library needed)
  │  3. Return {:ok, {bw_buffer, color_buffer}}
  ▼
Consumer
  │  Papyrus.Display.display(display_pid, bw_buf, color_buf)
```

## Build Order

The dependency graph between components determines what must be built first.

```
Tier 1 (no dependencies, build first):
  ├── Papyrus.Protocol           (pure binary encode/decode)
  └── Papyrus.DisplaySpec        (struct + behaviour definition)

Tier 2 (depends on Tier 1):
  ├── Papyrus.Displays.*         (implement DisplaySpec behaviour)
  └── epd_port C binary          (needs DisplaySpec's c_model_id concept locked)
      ├── epd_registry (dispatch table)
      └── Waveshare C driver sources (compiled in)

Tier 3 (depends on Tier 1 + 2):
  └── Papyrus.Display            (GenServer; needs Protocol + DisplaySpec + epd_port working)

Tier 4 (depends on Tier 3):
  └── Papyrus.TestPattern        (needs DisplaySpec; can be parallel with Display)
  └── ExUnit test suite          (needs Display + mock port binary)

Tier 5 (depends on Tier 3 + 4):
  └── Papyrus.Bitmap             (pure Elixir; needs DisplaySpec; image library integration)

Tier 6 (depends on Tier 5):
  └── Papyrus.Renderer.Headless  (needs Bitmap; optional Chromium dependency)
```

**Recommended milestone sequence:**

1. **DisplaySpec + Protocol + C port refactor:** Lock the extended struct (with `c_model_id`, `color_buffer_size`, `partial_refresh`). Refactor `epd_port.c` with the dispatch table. Validate on the 12.48" hardware. Add 2-3 additional model families (e.g., a 7.5" B&W, a 2.9" 3-color) to prove the dispatch mechanism. This is the riskiest piece — hardware availability determines pace.

2. **TestPattern + ExUnit suite:** TestPattern is pure Elixir. The mock port binary can be written alongside the C refactor. Once both exist, the test suite scaffolding (Protocol tests, TestPattern tests, Display GenServer tests with mock) can be fully built. These can be developed in parallel with hardware driver work.

3. **Bitmap + image library integration:** Depends on DisplaySpec being stable (buffer format must be known). The `image` library integration for PNG decode and dithering is pure Elixir work, no hardware needed. This is the largest pure-software milestone.

4. **Headless renderer:** Depends on Bitmap. Chromium integration is the most optional and most ops-heavy piece. Defer to last.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Chromium/Chromium headless | `System.cmd/3` or `Port.open/2` to `chromium --headless --screenshot` | Optional dependency; must not be required for basic display use. Isolate behind `Papyrus.Renderer.Headless` module. Document installation separately. |
| libvips (via `image` hex package) | Compile-time dep via `vix` NIF | This is a NIF, not a port — acceptable for image processing since a crash here does not affect the display port. libvips is available on Raspberry Pi via apt. |
| liblgpio | Linked into `epd_port` C binary at compile time | Must be installed on target (`apt install liblgpio-dev`). Not a BEAM-layer dependency. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Bitmap` / `Renderer.Headless` → `Display` | `Display.display/3` public API (raw buffer binary) | Renderers produce buffers; they never touch the port directly |
| `Display` ↔ `epd_port` | Binary protocol over stdin/stdout | Protocol is the contract; both sides must agree on byte layout |
| `Displays.*` → `Display` | `spec()` call at `start_link` | Display modules are pure data; they don't hold state |
| `TestPattern` → `DisplaySpec` | Struct field access | TestPattern reads `width`, `height`, `color_mode` to generate correct buffers |

## Anti-Patterns

### Anti-Pattern 1: Multiple Port Binaries (one per display model)

**What people do:** Compile a separate `epd_port_12in48`, `epd_port_7in5`, etc. and select the binary at runtime.

**Why it's wrong:** Doubles the supervision complexity. Requires one binary per model stored in `priv/`. Cross-compilation must be repeated for each binary. Offers no real isolation benefit since the hardware is serialized anyway (one display at a time on a single SPI bus).

**Do this instead:** Single binary with a dispatch table. Model identity is communicated via the init payload.

### Anti-Pattern 2: NIFs for Display Commands

**What people do:** Use Elixir NIFs to call libgpio/SPI functions directly, avoiding the port overhead.

**Why it's wrong:** A NIF crash kills the BEAM VM. Display hardware on Raspberry Pi is prone to faults (loose wiring, incorrect voltage, driver bugs). The existing v0.1.0 architecture explicitly chose ports for crash isolation — this is the right call for hardware I/O that takes 1-30s and can fault.

**Do this instead:** Keep the port architecture. Use NIFs only for pure computation (image processing via libvips is acceptable since it doesn't touch hardware).

### Anti-Pattern 3: Image Processing in C (inside epd_port)

**What people do:** Add PNG decode, dithering, or resizing to the C port binary to avoid sending large buffers over stdin/stdout.

**Why it's wrong:** Moves pure-computation logic into a crash-critical process. Makes testing impossible without hardware. The performance argument is weak — a 160KB buffer write on localhost is fast. Image processing bugs in C cause port crashes; the same bugs in Elixir are catchable exceptions.

**Do this instead:** All image processing in Elixir (`Papyrus.Bitmap`). Send the finished, packed binary to the C port.

### Anti-Pattern 4: Hardcoding Buffer Sizes in the C Port

**What people do:** `#define BUFFER_SIZE (163 * 984)` at compile time (as in the current v0.1.0).

**Why it's wrong:** Makes the binary single-model. Every display model has a different buffer size.

**Do this instead:** The C port reads `buffer_size` from the init payload and uses `malloc(buffer_size)` for the image buffer. The Elixir side (via `DisplaySpec.buffer_size`) is authoritative on buffer size; the C side trusts the value it receives.

### Anti-Pattern 5: Testing `Papyrus.Display` by Stubbing Protocol (Mox)

**What people do:** Use Mox to mock `Papyrus.Protocol` so the GenServer never actually opens a port.

**Why it's wrong:** This tests the mock, not the GenServer's port lifecycle, crash handling, or buffer streaming. The most important behaviors — port crash recovery, incomplete message buffering, async reply sequencing — are untestable this way.

**Do this instead:** Use a real `mock_epd_port` binary that speaks the full wire protocol. The GenServer logic is exercised end-to-end; only the hardware driver calls are stubbed out. This is the approach `Papyrus.Display` already supports via the `:port_binary` option.

## Scaling Considerations

This is an embedded library; "scaling" means supporting more display models and more concurrent displays, not more users.

| Concern | Current (1 display) | 40+ models | Multiple concurrent displays |
|---------|---------------------|------------|------------------------------|
| Port binary | Single binary, 1 model | Same binary, dispatch table | One port process per display instance; Supervisor handles all |
| Buffer memory | 1 × ~160KB in C | Same; dynamically allocated from init payload size | Each port owns its own `malloc`'d buffer |
| Elixir test suite | Mock port binary | Same approach; model config is data | Start one GenServer per display in test, using mock binary |
| Compilation time | Fast (2 C files) | Grows linearly with model sources | Not affected |

## Sources

- Existing `papyrus 0.1.0` codebase — `lib/papyrus/display.ex`, `c_src/epd_port.c`, `c_src/waveshare/epd12in48/` (direct inspection)
- Waveshare 12.48" driver repo — `lib/e-Paper/EPD_12in48b.h` showing 3-color `Display(blackimage, redimage)` vs. B&W `Display(image)` API difference (direct inspection)
- [Waveshare E-Paper API Analysis](https://www.waveshare.com/wiki/E-Paper_API_Analysis) — confirmed B&W vs. 3-color function signature split (MEDIUM confidence — Waveshare wiki)
- [epd-waveshare Rust library](https://github.com/rust-embedded-community/epd-waveshare) — confirmed model-per-struct + trait dispatch pattern as the standard approach (HIGH confidence)
- [Nerves: Compiling Non-BEAM Code](https://hexdocs.pm/nerves/compiling-non-beam-code.html) — ports preferred over NIFs for hardware (HIGH confidence)
- [Elixir Circuits SPI](https://github.com/elixir-circuits/circuits_spi) — confirmed test backend / mock backend pattern as idiomatic in the Nerves ecosystem (MEDIUM confidence)
- [image hex library](https://hexdocs.pm/image/Image.html) — libvips wrapper; supports dithering via quantization pipeline; exact API for 1-bit packing needs validation (MEDIUM confidence)
- Elixir Forum discussion on port binary testing — confirmed configurable `:port_binary` path as the idiomatic approach for hardware stub testing (MEDIUM confidence)

---
*Architecture research for: Papyrus — Elixir ePaper driver library*
*Researched: 2026-03-28*
