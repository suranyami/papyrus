# Requirements: Papyrus

**Defined:** 2026-03-28
**Core Value:** Any Waveshare ePaper display should be driveable from Elixir in under 10 lines of code, with the hardware abstraction solid enough that adding a new display model requires only a config module — not C code changes.

## v1 Requirements

### Hardware Driver

- [x] **DRIVER-01**: C port binary polls stdin alongside hardware I/O and exits on EOF, preventing zombie processes when the BEAM restarts
- [x] **DRIVER-02**: `Papyrus.DisplaySpec` struct extended with `color_mode`, `pin_config`, and `partial_refresh` fields — stable contract before any new drivers are ported

### Bitmap Rendering

- [ ] **BITMAP-01**: Library converts a PNG or BMP image to a packed 1-bit binary buffer matching a given `DisplaySpec`'s dimensions and bit order
- [ ] **BITMAP-02**: Library generates a blank (all-white) buffer of the correct size for any `DisplaySpec`

### Test Infrastructure

- [x] **TEST-01**: A mock port binary included in `test/support` speaks the length-prefixed protocol, enabling hardware-free CI testing
- [ ] **TEST-02**: ExUnit tests cover `Papyrus.Protocol`, `Papyrus.DisplaySpec`, and `Papyrus.TestPattern` with no hardware required
- [ ] **TEST-03**: Two-tier test taxonomy documented: CI (mock port) tests vs hardware-verified checklist

### Test Patterns

- [x] **PATTERN-01**: `Papyrus.TestPattern` produces a full-white buffer for any `DisplaySpec`
- [x] **PATTERN-02**: `Papyrus.TestPattern` produces a full-black buffer for any `DisplaySpec`
- [x] **PATTERN-03**: `Papyrus.TestPattern` produces a checkerboard buffer for any `DisplaySpec`

### Documentation & Packaging

- [ ] **DOCS-01**: ExDoc API docs generated with getting-started, hardware setup, and display model reference guides
- [ ] **DOCS-02**: Hex.pm package configured with `make_error_message` for missing `liblgpio`, `c_src/` in package files
- [ ] **DOCS-03**: `examples/hello_papyrus` demonstrates basic `init → clear → display → sleep` flow

## v2 Requirements

Deferred to the next milestone. These depend on v1's stable `DisplaySpec` contract and C port dispatch table.

### Multi-Display Driver

- **MDRIVER-01**: C port binary uses a runtime dispatch table — a single `epd_port` binary supports all model families, selected by an init payload from Elixir
- **MDRIVER-02**: Representative set of Waveshare drivers ported, covering all major variant types: B&W, 3-color (red/yellow), 4-gray grayscale, partial refresh
- **MDRIVER-03**: Display abstraction tier system designed before porting: `:standard` (config-only), `:dual_plane` (3-color), `:partial_refresh` (fast update)

### Extended Rendering

- **RENDER-01**: Floyd-Steinberg dithering applied when converting grayscale images to 1-bit ePaper buffer (custom Elixir implementation — no library covers this)
- **RENDER-02**: 3-color (red/yellow accent) encoding: dual-plane buffer split (black plane + color plane) for `color_mode: :three_color` displays
- **RENDER-03**: 4-gray grayscale encoding: 2-bit pixel packing for `color_mode: :four_gray` displays
- **RENDER-04**: HTML → bitmap rendering via headless Chromium: render HTML to PNG screenshot, convert to ePaper buffer; optional `chromic_pdf` dependency

### Extended Test Patterns

- **EPATTERN-01**: `Papyrus.TestPattern` produces a border/bounding-box buffer verifying edge pixels are addressed at the full display resolution
- **EPATTERN-02**: `Papyrus.TestPattern` produces a gray ramp buffer for `color_mode: :four_gray` displays
- **EPATTERN-03**: `Papyrus.TestPattern` produces a color-layer test buffer for `color_mode: :three_color` displays
- **EPATTERN-04**: `Papyrus.TestPattern` produces a text/font probe buffer rendered via the Bitmap pipeline

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom bitmap font renderer | Headless browser handles text rendering; a bespoke font engine is not worth the scope |
| Non-Waveshare display drivers | Abstraction should be generic enough to support other vendors, but no bundles in v1 or v2 |
| Video / animation | ePaper refresh cycles (1–30s) make animation impractical |
| Nerves firmware packaging helpers | Consuming app's responsibility; out of library scope |
| Partial refresh in v1 | High complexity, ghosting/timing bugs well-documented; must defer until stable dual-plane dispatch exists |
| NIF-based driver | Port crash isolation is a deliberate architectural choice; NIF segfault kills the VM |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DRIVER-01 | Phase 1 | Complete |
| DRIVER-02 | Phase 1 | Complete |
| TEST-01 | Phase 2 | Complete |
| TEST-02 | Phase 2 | Pending |
| TEST-03 | Phase 2 | Pending |
| PATTERN-01 | Phase 2 | Complete |
| PATTERN-02 | Phase 2 | Complete |
| PATTERN-03 | Phase 2 | Complete |
| BITMAP-01 | Phase 3 | Pending |
| BITMAP-02 | Phase 3 | Pending |
| DOCS-01 | Phase 4 | Pending |
| DOCS-02 | Phase 4 | Pending |
| DOCS-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after roadmap creation*
