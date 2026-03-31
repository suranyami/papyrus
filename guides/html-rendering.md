# HTML Rendering Guide

Papyrus provides HTML to bitmap rendering via the `Papyrus.Renderer.Headless` module, which supports two backends with different capabilities and requirements. It also provides export functions to save rendered buffers as PNG/BMP files for verification or archival.

## System Requirements

| Component | Required For | System Dependencies | Notes |
|-----------|--------------|---------------------|-------|
| `resvg` Hex package | SVG backend | None (precompiled NIF) | Ships with Papyrus, no manual installation |
| Node.js v18+ | Full HTML/CSS backend | `puppeteer` NPM package (auto-installed) | ~200MB with Chromium, cross-platform |
| `stb_image` Hex package | PNG/BMP export | None (precompiled NIF) | Ships with Papyrus, no manual installation |

**No system libraries need to be installed for basic usage** (SVG backend + export). The precompiled NIFs work on all major platforms (Linux, macOS, Windows).

## Backend Overview

| Feature | SVG Backend (`:svg`) | Node.js Backend (`:node`) |
|---------|---------------------|---------------------------|
| **Dependency** | `resvg` Hex package (~3MB) | Node.js v18+ + Puppeteer (~200MB) |
| **CSS Support** | Basic (absolute positioning only) | Full HTML5/CSS3 (flexbox, grid, web fonts) |
| **Nerves Compatible** | Yes | No (requires Node.js runtime) |
| **Network Required** | No | No (headless Chromium bundled) |
| **Installation** | Add to `mix.exs` deps | Install Node.js, run `npm install` |
| **Maintenance Status** | Active | Active (Puppeteer actively maintained) |

## Backend Selection

The `render_html/3` function accepts a `:backend` option:

```elixir
alias Papyrus.Renderer.Headless
alias Papyrus.DisplaySpec

spec = %DisplaySpec{
  model: :test,
  width: 800,
  height: 480,
  buffer_size: 48_000
}

# Auto-select (prefers Node.js, falls back to resvg)
{:ok, bitmap} = Headless.render_html({:html, "<h1>Hello</h1>"}, spec)

# Force SVG backend
{:ok, bitmap} = Headless.render_html({:svg, svg_string}, spec, backend: :svg)

# Force Node.js backend
{:ok, bitmap} = Headless.render_html({:html, "<h1>Hello</h1>"}, spec, backend: :node)
```

## Installation

### SVG Backend (resvg)

Add to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:papyrus, "~> 0.2"},
    {:resvg, "~> 0.5"}  # Required for SVG backend
  ]
end
```

Then fetch and compile:

```sh
mix deps.get && mix compile
```

The `resvg` library has precompiled NIFs for Linux, macOS, and Windows with no external dependencies. **No system libraries need to be installed.**

### Node.js Backend (Puppeteer + html-to-image)

The Node.js backend uses Puppeteer to render HTML content with full CSS support.

#### Step 1: Install Node.js

**Linux (Debian/Ubuntu):**
```sh
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**macOS:**
```sh
brew install node
```

**Windows:**
Download from https://nodejs.org/

**Raspberry Pi (ARM):**
```sh
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

#### Step 2: Install Puppeteer

Navigate to the Papyrus project directory and install the Node.js dependencies:

```sh
cd priv/node
npm install
```

This installs Puppeteer (which downloads a bundled Chromium) in the `priv/node/` directory.

#### Nerves

For Nerves deployments, the SVG backend is recommended due to size constraints. The Node.js backend is intended for development, testing, and server-side rendering scenarios.

## Usage Examples

### Simple Message

```elixir
alias Papyrus.Renderer.Headless
alias Papyrus.TestPattern.Html

spec = %Papyrus.DisplaySpec{
  model: :test,
  width: 800,
  height: 480,
  buffer_size: 48_000
}

# SVG-compatible pattern (works with both backends)
svg = Html.simple_message("System Ready")
{:ok, bitmap} = Headless.render_html({:svg, svg}, spec)

