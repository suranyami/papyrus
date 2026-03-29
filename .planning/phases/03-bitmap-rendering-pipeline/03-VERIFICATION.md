---
phase: 03-bitmap-rendering-pipeline
verified: 2026-03-29T20:30:00Z
status: passed
score: 13/13 must-haves verified
re_verification: false
---

# Phase 03: Bitmap Rendering Pipeline Verification Report

**Phase Goal:** Build the bitmap rendering pipeline — convert images to packed 1-bit binary buffers for ePaper displays
**Verified:** 2026-03-29T20:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

#### From Plan 01 (BITMAP-02)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `Papyrus.Bitmap.blank/1` returns a binary of `spec.buffer_size` bytes | VERIFIED | `bitmap.ex:8-12` pattern-matches on `%DisplaySpec{}`, returns `:binary.copy/2` |
| 2 | `blank/1` with `:white_high` returns all `0xFF` bytes | VERIFIED | `bitmap.ex:9`: `:binary.copy(<<0xFF>>, size)` |
| 3 | `blank/1` with `:white_low` returns all `0x00` bytes | VERIFIED | `bitmap.ex:12`: `:binary.copy(<<0x00>>, size)` |
| 4 | `Papyrus.Bitmap.Loader` behaviour is defined with `load/1` callback | VERIFIED | `loader.ex:4`: `@callback load(path :: String.t()) :: {:ok, StbImage.t()} \| {:error, atom()}` |
| 5 | `Papyrus.Bitmap.StbLoader` implements the Loader behaviour using stb_image | VERIFIED | `stb_loader.ex:4-12`: `@behaviour Papyrus.Bitmap.Loader`, calls `StbImage.read_file(path, channels: 1)` |
| 6 | `stb_image` is a production dependency in `mix.exs` | VERIFIED | `mix.exs:35`: `{:stb_image, "~> 0.6"}` |

#### From Plan 02 (BITMAP-01)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | `from_image/2` converts a PNG to a binary of `spec.buffer_size` bytes | VERIFIED | Full pipeline wired; 107 tests pass including `"converts white PNG to all-0xFF buffer"` |
| 8 | `from_image/2` converts a BMP to a binary of `spec.buffer_size` bytes | VERIFIED | `bitmap_test.exs:112-118` test `"loads BMP format"` passes |
| 9 | `from_image/2` handles dimension mismatches via letterbox resize | VERIFIED | `bitmap_test.exs:100-105` test `"handles mismatched dimensions via letterbox resize"` passes |
| 10 | `from_image/2` with all-white PNG and `:white_high` produces all `0xFF` bytes | VERIFIED | `bitmap_test.exs:68-74` asserts `buf == :binary.copy(<<0xFF>>, spec.buffer_size)` |
| 11 | `from_image/2` with all-white PNG and `:white_low` produces all `0x00` bytes | VERIFIED | `bitmap_test.exs:76-82` asserts `buf == :binary.copy(<<0x00>>, spec.buffer_size)` |
| 12 | `from_image/3` with `dither: true` produces a binary without error | VERIFIED | `bitmap_test.exs:122-125` passes |
| 13 | Buffer byte length always equals `spec.buffer_size` | VERIFIED | `bitmap_test.exs:94-98`; `pack_test.exs` confirms `ceil(width/8) * height` byte length |

**Score:** 13/13 truths verified

---

### Required Artifacts

#### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/papyrus/bitmap.ex` | Public API with `blank/1`, `from_image/2,3` | VERIFIED | 31 lines; real implementations, no stubs |
| `lib/papyrus/bitmap/loader.ex` | Loader behaviour with `load/1` callback | VERIFIED | 5 lines; `@callback load` present |
| `lib/papyrus/bitmap/stb_loader.ex` | StbImage implementation of Loader | VERIFIED | 13 lines; `@behaviour` + `StbImage.read_file` |
| `test/papyrus/bitmap_test.exs` | Tests for `blank/1` and Loader | VERIFIED | 143 lines; 3 blank/1 + 2 StbLoader + 9 from_image tests |
| `test/support/fixtures/white_4x8.png` | Fixture PNG | VERIFIED | 74 bytes on disk |
| `test/support/fixtures/black_4x8.png` | Fixture PNG | VERIFIED | 68 bytes on disk |

#### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/papyrus/bitmap/resize.ex` | Letterbox resize via StbImage.resize/3 | VERIFIED | 45 lines; `def letterbox` with pass-through, scale, and padding logic |
| `lib/papyrus/bitmap/pack.ex` | Threshold, Floyd-Steinberg, MSB-first packing | VERIFIED | 135 lines; both threshold and dither paths implemented |
| `lib/papyrus/bitmap.ex` (updated) | `from_image/2,3` wired to pipeline | VERIFIED | Stubs replaced; `loader().load -> Resize.letterbox -> Pack.to_buffer` |
| `test/papyrus/bitmap/resize_test.exs` | Letterbox unit tests | VERIFIED | 70 lines; 6 tests |
| `test/papyrus/bitmap/pack_test.exs` | Pack/dither unit tests | VERIFIED | 111 lines; 14 tests |
| `test/support/fixtures/gradient_4x8.png` | Gradient fixture for dither tests | VERIFIED | 75 bytes on disk |
| `test/support/fixtures/tall_2x8.png` | Tall fixture for letterbox tests | VERIFIED | 72 bytes on disk |
| `test/support/fixtures/white_4x8.bmp` | BMP fixture | VERIFIED | 150 bytes on disk |

