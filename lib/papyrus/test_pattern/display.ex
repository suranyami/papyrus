defmodule Papyrus.TestPattern.Display do
  @moduledoc """
  Convenience functions for displaying test patterns on hardware.

  This module provides a simplified API for displaying test patterns
  directly on the connected ePaper display.

  ## Quick Start

      # Start display and show checkerboard
      {:ok, pid} = TestPattern.Display.start()
      TestPattern.Display.checkerboard(pid)

      # Show all patterns in sequence
      TestPattern.Display.show_all(pid)

  ## Patterns

  - `checkerboard/1` - Pyramid checkerboard (64x64 to 1x1)
  - `full_white/1` - All pixels white
  - `full_black/1` - All pixels black

  """

  alias Papyrus.Display
  alias Papyrus.TestPattern
  alias Papyrus.Displays.Waveshare12in48

  @doc """
  Start a display GenServer using the default display module.

  ## Options

  - `:display_module` - Display module (default: Waveshare12in48)
  - `:name` - GenServer name (optional)

  ## Examples

      {:ok, pid} = TestPattern.Display.start()
      {:ok, pid} = TestPattern.Display.start(display_module: MyCustomDisplay)

  """
  @spec start(keyword()) :: GenServer.on_start()
  def start(opts \\ []) do
    display_module = Keyword.get(opts, :display_module, Waveshare12in48)
    Display.start_link(display_module: display_module, name: opts[:name])
  end

  @doc """
  Display the checkerboard pattern.

  The pyramid checkerboard shows squares at multiple scales from 64x64
  down to 1x1 pixels, useful for verifying pixel addressing at all scales.
  """
  @spec checkerboard(GenServer.server()) :: :ok | {:error, term()}
  def checkerboard(server) do
    spec = Display.spec(server)
    buffer = TestPattern.checkerboard(spec)
    Display.display(server, buffer)
  end

  @doc """
  Display a full white screen.

  Useful for verifying the display can clear all pixels to white.
  """
  @spec full_white(GenServer.server()) :: :ok | {:error, term()}
  def full_white(server) do
    spec = Display.spec(server)
    buffer = TestPattern.full_white(spec)
    Display.display(server, buffer)
  end

  @doc """
  Display a full black screen.

  Useful for verifying the display can set all pixels to black.
  """
  @spec full_black(GenServer.server()) :: :ok | {:error, term()}
  def full_black(server) do
    spec = Display.spec(server)
    buffer = TestPattern.full_black(spec)
    Display.display(server, buffer)
  end

  @doc """
  Display all test patterns in sequence with a pause between each.

  Useful for hardware verification - cycles through checkerboard, full white,
  and full black patterns.

  ## Options

  - `:delay_ms` - Delay between patterns in milliseconds (default: 2000)

  ## Examples

      # Show all patterns with 2 second delays
      TestPattern.Display.show_all(pid)

      # Show all patterns with 5 second delays
      TestPattern.Display.show_all(pid, delay_ms: 5000)

  """
  @spec show_all(GenServer.server(), keyword()) :: :ok
  def show_all(server, opts \\ []) do
    delay_ms = Keyword.get(opts, :delay_ms, 2000)

    patterns = [
      {"checkerboard", &checkerboard/1},
      {"full white", &full_white/1},
      {"full black", &full_black/1}
    ]

    Enum.each(patterns, fn {name, func} ->
      IO.puts("\n=== Displaying #{name} ===")
      func.(server)
      Process.sleep(delay_ms)
    end)

    IO.puts("\n=== All patterns displayed ===")
    :ok
  end

  @doc """
  Stop the display GenServer and put the display to sleep.

  This clears the pending operations and puts the display into
  low-power sleep mode.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    Display.sleep(server)
    GenServer.stop(server)
  end
end
