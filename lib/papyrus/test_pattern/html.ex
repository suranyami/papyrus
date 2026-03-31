defmodule Papyrus.TestPattern.Html do
  @moduledoc """
  Generate HTML test patterns for the headless renderer.

  This module provides pre-built HTML patterns for testing the
  `Papyrus.Renderer.Headless` module. Patterns are designed to work
  with both the SVG (resvg) and Node.js backends.

  ## ePaper Optimization

  All patterns use solid colors (black, white, and occasional red/yellow) optimized
  for 1-bit ePaper displays. Gradients and semi-transparent effects are avoided as
  they don't render well on ePaper.

  ## Backend Compatibility

  - **SVG-compatible patterns** — Use simplified HTML with absolute positioning,
    work with both `:svg` and `:node` backends.

  - **Full HTML patterns** — Use modern CSS (flexbox, grid, web fonts),
    require the `:node` backend.

  ## Patterns

  - `simple_message/2` — Centered message with optional title (SVG-compatible)
  - `dashboard_tile/2` — Card-style layout (SVG-compatible)
  - `lorem_ipsum_layout/1` — Multi-line text layout (SVG-compatible)
  - `full_html_dashboard/1` — Flexbox/grid dashboard (Node.js only)
  - `grid_layout/1` — CSS Grid dashboard (Node.js only)
  - `status_indicator/1` — Status badge with color (SVG-compatible)

  ## Examples

      alias Papyrus.TestPattern.Html

      # SVG-compatible pattern (works with both backends)
      html = Html.simple_message("System Ready")
      {:ok, bitmap} = Papyrus.Renderer.Headless.render_html(html, spec)

      # Full HTML pattern (Node.js only)
      html = Html.full_html_dashboard()
      {:ok, bitmap} = Papyrus.Renderer.Headless.render_html(html, spec, backend: :node)

  @since 0.2.0
  """

  @doc """
  Generates a simple centered message SVG pattern.

  ## Options

  - `:title` — Optional title text shown above the main message
  - `:background` — Background color (default: "#ffffff")
  - `:text_color` — Text color (default: "#000000")

  ## Examples

      # Simple message
      svg = Html.simple_message("System Ready")

      # With title and custom colors
      svg = Html.simple_message("Online", title: "Status", background: "#f0f0f0")

  @since 0.2.0
  """
  @spec simple_message(String.t(), keyword()) :: String.t()
  def simple_message(message, opts \\ []) do
    title = Keyword.get(opts, :title)
    background = Keyword.get(opts, :background, "#ffffff")
    text_color = Keyword.get(opts, :text_color, "#000000")

    title_section =
      if title do
        """
          <text x="400" y="180" text-anchor="middle" font-size="24" fill="#{text_color}">#{escape_xml(title)}</text>
        """
      else
        ""
      end

    """
    <svg width="800" height="480" xmlns="http://www.w3.org/2000/svg">
      <rect width="800" height="480" fill="#{background}"/>
    #{title_section}  <text x="400" y="260" text-anchor="middle" font-size="48" font-weight="bold" fill="#{text_color}">#{escape_xml(message)}</text>
    </svg>
    """
  end

  @doc """
  Generates a dashboard tile SVG pattern with a metric display.

  ## Options

  - `:label` — Label text (default: "TEMPERATURE")
  - `:value` — Value text (default: "24°C")
  - `:background` — Overall background color (default: "#e0e0e0")
  - `:card_color` — Card background color (default: "#f5f5f5")
  - `:label_color` — Label text color (default: "#666666")
  - `:value_color` — Value text color (default: "#1976d2")

  ## Examples

      # Default temperature tile
      svg = Html.dashboard_tile()

      # Custom metric
      svg = Html.dashboard_tile(label: "HUMIDITY", value: "65%", value_color: "#2e7d32")

  @since 0.2.0
  """
  @spec dashboard_tile(keyword()) :: String.t()
  def dashboard_tile(opts \\ []) do
    label = Keyword.get(opts, :label, "TEMPERATURE")
    value = Keyword.get(opts, :value, "24°C")
    background = Keyword.get(opts, :background, "#e0e0e0")
    card_color = Keyword.get(opts, :card_color, "#f5f5f5")
    label_color = Keyword.get(opts, :label_color, "#666666")
    value_color = Keyword.get(opts, :value_color, "#1976d2")

    """
    <svg width="800" height="480" xmlns="http://www.w3.org/2000/svg">
      <rect width="800" height="480" fill="#{background}"/>
      <rect x="300" y="140" width="200" height="200" rx="12" fill="#{card_color}"/>
      <text x="400" y="180" text-anchor="middle" font-size="14" fill="#{label_color}">#{escape_xml(label)}</text>
      <text x="400" y="260" text-anchor="middle" font-size="56" font-weight="bold" fill="#{value_color}">#{escape_xml(value)}</text>
    </svg>
    """
  end

  @doc """
  Generates a Lorem Ipsum text layout for typography testing.

  ## Options

  - `:title` — Title text (default: "Typography Test")
  - `:background` — Background color (default: "#ffffff")
  - `:text_color` — Text color (default: "#000000")

  ## Examples

      svg = Html.lorem_ipsum_layout()
      svg = Html.lorem_ipsum_layout(title: "Reading Test", background: "#fafafa")

  @since 0.2.0
  """
  @spec lorem_ipsum_layout(keyword()) :: String.t()
  def lorem_ipsum_layout(opts \\ []) do
    title = Keyword.get(opts, :title, "Typography Test")
    background = Keyword.get(opts, :background, "#ffffff")
    text_color = Keyword.get(opts, :text_color, "#000000")

    """
    <svg width="800" height="480" xmlns="http://www.w3.org/2000/svg">
      <rect width="800" height="480" fill="#{background}"/>
      <text x="400" y="40" text-anchor="middle" font-size="28" font-weight="bold" fill="#{text_color}">#{escape_xml(title)}</text>
      <text x="40" y="90" font-size="14" fill="#{text_color}">Lorem ipsum dolor sit amet, consectetur adipiscing elit.</text>
      <text x="40" y="115" font-size="14" fill="#{text_color}">Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</text>
      <text x="40" y="140" font-size="14" fill="#{text_color}">Ut enim ad minim veniam, quis nostrud exercitation ullamco.</text>
      <text x="40" y="165" font-size="14" fill="#{text_color}">Duis aute irure dolor in reprehenderit in voluptate velit esse cillum.</text>
      <text x="40" y="190" font-size="14" fill="#{text_color}">Dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non.</text>
      <text x="40" y="230" font-size="14" fill="#{text_color}">Proident sunt in culpa qui officia deserunt mollit anim id est laborum.</text>
      <text x="40" y="270" font-size="14" fill="#{text_color}">Sed ut perspiciatis unde omnis iste natus error sit voluptatem.</text>
      <text x="40" y="295" font-size="14" fill="#{text_color}">Accusantium doloremque laudantium totam rem aperiam eaque ipsa.</text>
      <text x="40" y="320" font-size="14" fill="#{text_color}">Quae ab illo inventore veritatis et quasi architecto beatae vitae.</text>
      <text x="40" y="360" font-size="12" fill="#{text_color}">— Test pattern for ePaper display verification</text>
    </svg>
    """
  end

  @doc """
  Generates a full HTML dashboard with flexbox layout.

  This pattern uses CSS flexbox and requires the Node.js backend.
  It demonstrates modern CSS features not supported by the SVG backend.

  Uses solid black and white colors optimized for ePaper displays.

  ## Options

  - `:tiles` — List of tile data (list of maps with :label and :value keys)
  - `:width` — Display width in pixels (default: 800)
  - `:height` — Display height in pixels (default: 480)

  ## Examples

      Html.full_html_dashboard()
      Html.full_html_dashboard(tiles: [
        %{label: "TEMP", value: "24°C"},
        %{label: "HUMIDITY", value: "65%"}
      ])
      Html.full_html_dashboard(width: 1304, height: 984)

  @since 0.2.0
  """
  @spec full_html_dashboard(keyword()) :: {:html, String.t()}
  def full_html_dashboard(opts \\ []) do
    tiles = Keyword.get(opts, :tiles, default_dashboard_tiles())
    width = Keyword.get(opts, :width, 800)
    height = Keyword.get(opts, :height, 480)

    tiles_html =
      Enum.map(tiles, fn tile ->
        """
        <div class="card">
          <div class="label">#{tile.label}</div>
          <div class="value">#{tile.value}</div>
        </div>
        """
      end)
      |> Enum.join("\n")

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          background: #ffffff;
          padding: 32px;
          width: #{width}px;
          height: #{height}px;
        }
        .dashboard {
          display: flex;
          gap: 24px;
          flex-wrap: wrap;
          justify-content: center;
          align-items: stretch;
        }
        .card {
          background: #ffffff;
          border: 2px solid #000000;
          border-radius: 16px;
          padding: 32px;
          flex: 1 1 200px;
          max-width: 280px;
          text-align: center;
        }
        .label {
          font-size: 12px;
          font-weight: 600;
          color: #000000;
          text-transform: uppercase;
          letter-spacing: 1px;
          margin-bottom: 16px;
        }
        .value {
          font-size: 48px;
          font-weight: 700;
          color: #000000;
        }
      </style>
    </head>
    <body>
      <div class="dashboard">
        #{tiles_html}
      </div>
    </body>
    </html>
    """

    {:html, html}
  end

  @doc """
  Generates a CSS grid-based layout.

  This pattern uses CSS Grid and requires the Node.js backend.
  Uses solid black and white colors optimized for ePaper displays.

  ## Options

  - `:width` — Display width in pixels (default: 800)
  - `:height` — Display height in pixels (default: 480)

  ## Examples

      Html.grid_layout()
      Html.grid_layout(width: 1304, height: 984)

  @since 0.2.0
  """
  @spec grid_layout(keyword()) :: {:html, String.t()}
  def grid_layout(opts \\ []) do
    width = Keyword.get(opts, :width, 800)
    height = Keyword.get(opts, :height, 480)

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: "Helvetica Neue", Arial, sans-serif;
          background: #ffffff;
          padding: 32px;
          width: #{width}px;
          height: #{height}px;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 20px;
          max-width: 900px;
          margin: 0 auto;
        }
        .cell {
          background: #ffffff;
          border: 2px solid #000000;
          border-radius: 12px;
          padding: 24px;
          color: #000000;
        }
        .cell.header {
          grid-column: 1 / -1;
          background: #000000;
          text-align: center;
          color: #ffffff;
        }
        .cell-title {
          font-size: 14px;
          margin-bottom: 8px;
        }
        .cell-value {
          font-size: 32px;
          font-weight: 700;
        }
        h1 {
          font-size: 28px;
          text-transform: uppercase;
          letter-spacing: 2px;
        }
      </style>
    </head>
    <body>
      <div class="grid">
        <div class="cell header">
          <h1>System Dashboard</h1>
        </div>
        <div class="cell">
          <div class="cell-title">CPU Usage</div>
          <div class="cell-value">42%</div>
        </div>
        <div class="cell">
          <div class="cell-title">Memory</div>
          <div class="cell-value">3.2GB</div>
        </div>
        <div class="cell">
          <div class="cell-title">Disk</div>
          <div class="cell-value">68%</div>
        </div>
        <div class="cell">
          <div class="cell-title">Network</div>
          <div class="cell-value">125 Mb/s</div>
        </div>
        <div class="cell">
          <div class="cell-title">Uptime</div>
          <div class="cell-value">14d</div>
        </div>
        <div class="cell">
          <div class="cell-title">Processes</div>
          <div class="cell-value">248</div>
        </div>
      </div>
    </body>
    </html>
    """

    {:html, html}
  end

  @doc """
  Generates a status indicator with colored badge.

  This pattern is SVG-compatible and works with both backends.

  ## Options

  - `:status` — Status text (default: "Online")
  - `:color` — Status color: `:green`, `:yellow`, `:red` (default: `:green`)

  ## Examples

      Html.status_indicator(status: "Offline", color: :red)
      Html.status_indicator(status: "Warning", color: :yellow)

  @since 0.2.0
  """
  @spec status_indicator(keyword()) :: {:html, String.t()}
  def status_indicator(opts \\ []) do
    status = Keyword.get(opts, :status, "Online")
    color = Keyword.get(opts, :color, :green)

    color_map = %{
      green: "#22c55e",
      yellow: "#eab308",
      red: "#ef4444"
    }

    bg_color = Map.get(color_map, color, "#22c55e")

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
    </head>
    <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background: #ffffff;">
      <div style="display: flex; align-items: center; justify-content: center; height: 480px;">
        <div style="display: flex; align-items: center; gap: 16px;">
          <div style="width: 24px; height: 24px; background: #{bg_color}; border-radius: 50%;"></div>
          <span style="font-size: 32px; font-weight: bold; color: #000;">#{escape_xml(status)}</span>
        </div>
      </div>
    </body>
    </html>
    """

    {:html, html}
  end

  # Default dashboard tiles for full_html_dashboard
  defp default_dashboard_tiles do
    [
      %{label: "TEMPERATURE", value: "24°C"},
      %{label: "HUMIDITY", value: "65%"},
      %{label: "PRESSURE", value: "1013 hPa"}
    ]
  end

  defp escape_xml(content) do
    content
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
