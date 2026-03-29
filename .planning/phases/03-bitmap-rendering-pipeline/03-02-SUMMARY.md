---
phase: 03-bitmap-rendering-pipeline
plan: "02"
subsystem: bitmap
tags: [bitmap, resize, pack, dithering, floyd-steinberg, from_image, pipeline]
dependency_graph:
  requires: [03-01]
  provides: [Papyrus.Bitmap.Resize, Papyrus.Bitmap.Pack, Papyrus.Bitmap.from_image]
  affects: []
tech_stack:
  added: []
  patterns:
    - Letterbox resize via StbImage.resize/3 with pure-Elixir white padding
    - MSB-first 1-bit packing with :white_high/:white_low bit_order polarity
    - Floyd-Steinberg error diffusion dithering in pure Elixir (row-by-row reduce)
    - Pipeline composition: loader().load -> Resize.letterbox -> Pack.to_buffer
key_files:
  created:
    - lib/papyrus/bitmap/resize.ex
    - lib/papyrus/bitmap/pack.ex
    - test/papyrus/bitmap/resize_test.exs
    - test/papyrus/bitmap/pack_test.exs
    - test/support/fixtures/gradient_4x8.png
    - test/support/fixtures/tall_2x8.png
    - test/support/fixtures/white_4x8.bmp
    - test/support/generate_phase02_fixtures.exs
  modified:
    - lib/papyrus/bitmap.ex (from_image/2,3 wired; loader/0 private function added)
    - test/papyrus/bitmap_test.exs (from_image/2,3 integration tests added)
decisions:
  - Floyd-Steinberg row-by-row reduce: carries next_row_errors list + right-neighbor error through reduce — avoids full %{{x,y} => val} map; constant-memory per row
  - resize.ex uses ^expected_size = byte_size(result) assertion to catch dimension math bugs at dev-time
  - BMP fixture generated from StbImage.new/2 (same API used for PNG fixtures in Plan 01)
metrics:
  duration_seconds: 480
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_created: 8
  files_modified: 2
---

# Phase 03 Plan 02: Image-to-Buffer Pipeline — Resize, Pack, from_image Summary

**One-liner:** Full PNG/BMP-to-1-bit-buffer pipeline via StbImage.resize letterbox, luminance threshold, Floyd-Steinberg dithering, and MSB-first bit packing; BITMAP-01 satisfied.

## What Was Built

**Papyrus.Bitmap.Resize** (`lib/papyrus/bitmap/resize.ex`) — Letterbox resize module:
- `letterbox/3`: takes an `%StbImage{}` and target `{width, height}`, returns flat binary of exactly `target_w * target_h` grayscale bytes
- Pass-through when dimensions match exactly
- Uses `StbImage.resize/3` (Mitchell/Catmull-Rom quality) for scaling
- Pads top/bottom or left/right with white (255) bytes using `:binary.copy/2`
- Internal assertion (`^expected_size = byte_size(result)`) catches padding math errors at dev-time

**Papyrus.Bitmap.Pack** (`lib/papyrus/bitmap/pack.ex`) — 1-bit conversion and packing:
- `to_buffer/3`: threshold path — pixels > 128 map to white_bit, MSB-first packing, 8 pixels per byte
- `to_buffer/4` with `dither: true`: Floyd-Steinberg error diffusion using 7/3/5/1 coefficients (out of 16), then same MSB-first packing
- Respects `:white_high` (luminance > 128 → 1 bit) and `:white_low` (luminance > 128 → 0 bit)
- Row padding to nearest byte boundary using white pixels when width is not a multiple of 8

**Papyrus.Bitmap** (`lib/papyrus/bitmap.ex`) — Pipeline wiring:
- `from_image/2` delegates to `from_image/3` with empty opts (per D-08)
- `from_image/3` chains: `loader().load(path)` → `Resize.letterbox(img, width, height)` → `Pack.to_buffer(pixels, width, bit_order, opts)`
- `loader/0` private function reads `:bitmap_loader` from application config, defaulting to `Papyrus.Bitmap.StbLoader`
- Errors from loader propagate automatically via `with`

**Test infrastructure:**
- `test/papyrus/bitmap/resize_test.exs` — 6 unit tests: pass-through, dimension check, narrow/tall padding, wide padding, white padding assertion
- `test/papyrus/bitmap/pack_test.exs` — 14 unit tests: white_high/white_low, MSB-first bit ordering, alternating pixels (0xAA pattern), dither path size and correctness
- `test/papyrus/bitmap_test.exs` — 9 new integration tests: from_image/2 with white/black/BMP/mismatch/nonexistent, from_image/3 with dither
- Fixtures: `gradient_4x8.png` (horizontal gradient for dither testing), `tall_2x8.png` (narrow/tall for letterbox), `white_4x8.bmp` (BMP format)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed invalid pin/caret assertion syntax in Resize.letterbox**
- **Found during:** GREEN phase, first compile
- **Issue:** `^(target_w * target_h) = byte_size(result)` is invalid Elixir syntax — the pin operator `^` only works on existing variables, not expressions
- **Fix:** Assigned result to a named variable `expected_size = target_w * target_h` and pinned that: `^expected_size = byte_size(result)`
- **Files modified:** `lib/papyrus/bitmap/resize.ex`
- **Commit:** `d5d7b0e`

**2. [Rule 1 - Bug] Fixed unused `height` variable in floyd_steinberg/3**
- **Found during:** GREEN phase, first compile
- **Issue:** The `height` variable in `floyd_steinberg/3` was computed but never used — `Enum.chunk_every(pixels, width)` infers row count implicitly. Would fail under `--warnings-as-errors`.
- **Fix:** Removed `height` computation and renamed function to `floyd_steinberg/2`. Changed call site accordingly.
- **Files modified:** `lib/papyrus/bitmap/pack.ex`
- **Commit:** `d5d7b0e`

## Known Stubs

None — all stubs from Plan 01 (`from_image/2,3` returning `:not_implemented`) have been replaced with the real pipeline.

## Self-Check: PASSED
