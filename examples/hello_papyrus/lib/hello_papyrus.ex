defmodule HelloPapyrus do
  @moduledoc """
  Checkerboard demo for the Waveshare 12.48" ePaper panel.

  Run with:

      mix run -e "HelloPapyrus.run()"
  """

  alias Papyrus.Displays.Waveshare12in48

  def run do
    {:ok, display} = Papyrus.start_display(display_module: Waveshare12in48)

    IO.puts("Clearing display...")
    :ok = Papyrus.clear(display)

    IO.puts("Displaying checkerboard...")
    :ok = Papyrus.display(display, checkerboard_image())

    IO.puts("Holding for 5 seconds...")
    Process.sleep(5_000)

    IO.puts("Sleeping display...")
    :ok = Papyrus.sleep(display)

    IO.puts("Done.")
  end

  # Builds an 8×8 pixel checkerboard across the full 1304×984 buffer.
  # Each byte encodes 8 pixels; alternating 0x55 (01010101) / 0xAA (10101010)
  # and shifting per row creates a 16-pixel-wide checker pattern.
  defp checkerboard_image do
    spec = Waveshare12in48.spec()

    for row <- 0..(spec.height - 1), into: <<>> do
      for col_byte <- 0..(div(spec.width, 8) - 1), into: <<>> do
        if rem(row + col_byte, 2) == 0, do: <<0x55>>, else: <<0xAA>>
      end
    end
  end
end
