defmodule Papyrus.DisplaySpecTest do
  use ExUnit.Case, async: true

  alias Papyrus.DisplaySpec

  @valid_pin_config %{rst: 6, dc: 13, cs: 8, busy: 5}
  @valid_attrs %{
    model: :test_display,
    width: 200,
    height: 200,
    buffer_size: 5000,
    pin_config: @valid_pin_config
  }

  describe "struct enforcement" do
    test "omitting pin_config raises KeyError" do
      assert_raise KeyError, fn ->
        %DisplaySpec{
          model: :test_display,
          width: 200,
          height: 200,
          buffer_size: 5000
        }
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

    test "omitting model raises KeyError" do
      assert_raise KeyError, fn ->
        %DisplaySpec{width: 200, height: 200, buffer_size: 5000, pin_config: @valid_pin_config}
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
