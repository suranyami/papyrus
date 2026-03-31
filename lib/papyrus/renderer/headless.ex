defmodule Papyrus.Renderer.Headless do
  @moduledoc """
  HTML to bitmap renderer with multiple backend support.

  This module provides HTML/CSS to bitmap conversion for ePaper displays using
  one of two backends:

  - **SVG backend** (`:svg`) — Uses the `resvg` library to render SVG content.
    Lightweight (~3MB), works on Nerves, but has limited CSS support (no flexbox/grid).

  - **Node.js backend** (`:node`) — Uses the `html-to-image` NPM package via Puppeteer
    to render full HTML5/CSS3 content. Requires Node.js installation but supports
    flexbox, grid, web fonts, and all modern CSS features.

  ## Backend Selection

  Backend selection can be controlled via the `:backend` option:

  - `:auto` (default) — Tries Node.js first, falls back to `resvg`
  - `:svg` — Forces SVG/resvg backend
  - `:node` — Forces Node.js backend (returns error if not available)

  ## Input Types

  The `render_html/3` function accepts three input formats:

  - `{:html, String.t()}` — Raw HTML string
  - `{:url, String.t()}` — URL to render (Node.js backend only)
  - `{:file, String.t()}` — Path to HTML file

  ## Examples

      alias Papyrus.Renderer.Headless
      alias Papyrus.TestPattern.Html

      spec = %Papyrus.DisplaySpec{
        model: :test,
        width: 800,
        height: 480,
        buffer_size: 48_000
      }

      # Auto-select backend (prefers Node.js, falls back to resvg)
      html = Html.simple_message("System Ready")
      {:ok, bitmap} = Headless.render_html(html, spec)

      # Force SVG backend
      {:ok, bitmap} = Headless.render_html(html, spec, backend: :svg)

      # Force Node.js backend (requires Node.js installation)
      # case Headless.render_html(html, spec, backend: :node) do
      #   {:ok, bitmap} -> IO.puts("Rendered: \#{byte_size(bitmap)} bytes")
      #   {:error, reason} -> IO.puts("Error: \#{reason}")
      # end

  @since "0.2.0"
  """

  alias Papyrus.DisplaySpec
  alias Papyrus.Bitmap

  @doc """
  Renders HTML or SVG input to a packed 1-bit ePaper binary buffer.

  ## Input types

  - `{:svg, String.t()}` — SVG string (rendered directly via resvg)
  - `{:html, String.t()}` — HTML string (requires Node.js backend)
  - `{:url, String.t()}` — URL to render (Node.js backend only)
  - `{:file, String.t()}` — Path to SVG or HTML file

  ## Options

  - `:backend` — `:auto` (default), `:svg`, or `:node`
  - `:node_script` — Custom path to the Node.js rendering script

  ## Returns

  `{:ok, binary()}` on success, `{:error, String.t()}` on failure.

  ## Examples

      # SVG rendering (works with resvg backend)
      {:ok, bitmap} = Headless.render_html({:svg, svg_string}, spec)

      # HTML rendering (requires Node.js)
      {:ok, bitmap} = Headless.render_html({:html, html_string}, spec, backend: :node)

      # Auto-select backend
      {:ok, bitmap} = Headless.render_html({:svg, svg_string}, spec)

  @since 0.2.0
  """
  @spec render_html({:svg | :html | :file | :url, String.t()}, DisplaySpec.t(), keyword()) ::
          {:ok, binary()} | {:error, String.t()}
  def render_html(input, spec, opts \\ []) do
    backend = Keyword.get(opts, :backend, :auto)
    do_render_html(select_backend(backend), input, spec, opts)
  end

  defp do_render_html({:error, reason}, _input, _spec, _opts), do: {:error, reason}
  defp do_render_html(:svg, input, spec, opts), do: render_with_svg_backend(input, spec, opts)
  defp do_render_html(:node, input, spec, opts), do: render_with_node_backend(input, spec, opts)

  defp do_render_html(:no_backend, _input, _spec, _opts),
    do:
      {:error,
       "no rendering backend available -- install Node.js or add {:resvg, \"~> 0.5\"}"}

  # Backend selection logic
  defp select_backend(:auto) do
    cond do
      node_available?() -> :node
      resvg_available?() -> :svg
      true -> :no_backend
    end
  end

  defp select_backend(:svg) do
    if resvg_available?(),
      do: :svg,
      else: {:error, "resvg not available -- add {:resvg, \"~> 0.5\"} to your deps"}
  end

  defp select_backend(:node) do
    if node_available?(),
      do: :node,
      else: {:error, "Node.js not found in PATH -- install Node.js (v18+)"}
  end

  # SVG backend rendering - only handles {:svg, svg_string} input
  defp render_with_svg_backend({:svg, svg_string}, spec, _opts) do
    render_svg(svg_string, spec)
  end

  defp render_with_svg_backend({:html, _html}, _spec, _opts) do
    {:error, "HTML input requires Node.js backend -- use backend: :node"}
  end

  defp render_with_svg_backend({:url, _url}, _spec, _opts) do
    {:error, "URL input requires Node.js backend -- use backend: :node"}
  end

  defp render_with_svg_backend({:file, path}, spec, _opts) do
    # Read file and treat as SVG
    case File.read(path) do
      {:ok, content} -> render_svg(content, spec)
      {:error, :enoent} -> {:error, "File not found: #{path}"}
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  # Node.js backend rendering using Puppeteer
  # SVG input is rendered directly by Puppeteer (which supports SVG natively)
  defp render_with_node_backend({:svg, svg_string}, spec, opts) do
    # Wrap SVG in minimal HTML for Puppeteer rendering
    html = "<!DOCTYPE html><html><body style=\"margin:0;padding:0;\">#{svg_string}</body></html>"
    render_with_node_backend({:html, html}, spec, opts)
  end

  defp render_with_node_backend({:html, html}, spec, opts) do
    script_path = Keyword.get(opts, :node_script, node_script_path())
    node_cmd = Keyword.get(opts, :node_cmd, "node")

    # Write HTML to temp file (Elixir 1.18+ removed :stdin_data from System.cmd)
    temp_path = Path.join(System.tmp_dir!(), "papyrus_html_#{System.unique_integer()}.html")
    File.write!(temp_path, html)

    args = [
      script_path,
      "--width", to_string(spec.width),
      "--height", to_string(spec.height),
      "--input", temp_path
    ]

    try do
      {png_binary, exit_code} = System.cmd(node_cmd, args, into: "", stderr_to_stdout: true)

      case exit_code do
        0 -> Bitmap.from_binary(png_binary, spec)
        code -> {:error, "Node.js renderer exited with code #{code}"}
      end
    after
      File.rm(temp_path)
    end
  end

  defp render_with_node_backend({:url, url}, spec, opts) do
    script_path = Keyword.get(opts, :node_script, node_script_path())
    node_cmd = Keyword.get(opts, :node_cmd, "node")

    args = [
      script_path,
      "--width", to_string(spec.width),
      "--height", to_string(spec.height),
      "--url", url
    ]

    {png_binary, exit_code} = System.cmd(node_cmd, args, into: "", exit_status: true, stderr_to_stdout: true)

    case exit_code do
      0 -> Bitmap.from_binary(png_binary, spec)
      code -> {:error, "Node.js renderer exited with code #{code}"}
    end
  end

  defp render_with_node_backend({:file, path}, spec, opts) do
    do_file_read(File.read(path), spec, opts)
  end

  defp do_file_read({:ok, content}, spec, opts),
    do: render_with_node_backend({:html, content}, spec, opts)

  defp do_file_read({:error, :enoent}, _spec, _opts),
    do: {:error, "File not found"}

  defp do_file_read({:error, _reason}, _spec, _opts),
    do: {:error, "Failed to read file"}

  defp node_script_path do
    # In dev/test: look relative to current working directory
    # In production: look in application priv directory
    case :code.priv_dir(:papyrus) do
      {:error, _} ->
        # Fallback to relative path (for dev/test)
        "priv/node/render_html.js"

      dir when is_list(dir) ->
        Path.join(List.to_string(dir), "node/render_html.js")
    end
  end

  @doc """
  Renders an SVG string to a packed 1-bit ePaper binary buffer via resvg.

  ## Returns

  `{:ok, binary()}` on success, `{:error, String.t()}` on failure.

  ## Examples

      svg = \"\"\"
      <svg width="800" height="480" xmlns="http://www.w3.org/2000/svg">
        <rect width="800" height="480" fill="#ffffff"/>
        <text x="400" y="240" text-anchor="middle" font-size="48">Hello</text>
      </svg>
      \"\"\"
      {:ok, bitmap} = Headless.render_svg(svg, spec)

  @since 0.2.0
  """
  @spec render_svg(String.t(), DisplaySpec.t()) :: {:ok, binary()} | {:error, String.t()}
  def render_svg(svg_string, %DisplaySpec{} = spec) do
    with true <- resvg_available?() do
      temp_dir = System.tmp_dir!()

      do_resvg_result(
        Resvg.svg_string_to_png_buffer(svg_string,
          width: spec.width,
          height: spec.height,
          resources_dir: temp_dir
        ),
        temp_dir,
        spec
      )
    else
      _ ->
        {:error,
         "resvg not available -- add {:resvg, \"~> 0.5\"} to your deps and ensure resvg compiled successfully"}
    end
  end

  defp do_resvg_result({:ok, png_binary}, temp_dir, spec) do
    temp_path = Path.join(temp_dir, "resvg_#{System.unique_integer()}.png")

    try do
      File.write!(temp_path, png_binary)
      Bitmap.from_image(temp_path, spec)
    after
      File.rm(temp_path)
    end
  end

  defp do_resvg_result({:error, _reason}, _temp_dir, _spec),
    do: {:error, "resvg failed"}

  @doc """
  Convenience wrapper that renders and displays on the given display.

  ## Input types

  - `{:svg, String.t()}` — SVG string (rendered via resvg)
  - `{:html, String.t()}` — HTML string (requires Node.js backend)

  ## Options

  - `:backend` — `:auto` (default), `:svg`, or `:node`

  ## Returns

  `{:ok, :sent}` on success, `{:error, String.t()}` on failure.

  ## Examples

      {:ok, :sent} = Headless.display({:svg, svg_string}, display_pid, spec)
      {:ok, :sent} = Headless.display({:html, html_string}, display_pid, spec, backend: :node)

  @since 0.2.0
  """
  @spec display({:svg | :html | :file, String.t()}, pid(), DisplaySpec.t(), keyword()) ::
          {:ok, :sent} | {:error, String.t()}
  def display(input, display_pid, spec, opts \\ []) do
    with {:ok, bitmap} <- render_html(input, spec, opts),
         :ok <- Papyrus.Display.display(display_pid, bitmap) do
      {:ok, :sent}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if the resvg backend is available.

  ## Returns

  `true` if resvg is loaded and available, `false` otherwise.

  @since "0.2.0"
  """
  @spec resvg_available?() :: boolean()
  def resvg_available? do
    Code.ensure_loaded?(Resvg) and function_exported?(Resvg, :svg_string_to_png_buffer, 2)
  end

  @doc """
  Checks if the Node.js backend is available.

  ## Returns

  `true` if Node.js (v18+) is found in PATH, `false` otherwise.

  @since "0.2.0"
  """
  @spec node_available?() :: boolean()
  def node_available? do
    System.find_executable("node") != nil
  end
end
