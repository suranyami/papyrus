defmodule Papyrus.DisplaySpecTest do
  use ExUnit.Case, async: true

  alias Papyrus.DisplaySpec

  @valid_pin_config %{rst: 6, dc: 13, cs: 8, busy: 5}
  @valid_attrs %{
    model: :test_display,
    width: 200,
    height: 200,
    buffer_size: 5000,
    pin_config: @valid_pin_config,
    bit_order: :white_high
  }

  describe "struct enforcement" do
    test "omitting pin_config raises ArgumentError" do
      assert_raise ArgumentError, ~r/pin_config/, fn ->
        # Use struct!/2 to bypass compile-time enforce_keys check so we can test runtime enforcement
        struct!(DisplaySpec, %{
          model: :test_display,
          width: 200,
          height: 200,
          buffer_size: 5000
        })
      end
    end

    test "omitting bit_order raises ArgumentError" do
      assert_raise ArgumentError, ~r/bit_order/, fn ->
        struct!(DisplaySpec, Map.delete(@valid_attrs, :bit_order))
      end
    end

    test "providing all required keys including pin_config succeeds" do
      spec = struct!(DisplaySpec, @valid_attrs)
      assert spec.model == :test_display
      assert spec.width == 200
      assert spec.height == 200
      assert spec.buffer_size == 5000
      assert spec.pin_config == @valid_pin_config
    end

    test "omitting model raises ArgumentError" do
      assert_raise ArgumentError, ~r/model/, fn ->
        struct!(DisplaySpec, %{width: 200, height: 200, buffer_size: 5000, pin_config: @valid_pin_config})
      end
    end
  end

  describe "default field values" do
    test "partial_refresh defaults to false when not provided" do
      spec = struct!(DisplaySpec, @valid_attrs)
      assert spec.partial_refresh == false
    end

    test "color_mode defaults to :black_white when not provided" do
      spec = struct!(DisplaySpec, @valid_attrs)
      assert spec.color_mode == :black_white
    end
  end

  describe "bit_order field" do
    test "bit_order is :white_high when set" do
      spec = struct!(DisplaySpec, @valid_attrs)
      assert spec.bit_order == :white_high
    end

    test "bit_order can be set to :white_low" do
      spec = struct!(DisplaySpec, Map.put(@valid_attrs, :bit_order, :white_low))
      assert spec.bit_order == :white_low
    end
  end

  describe "optional fields can be set" do
    test "partial_refresh can be set to true" do
      spec = struct!(DisplaySpec, Map.put(@valid_attrs, :partial_refresh, true))
      assert spec.partial_refresh == true
    end

    test "color_mode can be set to :three_color" do
      spec = struct!(DisplaySpec, Map.put(@valid_attrs, :color_mode, :three_color))
      assert spec.color_mode == :three_color
    end

    test "color_mode can be set to :four_gray" do
      spec = struct!(DisplaySpec, Map.put(@valid_attrs, :color_mode, :four_gray))
      assert spec.color_mode == :four_gray
    end
  end
end
