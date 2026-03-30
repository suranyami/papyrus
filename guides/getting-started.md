# Getting Started with Papyrus

Papyrus is an Elixir/Nerves library for driving Waveshare ePaper displays via a
supervised OS port process. This guide walks you through installing the library,
wiring your display, and getting your first image on screen.

## Prerequisites

- **Raspberry Pi** running Raspberry Pi OS (Bullseye or later), DietPi, or a
  compatible Debian-based Nerves target
- **Elixir 1.15+** and **Erlang/OTP 25+** installed (via `mise` or system packages)
- A Waveshare ePaper display (see [Supported Hardware](#supported-hardware))

### Install the C driver dependency

Papyrus uses [lgpio](https://github.com/joan2937/lg) for GPIO and SPI access.
Install it before compiling the library:

```sh
sudo apt update && sudo apt install -y liblgpio-dev
```

### GPIO permissions

lgpio accesses `/dev/gpiochip0` directly. Add your user to the `gpio` group so
the port process can open the device:

```sh
sudo usermod -a -G gpio $USER
newgrp gpio   # apply in the current shell, or log out and back in
```

Verify:

```sh
groups                  # should include 'gpio'
ls -la /dev/gpiochip0   # should show crw-rw---- root gpio
```

### macOS note

On macOS, the C port is not compiled — lgpio is Linux/Raspberry Pi only.
`mix compile` succeeds, and all CI-safe tests pass, but `Papyrus.Display.start_link/1`
will fail at runtime if you attempt to use real hardware. Development and testing
without hardware is fully supported; deploy to a Raspberry Pi for display output.

## Supported Hardware

| Model | Resolution | Module |
|-------|-----------|--------|
| Waveshare 12.48" (black/white) | 1304 × 984 | `Papyrus.Displays.Waveshare12in48` |

## Installation

Add Papyrus to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:papyrus, "~> 0.2"}
  ]
end
```

Fetch and compile:

```sh
mix deps.get && mix compile
```

The C port binary (`epd_port`) is compiled automatically as part of `mix compile`
via `elixir_make`. If compilation fails, ensure `liblgpio-dev` is installed.

## Your First Display

The fastest way to verify your wiring is to display a test pattern.
See `examples/hello_papyrus.exs` for a complete runnable script.

Here is the essential lifecycle:

```elixir
# Start the display GenServer
{:ok, display} = Papyrus.Display.start_link(display_module: Papyrus.Displays.Waveshare12in48)
spec = Papyrus.Display.spec(display)

# Display a checkerboard test pattern
pattern = Papyrus.TestPattern.checkerboard(spec)

# Waveshare12in48 is a :three_color panel — Display.display/2 expects
# 2 * buffer_size bytes (black plane + red plane concatenated).
# Duplicate the B&W pattern to fill both planes.
buffer =
  case spec.color_mode do
    :three_color -> pattern <> pattern
    _ -> pattern
  end

:ok = Papyrus.Display.display(display, buffer)

# Put the panel into deep sleep when done
:ok = Papyrus.Display.sleep(display)
```

Run the example script on your Raspberry Pi:

```sh
mix run examples/hello_papyrus.exs
# Override display model:
# mix run examples/hello_papyrus.exs --model Papyrus.Displays.MyDisplay
```

### Wiring

See the **Hardware Wiring** section in the README or your display's documentation
for the specific pin assignments. The Waveshare 12.48" panel uses SPI with
multiple chip-select lines.

## Supervision

In a production application, add `Papyrus.Display` as a worker under your
application supervisor. Use the `:name` option to register it so other processes
can look it up:

```elixir
# lib/my_app/application.ex
children = [
  {Papyrus.Display,
   display_module: Papyrus.Displays.Waveshare12in48,
   name: :epaper}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Then call display functions from anywhere:

```elixir
:ok = Papyrus.Display.clear(:epaper)
:ok = Papyrus.Display.display(:epaper, my_buffer)
```

If the port process crashes (hardware fault, GPIO error), the supervisor restarts
it automatically. Only the OS process is affected — the BEAM VM and your
supervision tree stay alive.

## Next Steps

- **[Loading Images](loading-images.md)** — Convert PNG files to ePaper buffers
  using `Papyrus.Bitmap.from_image/2`
- **[Hardware Testing](hardware-testing.md)** — Run `@tag :hardware` tests to
  verify rendering on real hardware
