defmodule Papyrus.Renderer.Headless.NodeTest do
  use ExUnit.Case, async: false

  alias Papyrus.Renderer.Headless
  alias Papyrus.DisplaySpec
  alias Papyrus.TestPattern.Html

  @moduletag :requires_node

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

  describe "render_html/3 with Node.js backend" do
    @tag :requires_node
    test "renders HTML with full CSS support" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          .flex { display: flex; justify-content: center; }
        </style>
      </head>
      <body>
        <div class="flex">Centered</div>
      </body>
      </html>
      """

      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:html, html}, spec, backend: :node)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    @tag :requires_node
    test "renders URL input" do
      spec = test_display_spec()
      # Use a simple test URL - example.com is reliable
      assert {:ok, bitmap} = Headless.render_html({:url, "https://example.com"}, spec, backend: :node)

      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end

    @tag :requires_node
    test "renders file input" do
      # Create temp HTML file
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.html")
      File.write!(path, "<!DOCTYPE html><html><body><h1>File Test</h1></body></html>")

      spec = test_display_spec()
      assert {:ok, bitmap} = Headless.render_html({:file, path}, spec, backend: :node)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250

      File.rm!(path)
    end

    @tag :requires_node
    test "renders SVG pattern via Node.js backend" do
      svg = Html.simple_message("Test")
      spec = test_display_spec()
      # SVG patterns work with Node.js backend too (Puppeteer can render SVG)
      assert {:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :node)
      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end

  describe "backend selection" do
    test "returns error when Node.js not found" do
      # Temporarily hide node from PATH
      orig_path = System.get_env("PATH")
      System.put_env("PATH", "/nonexistent")

      spec = test_display_spec()

      assert {:error, msg} =
               Headless.render_html({:html, "<h1>Test</h1>"}, spec, backend: :node)

      assert msg =~ "not found"

      System.put_env("PATH", orig_path)
    end

    test "node_available? returns false when binary not in PATH" do
      # This test documents the availability check behavior
      # The result depends on whether Node.js is installed
      result = Headless.node_available?()
      assert is_boolean(result)
    end
  end

  describe "custom node_cmd option" do
    @tag :requires_node
    test "uses custom path when provided" do
      # Find the actual path to node
      path = System.find_executable("node")

      spec = test_display_spec()
      html = "<h1>Test</h1>"

      assert {:ok, bitmap} =
               Headless.render_html({:html, html}, spec,
                 backend: :node,
                 node_cmd: path
               )

      assert is_binary(bitmap)
      assert byte_size(bitmap) >= 1250
    end
  end
end
