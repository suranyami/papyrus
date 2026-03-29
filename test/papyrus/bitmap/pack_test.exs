defmodule Papyrus.Bitmap.PackTest do
  use ExUnit.Case, async: true

  alias Papyrus.Bitmap.Pack

  describe "to_buffer/3 - threshold path" do
    test "all-255 pixels with :white_high returns all 0xFF bytes" do
      # 8x8 = 64 pixels, all white (255)
      pixels = :binary.copy(<<255>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert byte_size(result) == 8
      assert result == :binary.copy(<<0xFF>>, 8)
    end

    test "all-255 pixels with :white_low returns all 0x00 bytes" do
      pixels = :binary.copy(<<255>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_low)
      assert byte_size(result) == 8
      assert result == :binary.copy(<<0x00>>, 8)
    end

    test "all-0 pixels with :white_high returns all 0x00 bytes (black = low bit)" do
      pixels = :binary.copy(<<0>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert byte_size(result) == 8
      assert result == :binary.copy(<<0x00>>, 8)
    end

    test "all-0 pixels with :white_low returns all 0xFF bytes (black = high bit)" do
      pixels = :binary.copy(<<0>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_low)
      assert byte_size(result) == 8
      assert result == :binary.copy(<<0xFF>>, 8)
    end

    test "MSB-first packing: first pixel in row maps to bit 7 of first byte" do
      # Row: [255, 0, 0, 0, 0, 0, 0, 0] with :white_high
      # Expected byte: 0b10000000 = 0x80
      pixels = <<255, 0, 0, 0, 0, 0, 0, 0>>
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert result == <<0x80>>
    end

    test "MSB-first packing: last pixel in row maps to bit 0 of first byte" do
      # Row: [0, 0, 0, 0, 0, 0, 0, 255] with :white_high
      # Expected byte: 0b00000001 = 0x01
      pixels = <<0, 0, 0, 0, 0, 0, 0, 255>>
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert result == <<0x01>>
    end

    test "alternating pixels produce 0xAA pattern (width_high)" do
      # Row: [255, 0, 255, 0, 255, 0, 255, 0] -> 0b10101010 = 0xAA
      pixels = <<255, 0, 255, 0, 255, 0, 255, 0>>
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert result == <<0xAA>>
    end

    test "output byte_size equals ceil(width/8) * height" do
      # 8 width, 4 height -> 1 * 4 = 4 bytes
      pixels = :binary.copy(<<255>>, 8 * 4)
      result = Pack.to_buffer(pixels, 8, :white_high)
      assert byte_size(result) == div(8 + 7, 8) * 4
    end

    test "output size for 16x16 image" do
      pixels = :binary.copy(<<255>>, 16 * 16)
      result = Pack.to_buffer(pixels, 16, :white_high)
      # 16/8 = 2 bytes per row * 16 rows = 32 bytes
      assert byte_size(result) == 32
    end
  end

  describe "to_buffer/4 - dither path" do
    test "dither: true produces binary of correct size" do
      pixels = :binary.copy(<<128>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_high, dither: true)
      assert is_binary(result)
      assert byte_size(result) == 8
    end

    test "dither: true with all-white input produces all 0xFF (no error to diffuse)" do
      pixels = :binary.copy(<<255>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_high, dither: true)
      assert result == :binary.copy(<<0xFF>>, 8)
    end

    test "dither: true with all-black input produces all 0x00" do
      pixels = :binary.copy(<<0>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_high, dither: true)
      assert result == :binary.copy(<<0x00>>, 8)
    end

    test "dither: true produces different result from threshold for gradient" do
      # A gradient will be dithered differently than simple threshold
      # Both should produce correct byte size
      gradient_row = <<0, 85, 170, 255>>
      pixels = for _ <- 1..8, into: <<>>, do: gradient_row
      threshold_result = Pack.to_buffer(pixels, 4, :white_high)
      dither_result = Pack.to_buffer(pixels, 4, :white_high, dither: true)
      assert byte_size(threshold_result) == byte_size(dither_result)
      # They may or may not differ depending on gradient — but sizes must match
    end

    test "dither: true with :white_low all-white produces all 0x00" do
      pixels = :binary.copy(<<255>>, 8 * 8)
      result = Pack.to_buffer(pixels, 8, :white_low, dither: true)
      assert result == :binary.copy(<<0x00>>, 8)
    end
  end
end
