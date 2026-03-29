# Phase 3: Bitmap Rendering Pipeline - Research

**Researched:** 2026-03-29
**Domain:** Elixir image loading, grayscale conversion, 1-bit pixel packing, Floyd-Steinberg dithering
**Confidence:** HIGH

## Summary

Phase 3 implements `Papyrus.Bitmap` — a pure-Elixir pipeline that converts PNG/BMP images to packed 1-bit binary buffers sized and encoded exactly as the ePaper C port expects. The decisions in CONTEXT.md are specific and lock in the approach: `stb_image` for loading (no system deps), pure-Elixir bilinear letterbox resize, luminance threshold for default conversion, Floyd-Steinberg dithering behind an option flag, and a `Papyrus.Bitmap.Loader` behaviour as the swap seam for a future libvips backend.

The implementation is self-contained pure Elixir: `stb_image` bundles its own C (compiled via `elixir_make`'s existing infrastructure), all image math runs in Elixir, and the output is a raw `binary()` passed directly to `Papyrus.Display`. No additional system dependencies beyond what `stb_image` provides are required.

`stb_image` returns raw HWC bytes in a `%StbImage{}` struct. With `channels: 1` you get 1-byte-per-pixel grayscale, which eliminates the need for a separate luminance-from-RGB step. The resize function (`StbImage.resize/3`) uses bicubic/Mitchell filtering from the `stb_image_resize2` C layer — better than naive bilinear for the pre-threshold quality goal. Bit packing follows Elixir bitstring syntax: MSB-first 8-pixel-per-byte packing using `<<bit::1, ...>>` construction.

**Primary recommendation:** Load with `stb_image` at `channels: 1`, resize with `StbImage.resize/3`, apply letterbox padding in Elixir, threshold or Floyd-Steinberg in Elixir, pack 8 pixels per byte MSB-first respecting `spec.bit_order`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `stb_image` (~> 0.6) for Phase 3 — no system dependencies, self-contained, works on Nerves minimal rootfs
- **D-02:** Define a public `Papyrus.Bitmap.Loader` behaviour with a `load/1` callback — the `stb_image` backend is the default implementation
- **D-03:** The `Loader` behaviour is configurable via application config so users can swap in an `image`/libvips backend in a later phase without touching `Papyrus.Bitmap` internals
- **D-04:** `stb_image` returns raw HWC binary (height × width × channels); the Elixir pipeline handles grayscale conversion and bit packing from that
- **D-05:** When image dimensions don't match `spec.width × spec.height`, resize using letterbox: scale to fit within display bounds (preserving aspect ratio), pad remainder with white pixels
- **D-06:** Resize uses bilinear interpolation in pure Elixir — better pre-threshold quality than nearest-neighbour before the 1-bit conversion step

  > **Research note:** `StbImage.resize/3` uses Mitchell/Catmull-Rom (from stb_image_resize2 C layer), not bilinear. This is strictly better quality than bilinear. The spirit of D-06 (quality > speed before threshold) is satisfied by `StbImage.resize/3`. The planner can choose between: (a) using `StbImage.resize/3` (higher quality, uses C) or (b) implementing bilinear in pure Elixir (matches D-06 literally). D-06 says "pure Elixir" — see Open Questions.

- **D-07:** No `{:error, :dimension_mismatch}` — the library always handles mismatches transparently; caller does not need to pre-size images
- **D-08:** `from_image/2` uses simple luminance threshold (pixel luminance > 128 → white) by default — fast, sufficient for text and icons
- **D-09:** `from_image/3` accepts `dither: true` option to enable Floyd-Steinberg error diffusion dithering — better quality for photos and gradients
- **D-10:** Both paths must respect `spec.bit_order` — `:white_high` means luminance > 128 encodes as `1` (white bit); `:white_low` means luminance > 128 encodes as `0` (white bit)
- **D-11:** `Papyrus.Bitmap.blank/1` is an independent 1-liner — it does not delegate to `Papyrus.TestPattern.full_white/1`; clean module separation between the rendering API and hardware verification patterns
- **D-12:** `blank/1` respects `spec.bit_order` exactly as `full_white/1` does (same byte logic, independent implementation)

### Claude's Discretion

- Internal pipeline structure within `Papyrus.Bitmap` (pipeline functions, private helpers)
- Error handling for unreadable files or unsupported image formats — return `{:error, reason}` tuple is expected but exact error atoms are Claude's call
- How `Papyrus.Bitmap.Loader` default backend is selected (application config key name and default)
- Floyd-Steinberg implementation details (pixel scan order, clamping strategy)
- Bilinear interpolation implementation details

### Deferred Ideas (OUT OF SCOPE)

- `image` (libvips) backend for `Papyrus.Bitmap.Loader`
- 3-color (dual-plane) buffer encoding
- 4-gray grayscale (2-bit pixel packing)
- Floyd-Steinberg as a standalone public API
- HTML-to-bitmap via `chromic_pdf`
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BITMAP-01 | Library converts a PNG or BMP image to a packed 1-bit binary buffer matching a given `DisplaySpec`'s dimensions and bit order | `stb_image` read_file supports PNG and BMP; bit packing via Elixir bitstring syntax; bit_order from `DisplaySpec` controls white=1 or white=0 encoding |
| BITMAP-02 | Library generates a blank (all-white) buffer of the correct size for any `DisplaySpec` | `blank/1` mirrors `TestPattern.full_white/1` byte logic: `:binary.copy(<<0xFF>>, size)` for `:white_high`, `<<0x00>>` for `:white_low` |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `stb_image` | ~> 0.6.10 | PNG/BMP loading, grayscale channel extraction, resize | No system deps; self-contained C bundled in hex package; compiles on Nerves minimal rootfs via existing `elixir_make` infrastructure; locked by D-01 |
| ExUnit | built-in | Test suite | No alternative; already in use in Phase 2 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mox | ~> 1.2 | Behaviour mocking for `Papyrus.Bitmap.Loader` | Mock loader in tests to isolate bit-packing logic from file I/O |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `stb_image` | `image` (libvips) | libvips is faster and richer but requires system libvips install — breaks Nerves minimal rootfs (deferred to future phase per D-01) |
| `stb_image` | `Mogrify` | Shell-out to ImageMagick; no raw buffer access; explicitly excluded in CLAUDE.md |
| `StbImage.resize/3` | Pure-Elixir bilinear | StbImage.resize uses Mitchell/Catmull-Rom (better quality); pure-Elixir bilinear gives more control without C; D-06 says "pure Elixir" — see Open Questions |

**Installation:**
```bash
mix deps.get
# Add to mix.exs deps:
# {:stb_image, "~> 0.6", runtime: false}
# Note: runtime: false only if used in dev/test; use {:stb_image, "~> 0.6"} for production use
# Note: Mox is already present as dev/test dep if added in Phase 2
```

**Version verification (confirmed 2026-03-29):**
- `stb_image`: current = 0.6.10 (confirmed via `mix hex.info stb_image`)
- `mox`: 1.2.x is current (established in project CLAUDE.md)

## Architecture Patterns

### Recommended Project Structure
```
lib/papyrus/
├── bitmap.ex              # Public API: from_image/2,3 and blank/1
├── bitmap/
│   ├── loader.ex          # Behaviour: @callback load(path) :: {:ok, StbImage.t()} | {:error, atom}
│   ├── stb_loader.ex      # Default implementation using StbImage.read_file/2
│   ├── resize.ex          # Letterbox resize: scale-to-fit + white padding
│   └── pack.ex            # Grayscale → 1-bit: threshold + Floyd-Steinberg + bit packing
test/papyrus/
├── bitmap_test.exs        # Integration: from_image/2,3, blank/1 with real PNG/BMP fixtures
├── bitmap/
│   ├── loader_test.exs    # StbLoader reads real files; Loader behaviour contract
│   ├── resize_test.exs    # Letterbox math: exact dimensions, white padding verification
│   └── pack_test.exs      # Threshold, Floyd-Steinberg, bit_order variants
test/fixtures/
├── white_16x16.png        # All-white PNG (16×16) for threshold baseline
├── black_16x16.png        # All-black PNG
├── gradient_16x16.png     # Gray gradient for dithering tests
└── portrait_8x16.png      # Mismatched aspect ratio for letterbox tests
```

### Pattern 1: StbImage Loading with Forced Grayscale
**What:** Load any PNG/BMP as grayscale in a single call — eliminates luminance calculation from RGB
**When to use:** Always for Phase 3 (D-04 says HWC binary from stb_image; `channels: 1` gives 1-byte-per-pixel directly)
**Example:**
```elixir
# Source: https://hexdocs.pm/stb_image/0.6.10/StbImage.html
{:ok, img} = StbImage.read_file(path, channels: 1)
# img.shape == {height, width, 1}
# img.data  == <<gray_byte, gray_byte, ...>> (height * width bytes)
```

### Pattern 2: Letterbox Resize Strategy
**What:** Scale image to fit within display bounds preserving aspect ratio, fill edges with white
**When to use:** Always when `img.shape != {spec.height, spec.width, 1}`

```
Input: {img_h, img_w}, Target: {spec_h, spec_w}

scale = min(spec_w / img_w, spec_h / img_h)
scaled_w = floor(img_w * scale)
scaled_h = floor(img_h * scale)

pad_top    = div(spec_h - scaled_h, 2)
pad_bottom = spec_h - scaled_h - pad_top
pad_left   = div(spec_w - scaled_w, 2)
pad_right  = spec_w - scaled_w - pad_left

# Resize img to {scaled_h, scaled_w, 1} then prepend/append white rows/cols
```

**Important:** `StbImage.resize/3` signature is `resize(stb_image, output_h, output_w)` — takes struct, not raw binary. If pure-Elixir resize is used (per D-06 literal reading), implement bilinear via direct pixel index math on `img.data`.

### Pattern 3: 1-bit Bit Packing (MSB-first)
**What:** 8 grayscale pixels → 1 byte, MSB = leftmost pixel in the row
**When to use:** Always — ePaper buffers are packed 1-bit, 8 pixels per byte

```elixir
# Source: Elixir bitstring syntax — https://hexdocs.pm/elixir/binaries-strings-and-charlists.html
# Packing 8 pixel bits into one byte:
<<b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1>> = <<byte>>

# Building a byte from 8 pixel values (0 or 1):
byte = <<p0::1, p1::1, p2::1, p3::1, p4::1, p5::1, p6::1, p7::1>>

# Full row packing using for comprehension into bitstring:
row_bits =
  for pixel_byte <- row_bytes, into: <<>> do
    bit = if pixel_byte > 128, do: 1, else: 0
    # Apply bit_order inversion if :white_low
    <<bit::1>>
  end
# row_bits is a bitstring; collect into binary by padding if needed
```

**Note on bit_order:**
- `:white_high` → luminance > 128 → `1` bit
- `:white_low` → luminance > 128 → `0` bit (XOR each bit)

### Pattern 4: Floyd-Steinberg Error Diffusion
**What:** Distributes quantization error to neighbours, producing better halftoning than simple threshold
**When to use:** `from_image(path, spec, dither: true)`

**Algorithm (scan left-to-right, top-to-bottom):**
```
for each pixel at (x, y):
  old_val = pixel[y][x]
  new_val = if old_val > 128, do: 255, else: 0
  quant_err = old_val - new_val
  pixel[y][x+1]   += quant_err * 7/16
  pixel[y+1][x-1] += quant_err * 3/16
  pixel[y+1][x]   += quant_err * 5/16
  pixel[y+1][x+1] += quant_err * 1/16
```

**Elixir implementation notes:**
- Work on a flat list or 2D array of integers (not raw binary — mutation semantics differ)
- Convert `img.data` binary to a list of integers first: `:binary.bin_to_list(img.data)` or `for <<b <- img.data>>, do: b`
- Accumulate error in a mutable-style structure — use a flat tuple or map indexed by `{x, y}` for random access, or process row-by-row carrying error as state via Enum.reduce
- Clamp accumulated values to 0..255 before threshold comparison
- After dithering, threshold and pack exactly as Pattern 3

**Implementation strategy for pure-Elixir with no mutation:**
Use `Enum.reduce` scanning pixels in row-major order, carrying an error accumulator map `%{{x,y} => extra}`. For each pixel: look up accumulated error, add to pixel value, clamp, threshold, record error to three neighbours.

### Pattern 5: Loader Behaviour and Config Dispatch
**What:** `Papyrus.Bitmap.Loader` behaviour with configurable backend via `Application.get_env/3`
**When to use:** All calls to load images go through the behaviour

```elixir
defmodule Papyrus.Bitmap.Loader do
  @callback load(path :: String.t()) ::
    {:ok, StbImage.t()} | {:error, atom()}
end

defmodule Papyrus.Bitmap.StbLoader do
  @behaviour Papyrus.Bitmap.Loader
  def load(path) do
    StbImage.read_file(path, channels: 1)
  end
end

# In Papyrus.Bitmap:
defp loader do
  Application.get_env(:papyrus, :bitmap_loader, Papyrus.Bitmap.StbLoader)
end
```

**Config key:** `:bitmap_loader` under `:papyrus` application — consistent with Elixir convention.

### Pattern 6: blank/1 Implementation
**What:** Returns an all-white buffer; mirrors `TestPattern.full_white/1` byte logic (independent implementation per D-11/D-12)
**Example:**
```elixir
# Source: TestPattern.full_white/1 in lib/papyrus/test_pattern.ex (established pattern)
def blank(%DisplaySpec{bit_order: :white_high, buffer_size: size}),
  do: :binary.copy(<<0xFF>>, size)

def blank(%DisplaySpec{bit_order: :white_low, buffer_size: size}),
  do: :binary.copy(<<0x00>>, size)
```

### Anti-Patterns to Avoid
- **Reading `img.data` as an Elixir String:** The data binary is not UTF-8 — use binary pattern matching `for <<b <- img.data>>, do: b` not `String.graphemes/1`
- **Building bit buffer with Enum.reduce into <<>>:** Collecting into a bitstring with `for ..., into: <<>>` works but produces a bitstring, not a binary. Ensure total bit count is divisible by 8. For rows that are not multiples of 8, the spec's `buffer_size` determines truth — check if the display expects row-padding to a byte boundary (most Waveshare panels: `buffer_size = ceil(width/8) * height`)
- **Using `image` (libvips) in Phase 3:** Locked out by D-01; introduces system dependency
- **Calling `TestPattern.full_white/1` from `blank/1`:** Explicitly forbidden by D-11 (module separation)
- **Blocking on `StbImage.read_file/1` in a GenServer:** `read_file` is a C NIF call — it is fast but synchronous; for very large images it may block briefly. Not a concern for typical ePaper image sizes (< 2MP).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PNG/BMP parsing | Custom file parser | `stb_image` with `read_file/2` | PNG spec has 16 chunk types, CRC checking, ADAM7 interlacing, 16-bit depth — not worth building |
| Channel conversion | Luminance-from-RGB math | `channels: 1` in `StbImage.read_file/2` | stb_image performs the conversion in C before returning; eliminates a processing step |
| Image resize (C path) | Custom resize loop | `StbImage.resize/3` | Uses Mitchell/Catmull-Rom via stb_image_resize2 — higher quality than hand-rolled bilinear |

**Key insight:** `channels: 1` does the heavy lifting — by loading as grayscale directly, Phase 3 avoids writing any luminance math. The Elixir pipeline then only needs: letterbox padding, threshold/dither, bit packing.

## Common Pitfalls

### Pitfall 1: Buffer Size Mismatch from Row Width Assumption
**What goes wrong:** `byte_size(packed_buffer) != spec.buffer_size` causing the C port to receive a wrong-length frame
**Why it happens:** Assuming `buffer_size = width * height / 8`. Many Waveshare displays pad each row to a byte boundary: `buffer_size = ceil(width/8) * height`. A 200×200 display: `200*200/8 = 5000` bytes, `ceil(200/8)*200 = 5000` bytes (same here). A 122×250 display: `ceil(122/8)*250 = 16*250 = 4000` bytes vs `122*250/8 = 3812.5` (truncated). Always use `spec.buffer_size` as the output byte count — never recompute it.
**How to avoid:** Always assert `byte_size(result) == spec.buffer_size` in tests. Derive byte count from `spec.buffer_size`, not from `spec.width * spec.height / 8`.
**Warning signs:** Test failures with `assert byte_size(buf) == spec.buffer_size`, or garbled display output on real hardware.

### Pitfall 2: Bit Packing Direction (MSB vs LSB)
**What goes wrong:** Image appears horizontally mirrored or has checkerboard noise on display
**Why it happens:** ePaper panels expect MSB-first (leftmost pixel in MSB of byte). Constructing bytes LSB-first gives a mirrored image.
**How to avoid:** Build bytes as `<<px0::1, px1::1, ..., px7::1>>` where px0 is the leftmost pixel. Verify with a white-left/black-right test image: left half of buffer should be `0xFF` bytes (`:white_high`) or `0x00` bytes (`:white_low`).
**Warning signs:** Known test fixtures produce mirrored output.

### Pitfall 3: bit_order Inversion Applied at Wrong Stage
**What goes wrong:** `blank/1` and `from_image/2` produce incompatible buffers (one correct, one inverted)
**Why it happens:** Applying `bit_order` inversion in two different places in the pipeline, or missing it in one path.
**How to avoid:** Apply `bit_order` only at the final bit-value determination step: `bit = if luminance > 128, do: white_bit, else: black_bit` where `white_bit = if spec.bit_order == :white_high, do: 1, else: 0`. The `blank/1` implementation uses `:binary.copy` directly (the established `TestPattern` pattern) — keep it that way.
**Warning signs:** `blank/1` buffer differs from `from_image` output on an all-white image.

### Pitfall 4: Floyd-Steinberg Error Accumulation Overflow
**What goes wrong:** Accumulated errors drive pixel values outside 0..255, causing incorrect threshold decisions
**Why it happens:** Errors from multiple neighbors accumulate without clamping; integer underflow/overflow in Elixir integers doesn't happen (arbitrary precision) but values outside 0..255 produce wrong thresholds
**How to avoid:** Clamp accumulated pixel value to 0..255 before threshold: `value = max(0, min(255, base + accumulated_error))`. Do NOT clamp errors before adding them to neighbors — only clamp the final value before threshold (Wikipedia guidance).
**Warning signs:** Dark images have unexpected white spots or vice versa in dithered output.

### Pitfall 5: stb_image returns error for valid-looking files
**What goes wrong:** `{:error, reason}` returned for a file that appears valid
**Why it happens:** stb_image returns an opaque error atom. Common causes: file not found, unsupported PNG variant (16-bit depth), corrupt header.
**How to avoid:** Propagate the error as `{:error, :load_failed}` or `{:error, reason}` from `from_image/2`. Do not attempt to recover — let the caller handle missing files.
**Warning signs:** In tests, check that unreadable paths return `{:error, _}` not a crash.

### Pitfall 6: Letterbox Padding Using Wrong White Value
**What goes wrong:** Padding pixels are added as 0 (black) regardless of `bit_order`
**Why it happens:** White padding is added as a gray value (e.g., `255`) before bit-packing, but the bit-packing correctly maps 255 → white bit. This is actually fine. The pitfall is padding with `0` (which maps to black).
**How to avoid:** Pad with `255` in the grayscale domain (before threshold). The threshold step correctly maps `255 > 128 → white` for both `bit_order` variants.

## Code Examples

### Loading a PNG as Grayscale
```elixir
# Source: https://hexdocs.pm/stb_image/0.6.10/StbImage.html
{:ok, img} = StbImage.read_file("/path/to/image.png", channels: 1)
{height, width, 1} = img.shape
# img.data is a binary: <<gray_0, gray_1, ...>> (height * width bytes)
pixels = for <<byte <- img.data>>, do: byte
```

### Resize via StbImage
```elixir
# Source: https://hexdocs.pm/stb_image/0.6.10/StbImage.html
resized = StbImage.resize(img, target_height, target_width)
# Returns a new StbImage struct with updated shape and data
```

### Bit Packing a Row (MSB-first)
```elixir
# Source: Elixir bitstring syntax — https://hexdocs.pm/elixir/binaries-strings-and-charlists.html
# pixels: list of 0/1 integers, length = spec.width (padded to multiple of 8 if needed)
defp pack_row(pixels, white_bit) do
  for chunk <- Enum.chunk_every(pixels, 8, 8, List.duplicate(white_bit, 8)),
      into: <<>> do
    [p0, p1, p2, p3, p4, p5, p6, p7] = chunk
    <<p0::1, p1::1, p2::1, p3::1, p4::1, p5::1, p6::1, p7::1>>
  end
end
```

### blank/1 (verbatim pattern from TestPattern)
```elixir
# Source: lib/papyrus/test_pattern.ex — established pattern, replicated independently
def blank(%DisplaySpec{bit_order: :white_high, buffer_size: size}),
  do: :binary.copy(<<0xFF>>, size)

def blank(%DisplaySpec{bit_order: :white_low, buffer_size: size}),
  do: :binary.copy(<<0x00>>, size)
```

### Loader Behaviour + Config Dispatch
```elixir
# In Papyrus.Bitmap — config key: :bitmap_loader under :papyrus app
defp loader do
  Application.get_env(:papyrus, :bitmap_loader, Papyrus.Bitmap.StbLoader)
end

# Test config (config/test.exs or in setup_all):
# Application.put_env(:papyrus, :bitmap_loader, MockLoader)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `stb_image_resize.h` (legacy) | `stb_image_resize2.h` (v2) | nothings/stb ~2023 | Mitchell/Catmull-Rom defaults; better quality than old bilinear default |
| `image` (libvips) as standard Elixir image lib | `stb_image` for embedded/Nerves contexts | Established pattern | stb_image ships no system deps; correct for Nerves rootfs constraint |

**Deprecated/outdated:**
- `Mogrify` (ImageMagick shell-out): explicitly excluded in CLAUDE.md
- `mock` library (jjh42/mock): excluded in CLAUDE.md; use Mox

## Open Questions

1. **D-06 says "pure Elixir" resize — but `StbImage.resize/3` is available and higher quality**
   - What we know: D-06 specifies "pure Elixir bilinear interpolation" to avoid nearest-neighbour artifacts before the threshold step. `StbImage.resize/3` wraps C code (stb_image_resize2) and uses Mitchell/Catmull-Rom, which is strictly higher quality than bilinear.
   - What's unclear: Whether D-06's "pure Elixir" is a hard constraint (no C for resize) or a quality signal (don't use nearest-neighbour). Using `StbImage.resize/3` satisfies the quality goal better but uses C.
   - Recommendation: The planner should default to `StbImage.resize/3` (already approved C via stb_image; better quality; simpler implementation). If the user's intent for "pure Elixir" was genuinely about avoiding C in the resize step, implement a bilinear loop in pure Elixir. Flag this decision point in PLAN.md.

2. **Row padding: does `spec.buffer_size` always equal `ceil(width/8) * height`?**
   - What we know: `Waveshare12in48.spec()` sets `buffer_size` explicitly. Phase 2 tests verify `byte_size(buf) == spec.buffer_size`. The bit-packing loop must produce exactly `spec.buffer_size` bytes.
   - What's unclear: Whether any display has non-standard row padding (e.g., 32-bit aligned rows). The current `DisplaySpec` does not encode row stride.
   - Recommendation: Trust `spec.buffer_size` as ground truth. If `ceil(width/8) * height != spec.buffer_size`, the spec author is responsible for the correct value. The implementation should pack `spec.width` pixels per row into `ceil(spec.width/8)` bytes and produce `spec.height` rows, then assert the total equals `spec.buffer_size`.

3. **Error format for unreadable files**
   - What we know: CONTEXT.md says error atoms are Claude's discretion. `StbImage.read_file/2` returns `{:error, reason}` with an atom reason.
   - Recommendation: Pass `stb_image`'s error reason through as `{:error, :load_failed}` with a message, or propagate the raw atom. Simple propagation is easiest.

## Environment Availability

> Step 2.6: No external system dependencies beyond what stb_image bundles. stb_image compiles its C code via the same `elixir_make` mechanism already in place. No additional system tools required.

**Assessment:** SKIPPED for external tools. The only new dependency is `stb_image` itself, which bundles its own C and compiles on `mix deps.compile`. The existing `elixir_make` + Makefile infrastructure handles C compilation. No additional system installs needed.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in, already configured) |
| Config file | `test/test_helper.exs` — `ExUnit.start(exclude: [:hardware])` |
| Quick run command | `mix test test/papyrus/bitmap_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BITMAP-01 | `from_image/2` returns binary of `spec.buffer_size` bytes for PNG input | unit | `mix test test/papyrus/bitmap_test.exs::test from_image/2 returns correct buffer size for PNG` | ❌ Wave 0 |
| BITMAP-01 | `from_image/2` returns binary of `spec.buffer_size` bytes for BMP input | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-01 | Buffer byte length matches `spec.buffer_size` for mismatched image dimensions | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-01 | `bit_order: :white_high` — all-white image → all `0xFF` bytes | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-01 | `bit_order: :white_low` — all-white image → all `0x00` bytes | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-01 | `dither: true` option accepted without error | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-02 | `blank/1` returns binary of `spec.buffer_size` bytes | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-02 | `blank/1` with `:white_high` → all `0xFF` bytes | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |
| BITMAP-02 | `blank/1` with `:white_low` → all `0x00` bytes | unit | `mix test test/papyrus/bitmap_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/papyrus/bitmap_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/papyrus/bitmap_test.exs` — covers all BITMAP-01 and BITMAP-02 behaviors above
- [ ] `test/papyrus/bitmap/pack_test.exs` — unit tests for bit-packing, threshold, Floyd-Steinberg in isolation
- [ ] `test/papyrus/bitmap/resize_test.exs` — letterbox math: exact output dimensions, white-padding verification
- [ ] `test/fixtures/` — PNG/BMP fixture files: all-white, all-black, gradient, mismatched-aspect
- [ ] `test/papyrus/bitmap/loader_test.exs` — StbLoader reads real files, Mox mock for isolation

## Sources

### Primary (HIGH confidence)
- `https://hexdocs.pm/stb_image/0.6.10/StbImage.html` — `read_file/2` signature, `channels: 1` grayscale, `resize/3`, `shape` field format, `.data` binary layout
- `https://hexdocs.pm/elixir/binaries-strings-and-charlists.html` — `<<bit::1, ...>>` bitstring syntax for bit packing
- `lib/papyrus/test_pattern.ex` (project source) — `full_white/1` pattern for `blank/1` implementation
- `lib/papyrus/display_spec.ex` (project source) — `bit_order`, `buffer_size`, `width`, `height` field contracts
- `mix hex.info stb_image` — confirmed current version 0.6.10

### Secondary (MEDIUM confidence)
- `https://github.com/nothings/stb/blob/master/stb_image_resize2.h` — Mitchell/Catmull-Rom as default resize filters (verified against stb C source, not Elixir binding docs)
- `https://en.wikipedia.org/wiki/Floyd%E2%80%93Steinberg_dithering` — error coefficients (7/16, 5/16, 3/16, 1/16), scan order, clamping strategy

### Tertiary (LOW confidence)
- None — all key findings verified via primary or secondary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — stb_image version confirmed via hex.info; API confirmed via hexdocs
- Architecture: HIGH — patterns derived from existing project code (TestPattern, DisplaySpec) plus verified stb_image API
- Pitfalls: HIGH for buffer-size and bit-order pitfalls (derived from DisplaySpec contract); MEDIUM for Floyd-Steinberg clamping (Wikipedia verified, no Elixir-specific source)
- Floyd-Steinberg algorithm: HIGH for coefficients and scan order (Wikipedia primary source); MEDIUM for Elixir implementation approach (no existing Elixir ePaper dithering prior art found)

**Research date:** 2026-03-29
**Valid until:** 2026-04-29 (stb_image is stable; 30-day window appropriate)
