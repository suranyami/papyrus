---
phase: 03-bitmap-rendering-pipeline
plan: "01"
subsystem: bitmap
tags: [bitmap, stb_image, loader, blank, test-fixtures]
dependency_graph:
  requires: []
  provides: [Papyrus.Bitmap, Papyrus.Bitmap.Loader, Papyrus.Bitmap.StbLoader]
  affects: [03-02-PLAN.md]
tech_stack:
  added:
    - stb_image ~> 0.6 (production dep; lightweight PNG/BMP reader for Nerves contexts)
  patterns:
    - Behaviour-based loader seam (Papyrus.Bitmap.Loader) for swap-able image backends
    - Application.get_env/3 for loader configuration (planned for Plan 02 wiring)
key_files:
  created:
    - lib/papyrus/bitmap.ex
    - lib/papyrus/bitmap/loader.ex
    - lib/papyrus/bitmap/stb_loader.ex
    - test/papyrus/bitmap_test.exs
    - test/support/fixtures/white_4x8.png
    - test/support/fixtures/black_4x8.png
    - test/support/generate_fixtures.exs
  modified:
    - mix.exs (stb_image added to deps)
    - mix.lock (stb_image + cc_precompiler resolved)
decisions:
  - loader/0 private function deferred to Plan 02 — unused function would fail --warnings-as-errors in current state
  - StbImage.new/2 used for fixture generation (not StbImage.from_binary/2 which does not exist in 0.6.10)
metrics:
  duration_seconds: 208
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_created: 7
  files_modified: 2
---

# Phase 03 Plan 01: Bitmap Foundation — Blank Buffer, Loader Behaviour, StbLoader Summary

**One-liner:** stb_image-backed Loader behaviour with Bitmap.blank/1 respecting bit_order polarity, test fixtures generated via StbImage.new/2, full suite green at 77 tests.

## What Was Built

**Papyrus.Bitmap** (`lib/papyrus/bitmap.ex`) — Public API module providing:
- `blank/1` — returns an all-white packed binary buffer for a given `%DisplaySpec{}`, implemented independently of `TestPattern` per D-11 decision. Pattern-matches on `bit_order: :white_high` (returns `0xFF` bytes) and `bit_order: :white_low` (returns `0x00` bytes).
- `from_image/2` and `from_image/3` — placeholder stubs returning `{:error, :not_implemented}`, establishing the public API surface for Plan 02.

**Papyrus.Bitmap.Loader** (`lib/papyrus/bitmap/loader.ex`) — Behaviour defining the swap seam for image loading backends. Single callback: `load(path :: String.t()) :: {:ok, StbImage.t()} | {:error, atom()}`.

**Papyrus.Bitmap.StbLoader** (`lib/papyrus/bitmap/stb_loader.ex`) — Default implementation of the Loader behaviour. Loads images as single-channel grayscale via `StbImage.read_file(path, channels: 1)`.

**Test infrastructure:**
- `test/support/fixtures/white_4x8.png` and `black_4x8.png` — 4x8 grayscale PNGs used as StbLoader test fixtures.
- `test/support/generate_fixtures.exs` — Mix script for regenerating fixtures if needed.
- `test/papyrus/bitmap_test.exs` — 5 tests covering blank/1 (both bit_order variants, large display), StbLoader (valid PNG, nonexistent path).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed loader/0 private function from Bitmap module**
- **Found during:** Task 1 verification (`mix compile --warnings-as-errors`)
- **Issue:** The plan specified adding a `loader/0` private function to `bitmap.ex` for `Application.get_env(:papyrus, :bitmap_loader, ...)`. Since `from_image/2` and `from_image/3` are stubs that don't call `loader/0`, the function is unused. This causes a compile failure under `--warnings-as-errors`.
- **Fix:** Removed `loader/0` from `bitmap.ex`. It will be added back in Plan 02 when `from_image/2` is properly implemented and calls the loader.
- **Files modified:** `lib/papyrus/bitmap.ex`
- **Commit:** `964269a`

**2. [Rule 1 - Bug] Corrected StbImage fixture API from from_binary/2 to new/2**
- **Found during:** Task 2 GREEN phase (fixture generation script)
- **Issue:** The plan specified `StbImage.from_binary/2` for creating in-memory images to write as PNG fixtures. This function does not exist in stb_image 0.6.10. The correct API is `StbImage.new/2`.
- **Fix:** Updated `generate_fixtures.exs` to use `StbImage.new(data, {h, w, channels})`.
- **Files modified:** `test/support/generate_fixtures.exs`
- **Commit:** `ba41bf9`

**3. [Rule 1 - Bug] Removed default argument from test_spec/1**
- **Found during:** Task 2 test run
- **Issue:** `defp test_spec(opts \\ [])` generated a compiler warning ("default values for the optional arguments in test_spec/1 are never used") since all call sites pass explicit opts lists. ExUnit doesn't fail on warnings, but clean output is preferred.
- **Fix:** Changed to `defp test_spec(opts)` with explicit argument at all call sites.
- **Files modified:** `test/papyrus/bitmap_test.exs`
- **Commit:** `ba41bf9`

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `from_image/2` returns `{:error, :not_implemented}` | `lib/papyrus/bitmap.ex:17` | Plan 02 implements the full image-to-buffer pipeline |
| `from_image/3` returns `{:error, :not_implemented}` | `lib/papyrus/bitmap.ex:21` | Plan 02 implements the full image-to-buffer pipeline with options |

These stubs are intentional placeholders. They do not prevent the plan's goal (blank/1 working, Loader behaviour defined) from being achieved. Plan 02 will resolve them.

## Self-Check: PASSED

All files exist and both task commits verified:
- `lib/papyrus/bitmap.ex` — FOUND
- `lib/papyrus/bitmap/loader.ex` — FOUND
- `lib/papyrus/bitmap/stb_loader.ex` — FOUND
- `test/papyrus/bitmap_test.exs` — FOUND
- `test/support/fixtures/white_4x8.png` — FOUND
- `test/support/fixtures/black_4x8.png` — FOUND
- Commit `964269a` — FOUND
- Commit `ba41bf9` — FOUND
