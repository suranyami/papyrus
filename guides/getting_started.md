# Getting Started with Papyrus

## Installation

Add Papyrus to your `mix.exs`:

```elixir
def deps do
  [
    {:papyrus, "~> 0.1"}
  ]
end
```

Install the C library dependency on your Raspberry Pi:

```sh
sudo apt install liblgpio-dev
```

Fetch and compile:

```sh
mix deps.get
mix compile
```

This compiles the `c_src/epd_port.c` port binary into `priv/epd_port`.

## Basic Usage

```elixir
alias Papyrus.Displays.Waveshare12in48

{:ok, display} = Papyrus.start_display(display_module: Waveshare12in48)

# Clear to white
:ok = Papyrus.clear(display)

# Build and display a custom buffer
spec = Papyrus.spec(display)
image = :binary.copy(<<0x00>>, spec.buffer_size)  # all black
:ok = Papyrus.display(display, image)

# Sleep when done
:ok = Papyrus.sleep(display)
```

## Supervision Tree

In production, add `Papyrus.Display` under your application supervisor:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Papyrus.Display,
       display_module: Papyrus.Displays.Waveshare12in48,
       name: :epaper}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

Then use the registered name anywhere:

```elixir
Papyrus.clear(:epaper)
Papyrus.display(:epaper, my_image)
```

If the hardware port process crashes (e.g. a GPIO error), the supervisor
restarts the GenServer and re-opens the port automatically.