# With custom options
svg = Html.simple_message("Online", title: "Status")
{:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
```

### Dashboard Tile

```elixir
# SVG-compatible card layout
svg = Html.dashboard_tile(label: "TEMPERATURE", value: "24°C")
{:ok, bitmap} = Headless.render_html({:svg, svg}, spec)

# Custom colors
svg = Html.dashboard_tile(
  label: "HUMIDITY",
  value: "65%",
  value_color: "#2e7d32"
)
{:ok, bitmap} = Headless.render_html({:svg, svg}, spec, backend: :svg)
```

### Full HTML Dashboard (Node.js only)

```elixir
# Uses CSS flexbox - requires Node.js backend
html = Html.full_html_dashboard(tiles: [
  %{label: "TEMP", value: "24°C"},
  %{label: "HUMIDITY", value: "65%"},
  %{label: "PRESSURE", value: "1013 hPa"}
])

{:ok, bitmap} = Headless.render_html({:html, html}, spec, backend: :node)
```

### CSS Grid Layout (Node.js only)

```elixir
# Uses CSS Grid - requires Node.js backend
html = Html.grid_layout()
{:ok, bitmap} = Headless.render_html({:html, html}, spec, backend: :node)
```

### Custom HTML

```elixir
custom_html = """
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial; padding: 20px; }
    .title { font-size: 24px; font-weight: bold; }
  </style>
</head>
<body>
  <div class="title">Custom Content</div>
  <p>Your HTML here...</p>
</body>
</html>
"""

{:ok, bitmap} = Headless.render_html({:html, custom_html}, spec, backend: :node)
```

### Rendering from URL (Node.js only)

```elixir
{:ok, bitmap} = Headless.render_html(
  {:url, "https://example.com"},
  spec,
  backend: :node
)
```

### Rendering from File

```elixir
# Auto-detects SVG or HTML based on content
{:ok, bitmap} = Headless.render_html(
  {:file, "templates/dashboard.html"},
  spec
)
```

## Exporting to PNG/BMP Files

After rendering HTML to a packed ePaper buffer, you can export the result as a PNG or BMP file for visual verification, debugging, or archival.

### Export to File

```elixir
alias Papyrus.Bitmap
alias Papyrus.Renderer.Headless

spec = %Papyrus.DisplaySpec{...}
html = "<h1>Hello World</h1>"

# Render HTML to packed buffer
{:ok, buffer} = Headless.render_html({:html, html}, spec)

# Export to PNG file
:ok = Bitmap.to_file(buffer, "output.png", spec)

# Export to BMP file
:ok = Bitmap.to_file(buffer, "output.bmp", spec)
```

### Export to Binary

```elixir
# Render and get PNG binary
{:ok, buffer} = Headless.render_html({:html, html}, spec)
{:ok, png_binary} = Bitmap.to_binary(buffer, spec)

# Send over network, store in database, etc.
:ok = File.write!("rendered.png", png_binary)
```

### Complete Example: Render and Export

```elixir
alias Papyrus.Renderer.Headless
alias Papyrus.Bitmap
alias Papyrus.TestPattern.Html
alias Papyrus.DisplaySpec

spec = %DisplaySpec{
  model: :test,
  width: 800,
  height: 480,
  buffer_size: 48_000,
  bit_order: :white_high
}

# Generate HTML pattern
svg = Html.dashboard_tile(label: "TEMP", value: "24°C")

# Render to ePaper buffer
{:ok, buffer} = Headless.render_html({:svg, svg}, spec, backend: :svg)

# Export for verification
:ok = Bitmap.to_file(buffer, "dashboard.png", spec)
IO.puts("Exported dashboard.png")
```

## Configuration

You can configure the default backend in your `config/config.exs`:

```elixir
config :papyrus, :headless,
  backend: :auto,  # or :svg, :node
  node_script: "/custom/path/render_html.js"  # Optional: custom Node.js script path
```

Then use defaults in your code:

```elixir
# Uses configured backend
{:ok, bitmap} = Headless.render_html({:html, html_string}, spec)
```

## Troubleshooting

### "Node.js not found in PATH"

Ensure Node.js v18+ is installed and in your PATH:

```sh
node --version
npm --version
```

If installed but not found, specify the full path:

```elixir
{:ok, bitmap} = Headless.render_html(
  {:html, html},
  spec,
  backend: :node,
  node_cmd: "/usr/local/bin/node"
)
```

### "Cannot find module 'puppeteer'"

Run `npm install` in the `priv/node/` directory:

```sh
cd priv/node
npm install
```

### "resvg not available"

Add `{:resvg, "~> 0.5"}` to your `mix.exs` dependencies and recompile:

```sh
mix deps.get && mix compile
```

### Poor rendering quality

- Ensure your HTML specifies explicit dimensions matching the display
- Use high-contrast colors (ePaper is typically 1-bit black/white)
- Avoid thin lines or small text below 12px

### Puppeteer crashes or hangs

- Reduce HTML complexity
- Remove external resource references (fonts, images from URLs)
- Use inline styles instead of external stylesheets
- Ensure sufficient system memory (Puppeteer + Chromium requires ~200MB RAM)

## Exporting Test Patterns

Use the included Mix task to export all test patterns as PNG files:

```sh
# Export all patterns with default settings (1304x984, auto backend)
mix papyrus.export_test_patterns

# Custom output directory
mix papyrus.export_test_patterns --output-dir exports/

# Use full HTML backend (requires Node.js)
mix papyrus.export_test_patterns --backend auto

# Custom display size
mix papyrus.export_test_patterns --width 600 --height 448

# Combine options
mix papyrus.export_test_patterns --output-dir patterns/ --backend auto --width 800 --height 480
```

This exports the following patterns:

**Bitmap patterns:**
- `checkerboard.png` - Alternating pixel pattern
- `full_white.png` - All white pixels
- `full_black.png` - All black pixels

**HTML patterns (SVG backend):**
- `simple_message.png` - Centered message
- `simple_message_with_title.png` - Message with title
- `dashboard_tile.png` - Card-style metric display
- `lorem_ipsum_layout.png` - Multi-line typography test
- `status_indicator_green.png` - Green status badge
- `status_indicator_red.png` - Red status badge

**Full HTML patterns (Node.js backend):**
- `full_html_dashboard.png` - Flexbox dashboard layout
- `grid_layout.png` - CSS Grid layout

## See Also

- `Papyrus.Renderer.Headless` - Main rendering module documentation
- `Papyrus.TestPattern.Html` - Pre-built HTML test patterns
- [Loading Images](loading-images.md) - Convert PNG files to ePaper buffers
