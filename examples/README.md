# Papyrus Examples

Runnable scripts that demonstrate Papyrus on real hardware.

## Prerequisites

- Raspberry Pi (or compatible SBC) with a Waveshare ePaper display connected via SPI/GPIO
- Elixir + Mix installed
- Dependencies compiled: `mix deps.get && mix compile`

The examples target `Papyrus.Displays.Waveshare12in48` by default. Pass `--model` to override.

---

## hello_papyrus.exs

Demonstrates the full display lifecycle: init → render test pattern → clear → sleep.

```sh
mix run examples/hello_papyrus.exs

# Use a different display model
mix run examples/hello_papyrus.exs --model Papyrus.Displays.MyDisplay
```

What it does:
1. Starts a supervised display process
2. Renders a checkerboard test pattern
3. Waits 3 seconds
4. Clears the display to white
5. Puts the display into low-power sleep

---

## load_images.exs

Loads all PNG images from `examples/images/` and displays them sequentially.

```sh
mix run examples/load_images.exs

# Override display model and delay between images (seconds)
mix run examples/load_images.exs --model Papyrus.Displays.MyDisplay --delay 5
```

Options:
| Flag | Default | Description |
|------|---------|-------------|
| `--model` | `Papyrus.Displays.Waveshare12in48` | Display module to use |
| `--delay` | `3` | Seconds to show each image before advancing |

Images are scaled and dithered to fit the display's resolution automatically via `Papyrus.Bitmap.from_image/2`.

---

## images/

Sample PNG images used by `load_images.exs`:

| File | Description |
|------|-------------|
| `botanical_illustration.png` | Procedurally generated radial pattern (400×300, landscape) |
| `mechanical_drawing.png` | Geometric grid with concentric squares and hatching (300×400, portrait) |
| `soviet-poster.png` | High-contrast B&W poster — good for testing threshold/dithering |

### Regenerating the procedural samples

```sh
mix run examples/images/generate_samples.exs
```

This recreates `botanical_illustration.png` and `mechanical_drawing.png` from scratch. The generated images are CC0 / public domain.

---

## Adding your own images

Drop any PNG into `examples/images/` and run `load_images.exs`. The pipeline:
- Converts to grayscale
- Scales to fit the display (letterboxed, white padding)
- Applies a 128-threshold to produce a 1-bit buffer

For best results, use high-contrast images with clean black-on-white content.

---

## Three-color displays (black + red + white)

If your display has a red ink channel (e.g. Waveshare 12.48" B), the display buffer is two planes concatenated: `black_plane <> red_plane`. The red plane uses **inverted encoding** from the black plane:

| Value | Black plane | Red plane |
|-------|-------------|-----------|
| `0xFF` | white | **red ink** |
| `0x00` | black | no red |

Both example scripts handle this automatically using `Papyrus.Bitmap.blank_red_plane/1` for the red plane, which produces an all-black-ink-free buffer. Do **not** duplicate the black plane as the red plane — white pixels (`0xFF`) would render as red on the display.
