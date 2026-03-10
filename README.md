# Papyrus

Elixir/Nerves library for driving ePaper displays from [Waveshare](https://www.waveshare.com/) (and others) via a supervised OS port process.

## Why a Port, not a NIF?

ePaper display refreshes take 1–30 seconds. A Port crash (hardware fault,
lgpio error) kills only the OS process — the BEAM VM and your supervision tree
stay alive. A NIF segfault kills the whole VM.

## Supported Hardware

| Model | Resolution | Notes |
|-------|-----------|-------|
| Waveshare 12.48" (black/white) | 1304 × 984 | `Papyrus.Displays.Waveshare12in48` |

## Installation

```elixir
# mix.exs
def deps do
  [
    {:papyrus, "~> 0.1"}
  ]
end
```

Requires `liblgpio-dev` on the Raspberry Pi:

```sh
sudo apt install liblgpio-dev
```

## Usage

```elixir
alias Papyrus.Displays.Waveshare12in48

# Start a display GenServer (usually under your app's supervisor)
{:ok, display} = Papyrus.start_display(display_module: Waveshare12in48)

# Clear to white
:ok = Papyrus.clear(display)

# Display a 160,392-byte image buffer (1 bit per pixel, 1=white 0=black)
:ok = Papyrus.display(display, my_image_buffer)

# Put the panel into deep sleep when done
:ok = Papyrus.sleep(display)
```

## Buffer Format

The image buffer is a flat binary of `width_bytes × height` bytes:

- Width bytes: `ceil(width / 8)` = 163 for the 12.48" panel
- Total: `163 × 984 = 160,392` bytes
- Bit order: MSB first; bit 7 of byte 0 = pixel (0, 0)
- `1` = white, `0` = black

## Supervision Tree

Add `Papyrus.Display` as a worker under your supervisor:

```elixir
children = [
  {Papyrus.Display, display_module: Papyrus.Displays.Waveshare12in48, name: :epaper}
]
Supervisor.start_link(children, strategy: :one_for_one)

# Then use the registered name:
Papyrus.clear(:epaper)
```

## Hardware Wiring (12.48" panel, Raspberry Pi)

| Display Pin | Pi GPIO (BCM) | Pi Header Pin |
|-------------|--------------|---------------|
| SCK         | GPIO 11      | Pin 23        |
| MOSI        | GPIO 10      | Pin 19        |
| M1 CS       | GPIO 8       | Pin 24        |
| S1 CS       | GPIO 7       | Pin 26        |
| M2 CS       | GPIO 17      | Pin 11        |
| S2 CS       | GPIO 18      | Pin 12        |
| M1/S1 DC    | GPIO 13      | Pin 33        |
| M2/S2 DC    | GPIO 22      | Pin 15        |
| M1/S1 RST   | GPIO 6       | Pin 31        |
| M2/S2 RST   | GPIO 23      | Pin 16        |
| M1 BUSY     | GPIO 5       | Pin 29        |
| S1 BUSY     | GPIO 19      | Pin 35        |
| M2 BUSY     | GPIO 27      | Pin 13        |
| S2 BUSY     | GPIO 24      | Pin 18        |
| VCC         | 3.3V         | Pin 1         |
| GND         | GND          | Pin 6         |

## License

MIT — see [LICENSE](LICENSE).
