# Phase 3: Bitmap Rendering Pipeline - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `Papyrus.Bitmap` — converts PNG/BMP images to packed 1-bit binary buffers ready for the ePaper display port. Deliverables:

- `Papyrus.Bitmap.from_image(path, spec)` — load image, resize to display dimensions, convert to 1-bit, return binary
- `Papyrus.Bitmap.from_image(path, spec, opts)` — same with options (`dither: true`)
- `Papyrus.Bitmap.blank(spec)` — return all-white buffer of correct size

3-color rendering, 4-gray grayscale, HTML-to-bitmap, and dithering as a standalone library feature are Phase 4+ — not this phase.

</domain>

<decisions>
## Implementation Decisions

### Image Loading Library (Area 1)

- **D-01:** Use `stb_image` (~> 0.6) for Phase 3 — no system dependencies, self-contained, works on Nerves minimal rootfs
- **D-02:** Define a public `Papyrus.Bitmap.Loader` behaviour with a `load/1` callback — the `stb_image` backend is the default implementation
- **D-03:** The `Loader` behaviour is configurable via application config so users can swap in an `image`/libvips backend in a later phase without touching `Papyrus.Bitmap` internals
- **D-04:** `stb_image` returns raw HWC binary (height × width × channels); the Elixir pipeline handles grayscale conversion and bit packing from that

### Dimension Mismatch — Resize Strategy (Area 2)

- **D-05:** When image dimensions don't match `spec.width × spec.height`, resize using letterbox: scale to fit within display bounds (preserving aspect ratio), pad remainder with white pixels
- **D-06:** Resize uses bilinear interpolation in pure Elixir — better pre-threshold quality than nearest-neighbour before the 1-bit conversion step
- **D-07:** No `{:error, :dimension_mismatch}` — the library always handles mismatches transparently; caller does not need to pre-size images

### Grayscale → 1-bit Conversion Strategy (Area 3)

- **D-08:** `from_image/2` uses simple luminance threshold (pixel luminance > 128 → white) by default — fast, sufficient for text and icons
- **D-09:** `from_image/3` accepts `dither: true` option to enable Floyd-Steinberg error diffusion dithering — better quality for photos and gradients
- **D-10:** Both paths must respect `spec.bit_order` — `:white_high` means luminance > 128 encodes as `1` (white bit); `:white_low` means luminance > 128 encodes as `0` (white bit)

### `blank/1` Design (Area 4)

- **D-11:** `Papyrus.Bitmap.blank/1` is an independent 1-liner — it does not delegate to `Papyrus.TestPattern.full_white/1`; clean module separation between the rendering API and hardware verification patterns
- **D-12:** `blank/1` respects `spec.bit_order` exactly as `full_white/1` does (same byte logic, independent implementation)

### Claude's Discretion

- Internal pipeline structure within `Papyrus.Bitmap` (pipeline functions, private helpers)
- Error handling for unreadable files or unsupported image formats — return `{:error, reason}` tuple is expected but exact error atoms are Claude's call
- How `Papyrus.Bitmap.Loader` default backend is selected (application config key name and default)
- Floyd-Steinberg implementation details (pixel scan order, clamping strategy)
- Bilinear interpolation implementation details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### DisplaySpec (integration target)
- `lib/papyrus/display_spec.ex` — `bit_order`, `buffer_size`, `width`, `height` fields that `Bitmap` must consume correctly

### Existing rendering patterns (reference for conventions)
- `lib/papyrus/test_pattern.ex` — Shows how `bit_order` is respected in buffer generation; `blank/1` follows the same byte logic as `full_white/1` here (independent, not delegating)

### Requirements being satisfied
- `.planning/REQUIREMENTS.md` §BITMAP-01 — Convert PNG/BMP to packed 1-bit binary matching `DisplaySpec` dimensions
- `.planning/REQUIREMENTS.md` §BITMAP-02 — `blank(spec)` returns all-white buffer of correct size

### Roadmap
- `.planning/ROADMAP.md` §Phase 3 — 4 success criteria that define "done"

### stb_image library
- Hexdocs: https://hexdocs.pm/stb_image — `StbImage.read_file/1`, `StbImage.to_nx/1`, raw pixel access patterns (no external spec file — agent should check hexdocs at research time)

No project-level ADRs — all constraints captured in PROJECT.md and REQUIREMENTS.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Papyrus.TestPattern` — `full_white/1` and `full_black/1` show the exact bit_order byte logic; `blank/1` implements the same pattern independently
- `Papyrus.DisplaySpec` — `buffer_size` is the canonical byte count; `width` and `height` are pixel dimensions; `bit_order` controls white/black encoding

### Established Patterns
- `@enforce_keys` and pattern-matching on struct fields — established in `DisplaySpec` and used throughout `TestPattern`; `Bitmap` functions should pattern-match on `%DisplaySpec{bit_order: ..., buffer_size: ..., width: ..., height: ...}`
- Pure-Elixir buffer construction via `:binary.copy/2` and binary concatenation — `TestPattern` shows this pattern; Bitmap's bit-packing loop should follow suit
- No NIFs for core logic — C port handles hardware I/O; all Elixir-side processing stays in pure Elixir (or safe NIF via stb_image's bundled C)

### Integration Points
- `Papyrus.Bitmap.from_image/2,3` output feeds directly into `Papyrus.Display` commands (the binary is passed to the C port as-is); the buffer must be exactly `spec.buffer_size` bytes
- `mix.exs` deps — `stb_image` must be added; currently only `elixir_make` and `ex_doc` are present

</code_context>

<specifics>
## Specific Ideas

- The `Papyrus.Bitmap.Loader` behaviour design enables a future `:papyrus_image` optional package that wraps libvips — fits the CLAUDE.md pattern of marking `chromic_pdf` as optional
- Bilinear interpolation chosen over nearest-neighbour specifically because the 1-bit threshold step follows immediately — better pre-threshold quality matters even though the final output is 1-bit

</specifics>

<deferred>
## Deferred Ideas

- `image` (libvips) backend for `Papyrus.Bitmap.Loader` — the behaviour is the seam; implementation is a future phase or optional package
- 3-color (dual-plane) buffer encoding — `color_mode: :three_color` is in `DisplaySpec` type but encoding is Phase 4+
- 4-gray grayscale (2-bit pixel packing) — `color_mode: :four_gray` type exists; encoding deferred
- Floyd-Steinberg as a standalone public API (e.g., `Papyrus.Bitmap.dither/2`) — internal for now, may be worth exposing later
- HTML-to-bitmap via `chromic_pdf` — Phase 4+

</deferred>

---

*Phase: 03-bitmap-rendering-pipeline*
*Context gathered: 2026-03-29*
