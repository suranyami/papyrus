---
status: awaiting_human_verify
trigger: "bitmap-background-not-white — red background renders as red instead of white on ePaper display"
created: 2026-04-14T16:23:00Z
updated: 2026-04-14T16:40:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — Root cause identified. The `buffer <> buffer` pattern in load_images.exs, hello_papyrus.exs, and test/hardware/bitmap_render_test.exs is wrong because the black plane (white_high: 0xFF=white) and the red plane (0x00=no-red, 0xFF=red) have OPPOSITE encodings. Duplicating the black buffer puts 0xFF (white areas) onto the red plane where 0xFF means "show red ink" — causing all white areas to render as red.

Fix: replace `buffer <> buffer` with `buffer <> no_red_plane` where no_red_plane is all-zero bytes. Add `Bitmap.blank_red_plane/1` as a convenience function. Fix all three call sites. Update DisplaySpec docs to clarify the encoding difference.

next_action: implement the fix

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Background renders as white when converting examples/images/soviet-poster.png to ePaper bitmap buffer
actual: Background is red in the rendered output (visible on display hardware)
errors: None — no crash, just wrong colours
reproduction: Render examples/images/soviet-poster.png using the Papyrus bitmap pipeline to a Waveshare ePaper display
started: Current behaviour — unclear if this ever worked correctly

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-14T16:25:00Z
  checked: StbLoader (lib/papyrus/bitmap/stb_loader.ex)
  found: Uses `StbImage.read_file(path, channels: 1)` — this converts colour PNG to grayscale using stb_image's built-in luminance formula (0.299*R + 0.587*G + 0.114*B)
  implication: Red pixels (R=255, G=0, B=0) convert to approximately 76 luminance — below the 128 threshold, so they are mapped to BLACK

- timestamp: 2026-04-14T16:25:00Z
  checked: Bitmap.Pack.pixel_bit/2 in lib/papyrus/bitmap/pack.ex line 58-59
  found: `defp pixel_bit(value, white_bit) when value > 128, do: white_bit` — threshold is strictly > 128; values 0-128 inclusive map to black, 129-255 map to white
  implication: Red pixels at ~76 luminance fall below threshold and are encoded as BLACK bits

- timestamp: 2026-04-14T16:25:00Z
  checked: load_images.exs lines 41-47 (three_color handling)
  found: `case spec.color_mode do :three_color -> buffer <> buffer ...` — for 3-color displays, the same B&W buffer is sent as BOTH the black plane AND the red plane
  implication: Whatever is black in the B&W buffer also appears on the red plane. A red-background image has its background converted to black, then that black also populates the red plane — the display lights up both black AND red ink for those pixels, producing visible red output

- timestamp: 2026-04-14T16:25:00Z
  checked: Waveshare12in48 display spec — red plane semantics AND C driver Clear function
  found: Black plane (register 0x10): 0xFF = white, 0x00 = black. Red plane (register 0x13): 0x00 = no red (transparent), 0xFF = red pixels. These are INVERTED relative to each other. C driver Clear confirms: sends 0xFF to black plane (white), 0x00 to red plane (no red).
  implication: CRITICAL — the black plane and red plane have OPPOSITE encodings. When `buffer <> buffer` duplicates the B&W buffer for both planes: white pixels (0xFF in black plane) become 0xFF in red plane which means RED. Dark/black pixels (0x00 in black plane) become 0x00 in red plane which means no-red. Result: every white area in the image shows as RED on the display because white=0xFF in the black plane encoding, and 0xFF in the red plane encoding means "show red ink".

- timestamp: 2026-04-14T16:30:00Z
  checked: Specifically for the soviet-poster.png case
  found: The image has a bright red background. After grayscale conversion (~76 luminance), the red background converts to BLACK bits (0-bits, encoded as 0x00 bytes in white_high mode). The non-red content (darker areas) also becomes black. The white areas/letterbox padding = 0xFF. When duplicated to the red plane: 0xFF (white areas in black plane) = red on display. 0x00 (dark/former-red areas in black plane) = no-red on display.
  implication: The red background of the poster actually becomes BLACK on the black plane (correct, it's dark), and because the red plane duplication inverts semantics, the white space shows as red instead. The background looks red because the letterbox padding and any light-coloured areas become 0xFF, which the red plane interprets as "show red ink".

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: The black plane and red plane of the Waveshare 12.48" B display use opposite bit encodings. Black plane (white_high): 0xFF = white, 0x00 = black. Red plane: 0x00 = no red (transparent), 0xFF = red ink. The code in load_images.exs, hello_papyrus.exs, and test/hardware/bitmap_render_test.exs used `buffer <> buffer` to construct two-plane buffers for three_color displays — duplicating the black buffer as the red plane. This causes every 0xFF (white) byte in the black plane to be sent to the red plane where 0xFF means "show red ink", making all white/light areas of the image appear red on the display.

fix: Added `Papyrus.Bitmap.blank_red_plane/1` which returns an all-zero buffer (the correct "no red anywhere" red plane). Replaced all `buffer <> buffer` patterns with `buffer <> Papyrus.Bitmap.blank_red_plane(spec)`. Also fixed the `white <> white` clear buffer in hello_papyrus.exs which had the same encoding bug.

verification: 158 tests, 0 failures. 3 new unit tests added for blank_red_plane/1.

files_changed:
  - lib/papyrus/bitmap.ex (added blank_red_plane/1 with detailed docstring explaining the encoding difference)
  - examples/load_images.exs (fixed buffer <> buffer → buffer <> blank_red_plane)
  - examples/hello_papyrus.exs (fixed both pattern <> pattern and white <> white)
  - test/hardware/bitmap_render_test.exs (fixed both buffer <> buffer and pattern <> pattern)
  - test/papyrus/bitmap_test.exs (added 3 tests for blank_red_plane/1)
