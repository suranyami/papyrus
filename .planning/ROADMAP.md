# Roadmap: Papyrus

## Overview

Starting from the working v0.1.0 single-display foundation, this roadmap builds Papyrus into a publishable Hex.pm library. Phase 1 extends the `DisplaySpec` contract and hardens the C port so it is the stable foundation everything else targets. Phase 2 establishes hardware-free test infrastructure and the `TestPattern` module — the tools that keep CI green and hardware bring-up reliable throughout. Phase 3 builds the `Papyrus.Bitmap` rendering pipeline in pure Elixir, the highest-value user-facing feature. Phase 4 finalizes documentation, the example app, and Hex.pm packaging so the library is genuinely usable by an Elixir or Nerves developer without library-source archaeology.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: DisplaySpec and C Port Foundation** - Extend `DisplaySpec` with color/pin/partial-refresh fields; harden the C port with stdin-sentinel to prevent zombie processes (completed 2026-03-28)
- [ ] **Phase 2: Test Infrastructure and TestPattern** - Mock port binary for hardware-free CI; `Papyrus.TestPattern` fill patterns; full ExUnit suite; two-tier test taxonomy
- [ ] **Phase 3: Bitmap Rendering Pipeline** - `Papyrus.Bitmap` converts PNG/BMP to packed 1-bit ePaper binary buffers using spec-aware encoding
- [ ] **Phase 4: Documentation and Hex.pm Readiness** - ExDoc guides, `examples/hello_papyrus`, and complete Hex.pm packaging
- [ ] **Phase 5: Hardware SPI Optimization** - Replace bit-banged software SPI with lgpio hardware SPI; reduce bitmap transfer from ~10s to ~150ms

## Phase Details

### Phase 1: DisplaySpec and C Port Foundation
**Goal**: The `DisplaySpec` struct is the complete, stable contract between Elixir and C, and the C port never leaves zombie processes on the host system
**Depends on**: Nothing (first phase)
**Requirements**: DRIVER-01, DRIVER-02
**Success Criteria** (what must be TRUE):
  1. A developer can define a new display model by creating a config module that implements the `DisplaySpec` behaviour — no C code changes required
  2. `Papyrus.DisplaySpec` includes `color_mode`, `pin_config`, and `partial_refresh` fields with documented types and defaults
  3. When the BEAM VM is killed with kill -9, the `epd_port` OS process exits within one select timeout cycle (no zombie device-busy on next start)
  4. The existing 12.48" B&W display continues to work end-to-end with the updated struct and port binary
**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Extend DisplaySpec struct with pin_config, partial_refresh, expanded color_mode type; update Waveshare12in48
- [x] 01-02-PLAN.md — Harden C port with select()-based stdin EOF detection to prevent zombie processes

### Phase 2: Test Infrastructure and TestPattern
**Goal**: Any contributor can run the full ExUnit suite on a Mac or CI runner with no display hardware attached and get a green result
**Depends on**: Phase 1
**Requirements**: TEST-01, TEST-02, TEST-03, PATTERN-01, PATTERN-02, PATTERN-03
**Success Criteria** (what must be TRUE):
  1. `mix test` passes on a machine with no Waveshare hardware attached
  2. `Papyrus.TestPattern.full_white(spec)` returns a correctly-sized all-bits-set binary for any valid `DisplaySpec`
  3. `Papyrus.TestPattern.full_black(spec)` returns a correctly-sized all-bits-clear binary for any valid `DisplaySpec`
  4. `Papyrus.TestPattern.checkerboard(spec)` returns a correctly-sized alternating-byte binary for any valid `DisplaySpec`
  5. The two-tier test taxonomy (CI-safe vs hardware-required) is documented so contributors know which tests require physical hardware
**Plans:** 3 plans

Plans:
- [ ] 02-01-PLAN.md — Extend DisplaySpec with :bit_order and create Papyrus.TestPattern module
- [ ] 02-02-PLAN.md — Create mock port script for hardware-free CI testing
- [ ] 02-03-PLAN.md — Protocol/Display tests, two-tier test taxonomy, REQUIREMENTS.md update

### Phase 3: Bitmap Rendering Pipeline
**Goal**: A developer can convert any PNG or BMP image to a ready-to-display ePaper binary buffer in a single function call
**Depends on**: Phase 2
**Requirements**: BITMAP-01, BITMAP-02
**Success Criteria** (what must be TRUE):
  1. `Papyrus.Bitmap.from_image(path, spec)` returns a 1-bit packed binary buffer whose byte length matches `DisplaySpec` dimensions
  2. `Papyrus.Bitmap.blank(spec)` returns an all-white buffer of the correct size for any `DisplaySpec`
  3. PNG and BMP input formats both load and convert without error
  4. Buffer encoding respects the `DisplaySpec`'s bit order so the image appears correctly oriented on hardware
**Plans**: TBD

### Phase 5: Hardware SPI Optimization
**Goal**: Replace the bit-banged software SPI in `DEV_Config.c` with lgpio hardware SPI so bitmap transfers take ~150ms instead of ~10s
**Depends on**: Phase 4
**Requirements**: TBD
**Success Criteria** (what must be TRUE):
  1. A full clear + display cycle (640k bytes) completes SPI transfer in under 500ms on a Raspberry Pi at 10 MHz
  2. The 4 sub-panel CS pins continue to be asserted correctly per-transfer (GPIO-controlled CS, hardware SPI for data)
  3. All existing display, clear, and sleep operations pass hardware smoke tests
  4. The software SPI path is removed; no regression on non-Linux platforms (compilation still skipped on macOS)

**Background:** `DEV_SPI_WriteByte` is bit-banged — each byte requires 27 `lgGpioWrite()` syscalls (~1–2 µs each), costing ~50 µs/byte. At 320,784 bytes per refresh this takes 5–10 seconds just to transfer data before the panel refresh even starts. Switching to `lgSpiOpen`/`lgSpiWrite` bulk transfers at 10+ MHz would reduce this to ~150ms.
**Plans**: TBD

### Phase 4: Documentation and Hex.pm Readiness
**Goal**: A new Elixir developer can find Papyrus on Hex.pm, add it as a dependency, follow the getting-started guide, and drive their first display
**Depends on**: Phase 3
**Requirements**: DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. `mix docs` generates an ExDoc site with a getting-started guide, hardware wiring instructions, and a display model reference page
  2. `examples/hello_papyrus` compiles and demonstrates the `init → clear → display → sleep` lifecycle with inline comments explaining each step
  3. Adding `{:papyrus, "~> 0.2"}` to a project on a Mac (no lgpio) produces a clear error message pointing to the Raspberry Pi requirement, not a cryptic compile failure
  4. `mix hex.publish` succeeds with `c_src/` and all required files present in the package
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. DisplaySpec and C Port Foundation | 2/2 | Complete   | 2026-03-28 |
| 2. Test Infrastructure and TestPattern | 0/3 | Not started | - |
| 3. Bitmap Rendering Pipeline | 0/? | Not started | - |
| 4. Documentation and Hex.pm Readiness | 0/? | Not started | - |
| 5. Hardware SPI Optimization | 0/? | Not started | - |
