# Papyrus

## What This Is

Papyrus is a public Elixir/Nerves library for driving Waveshare ePaper/eInk displays via supervised OS port processes. It provides hardware drivers for 40+ display models, a bitmap rendering pipeline, an HTML-to-bitmap rendering path (via headless browser), and built-in visual test patterns for hardware verification. The target audience is Elixir and Nerves developers building dashboards, signage, and IoT devices with ePaper displays.

## Core Value

Any Waveshare ePaper display should be driveable from Elixir in under 10 lines of code, with the hardware abstraction solid enough that adding a new display model requires only a config module — not C code changes.

## Requirements

### Validated

- ✓ Port-based GenServer driver for Waveshare 12.48" (B&W) — v0.1.0
- ✓ Binary protocol (length-prefixed stdin/stdout) between BEAM and C port — v0.1.0
- ✓ `Papyrus.DisplaySpec` behaviour for describing display models — v0.1.0
- ✓ Supervised port restart on hardware fault (port crash isolation) — v0.1.0

### Active

**Driver abstraction & multi-display support**
- [ ] Refactor C port to support multiple display families via a config-driven approach (width, height, pin assignments, command bytes as parameters rather than compile-time constants)
- ✓ `Papyrus.DisplaySpec` struct extended with `pin_config` (enforce_keys), `partial_refresh`, and `color_mode: :three_color` — stable Elixir↔C contract — Phase 1 (2026-03-28)
- ✓ C port `epd_port` hardened with `select()`-based stdin EOF detection — no zombie processes on BEAM restart — Phase 1 (2026-03-28)
- [ ] Define Elixir-side display config struct covering all variant dimensions: resolution, buffer format, color mode (B&W / 3-color / 4-gray), partial refresh capability, pin assignments
- [ ] Port a representative set of Waveshare drivers covering all major variants: standard B&W, 3-color (red/yellow), 4-gray, partial-refresh capable

**Rendering pipeline**
- [ ] `Papyrus.Bitmap` — convert common image formats (PNG, BMP) to ePaper buffer binary (1-bit, 2-bit, 3-color)
- [ ] `Papyrus.Renderer.Headless` — HTML → bitmap via headless Chromium; works both on Raspberry Pi and as a remote renderer pushing bitmaps over the network
- [ ] Dithering support for converting grayscale images to 1-bit and 4-gray formats

**Test patterns**
- ✓ `Papyrus.TestPattern` — `full_white/1`, `full_black/1`, `checkerboard/1` with `:bit_order` awareness — Phase 2 (2026-03-29)
- [ ] Border/edge, gray ramp, color layer, text/font probe patterns (v2)

**Library quality (Hex.pm readiness)**
- ✓ ExUnit test suite: 72 tests, 0 failures on macOS with no hardware — Protocol, DisplaySpec, Display (mock port), TestPattern — Phase 2 (2026-03-29)
- ✓ Mock port (`test/support/mock_port_script.exs`) with configurable per-test responses — Phase 2 (2026-03-29)
- ✓ Two-tier test taxonomy (CI-safe vs hardware-required) documented in TESTING.md — Phase 2 (2026-03-29)
- [ ] ExDoc documentation with getting-started guide, hardware setup, and display model reference
- [ ] Working `examples/hello_papyrus` example app

### Out of Scope

- **Custom font rendering engine** — use system fonts via the headless browser path; a bespoke bitmap font renderer is not worth the scope for v1
- **Non-Waveshare displays** — the abstraction should be generic enough to support other vendors, but no other vendor drivers will be bundled in v1
- **Video / animation** — ePaper refresh cycles (1–30s) make animation impractical; out of scope entirely
- **Nerves integration helpers** — Nerves-specific config (target board, firmware packaging) is the consuming app's responsibility, not the library's

## Context

- **Existing code:** `papyrus 0.1.0` is complete — `Papyrus.Display` GenServer, `Papyrus.Protocol`, `Papyrus.DisplaySpec` behaviour, `Papyrus.Displays.Waveshare12in48`, and `c_src/epd_port.c` (init/display/clear/sleep over stdin/stdout via liblgpio)
- **Driver source:** ~40+ Waveshare C driver sources exist in a separate repo (`~/development/projects/12.48inch_e-Paper_Module_Code_RPI` and related). Drivers are a mix: most share the same logic with different constants (resolution, pin assignments, command bytes), but color modes (3-color, 4-gray) and partial refresh add genuine structural differences
- **Hardware:** Primary test hardware is the Waveshare 12.48" B&W panel on Raspberry Pi. Rendering target is flexible — headless browser can run on-device or on a separate machine pushing bitmaps
- **Why port not NIF:** Display refreshes take 1–30s and involve hardware I/O that can fault. Port crash isolation is a deliberate design choice — a C crash kills only the OS process, not the BEAM VM

## Constraints

- **Tech stack:** Elixir + C (via `elixir_make`); no NIFs; no Rust; liblgpio for GPIO/SPI on Raspberry Pi
- **C compilation:** Must compile on the target (Raspberry Pi / Nerves); cross-compilation is the consuming project's concern
- **HTML rendering:** Headless browser dependency (Chromium) is optional — `Papyrus.Renderer.Headless` should be an opt-in dependency, not required for basic display use
- **Hex.pm packaging:** `c_src/` must be included in the package so consumers compile the C port themselves; pre-built binaries are not distributed

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Port process, not NIF | Hardware faults must not crash the BEAM VM; display refreshes are inherently slow and blocking anyway | ✓ Good |
| `elixir_make` for C compilation | Standard Nerves/Elixir approach; integrates cleanly with Mix | ✓ Good |
| `liblgpio` for GPIO/SPI | Modern lgpio API; replaces deprecated wiringPi and bcm2835 | — Pending |
| Single C binary dispatches all commands | Simpler supervision model; one port per display, not one port per command type | ✓ Good |
| Config-driven display abstraction | 40+ drivers with mostly-shared logic — parameterise constants, subclass for structural differences | — Pending |

---
*Last updated: 2026-03-29 after Phase 2 completion — 72-test suite green on macOS, TestPattern implemented, two-tier test taxonomy established*
