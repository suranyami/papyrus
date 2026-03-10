# Hardware Setup

## Supported Boards

- Raspberry Pi 4 (gpiochip0)
- Raspberry Pi 5 (gpiochip4 — detected automatically)
- Other boards with lgpio-compatible GPIO

## Install lgpio

```sh
sudo apt update
sudo apt install liblgpio-dev
```

## GPIO Permissions

Add your user to the `gpio` group so the port binary can access GPIO without sudo:

```sh
sudo usermod -aG gpio $USER
# Log out and back in for the change to take effect
```

Alternatively, run with `sudo` during development.

## Wiring the 12.48" Panel

Connect the Waveshare 12.48" ePaper panel to your Raspberry Pi as follows.
The C driver uses software SPI on GPIO 10/11 plus separate CS/DC/RST/BUSY
lines for each of the four sub-panels.

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

## Pi 5 vs Pi 4 Differences

On Raspberry Pi 5, the GPIO controller is on `gpiochip4` instead of `gpiochip0`.
The `DEV_Config.c` code handles this automatically by inspecting `/proc/cpuinfo`.
No changes are needed in your Elixir code.

## Verifying the Build

After `mix compile`, check that the port binary was produced:

```sh
ls -lh _build/dev/lib/papyrus/priv/epd_port
```

You can test it manually (it will wait for stdin):

```sh
echo -n | ./_build/dev/lib/papyrus/priv/epd_port
```
