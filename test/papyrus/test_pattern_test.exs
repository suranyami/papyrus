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

  @odd_spec struct!(DisplaySpec, %{
    model: :test_odd,
    width: 16,
    height: 17,
    buffer_size: 33,
    pin_config: @valid_pin_config,
    bit_order: :white_high
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

    test "first byte is 0xAA" do
      buf = TestPattern.checkerboard(@small_spec_white_high)
      assert :binary.at(buf, 0) == 0xAA
    end

    test "second byte is 0x55" do
      buf = TestPattern.checkerboard(@small_spec_white_high)
      assert :binary.at(buf, 1) == 0x55
    end

    test "alternating 0xAA/0x55 pattern throughout even-size buffer" do
      buf = TestPattern.checkerboard(@small_spec_white_high)
      expected = :binary.copy(<<0xAA, 0x55>>, div(@small_spec_white_high.buffer_size, 2))
      assert buf == expected
    end

    test "odd buffer_size: last byte is 0xAA" do
      buf = TestPattern.checkerboard(@odd_spec)
      assert byte_size(buf) == 33
      assert :binary.at(buf, 32) == 0xAA
    end

    test "bit_order does not affect checkerboard pattern" do
      buf_high = TestPattern.checkerboard(@small_spec_white_high)
      buf_low = TestPattern.checkerboard(@small_spec_white_low)
      assert buf_high == buf_low
    end

    test "works with real Waveshare12in48 spec" do
      spec = Waveshare12in48.spec()
      buf = TestPattern.checkerboard(spec)
      assert byte_size(buf) == spec.buffer_size
    end
  end
end
