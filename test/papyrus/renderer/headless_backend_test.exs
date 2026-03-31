defmodule Papyrus.Renderer.Headless.BackendTest do
  use ExUnit.Case, async: false

  alias Papyrus.Renderer.Headless
  alias Papyrus.DisplaySpec

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

  describe "backend auto-selection" do
    test "selects backend based on availability" do
      spec = test_display_spec()
      # Use SVG input - works with any backend
      svg =
        "<svg width=\"100\" height=\"100\" xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"100\" height=\"100\" fill=\"#ff0000\"/></svg>"

      # Should succeed with auto backend (uses whatever is available)
      result = Headless.render_html({:svg, svg}, spec, backend: :auto)
      assert {:ok, bitmap} = result
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    test "uses SVG backend for SVG input" do
      spec = test_display_spec()

      svg =
        "<svg width=\"100\" height=\"100\" xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"100\" height=\"100\" fill=\"#ff0000\"/></svg>"

      # Force SVG backend
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    test "returns error when no backend available" do
      # This test documents the error path
      # In practice, resvg should always be available since it's a dependency
      unless Headless.resvg_available?() do
        spec = test_display_spec()
        svg = "<svg/>"

        assert {:error, msg} = Headless.render_html({:svg, svg}, spec)
        assert msg =~ "no rendering backend available"
      end
    end
  end

  describe "backend selection with :svg" do
    test "forces SVG backend for SVG input" do
      spec = test_display_spec()

      svg =
        "<svg width=\"100\" height=\"100\" xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"100\" height=\"100\" fill=\"#00ff00\"/></svg>"

      # Should use SVG backend regardless of wkhtmltoimage availability
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    test "returns error when resvg not available" do
      unless Headless.resvg_available?() do
        spec = test_display_spec()
        svg = "<svg/>"

        assert {:error, msg} = Headless.render_html({:svg, svg}, spec, backend: :svg)
        assert msg =~ "resvg not available"
      end
    end

    test "returns error for HTML input with SVG backend" do
      spec = test_display_spec()

      result = Headless.render_html({:html, "<h1>Test</h1>"}, spec, backend: :svg)
      assert {:error, msg} = result
      assert msg =~ "HTML input requires Node.js"
    end
  end

  describe "backend selection with :node" do
    test "uses Node.js backend when available" do
      if Headless.node_available?() do
        spec = test_display_spec()
        html = "<!DOCTYPE html><html><body><h1>Test</h1></body></html>"

        result = Headless.render_html({:html, html}, spec, backend: :node)
        assert {:ok, bitmap} = result
        assert is_binary(bitmap)
        # 100x100 display: each row needs ceil(100/8)=13 bytes, so 100*13=1300 bytes
        assert byte_size(bitmap) >= 1250
      else
        # Test returns error when not available
        spec = test_display_spec()
        html = "<h1>Test</h1>"

        assert {:error, msg} = Headless.render_html({:html, html}, spec, backend: :node)
        assert msg =~ "not found"
      end
    end

    test "returns error when Node.js not found" do
      # Temporarily hide node from PATH
      orig_path = System.get_env("PATH")
      System.put_env("PATH", "/nonexistent")

      spec = test_display_spec()
      html = "<h1>Test</h1>"

      assert {:error, msg} = Headless.render_html({:html, html}, spec, backend: :node)
      assert msg =~ "not found"

      System.put_env("PATH", orig_path)
    end
  end

  describe "input type handling" do
    test "SVG input renders directly" do
      svg = """
      <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#ff0000"/>
      </svg>
      """

      spec = test_display_spec()

      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    test "file input reads and renders file" do
      # Create temp SVG file
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.svg")

      svg_content = """
      <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#00ff00"/>
      </svg>
      """

      File.write!(path, svg_content)

      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:file, path}, spec, backend: :svg)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250

      File.rm!(path)
    end

    test "file input returns error for non-existent file" do
      spec = test_display_spec()

      assert {:error, msg} =
               Headless.render_html({:file, "/nonexistent/file.svg"}, spec, backend: :svg)

      assert msg =~ "not found"
    end

    test "URL input returns error for SVG backend" do
      spec = test_display_spec()

      assert {:error, msg} =
               Headless.render_html({:url, "https://example.com"}, spec, backend: :svg)

      assert msg =~ "URL input requires Node.js"
    end
  end

  describe "availability checks" do
    test "resvg_available? returns boolean" do
      result = Headless.resvg_available?()
      assert is_boolean(result)
    end

    test "node_available? returns boolean" do
      result = Headless.node_available?()
      assert is_boolean(result)
    end
  end
end
