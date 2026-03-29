defmodule Papyrus.TestPattern do
  @moduledoc """
  Generate test pattern buffers for hardware verification.

  Each function accepts a `%Papyrus.DisplaySpec{}` and returns a packed
  binary buffer of `spec.buffer_size` bytes. The encoding respects
  `spec.bit_order` so white/black semantics are correct for any display.

  ## Patterns

  - `full_white/1` — every pixel white; useful for verifying display clears
  - `full_black/1` — every pixel black; useful for verifying full coverage
  - `checkerboard/1` — alternating pixels at bit level (0xAA/0x55); useful
    for verifying pixel addressing and bit order
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

  @doc "Return a pixel-level checkerboard buffer (alternating 0xAA/0x55 bytes)."
  @spec checkerboard(DisplaySpec.t()) :: binary()
  def checkerboard(%DisplaySpec{buffer_size: size}) do
    pair = <<0xAA, 0x55>>
    full_pairs = div(size, 2)
    remainder = rem(size, 2)
    base = :binary.copy(pair, full_pairs)

    case remainder do
      0 -> base
      1 -> base <> <<0xAA>>
    end
  end
end
