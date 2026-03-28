defmodule HelloPapyrus do
  @moduledoc """
  3-colour demo for the Waveshare 12.48" B (black/white/red) ePaper panel.

  Displays a 64×64 pixel black/white checkerboard on the top half and solid
  red on the bottom half, demonstrating all three colours.

  Run with:

      iex -S mix run
      HelloPapyrus.run()
  """

  alias Papyrus.Displays.Waveshare12in48

  # Square size in pixels for the checkerboard pattern.
  @square_px 64

  def run do
    {:ok, display} = Papyrus.start_display(display_module: Waveshare12in48)

    IO.puts("Clearing display...")
    :ok = Papyrus.clear(display)

    IO.puts("Displaying 3-colour test pattern...")
    {black, red} = test_pattern()
    :ok = Papyrus.display(display, black <> red)

    IO.puts("Holding for 5 seconds...")
    Process.sleep(5_000)

    IO.puts("Sleeping display...")
    :ok = Papyrus.sleep(display)

    IO.puts("Done.")
  end

  # Produces {black_plane, red_plane}, each 160,392 bytes.
  #
  # Top half (rows 0–491):   64×64 px black/white checkerboard, no red
  # Bottom half (rows 492–983): solid white background, solid red overlay
  #
  # Black plane: 0xFF = white, 0x00 = black
  # Red plane:   0x00 = no red, 0xFF = red
  defp test_pattern do
    spec = Waveshare12in48.spec()
    bytes_per_row = div(spec.width, 8)
    half_row = div(spec.height, 2)
    sq = @square_px
    sq_bytes = div(sq, 8)  # bytes per checkerboard square width

    black =
      for row <- 0..(spec.height - 1), into: <<>> do
        for col_byte <- 0..(bytes_per_row - 1), into: <<>> do
          if row < half_row do
            # Top half: 64×64 checkerboard
            row_block = div(row, sq)
            col_block = div(col_byte, sq_bytes)
            if rem(row_block + col_block, 2) == 0, do: <<0xFF>>, else: <<0x00>>
          else
            # Bottom half: all white (red layer will provide the colour)
            <<0xFF>>
          end
        end
      end

    red =
      for row <- 0..(spec.height - 1), into: <<>> do
        for _col_byte <- 0..(bytes_per_row - 1), into: <<>> do
          if row < half_row do
            <<0x00>>  # no red on top half
          else
            <<0xFF>>  # solid red on bottom half
          end
        end
      end

    {black, red}
  end
end
