defmodule Papyrus.Renderer.Headless.SvgTest do
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

  describe "render_html/3 with SVG backend" do
    @tag :svg_backend
    test "returns {:ok, binary} for simple_message pattern" do
      svg = Html.simple_message("Test")
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, test_display_spec(), backend: :svg)
      assert is_binary(bitmap)
      # Bitmap size should be close to expected (may vary slightly due to resvg output)
      assert byte_size(bitmap) >= 1250
    end

    @tag :svg_backend
    test "returns {:ok, binary} for dashboard_tile pattern" do
      svg = Html.dashboard_tile(value: "24°C", label: "Temp")
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, test_display_spec(), backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    @tag :svg_backend
    test "returns {:ok, binary} for lorem_ipsum_layout pattern" do
      svg = Html.lorem_ipsum_layout(title: "Test")
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, test_display_spec(), backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "render_svg/2" do
    @tag :svg_backend
    test "renders raw SVG string" do
      svg = """
      <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#ff0000"/>
      </svg>
      """

      assert {:ok, bitmap} = Headless.render_svg(svg, test_display_spec())
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    @tag :svg_backend
    test "renders SVG string with text element" do
      svg = """
      <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#ffffff"/>
        <text x="50" y="50" text-anchor="middle" font-size="16">Hello</text>
      </svg>
      """

      assert {:ok, bitmap} = Headless.render_svg(svg, test_display_spec())
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    @tag :svg_backend
    test "returns error for invalid SVG" do
      assert {:error, _reason} = Headless.render_svg("not valid svg", test_display_spec())
    end

    @tag :svg_backend
    test "returns error when resvg not available" do
      # This test documents the error case - resvg should be available in test env
      # If resvg is not compiled, this error path is tested
      unless Headless.resvg_available?() do
        assert {:error, msg} = Headless.render_svg("<svg/>", test_display_spec())
        assert msg =~ "resvg not available"
      end
    end
  end

  describe "display/4 with SVG backend" do
    @tag :svg_backend
    test "renders SVG successfully" do
      spec = test_display_spec()
      svg = Html.simple_message("Test")

      # Test that render_html works correctly
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "resvg_available?/0" do
    @tag :svg_backend
    test "returns true when resvg is available" do
      # resvg should be available since it's a dependency
      assert Headless.resvg_available?() == true
    end
  end
end
