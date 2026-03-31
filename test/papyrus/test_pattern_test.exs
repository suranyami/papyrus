defmodule Papyrus.TestPatternTest do
  use ExUnit.Case, async: true

  alias Papyrus.DisplaySpec
  alias Papyrus.TestPattern
  alias Papyrus.Displays.Waveshare12in48

  @valid_pin_config %{rst: 1, dc: 2, cs: 3, busy: 4}

  @small_spec_white_high struct!(DisplaySpec, %{
                           model: :test,
                           width: 16,
                           height: 16,
                           buffer_size: 32,
                           pin_config: @valid_pin_config,
                           bit_order: :white_high
                         })

  @small_spec_white_low struct!(DisplaySpec, %{
                          model: :test,
                          width: 16,
                          height: 16,
                          buffer_size: 32,
                          pin_config: @valid_pin_config,
                          bit_order: :white_low
                        })

  describe "full_white/1" do
    test "returns a binary of buffer_size bytes for :white_high spec" do
      buf = TestPattern.full_white(@small_spec_white_high)
      assert is_binary(buf)
      assert byte_size(buf) == @small_spec_white_high.buffer_size
    end

    test "all bytes are 0xFF for :white_high spec" do
      buf = TestPattern.full_white(@small_spec_white_high)
      assert buf == :binary.copy(<<0xFF>>, @small_spec_white_high.buffer_size)
    end

    test "returns a binary of buffer_size bytes for :white_low spec" do
      buf = TestPattern.full_white(@small_spec_white_low)
      assert is_binary(buf)
      assert byte_size(buf) == @small_spec_white_low.buffer_size
    end

    test "all bytes are 0x00 for :white_low spec" do
      buf = TestPattern.full_white(@small_spec_white_low)
      assert buf == :binary.copy(<<0x00>>, @small_spec_white_low.buffer_size)
    end

    test "works with real Waveshare12in48 spec" do
      spec = Waveshare12in48.spec()
      buf = TestPattern.full_white(spec)
      assert byte_size(buf) == spec.buffer_size
    end
  end

  describe "full_black/1" do
    test "returns a binary of buffer_size bytes for :white_high spec" do
      buf = TestPattern.full_black(@small_spec_white_high)
      assert is_binary(buf)
      assert byte_size(buf) == @small_spec_white_high.buffer_size
    end

    test "all bytes are 0x00 for :white_high spec" do
      buf = TestPattern.full_black(@small_spec_white_high)
      assert buf == :binary.copy(<<0x00>>, @small_spec_white_high.buffer_size)
    end

    test "returns a binary of buffer_size bytes for :white_low spec" do
      buf = TestPattern.full_black(@small_spec_white_low)
      assert is_binary(buf)
      assert byte_size(buf) == @small_spec_white_low.buffer_size
    end

    test "all bytes are 0xFF for :white_low spec" do
      buf = TestPattern.full_black(@small_spec_white_low)
      assert buf == :binary.copy(<<0xFF>>, @small_spec_white_low.buffer_size)
    end

    test "works with real Waveshare12in48 spec" do
      spec = Waveshare12in48.spec()
      buf = TestPattern.full_black(spec)
      assert byte_size(buf) == spec.buffer_size
    end
  end

  describe "checkerboard/1" do
    test "returns a binary of buffer_size bytes" do
      buf = TestPattern.checkerboard(@small_spec_white_high)
      assert is_binary(buf)
      assert byte_size(buf) == @small_spec_white_high.buffer_size
    end

    test "produces varied pattern across diagonal bands" do
      # Pyramid checkerboard should have varied bytes at different scales
      buf = TestPattern.checkerboard(@small_spec_white_high)
      unique_bytes = MapSet.size(MapSet.new(:binary.bin_to_list(buf)))
      # Should have multiple different byte values due to pyramid pattern
      assert unique_bytes > 5
    end

    test "produces fine checkerboard at bottom-right of large display" do
      # Use a larger spec to see the full pyramid effect
      large_spec = struct!(DisplaySpec, %{
        model: :test,
        width: 128,
        height: 128,
        buffer_size: 2048,
        pin_config: @valid_pin_config,
        bit_order: :white_high
      })
      buf = TestPattern.checkerboard(large_spec)
      # Bottom-right corner should have 1x1 pixel checkerboard
      # This produces alternating bit patterns within bytes
      unique_bytes = MapSet.size(MapSet.new(:binary.bin_to_list(buf)))
      assert unique_bytes > 20
    end

    test "bit_order produces consistent pattern" do
      buf_high = TestPattern.checkerboard(@small_spec_white_high)
      buf_low = TestPattern.checkerboard(@small_spec_white_low)
      # Same dimensions should produce same buffer size
      assert byte_size(buf_high) == byte_size(buf_low)
    end

    test "works with real Waveshare12in48 spec" do
      spec = Waveshare12in48.spec()
      buf = TestPattern.checkerboard(spec)
      assert byte_size(buf) == spec.buffer_size
    end
  end
end
