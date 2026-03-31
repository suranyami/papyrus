defmodule Papyrus.TestPattern do
  @moduledoc """
  Generate test pattern buffers for hardware verification.

  Each function accepts a `%Papyrus.DisplaySpec{}` and returns a packed
  binary buffer of `spec.buffer_size` bytes. The encoding respects
  `spec.bit_order` so white/black semantics are correct for any display.

  ## Patterns

  - `full_white/1` — every pixel white; useful for verifying display clears
  - `full_black/1` — every pixel black; useful for verifying full coverage
  - `checkerboard/1` — pyramid checkerboard with squares from 64x64 down to 1x1;
    useful for verifying pixel addressing, bit order, and visual clarity at multiple scales
  """

  alias Papyrus.DisplaySpec

  @doc "Return an all-white buffer for the given display spec."
  @spec full_white(DisplaySpec.t()) :: binary()
  def full_white(%DisplaySpec{bit_order: :white_high, buffer_size: size}),
    do: :binary.copy(<<0xFF>>, size)

  def full_white(%DisplaySpec{bit_order: :white_low, buffer_size: size}),
    do: :binary.copy(<<0x00>>, size)

  @doc "Return an all-black buffer for the given display spec."
  @spec full_black(DisplaySpec.t()) :: binary()
  def full_black(%DisplaySpec{bit_order: :white_high, buffer_size: size}),
    do: :binary.copy(<<0x00>>, size)

  def full_black(%DisplaySpec{bit_order: :white_low, buffer_size: size}),
    do: :binary.copy(<<0xFF>>, size)

  @doc """
  Return a pyramid checkerboard buffer with squares at multiple scales.

  Creates a stairstep pattern where square sizes start at 64x64 pixels and halve
  (64→32→16→8→4→2→1) as you move diagonally across the display. This allows visual
  verification at multiple scales - large squares are visible from a distance,
  while 1x1 squares verify individual pixel addressing.

  The pattern divides the display into diagonal bands, with each band having
  a different checkerboard size. The top-left corner has 64x64 squares, and
  the bottom-right has 1x1 pixel squares.

  The pattern scales to fit the display - larger displays show more levels,
  while smaller displays compress the levels to fit.
  """
  @spec checkerboard(DisplaySpec.t()) :: binary()
  def checkerboard(%DisplaySpec{} = spec) do
    width = spec.width
    height = spec.height
    bit_order = spec.bit_order
    white_bit = if bit_order == :white_high, do: 1, else: 0
    row_bytes = div(width + 7, 8)

    # Calculate the maximum diagonal
    max_diagonal = width + height - 2

    # Build buffer row by row
    for y <- 0..(height - 1), into: <<>> do
      build_row(width, y, white_bit, row_bytes, max_diagonal)
    end
  end

  # Build a single row of bytes for the given y position
  defp build_row(width, y, white_bit, row_bytes, max_diagonal) do
    for x <- 0..(width - 1), into: <<>> do
      pixel = pyramid_pixel(x, y, white_bit, max_diagonal)
      <<pixel::1>>
    end
    |> pad_to_bytes(row_bytes)
  end

  # Compute pixel value (0 or 1) for pyramid checkerboard
  defp pyramid_pixel(x, y, white_bit, max_diagonal) do
    # Use diagonal position to determine which "level" we're at
    # Top-left = level 0 (largest squares), bottom-right = level 6 (1x1)
    diagonal = x + y

    # Scale diagonal to 0-6 range based on display size
    # This ensures all 7 levels are represented across the display diagonal
    level =
      if max_diagonal > 0 do
        min(6, div(diagonal * 7, max_diagonal))
      else
        0
      end

    # Square size for this level: 64, 32, 16, 8, 4, 2, 1
    square_size = max(1, div(64, round(:math.pow(2, level))))

    # Calculate which square we're in for checkerboard pattern
    square_x = div(x, square_size)
    square_y = div(y, square_size)

    # Checkerboard alternation: (square_x + square_y) mod 2
    if rem(square_x + square_y, 2) == 0 do
      white_bit
    else
      1 - white_bit
    end
  end

  # Pad bitstring to full bytes
  defp pad_to_bytes(bits, target_bytes) do
    padding_bits = target_bytes * 8 - bit_size(bits)
    if padding_bits > 0 do
      <<bits::bitstring, 0::size(padding_bits)>>
    else
      bits
    end
  end
end
