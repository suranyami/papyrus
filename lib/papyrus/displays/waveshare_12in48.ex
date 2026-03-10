defmodule Papyrus.Displays.Waveshare12in48 do
  @moduledoc """
  Display spec for the Waveshare 12.48\" black-and-white ePaper panel.

  - Resolution: 1304 × 984 pixels
  - Buffer: 163 bytes/row × 984 rows = 160,392 bytes
  - Each byte encodes 8 horizontal pixels; 1 = white, 0 = black
  - Four sub-panels: M1, S1, M2, S2 (handled transparently by the C driver)
  """

  @behaviour Papyrus.DisplaySpec
  alias Papyrus.DisplaySpec

  @impl Papyrus.DisplaySpec
  @spec spec() :: DisplaySpec.t()
  def spec do
    %DisplaySpec{
      model: :waveshare_12in48,
      width: 1304,
      height: 984,
      buffer_size: 163 * 984,
      color_mode: :black_white
    }
  end

  @doc "Return a fully-white (blank) image buffer."
  @spec blank_buffer() :: binary()
  def blank_buffer, do: :binary.copy(<<0xFF>>, spec().buffer_size)
end
