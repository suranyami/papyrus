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

  describe "blank_red_plane/1" do
    test "returns all-zero binary of spec.buffer_size bytes" do
      spec = test_spec(width: 16, height: 16, bit_order: :white_high)
      buf = Papyrus.Bitmap.blank_red_plane(spec)
      assert byte_size(buf) == spec.buffer_size
      assert buf == :binary.copy(<<0x00>>, spec.buffer_size)
    end

    test "is all-zero regardless of bit_order (red plane encoding is fixed)" do
      spec_high = test_spec(width: 8, height: 8, bit_order: :white_high)
      spec_low = test_spec(width: 8, height: 8, bit_order: :white_low)
      assert Papyrus.Bitmap.blank_red_plane(spec_high) == :binary.copy(<<0x00>>, spec_high.buffer_size)
      assert Papyrus.Bitmap.blank_red_plane(spec_low) == :binary.copy(<<0x00>>, spec_low.buffer_size)
    end

    test "is NOT the same as blank/1 for :white_high display" do
      # This test documents the critical encoding difference:
      # blank/1 returns 0xFF (white in black-plane encoding)
      # blank_red_plane/1 returns 0x00 (no-red in red-plane encoding)
      # Using blank/1 as a red plane would make the entire display show red ink.
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)
      refute Papyrus.Bitmap.blank(spec) == Papyrus.Bitmap.blank_red_plane(spec)
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

  describe "from_image/2" do
    test "converts white PNG to all-0xFF buffer with :white_high" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("white_4x8.png"), spec)
      assert byte_size(buf) == spec.buffer_size
      # white_4x8.png letterboxed into 8x8: all pixels white (255) -> all 0xFF
      assert buf == :binary.copy(<<0xFF>>, spec.buffer_size)
    end

    test "converts white PNG to all-0x00 buffer with :white_low" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_low)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("white_4x8.png"), spec)
      assert byte_size(buf) == spec.buffer_size
      # White pixels + :white_low -> all 0x00 bits
      assert buf == :binary.copy(<<0x00>>, spec.buffer_size)
    end

    test "converts black PNG with :white_high returns binary with black rows" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("black_4x8.png"), spec)
      assert byte_size(buf) == spec.buffer_size
      # black_4x8.png (4x8) letterboxed into 8x8: the black content rows map to 0x00
      # Padding rows (white) map to 0xFF. Not all bytes will be 0x00.
      # At minimum: the buffer should not be all 0xFF (there are black pixels)
      refute buf == :binary.copy(<<0xFF>>, spec.buffer_size)
    end

    test "buffer byte_size always equals spec.buffer_size" do
      spec = test_spec(width: 16, height: 16, bit_order: :white_high)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("white_4x8.png"), spec)
      assert byte_size(buf) == spec.buffer_size
    end

    test "handles mismatched dimensions via letterbox resize" do
      # 4x8 image into 16x16 spec — dimension mismatch, handled by letterbox
      spec = test_spec(width: 16, height: 16, bit_order: :white_high)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("white_4x8.png"), spec)
      assert byte_size(buf) == spec.buffer_size
    end

    test "returns {:error, _} for nonexistent file" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)
      assert {:error, _} = Papyrus.Bitmap.from_image("/does/not/exist.png", spec)
    end

    test "loads BMP format" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)
      assert {:ok, buf} = Papyrus.Bitmap.from_image(fixture_path("white_4x8.bmp"), spec)
      assert byte_size(buf) == spec.buffer_size
      # BMP all-white letterboxed into 8x8 with :white_high -> all 0xFF
      assert buf == :binary.copy(<<0xFF>>, spec.buffer_size)
    end
  end

  describe "from_image/3" do
    test "dither: true returns binary of correct size" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)

      assert {:ok, buf} =
               Papyrus.Bitmap.from_image(fixture_path("gradient_4x8.png"), spec, dither: true)

      assert byte_size(buf) == spec.buffer_size
    end

    test "dither: true with all-white input produces all-0xFF" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)

      assert {:ok, buf} =
               Papyrus.Bitmap.from_image(fixture_path("white_4x8.png"), spec, dither: true)

      assert byte_size(buf) == spec.buffer_size
      # All-white input has no quantization error -> same as threshold
      assert buf == :binary.copy(<<0xFF>>, spec.buffer_size)
    end

    test "dither: true with gradient PNG returns {:ok, binary}" do
      spec = test_spec(width: 8, height: 8, bit_order: :white_high)

      assert {:ok, buf} =
               Papyrus.Bitmap.from_image(fixture_path("gradient_4x8.png"), spec, dither: true)

      assert is_binary(buf)
    end
  end
end
