# Loading Images onto Your Display

Papyrus can convert PNG and BMP images to 1-bit packed binary buffers ready for
display on any Waveshare ePaper panel. This guide covers `Papyrus.Bitmap.from_image/2`,
the image loader script, and the bundled sample images.

## Overview

`Papyrus.Bitmap` converts raster images to the 1-bit packed binary format the
C port expects:

1. Loads the image via `StbImage` (PNG, BMP, JPEG)
2. Resizes to the display's exact pixel dimensions using letterboxing to preserve
   aspect ratio (unused area fills to white)
3. Converts to grayscale
4. Thresholds at 128 to produce 1-bit pixels (`1` = white, `0` = black by default)
5. Packs pixels into bytes according to `spec.bit_order` (MSB-first for the 12.48" panel)

The result is a binary of exactly `spec.buffer_size` bytes — the size that
`Papyrus.Display.display/2` expects.

## Using from_image/2

```elixir
# Get the display spec from a running Display GenServer
spec = Papyrus.Display.spec(display)

# Load an image and convert it to a display buffer
{:ok, buffer} = Papyrus.Bitmap.from_image("path/to/image.png", spec)

# Send to the display
:ok = Papyrus.Display.display(display, buffer)
```

`from_image/2` returns `{:ok, binary}` on success or `{:error, reason}` if the
file cannot be read or decoded.

### What letterboxing looks like

Images that don't match the display's aspect ratio are centered with white bars:

- A square image on a 4:3 display gets vertical white bars on both sides
- A wide landscape image on a portrait display gets horizontal white bars top and bottom

This ensures the image is never cropped or stretched.

## Dithering

By default, `from_image/2` uses a simple threshold (pixel > 128 = white). For
images with gradients or halftones, Floyd-Steinberg dithering produces much
better results by simulating gray tones with a pattern of black and white pixels:

```elixir
{:ok, buffer} = Papyrus.Bitmap.from_image("path/to/image.png", spec, dither: true)
```

Use dithering for:
- Photographs and artwork with smooth gradients
- Diagrams with gray fills
- Any image that looks too harsh with plain thresholding

Skip dithering (the default) for:
- Already-binary images (line art, logos, QR codes)
- Images where you want maximum sharpness without halftone patterns

## Three-Color Displays

The Waveshare 12.48" panel (`Papyrus.Displays.Waveshare12in48`) has
`color_mode: :three_color`. `Papyrus.Display.display/2` expects `2 * buffer_size`
bytes — one plane for black pixels and one plane for red pixels, concatenated.

`from_image/2` returns a single B&W plane (`buffer_size` bytes). For a
three-color display, duplicate the buffer:

```elixir
{:ok, buffer} = Papyrus.Bitmap.from_image("path/to/image.png", spec)

display_buffer =
  case spec.color_mode do
    :three_color -> buffer <> buffer   # both planes identical for B&W images
    _ -> buffer
  end

:ok = Papyrus.Display.display(display, display_buffer)
```

The second (red) plane contains the same B&W data — on a three-color panel this
means black pixels may appear as a mix of black and red depending on the hardware
model. Full three-color rendering (where red pixels are set independently) is
planned for a future release.

## Running the Image Loader

The `examples/load_images.exs` script loops through all PNG files in
`examples/images/`, converts each to a display buffer, and shows them
sequentially with a configurable pause between images:

```sh
mix run examples/load_images.exs
```

Override the display model or delay:

```sh
mix run examples/load_images.exs --model Papyrus.Displays.MyDisplay --delay 5
```

Options:
- `--model` — fully-qualified module name (default: `Papyrus.Displays.Waveshare12in48`)
- `--delay` — seconds between images (default: `3`)

## Sample Images

Two CC0 PNG illustrations are bundled in `examples/images/`:

| File | Size | Aspect ratio | Description |
|------|------|--------------|-------------|
| `botanical_illustration.png` | 400x300 | 4:3 landscape | Radial concentric ring pattern with spokes |
| `mechanical_drawing.png` | 300x400 | 3:4 portrait | Crosshatch grid with concentric squares |

The different aspect ratios demonstrate letterboxing on non-matching displays.
Both images are procedurally generated original works released as CC0.

A red/black illustration is planned for a future release when the three-color
rendering pipeline is built.