---

### Key Link Verification

#### Plan 01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bitmap.ex` | `display_spec.ex` | `%DisplaySpec{}` pattern match | VERIFIED | Lines 8, 11, 20: `%DisplaySpec{bit_order: ...}` and `%DisplaySpec{} = spec` |
| `stb_loader.ex` | `stb_image` (dep) | `StbImage.read_file/2` | VERIFIED | Line 8: `StbImage.read_file(path, channels: 1)` |

#### Plan 02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bitmap.ex` | `bitmap/loader.ex` | `loader().load(path)` | VERIFIED | Line 21: `with {:ok, img} <- loader().load(path)` |
| `bitmap.ex` | `bitmap/resize.ex` | `Resize.letterbox/3` | VERIFIED | Line 22: `Papyrus.Bitmap.Resize.letterbox(img, spec.width, spec.height)` |
| `bitmap.ex` | `bitmap/pack.ex` | `Pack.to_buffer/4` | VERIFIED | Line 23: `Papyrus.Bitmap.Pack.to_buffer(pixels, spec.width, spec.bit_order, opts)` |

---

### Data-Flow Trace (Level 4)

`from_image/3` is the primary data-rendering function. Tracing the pipeline:

| Step | Code Path | Produces Real Data | Status |
|------|-----------|-------------------|--------|
| Load | `loader().load(path)` → `StbImage.read_file/2` → `{:ok, %StbImage{data: binary()}}` | Yes — reads actual file bytes | FLOWING |
| Resize | `Resize.letterbox(img, w, h)` → scales + pads → flat binary | Yes — transforms real pixel data | FLOWING |
| Pack | `Pack.to_buffer(pixels, w, bit_order, opts)` → MSB-first packed binary | Yes — bit-packs real pixel data | FLOWING |
| Return | `{:ok, buffer}` where `byte_size(buffer) == spec.buffer_size` | Yes — verified by tests | FLOWING |

---

### Behavioral Spot-Checks

The test suite was run directly.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes | `mix test` | 107 tests, 0 failures in 3.9s | PASS |
| Compile clean with warnings-as-errors | `mix compile --warnings-as-errors` | Exit 0, no warnings | PASS |
| `blank/1` with `:white_high` produces `0xFF` buffer | test `"returns binary of spec.buffer_size bytes with :white_high"` | PASS | PASS |
| `from_image/2` PNG to buffer pipeline | test `"converts white PNG to all-0xFF buffer with :white_high"` | PASS | PASS |
| `from_image/2` BMP format | test `"loads BMP format"` | PASS | PASS |
| Floyd-Steinberg dither path | test `"dither: true returns binary of correct size"` | PASS | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BITMAP-01 | 03-02-PLAN.md | Library converts a PNG or BMP image to a packed 1-bit binary buffer matching a given `DisplaySpec`'s dimensions and bit order | SATISFIED | `from_image/2,3` wired end-to-end; PNG and BMP formats tested; `:white_high`/`:white_low` both verified; `byte_size(buffer) == spec.buffer_size` asserted |
| BITMAP-02 | 03-01-PLAN.md | Library generates a blank (all-white) buffer of the correct size for any `DisplaySpec` | SATISFIED | `blank/1` pattern-matches on both bit_order variants; tested for large display (1304x984) |

No orphaned requirements — REQUIREMENTS.md marks both BITMAP-01 and BITMAP-02 as `[x] Complete` at Phase 3.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `pack.ex` | 19 | `_height = div(byte_size(pixels), width)` — variable computed but prefixed with `_` (unused) | Info | No impact; the summary notes this was a deliberate fix from the original unused `height` variable to pass `--warnings-as-errors`. The `_height` form silences the warning correctly. |

No blockers or warnings found. The single info item is an acknowledged deviation from the plan that was auto-fixed during execution.

**`from_image/2` stub check:** Confirmed `lib/papyrus/bitmap.ex` does NOT contain `:not_implemented` — stubs from Plan 01 were fully replaced.

**TestPattern isolation check:** Confirmed `lib/papyrus/bitmap.ex` does NOT reference `TestPattern` (per design decision D-11).

---

### Human Verification Required

None. All observable truths are verifiable programmatically and the full test suite passes with zero failures.

---

### Gaps Summary

No gaps. All 13 must-have truths verified. All artifacts exist, are substantive (no stubs), and are wired correctly. Both BITMAP-01 and BITMAP-02 requirements are satisfied. 107 tests pass with zero failures. Compile is clean under `--warnings-as-errors`.

---

_Verified: 2026-03-29T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
