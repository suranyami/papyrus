defmodule Mix.Tasks.Papyrus.ExportTestPatterns do
  @moduledoc """
  Export test patterns as PNG files for visual verification.

  Generates PNG files from all built-in test patterns, useful for
  previewing patterns without hardware attached.

  ## Usage

      mix papyrus.export_test_patterns

  ## Options

      --output-dir    Output directory (default: "test_pattern_exports")
      --backend       Rendering backend: :svg, :node, :auto (default: :auto)
      --width         Display width in pixels (default: 1304, Waveshare 12.48")
      --height        Display height in pixels (default: 984, Waveshare 12.48")

  ## Examples

      # Export all patterns with default settings
      mix papyrus.export_test_patterns

      # Export to custom directory
      mix papyrus.export_test_patterns --output-dir exports/

      # Use full HTML backend (requires Node.js)
      mix papyrus.export_test_patterns --backend :auto

      # Custom display size
      mix papyrus.export_test_patterns --width 600 --height 448

  ## Exported Patterns

  The following patterns are exported:

  **Bitmap patterns** (via `Papyrus.TestPattern`):
  - `checkerboard` - Alternating pixel pattern
  - `full_white` - All white pixels
  - `full_black` - All black pixels

  **HTML patterns** (via `Papyrus.TestPattern.Html`):
  - `simple_message` - Centered message with optional title
  - `dashboard_tile` - Card-style metric display
  - `lorem_ipsum_layout` - Multi-line typography test
  - `status_indicator` - Status badge with colored indicator

  **Full HTML patterns** (Node.js only):
  - `full_html_dashboard` - Flexbox/grid dashboard
  - `grid_layout` - CSS Grid layout

  """

  use Mix.Task

  @shortdoc "Export test patterns as PNG files"

  @impl true
  def run(args) do
    # Parse command-line options
    {opts, _args, _invalid} =
      OptionParser.parse(args,
        strict: [
          output_dir: :string,
          backend: :string,
          width: :integer,
          height: :integer
        ]
      )

    output_dir = Keyword.get(opts, :output_dir, "test_pattern_exports")
    backend = parse_backend(Keyword.get(opts, :backend, "auto"))
    width = Keyword.get(opts, :width, 1304)
    height = Keyword.get(opts, :height, 984)

    # Create output directory
    File.mkdir_p!(output_dir)

    # Build display spec
    spec = build_display_spec(width, height)

    Mix.shell().info("Exporting test patterns to #{output_dir}/")
    Mix.shell().info("Display: #{width}x#{height}, Backend: #{backend}")
    Mix.shell().info("")

    # Export bitmap patterns
    export_bitmap_patterns(spec, output_dir)

    # Export HTML patterns
    export_html_patterns(spec, output_dir, backend)

    Mix.shell().info("")
    Mix.shell().info("Export complete!")
  end

  defp parse_backend("auto"), do: :auto
  defp parse_backend("svg"), do: :svg
  defp parse_backend("node"), do: :node
  defp parse_backend(:auto), do: :auto
  defp parse_backend(:svg), do: :svg
  defp parse_backend(:node), do: :node
  defp parse_backend(_other), do: :svg

  defp build_display_spec(width, height) do
    %Papyrus.DisplaySpec{
      model: :test,
      width: width,
      height: height,
      buffer_size: div(width * height, 8),
      bit_order: :white_high,
      pin_config: %{rst: 6, dc: 13, cs: 8, busy: 5},
      color_mode: :black_white,
      partial_refresh: false
    }
  end

  defp export_bitmap_patterns(spec, output_dir) do
    Mix.shell().info("Bitmap patterns:")

    # Checkerboard
    buffer = Papyrus.TestPattern.checkerboard(spec)
    path = Path.join(output_dir, "checkerboard.png")
    :ok = Papyrus.Bitmap.to_file(buffer, path, spec)
    Mix.shell().info("  ✓ checkerboard.png")

    # Full white
    buffer = Papyrus.TestPattern.full_white(spec)
    path = Path.join(output_dir, "full_white.png")
    :ok = Papyrus.Bitmap.to_file(buffer, path, spec)
    Mix.shell().info("  ✓ full_white.png")

    # Full black
    buffer = Papyrus.TestPattern.full_black(spec)
    path = Path.join(output_dir, "full_black.png")
    :ok = Papyrus.Bitmap.to_file(buffer, path, spec)
    Mix.shell().info("  ✓ full_black.png")
  end

  defp export_html_patterns(spec, output_dir, backend) do
    Mix.shell().info("")
    Mix.shell().info("HTML patterns (backend: #{backend}):")

    alias Papyrus.Renderer.Headless
    alias Papyrus.TestPattern.Html

    # Simple message
    with {:ok, buffer} <-
           Headless.render_html({:svg, Html.simple_message("System Ready")}, spec,
             backend: backend
           ),
         :ok <- Papyrus.Bitmap.to_file(buffer, Path.join(output_dir, "simple_message.png"), spec) do
      Mix.shell().info("  ✓ simple_message.png")
    else
      {:error, reason} -> Mix.shell().error("  ✗ simple_message: #{reason}")
    end

    # Simple message with title
    with {:ok, buffer} <-
           Headless.render_html({:svg, Html.simple_message("Online", title: "Status")}, spec,
             backend: backend
           ),
         :ok <-
           Papyrus.Bitmap.to_file(
             buffer,
             Path.join(output_dir, "simple_message_with_title.png"),
             spec
           ) do
      Mix.shell().info("  ✓ simple_message_with_title.png")
    else
      {:error, reason} -> Mix.shell().error("  ✗ simple_message_with_title: #{reason}")
    end

    # Dashboard tile
    with {:ok, buffer} <-
           Headless.render_html(
             {:svg, Html.dashboard_tile(label: "TEMPERATURE", value: "24°C")},
             spec,
             backend: backend
           ),
         :ok <- Papyrus.Bitmap.to_file(buffer, Path.join(output_dir, "dashboard_tile.png"), spec) do
      Mix.shell().info("  ✓ dashboard_tile.png")
    else
      {:error, reason} -> Mix.shell().error("  ✗ dashboard_tile: #{reason}")
    end

    # Lorem ipsum layout
    with {:ok, buffer} <-
           Headless.render_html({:svg, Html.lorem_ipsum_layout(title: "Typography Test")}, spec,
             backend: backend
           ),
         :ok <-
           Papyrus.Bitmap.to_file(buffer, Path.join(output_dir, "lorem_ipsum_layout.png"), spec) do
      Mix.shell().info("  ✓ lorem_ipsum_layout.png")
    else
      {:error, reason} -> Mix.shell().error("  ✗ lorem_ipsum_layout: #{reason}")
    end

    # Status indicator (green) - requires Node.js for CSS flexbox
    export_html_pattern(
      Html.status_indicator(status: "Online", color: :green),
      "status_indicator_green.png",
      spec,
      output_dir,
      backend
    )

    # Status indicator (red) - requires Node.js for CSS flexbox
    export_html_pattern(
      Html.status_indicator(status: "Offline", color: :red),
      "status_indicator_red.png",
      spec,
      output_dir,
      backend
    )

    # Full HTML dashboard (only with :auto or :node)
    if backend in [:auto, :node] do
      export_html_pattern(
        Html.full_html_dashboard(width: spec.width, height: spec.height),
        "full_html_dashboard.png",
        spec,
        output_dir,
        backend
      )

      export_html_pattern(
        Html.grid_layout(width: spec.width, height: spec.height),
        "grid_layout.png",
        spec,
        output_dir,
        backend
      )
    else
      Mix.shell().info("  ⊘ full_html_dashboard: skipped (use --backend auto)")
      Mix.shell().info("  ⊘ grid_layout: skipped (use --backend auto)")
    end
  end

  defp export_html_pattern(html_tuple, filename, spec, output_dir, backend) do
    # HTML patterns with complex CSS (flexbox, etc.) need Node.js backend
    # Skip them if Node.js is not available
    actual_backend =
      cond do
        backend == :auto and Papyrus.Renderer.Headless.node_available?() ->
          :node

        backend == :auto ->
          :svg

        backend in [:node, :auto] ->
          :node

        true ->
          backend
      end

    # Only try to render HTML patterns with Node.js backend
    # SVG backend can't handle complex HTML/CSS
    if actual_backend == :svg do
      Mix.shell().info("  ⊘ #{filename}: skipped (requires Node.js backend)")
    else
      case Papyrus.Renderer.Headless.render_html(html_tuple, spec, backend: actual_backend) do
        {:ok, buffer} ->
          path = Path.join(output_dir, filename)
          :ok = Papyrus.Bitmap.to_file(buffer, path, spec)
          Mix.shell().info("  ✓ #{filename} (node)")

        {:error, reason} ->
          Mix.shell().error("  ✗ #{filename}: #{reason}")
      end
    end
  end
end
