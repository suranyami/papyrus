# Phase 3: Bitmap Rendering Pipeline — Discussion Log

**Date:** 2026-03-29
**Phase:** 03-bitmap-rendering-pipeline

---

## Area 1: Image loading library

**Q:** How should image loading work in `Papyrus.Bitmap`?

Options presented:
1. `image` only — depend on `image` (~> 0.63), document libvips as a system requirement
2. `stb_image` only — no system deps, implement resize and grayscale in pure Elixir
3. `stb_image` now, `image` later — ship Phase 3 with `stb_image`, leave an abstraction seam for `image` integration

**Selected:** 3 — `stb_image` now, `image` later

**Follow-up Q:** How should the image loading abstraction be structured?
1. Private module, no formal behaviour — `Papyrus.Bitmap.Loader` is an internal refactor target
2. Public behaviour — `Papyrus.Bitmap.Loader` with `load/1` callback, configurable via application config

**Selected:** 2 — Public behaviour

**Decision captured:** `stb_image` default backend; `Papyrus.Bitmap.Loader` public behaviour with `load/1` callback; configurable via application config.

---

## Area 2: Dimension mismatch handling

**Q:** What should `from_image/2` do when image dimensions don't match the display?

Options presented:
1. Error — return `{:error, :dimension_mismatch}`, caller must pre-size
2. Resize to fit (stretch) — scale to exact dimensions, may distort
3. Resize to fit (letterbox) — scale to fit within bounds, pad with white
4. Resize to fill (crop) — scale until covered, crop overflow

**Selected:** 3 — Letterbox

**Follow-up Q:** Since `stb_image` has no resize, what algorithm for the pure-Elixir resize?
1. Nearest-neighbour — fast, simple, slightly blocky
2. Bilinear — better quality, more complex

**Selected:** 2 — Bilinear

**Decision captured:** Letterbox with bilinear interpolation in pure Elixir.

---

## Area 3: Grayscale conversion + dithering

**Q:** How should grayscale → 1-bit conversion work?

Options presented:
1. Threshold only — luminance > 128 → white; fast
2. Dithering only — Floyd-Steinberg always
3. Both, threshold default — `from_image/2` uses threshold; `from_image/3` accepts `dither: true`

**Selected:** 3 — Both, threshold default

**Decision captured:** `from_image/2` = threshold default; `from_image(path, spec, dither: true)` = Floyd-Steinberg.

---

## Area 4: `blank/1` and `TestPattern`

**Q:** How should `Papyrus.Bitmap.blank/1` relate to `Papyrus.TestPattern.full_white/1`?

Options presented:
1. Delegate — `Bitmap.blank/1` calls `TestPattern.full_white/1`
2. Independent — `Bitmap.blank/1` is its own 1-liner, clean separation of concerns
3. Shared private — extract a `Papyrus.Buffer` module both delegate to (overkill)

**Selected:** 2 — Independent

**Decision captured:** `Bitmap.blank/1` is an independent implementation; `TestPattern` stays hardware verification, `Bitmap` is the rendering API.
