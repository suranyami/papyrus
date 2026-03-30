# Hardware Testing

Papyrus includes a two-tier test taxonomy that separates tests that require
physical display hardware from tests that run anywhere, including CI and macOS.

## Two-Tier Test Taxonomy

### Tier 1: CI-Safe Tests

**Location:** `test/papyrus/`
**Run with:** `mix test`

These tests use `Papyrus.MockPort` — an Elixir script that speaks the
length-prefixed binary protocol — instead of the real C port binary. They run
on any machine with no display hardware and no Raspberry Pi required.

Modules covered: `Papyrus.Protocol`, `Papyrus.DisplaySpec`, `Papyrus.TestPattern`,
`Papyrus.Display` (via mock port), `Papyrus.Bitmap`.

### Tier 2: Hardware-Required Tests

**Location:** `test/hardware/`
**Run with:** `mix test test/hardware/ --include hardware`

These tests require a Raspberry Pi with a Waveshare ePaper display physically
connected. They are tagged `@moduletag :hardware` and excluded from `mix test`
by default in `test/test_helper.exs`.

Use hardware tests for:
- End-to-end display refresh verification on real hardware
- Visual confirmation that images render correctly on screen
- GPIO pin configuration and SPI timing validation

## Running CI Tests

```sh
# Run all CI-safe tests (default — no hardware needed)
mix test

# Run a specific test file
mix test test/papyrus/bitmap_test.exs

# Re-run only failed tests
mix test --failed
```

All 100+ CI tests pass on macOS and Linux without a connected display.

## Running Hardware Tests

Requirements before running hardware tests:
- Raspberry Pi (any model with SPI)
- Waveshare ePaper display physically connected and wired
- `liblgpio-dev` installed: `sudo apt install liblgpio-dev`
- User in the `gpio` group: `sudo usermod -a -G gpio $USER`

Run hardware tests:

```sh
mix test test/hardware/ --include hardware
```

Run everything (CI + hardware):

```sh
mix test --include hardware
```

## Bitmap Render Test

`test/hardware/bitmap_render_test.exs` exercises the full image pipeline on
real hardware. It loads each PNG from `examples/images/`, converts it to a
display buffer via `Papyrus.Bitmap.from_image/2`, sends it to the display, and
pauses for visual inspection before moving to the next image.

The test also displays the checkerboard test pattern as a baseline verification.

### Default display module

The test defaults to `Papyrus.Displays.Waveshare12in48`. Override it with
application config if your display is different:

```elixir
# config/test.exs
config :papyrus, test_display_module: Papyrus.Displays.MyDisplay
```

### What to look for

When running `bitmap_render_test.exs`, inspect the screen after each image:

- [ ] Image fills the display area (no blank screen)
- [ ] No garbled, shifted, or corrupted pixels
- [ ] Letterboxing is visible on images with a non-matching aspect ratio
  (white bars on the shorter dimension)
- [ ] High-contrast edges are sharp and clean
- [ ] (Optional) Compare threshold vs. dithered rendering for gradient images

Pass/fail is determined by whether errors are raised — not by pixel inspection.
The visual check is a manual step: the test pauses between images and waits for
you to press Enter.

## Writing Your Own Hardware Tests

Place hardware tests in `test/hardware/`. Use `@moduletag :hardware` and
`async: false` (hardware tests must serialize to avoid port conflicts):

```elixir
defmodule Papyrus.Hardware.MyTest do
  use ExUnit.Case, async: false

  @moduletag :hardware

  setup do
    display_module =
      Application.get_env(:papyrus, :test_display_module, Papyrus.Displays.Waveshare12in48)

    {:ok, display} = Papyrus.Display.start_link(display_module: display_module)

    on_exit(fn ->
      if Process.alive?(display), do: Papyrus.Display.sleep(display)
    end)

    {:ok, display: display, spec: Papyrus.Display.spec(display)}
  end

  test "my hardware behavior", %{display: display, spec: spec} do
    # ... your test here
    assert :ok == Papyrus.Display.display(display, my_buffer)
  end
end
```

Key conventions:
- `on_exit` sleeps the display so it is not left powered on after the test
- `Application.get_env(:papyrus, :test_display_module, ...)` makes the test
  configurable for different display models
- `IO.read(:line)` pauses for visual inspection between operations
