# Roadmap: Papyrus

## Overview

Starting from the working v0.1.0 single-display foundation, this roadmap builds Papyrus into a publishable Hex.pm library. Phase 1 extends the `DisplaySpec` contract and hardens the C port so it is the stable foundation everything else targets. Phase 2 establishes hardware-free test infrastructure and the `TestPattern` module — the tools that keep CI green and hardware bring-up reliable throughout. Phase 3 builds the `Papyrus.Bitmap` rendering pipeline in pure Elixir, the highest-value user-facing feature. Phase 4 finalizes documentation, the example app, and Hex.pm packaging so the library is genuinely usable by an Elixir or Nerves developer without library-source archaeology.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: DisplaySpec and C Port Foundation** - Extend `DisplaySpec` with color/pin/partial-refresh fields; harden the C port with stdin-sentinel to prevent zombie processes
- [ ] **Phase 2: Test Infrastructure and TestPattern** - Mock port binary for hardware-free CI; `Papyrus.TestPattern` fill patterns; full ExUnit suite; two-tier test taxonomy
- [ ] **Phase 3: Bitmap Rendering Pipeline** - `Papyrus.Bitmap` converts PNG/BMP to packed 1-bit ePaper binary buffers using spec-aware encoding
- [ ] **Phase 4: Documentation and Hex.pm Readiness** - ExDoc guides, `examples/hello_papyrus`, and complete Hex.pm packaging

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
**Plans**: TBD

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
**Plans**: TBD

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
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. DisplaySpec and C Port Foundation | 0/? | Not started | - |
| 2. Test Infrastructure and TestPattern | 0/? | Not started | - |
| 3. Bitmap Rendering Pipeline | 0/? | Not started | - |
| 4. Documentation and Hex.pm Readiness | 0/? | Not started | - |
