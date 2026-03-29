defmodule Papyrus.BitmapTest do
  use ExUnit.Case, async: true

  alias Papyrus.DisplaySpec

  @valid_pin_config %{rst: 1, dc: 2, cs: 3, busy: 4}
  @fixtures_dir Path.join(__DIR__, "../support/fixtures")

  defp test_spec(opts) do
    width = Keyword.get(opts, :width, 8)
    height = Keyword.get(opts, :height, 8)
    bit_order = Keyword.get(opts, :bit_order, :white_high)

    %DisplaySpec{
      model: :test,
      width: width,
      height: height,
      buffer_size: div(width, 8) * height,
      pin_config: @valid_pin_config,
      bit_order: bit_order
    }
  end

  defp fixture_path(name), do: Path.join(@fixtures_dir, name)

  describe "blank/1" do
    test "returns binary of spec.buffer_size bytes with :white_high" do
      spec = test_spec(width: 16, height: 16, bit_order: :white_high)
      buf = Papyrus.Bitmap.blank(spec)
      assert byte_size(buf) == spec.buffer_size
      assert buf == :binary.copy(<<0xFF>>, spec.buffer_size)
    end

    test "returns binary of spec.buffer_size bytes with :white_low" do
      spec = test_spec(width: 16, height: 16, bit_order: :white_low)
      buf = Papyrus.Bitmap.blank(spec)
      assert byte_size(buf) == spec.buffer_size
      assert buf == :binary.copy(<<0x00>>, spec.buffer_size)
    end

    test "buffer size matches spec exactly for large display" do
      spec = %DisplaySpec{
        model: :test_large,
        width: 1304,
        height: 984,
        buffer_size: 163 * 984,
        pin_config: @valid_pin_config,
        bit_order: :white_high
      }

      buf = Papyrus.Bitmap.blank(spec)
      assert byte_size(buf) == 163 * 984
    end
  end

  describe "StbLoader" do
    test "loads PNG as grayscale returning {:ok, %StbImage{}}" do
      {:ok, img} = Papyrus.Bitmap.StbLoader.load(fixture_path("white_4x8.png"))
      assert {8, 4, 1} = img.shape
    end

    test "returns {:error, _} for nonexistent file" do
      assert {:error, _reason} = Papyrus.Bitmap.StbLoader.load("/nonexistent.png")
    end
  end
end
