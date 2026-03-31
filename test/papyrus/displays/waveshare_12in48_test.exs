defmodule Papyrus.Displays.Waveshare12in48Test do
  use ExUnit.Case, async: true

  alias Papyrus.Displays.Waveshare12in48
  alias Papyrus.DisplaySpec

  describe "spec/0" do
    setup do
      {:ok, spec: Waveshare12in48.spec()}
    end

    test "returns a %Papyrus.DisplaySpec{} struct", %{spec: spec} do
      assert %DisplaySpec{} = spec
    end

    test "has the correct model", %{spec: spec} do
      assert spec.model == :waveshare_12in48
    end

    test "has correct dimensions", %{spec: spec} do
      assert spec.width == 1304
      assert spec.height == 984
    end

    test "has correct buffer_size (163 bytes/row * 984 rows)", %{spec: spec} do
      assert spec.buffer_size == 163 * 984
    end

    test "color_mode is :three_color", %{spec: spec} do
      assert spec.color_mode == :three_color
    end

    test "bit_order is :white_high", %{spec: spec} do
      assert spec.bit_order == :white_high
    end

    test "partial_refresh is false", %{spec: spec} do
      assert spec.partial_refresh == false
    end

    test "pin_config.m1s1_rst matches DEV_Config.h EPD_M1S1_RST_PIN (6)", %{spec: spec} do
      assert spec.pin_config.m1s1_rst == 6
    end

    test "pin_config.m1_cs matches DEV_Config.h EPD_M1_CS_PIN (8)", %{spec: spec} do
      assert spec.pin_config.m1_cs == 8
    end

    test "pin_config.s2_busy matches DEV_Config.h EPD_S2_BUSY_PIN (24)", %{spec: spec} do
      assert spec.pin_config.s2_busy == 24
    end

    test "pin_config has all 14 pins present", %{spec: spec} do
      assert map_size(spec.pin_config) == 14
    end

    test "pin_config matches DEV_Config.h constants exactly", %{spec: spec} do
      assert spec.pin_config == %{
               sck: 11,
               mosi: 10,
               m1_cs: 8,
               s1_cs: 7,
               m2_cs: 17,
               s2_cs: 18,
               m1s1_dc: 13,
               m2s2_dc: 22,
               m1s1_rst: 6,
               m2s2_rst: 23,
               m1_busy: 5,
               s1_busy: 19,
               m2_busy: 27,
               s2_busy: 24
             }
    end
  end

  describe "blank_buffer/0" do
    test "returns a binary" do
      assert is_binary(Waveshare12in48.blank_buffer())
    end

    test "returns a binary of spec.buffer_size bytes" do
      spec = Waveshare12in48.spec()
      buffer = Waveshare12in48.blank_buffer()
      assert byte_size(buffer) == spec.buffer_size
    end

    test "buffer is all 0xFF bytes (white pixels)" do
      buffer = Waveshare12in48.blank_buffer()
      assert buffer == :binary.copy(<<0xFF>>, 163 * 984)
    end
  end
end
