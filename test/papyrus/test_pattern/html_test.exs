defmodule Papyrus.TestPattern.HtmlTest do
  use ExUnit.Case, async: false

  alias Papyrus.Renderer.Headless
  alias Papyrus.DisplaySpec
  alias Papyrus.TestPattern.Html

  @valid_pin_config %{rst: 6, dc: 13, cs: 8, busy: 5}

  @spec test_display_spec() :: DisplaySpec.t()
  defp test_display_spec do
    struct!(DisplaySpec, %{
      model: :test,
      width: 100,
      height: 100,
      buffer_size: 1250,
      pin_config: @valid_pin_config,
      bit_order: :white_high
    })
  end

  describe "simple_message/2" do
    test "generates SVG with message" do
      svg = Html.simple_message("System Ready")
      assert svg =~ ~s(<svg)
      assert svg =~ "System Ready"
      assert svg =~ ~s(xmlns="http://www.w3.org/2000/svg")
    end

    test "generates SVG with title option" do
      svg = Html.simple_message("Online", title: "Status")
      assert svg =~ "Status"
      assert svg =~ "Online"
    end

    test "generates SVG with custom background" do
      svg = Html.simple_message("Test", background: "#f0f0f0")
      assert svg =~ ~s(fill="#f0f0f0")
    end

    test "renders successfully on SVG backend" do
      svg = Html.simple_message("System Ready", title: "Status")
      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "dashboard_tile/1" do
    test "generates SVG with default values" do
      svg = Html.dashboard_tile()
      assert svg =~ "TEMPERATURE"
      assert svg =~ "24°C"
      assert svg =~ ~s(<rect)
    end

    test "generates SVG with custom label and value" do
      svg = Html.dashboard_tile(label: "HUMIDITY", value: "65%")
      assert svg =~ "HUMIDITY"
      assert svg =~ "65%"
    end

    test "generates SVG with custom colors" do
      svg =
        Html.dashboard_tile(
          label: "PRESSURE",
          value: "1013 hPa",
          label_color: "#333333",
          value_color: "#0066cc"
        )

      assert svg =~ ~s(fill="#333333")
      assert svg =~ ~s(fill="#0066cc")
    end

    test "renders successfully on SVG backend" do
      svg = Html.dashboard_tile(value: "24°C", label: "Temperature")
      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "lorem_ipsum_layout/1" do
    test "generates SVG with default title" do
      svg = Html.lorem_ipsum_layout()
      assert svg =~ "Typography Test"
      assert svg =~ "Lorem ipsum"
    end

    test "generates SVG with custom title" do
      svg = Html.lorem_ipsum_layout(title: "Reading Test")
      assert svg =~ "Reading Test"
    end

    test "generates SVG with custom background" do
      svg = Html.lorem_ipsum_layout(background: "#fafafa")
      assert svg =~ ~s(fill="#fafafa")
    end

    test "renders successfully on SVG backend" do
      svg = Html.lorem_ipsum_layout(title: "Test")
      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "integration: pattern to bitmap" do
    test "simple_message produces valid bitmap" do
      svg = Html.simple_message("System Ready", title: "Status")
      spec = test_display_spec()

      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)

      # Verify bitmap properties
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= spec.buffer_size

      # Verify bitmap is not all zeros or all ones (has some content)
      refute bitmap == :binary.copy(<<0x00>>, spec.buffer_size)
      refute bitmap == :binary.copy(<<0xFF>>, spec.buffer_size)
    end

    test "dashboard_tile produces valid bitmap" do
      svg = Html.dashboard_tile(value: "24°C", label: "Temperature")
      spec = test_display_spec()

      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)

      assert is_binary(bitmap)
      assert byte_size(bitmap) >= spec.buffer_size
    end

    test "lorem_ipsum_layout produces valid bitmap" do
      svg = Html.lorem_ipsum_layout(title: "Typography")
      spec = test_display_spec()

      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)

      assert is_binary(bitmap)
      assert byte_size(bitmap) >= spec.buffer_size
    end
  end

  describe "escape_xml/1" do
    test "escapes ampersand" do
      # The Html module should escape XML entities
      svg = Html.simple_message("A & B")
      assert svg =~ "&amp;"
    end

    test "escapes less-than" do
      svg = Html.simple_message("A < B")
      assert svg =~ "&lt;"
    end

    test "escapes greater-than" do
      svg = Html.simple_message("A > B")
      assert svg =~ "&gt;"
    end
  end
end
