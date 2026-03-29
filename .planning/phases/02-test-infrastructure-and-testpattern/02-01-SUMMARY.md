---
phase: 02-test-infrastructure-and-testpattern
plan: "01"
subsystem: display-spec-and-test-pattern
tags: [display-spec, bit-order, test-pattern, tdd]
dependency_graph:
  requires: []
  provides: [bit_order_field, TestPattern_module]
  affects: [lib/papyrus/display_spec.ex, lib/papyrus/displays/waveshare_12in48.ex, lib/papyrus/test_pattern.ex]
tech_stack:
  added: []
  patterns: [TDD red-green, pattern-matching on struct fields for dispatch, :binary.copy/2 for buffer generation]
key_files:
  created:
    - lib/papyrus/test_pattern.ex
    - test/papyrus/test_pattern_test.exs
  modified:
    - lib/papyrus/display_spec.ex
    - lib/papyrus/displays/waveshare_12in48.ex
    - test/papyrus/display_spec_test.exs
    - test/papyrus/displays/waveshare_12in48_test.exs
decisions:
  - ":bit_order enforced on DisplaySpec — every display module must declare pixel polarity; no silent wrong-color buffers"
  - "checkerboard/1 is bit_order-agnostic — it tests pixel addressing, not color semantics; same 0xAA/0x55 pattern regardless of display polarity"
metrics:
  duration_minutes: 4
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_modified: 6
---

# Phase 02 Plan 01: DisplaySpec bit_order + Papyrus.TestPattern Summary

**One-liner:** `:bit_order` enforce_key added to DisplaySpec (`:white_high`/`:white_low`) enabling `Papyrus.TestPattern` to generate correct white, black, and checkerboard buffers for any display.

## Objective

Extend `DisplaySpec` with `:bit_order` (the pixel polarity field that distinguishes 0xFF=white from 0x00=white displays), update the Waveshare12in48 spec to declare `:white_high`, implement the three core test patterns, and ensure the full test suite passes on macOS without hardware.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add :bit_order to DisplaySpec and update Waveshare12in48 | 9445ba5 | display_spec.ex, waveshare_12in48.ex, display_spec_test.exs, waveshare_12in48_test.exs |
| 2 | Create Papyrus.TestPattern with full_white/1, full_black/1, checkerboard/1 | 196ebab | test_pattern.ex, test_pattern_test.exs |

## What Was Built

### Task 1: :bit_order field

`lib/papyrus/display_spec.ex`:
- Added `:bit_order` to `@enforce_keys` — compile-time + runtime enforcement
- Added `@type bit_order :: :white_high | :white_low` with typedoc explaining polarity semantics
- Added `bit_order: bit_order()` to `@type t`
- Updated moduledoc to document the field

`lib/papyrus/displays/waveshare_12in48.ex`:
- Added `bit_order: :white_high` to the `spec/0` return struct

Test updates:
- `@valid_attrs` in display_spec_test.exs gains `bit_order: :white_high`
- New tests: omitting bit_order raises ArgumentError, bit_order can be :white_low
- Fixed stale assertion: `color_mode == :black_white` corrected to `color_mode == :three_color` in waveshare_12in48_test.exs
- New test: `bit_order is :white_high` in waveshare_12in48_test.exs

### Task 2: Papyrus.TestPattern

`lib/papyrus/test_pattern.ex`:
- `full_white/1` — pattern-matches on `bit_order: :white_high` -> `:binary.copy(<<0xFF>>, size)`; `:white_low` -> `<<0x00>>`
- `full_black/1` — inverse: `:white_high` -> `<<0x00>>`; `:white_low` -> `<<0xFF>>`
- `checkerboard/1` — alternating `0xAA/0x55` pairs; handles odd buffer_size with trailing `0xAA`; bit_order-agnostic

`test/papyrus/test_pattern_test.exs`:
- 17 tests covering: both bit_order variants for full_white and full_black, exact byte value checks, even/odd buffer sizes, integration with real Waveshare12in48 spec, bit_order-agnostic checkerboard verification

## Test Results

```
43 tests, 0 failures
```

All tests pass on macOS (no hardware required).

## Decisions Made

1. **`:bit_order` is enforced, not optional** — every display module must declare pixel polarity. Silent wrong-color buffers would be worse than a compile-time error when adding a new display model.

2. **`checkerboard/1` ignores `bit_order`** — checkerboard tests pixel addressing and bit-level patterns (0xAA = 10101010, 0x55 = 01010101), not white/black semantics. The same byte pattern serves both polarity conventions equally.

3. **`:binary.copy/2` for buffer generation** — more efficient than list comprehension or Enum.reduce for large buffers (Waveshare 12.48" is ~160KB). Delegates to BEAM's binary module which handles memory efficiently.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Waveshare12in48 had wrong bit_order value from parallel agent**
- **Found during:** Task 1 GREEN phase
- **Issue:** Another parallel agent had already written `bit_order: :msb_first` to waveshare_12in48.ex (incorrect value, wrong type — `:msb_first` is not a valid `bit_order()`)
- **Fix:** Corrected to `bit_order: :white_high` as specified in the plan
- **Files modified:** lib/papyrus/displays/waveshare_12in48.ex
- **Commit:** 9445ba5

## Known Stubs

None. All three TestPattern functions return real buffers computed from `spec.buffer_size` and `spec.bit_order`.

## Self-Check: PASSED

- FOUND: lib/papyrus/display_spec.ex
- FOUND: lib/papyrus/displays/waveshare_12in48.ex
- FOUND: lib/papyrus/test_pattern.ex
- FOUND: test/papyrus/test_pattern_test.exs
- FOUND: 02-01-SUMMARY.md
- FOUND commit: 9445ba5
- FOUND commit: 196ebab
- Tests: 43 tests, 0 failures
