defmodule Papyrus.Displays.Waveshare12in48 do
  @moduledoc """
  Display spec for the Waveshare 12.48\" black-and-white ePaper panel.

  - Resolution: 1304 × 984 pixels
  - Buffer: 163 bytes/row × 984 rows = 160,392 bytes
  - Each byte encodes 8 horizontal pixels; 1 = white, 0 = black
  - Four sub-panels: M1, S1, M2, S2 (handled transparently by the C driver)

  ## Pin configuration

  The `pin_config` map uses flat namespaced keys mirroring `DEV_Config.h` constants.
  Pin numbers are BCM GPIO numbers for Raspberry Pi.

  | Key        | Pin | Description                       |
  |------------|-----|-----------------------------------|
  | `:sck`     | 11  | SPI clock                         |
  | `:mosi`    | 10  | SPI MOSI                          |
  | `:m1_cs`   |  8  | M1 sub-panel chip select          |
  | `:s1_cs`   |  7  | S1 sub-panel chip select          |
  | `:m2_cs`   | 17  | M2 sub-panel chip select          |
  | `:s2_cs`   | 18  | S2 sub-panel chip select          |
  | `:m1s1_dc` | 13  | M1/S1 data/command                |
  | `:m2s2_dc` | 22  | M2/S2 data/command                |
  | `:m1s1_rst`|  6  | M1/S1 reset                       |
  | `:m2s2_rst`| 23  | M2/S2 reset                       |
  | `:m1_busy` |  5  | M1 busy signal                    |
  | `:s1_busy` | 19  | S1 busy signal                    |
  | `:m2_busy` | 27  | M2 busy signal                    |
  | `:s2_busy` | 24  | S2 busy signal                    |
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
      color_mode: :black_white,
      partial_refresh: false,
      pin_config: %{
        sck: 11, mosi: 10,
        m1_cs: 8,  s1_cs: 7,  m2_cs: 17, s2_cs: 18,
        m1s1_dc: 13, m2s2_dc: 22,
        m1s1_rst: 6, m2s2_rst: 23,
        m1_busy: 5, s1_busy: 19, m2_busy: 27, s2_busy: 24
      }
    }
  end

  @doc "Return a fully-white (blank) image buffer."
  @spec blank_buffer() :: binary()
  def blank_buffer, do: :binary.copy(<<0xFF>>, spec().buffer_size)
end
