# Phase 5: Headless HTML Rendering - Research

**Researched:** 2026-03-30
**Domain:** ChromicPDF, Elixir optional dependencies, OTP supervision, Base64/PNG pipeline
**Confidence:** HIGH

## Summary

Phase 5 adds `Papyrus.Renderer.Headless` — a thin wrapper that accepts `{:html, …}`, `{:url, …}`, or `{:file, …}` inputs, renders a PNG screenshot via ChromicPDF (headless Chromium), decodes the Base64 result, and feeds the raw binary into the existing `Papyrus.Bitmap.from_image/2` pipeline to produce a packed 1-bit ePaper buffer.

ChromicPDF `capture_screenshot/2` returns a Base64-encoded PNG string. The raw PNG binary is obtained with `Base.decode64!/1`. That binary can be written to a temp file and passed to `Papyrus.Bitmap.from_image/3`, or streamed through a custom bitmap loader. The current `Papyrus.Bitmap.from_image/2` implementation accepts a file path, so a temp-file route is the lowest-friction integration. The fixed-resolution viewport is controlled via the CDP `clip` parameter passed through the `:capture_screenshot` map option.

The optional-dependency story is straightforward: `chromic_pdf` is added with `optional: true` in `mix.exs`. At call-site, `Code.ensure_loaded?(ChromicPDF)` guards the runtime path, and `Papyrus.Application` conditionally appends ChromicPDF to its children list using the same check.

**Primary recommendation:** Implement `Papyrus.Renderer.Headless` as a single module with two public functions (`render_html/2`, `display/3`). Use `Code.ensure_loaded?(ChromicPDF)` for both the application startup guard and the call-site guard. Decode the Base64 PNG, write to a temp file via `System.tmp_dir!/0`, pass to `Bitmap.from_image/2`, then clean up. This approach requires zero changes to the existing bitmap pipeline.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Expose two public functions:
  - `Papyrus.Renderer.Headless.render_html(input, spec)` → `{:ok, bitmap_binary} | {:error, reason}`
  - `Papyrus.Renderer.Headless.display(input, display_pid, spec)` → `{:ok, :sent} | {:error, reason}` (calls `render_html/2` then `Papyrus.Display.display/2`)
- **D-02:** Error contract is `{:ok, binary} | {:error, reason}` throughout. No bang (`!`) variants.
- **D-03:** All inputs use tagged tuples — no bare string shorthand:
  - `{:html, html_string}` — render an HTML string directly
  - `{:url, url_string}` — navigate ChromicPDF to a URL and screenshot (e.g., local Phoenix endpoint)
  - `{:file, file_path}` — read an HTML file from disk and render it
- **D-04:** The tag always disambiguates — no implicit type inference.
- **D-05:** Viewport dimensions are auto-derived from `spec.width` and `spec.height`. No user-facing override option. The DisplaySpec is the single source of truth for display resolution.
- **D-06:** The ChromicPDF screenshot is taken at exactly `spec.width × spec.height` pixels, then passed directly to `Papyrus.Bitmap.from_image/2` for grayscale conversion and 1-bit packing.
- **D-07:** `Papyrus.Application` checks whether `:chromic_pdf` application is available at startup. If present, it starts ChromicPDF as a child. If absent, it does nothing (no warning at startup).
- **D-08:** When `render_html/2` is called and ChromicPDF is not loaded/started, the function returns `{:error, "chromic_pdf not available — add {:chromic_pdf, \"~> 1.17\"} to your deps and ensure it is started"}`. Error lives at the call site, not at application startup.
- **D-09:** `chromic_pdf` is added to `mix.exs` deps with `optional: true` so it is not pulled transitively for users who don't need headless rendering.

### Claude's Discretion

- Internal implementation of the `{:file, path}` input (read file, pass as HTML string to ChromicPDF, or use file:// URL)
- Exact ChromicPDF `capture_screenshot/2` options (page dimensions, clip vs viewport)
- Module doc and `@since` tags
- Whether to expose a `Papyrus.Renderer` namespace module or just the `Headless` submodule directly

### Deferred Ideas (OUT OF SCOPE)

- HiDPI/retina scaling — render at 2× resolution and downscale for sharper text
- Viewport override option — `opts: [viewport: {w, h}]` for non-DisplaySpec-sized screenshots
- Streaming/progressive render — ChromicPDF pool exhaustion handling beyond simple `{:error, reason}`
- 3-color HTML rendering — dual-plane output for `color_mode: :three_color` displays
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RENDER-04 | HTML → bitmap rendering via headless Chromium: render HTML to PNG screenshot, convert to ePaper buffer; optional `chromic_pdf` dependency | ChromicPDF `capture_screenshot/2` returns Base64 PNG → decode → `Bitmap.from_image/2`; `optional: true` dep pattern confirmed |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `chromic_pdf` | ~> 1.17 | HTML → PNG screenshot via CDP (no Node.js) | Pre-selected in CLAUDE.md; OTP supervised pool; `capture_screenshot/2` returns Base64 PNG; v1.17.1 current on Hex |
| `stb_image` | ~> 0.6 | Load PNG binary for 1-bit packing (already in use) | Already in deps; `Papyrus.Bitmap.StbLoader` uses it; no new dependency needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Elixir `Base` module | built-in | Decode Base64 PNG from ChromicPDF | Always — `Base.decode64!/1` converts `capture_screenshot` output to raw PNG binary |
| `System.tmp_dir!/0` | built-in | Temp directory for intermediate PNG file | Used to bridge ChromicPDF output to `Bitmap.from_image/2` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Temp file bridge | Custom `Bitmap.Loader` for binary | Binary loader would avoid disk I/O but requires changes to `Papyrus.Bitmap`; temp file keeps existing pipeline unchanged |
| `Code.ensure_loaded?(ChromicPDF)` | `Application.ensure_all_started(:chromic_pdf)` | The former is a read-only check (correct for call-site guard); the latter starts the app which is side-effectful and inappropriate at call time |
| `{:file, path}` → `file://` URL | Read file, pass as `{:html, content}` | `file://` URL works but exposes OS path concerns; reading the file and passing as HTML is more portable and avoids ChromicPDF's URL navigation path |

**Installation:**
```bash
# In mix.exs deps — chromic_pdf is optional
{:chromic_pdf, "~> 1.17", optional: true}
```

**Version verification (confirmed 2026-03-30):**
- `chromic_pdf` current: 1.17.1 (published 2024-08-09)

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── papyrus/
│   ├── renderer/
│   │   └── headless.ex     # New — Papyrus.Renderer.Headless
│   ├── application.ex      # Modify — conditional ChromicPDF child
│   └── ...existing files...
```

No `Papyrus.Renderer` namespace module is needed. The `Headless` submodule is the complete deliverable.

### Pattern 1: Optional Dependency Call-Site Guard
**What:** Check `Code.ensure_loaded?(ChromicPDF)` before invoking any ChromicPDF API. Return structured error if unavailable.
**When to use:** At the top of `render_html/2` before any ChromicPDF call.
**Example:**
```elixir
# Source: https://nts.strzibny.name/soft-dependencies-in-elixir-projects/
# and Elixir hex docs Code.ensure_loaded?/1
def render_html(input, %DisplaySpec{} = spec) do
  if Code.ensure_loaded?(ChromicPDF) do
    do_render(input, spec)
  else
    {:error, "chromic_pdf not available — add {:chromic_pdf, \"~> 1.17\"} to your deps and ensure it is started"}
  end
end
```

### Pattern 2: Conditional Application Child
**What:** In `Papyrus.Application.start/2`, append ChromicPDF to children only if the module is loaded.
**When to use:** The single place where ChromicPDF is supervised (D-07).
**Example:**
```elixir
# Source: Established Elixir pattern for optional OTP children
def start(_type, _args) do
  children =
    if Code.ensure_loaded?(ChromicPDF) do
      [{ChromicPDF, []}]
    else
      []
    end

  Supervisor.start_link(children, strategy: :one_for_one, name: Papyrus.Supervisor)
end
```

### Pattern 3: ChromicPDF Input Mapping
**What:** Map Papyrus tagged-tuple inputs to ChromicPDF `source()` tuples.
**When to use:** Inside `do_render/2` private function.
**Example:**
```elixir
# Source: https://hexdocs.pm/chromic_pdf/ChromicPDF.html#capture_screenshot/2
# ChromicPDF source() type: {:url, binary()} | {:html, iodata()}
defp to_chromic_source({:html, html}), do: {:html, html}
defp to_chromic_source({:url, url}),   do: {:url, url}
defp to_chromic_source({:file, path}),  do: {:html, File.read!(path)}
# {:file, path} reads content and passes as {:html, ...} to avoid file:// URL concerns
```

### Pattern 4: Fixed-Viewport Screenshot via CDP Clip
**What:** Use the `:capture_screenshot` map option to pass Chrome DevTools Protocol `Page.captureScreenshot` parameters. The `clip` parameter restricts the screenshot to an exact pixel region.
**When to use:** Always in `render_html/2` — the viewport must match `spec.width × spec.height` (D-06).
**Example:**
```elixir
# Source: https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot
# and ChromicPDF docs: https://hexdocs.pm/chromic_pdf/ChromicPDF.html
# capture_screenshot: map() passes options directly to Page.captureScreenshot CDP call
opts = [
  capture_screenshot: %{
    "clip" => %{
      "x" => 0,
      "y" => 0,
      "width" => spec.width,
      "height" => spec.height,
      "scale" => 1
    }
  }
]
ChromicPDF.capture_screenshot(source, opts)
```

Note: String keys are required because `stringify_map_keys/2` in ChromicPDF's `protocol_options.ex` only stringifies the top-level `:capture_screenshot` key, not nested maps. Use string keys for nested CDP parameters.

### Pattern 5: Base64 PNG to Temp File Bridge
**What:** ChromicPDF `capture_screenshot/2` returns `{:ok, base64_blob}`. Decode and write to a temp file, pass the path to `Papyrus.Bitmap.from_image/2`, then clean up.
**When to use:** The existing bitmap pipeline accepts a file path, not a binary blob.
**Example:**
```elixir
# Source: ChromicPDF hexdocs + Elixir Base module
with {:ok, base64_blob} <- ChromicPDF.capture_screenshot(source, opts) do
  png_binary = Base.decode64!(base64_blob)
  tmp_path = Path.join(System.tmp_dir!(), "papyrus_screenshot_#{:erlang.unique_integer([:positive])}.png")

  try do
    File.write!(tmp_path, png_binary)
    Papyrus.Bitmap.from_image(tmp_path, spec)
  after
    File.rm(tmp_path)
  end
end
```

### Anti-Patterns to Avoid
- **Bang functions in `render_html/2`:** `Base.decode64!/1` raises on invalid input. Wrap in `try/rescue` or validate that the blob is non-empty before decoding. ChromicPDF won't return invalid Base64, but defensive coding is appropriate here.
- **Calling `Application.ensure_all_started(:chromic_pdf)` at call-site:** This starts ChromicPDF lazily, outside the supervisor tree. Use `Code.ensure_loaded?` as a read-only guard only; ChromicPDF must be started by the supervisor (D-07).
- **Using `{:file, path}` → `{:url, "file://#{path}"}` pattern:** ChromicPDF's URL navigation for `file://` URLs may have path encoding issues on some platforms. Reading the file and passing as HTML string is safer and simpler.
- **Leaving temp files on error:** Always use `try/after` or `on_exit` to clean up temp files. A crash mid-render otherwise leaks files in the temp directory.
- **Adding `chromic_pdf` to `extra_applications`:** The conditional `Code.ensure_loaded?` startup pattern handles this. Do not add to `extra_applications` in `mix.exs` — that would make it unconditional.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Headless browser control | Custom CDP protocol implementation | `chromic_pdf` | CDP is complex (WebSocket over stdin/stdout, session management, race conditions on page load); ChromicPDF encapsulates all of this |
| PNG decoding | Custom PNG parser | `stb_image` (already present) via temp file + `Bitmap.StbLoader` | PNG has multiple color modes, compression variants, and alpha; stb_image handles all of them |
| Base64 decoding | Custom base64 impl | `Base.decode64!/1` (Elixir built-in) | Built-in is correct, zero-overhead |
| Optional dep detection | Custom application flag | `Code.ensure_loaded?(ChromicPDF)` | Standard Elixir pattern; returns `true/false` at compile or runtime |

**Key insight:** ChromicPDF already handles the hardest parts — spawning Chrome, managing a session pool, speaking CDP, and returning clean output. The entire renderer is a thin mapping layer on top.

---

## Common Pitfalls

### Pitfall 1: Base64 String Encoding Variant
**What goes wrong:** `Base.decode64!/1` raises `ArgumentError` because ChromicPDF may use URL-safe Base64 or include line breaks in the encoded blob.
**Why it happens:** The Chrome DevTools Protocol `Page.captureScreenshot` returns standard Base64 without padding, but line breaks can appear in some Chrome versions.
**How to avoid:** Use `Base.decode64!(blob, ignore: :whitespace, padding: false)` to strip whitespace and handle no-padding variants. Test against a real ChromicPDF instance before assuming clean Base64.
**Warning signs:** `ArgumentError` on `Base.decode64!` in tests.

### Pitfall 2: Viewport vs. Clip — Content Overflow
**What goes wrong:** The HTML content overflows the viewport, making the screenshot larger than `spec.width × spec.height`, so the resulting bitmap is wrong dimensions for the display buffer.
**Why it happens:** `Page.captureScreenshot` captures the visible viewport; if CSS causes content to overflow, Chrome may expand the viewport or clip incorrectly.
**How to avoid:** Always inject a CSS reset into HTML inputs to constrain layout: `<style>html,body{width:${spec.width}px;height:${spec.height}px;overflow:hidden;margin:0;padding:0;}</style>`. The `clip` CDP option hard-clips the output regardless of content size.
**Warning signs:** `{:error, {:bad_buffer_size, …}}` from `Papyrus.Display.display/2` — the bitmap byte count doesn't match `spec.buffer_size`.

### Pitfall 3: File:// Path Encoding on macOS vs. Linux
**What goes wrong:** When using `{:url, "file://#{path}"}` for `{:file, path}` inputs, paths with spaces or special characters cause Chrome navigation failure.
**Why it happens:** `file://` URLs must be percent-encoded; Elixir string interpolation does not encode paths.
**How to avoid:** For `{:file, path}` inputs, read the file content with `File.read/1` and pass as `{:html, content}` to ChromicPDF instead of using a `file://` URL. This is the recommended approach (Claude's Discretion).
**Warning signs:** ChromicPDF returns `{:error, _}` for `{:file, …}` inputs but `{:html, …}` works fine.

### Pitfall 4: Temp File Accumulation on Repeated Errors
**What goes wrong:** If `Bitmap.from_image/2` returns an error, the caller may not notice the temp file was not cleaned up.
**Why it happens:** Elixir `try/after` ensures cleanup even on error, but not if the process is killed.
**How to avoid:** Use `try/after` unconditionally around the temp file path. The `after` block runs even when `from_image` returns `{:error, _}`. For process crashes, consider using `System.tmp_dir!/0` with a deterministic-enough name so stale files can be identified.
**Warning signs:** Accumulating `.png` files in the system temp directory named `papyrus_screenshot_*.png`.

### Pitfall 5: ChromicPDF Not Started When `Code.ensure_loaded?` Returns True
**What goes wrong:** `Code.ensure_loaded?(ChromicPDF)` returns `true` (the module is compiled and available), but ChromicPDF's supervisor is not running — perhaps because the consuming app did not include it in its supervision tree and `Papyrus.Application` startup guard didn't fire.
**Why it happens:** `Code.ensure_loaded?` checks whether the module is compiled, not whether its supervised pool is running. If the consuming app sets `Papyrus.Application` to not start (e.g., in test config), ChromicPDF is never started.
**How to avoid:** The call-site guard checks `Code.ensure_loaded?` first but the actual ChromicPDF call will raise `(exit :noproc)` if the pool is not running. Catch this: wrap the `ChromicPDF.capture_screenshot/2` call in a `try/rescue` and convert `(exit :noproc)` into `{:error, "chromic_pdf pool not running — is it started in your supervision tree?"}`.
**Warning signs:** `** (exit) :noproc` exception in `render_html/2`.

---

## Code Examples

Verified patterns from official sources:

### ChromicPDF — Start as OTP Child
```elixir
# Source: https://hexdocs.pm/chromic_pdf/ChromicPDF.html
# In Papyrus.Application (simplified form):
children =
  if Code.ensure_loaded?(ChromicPDF) do
    [{ChromicPDF, []}]
  else
    []
  end

Supervisor.start_link(children, strategy: :one_for_one, name: Papyrus.Supervisor)
```

### ChromicPDF — Capture Screenshot with Fixed Clip
```elixir
# Source: https://hexdocs.pm/chromic_pdf/ChromicPDF.html#capture_screenshot/2
# clip parameter: https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot
{:ok, base64_blob} = ChromicPDF.capture_screenshot(
  {:html, "<html>...</html>"},
  [
    capture_screenshot: %{
      "clip" => %{"x" => 0, "y" => 0, "width" => 800, "height" => 480, "scale" => 1}
    }
  ]
)

# Decode Base64 PNG to raw binary
png_binary = Base.decode64!(base64_blob, ignore: :whitespace, padding: false)
```

### Optional Dep in mix.exs
```elixir
# Source: https://hexdocs.pm/elixir/Mix.Tasks.Deps.html
# CLAUDE.md: mark chromic_pdf as optional: true
{:chromic_pdf, "~> 1.17", optional: true}
```

### Full render_html/2 Skeleton (implementation guidance)
```elixir
# Source: derived from ChromicPDF hexdocs + Elixir Base module + existing Papyrus.Bitmap API
def render_html(input, %DisplaySpec{} = spec) do
  if Code.ensure_loaded?(ChromicPDF) do
    source = to_chromic_source(input)
    opts = screenshot_opts(spec)

    try do
      case ChromicPDF.capture_screenshot(source, opts) do
        {:ok, base64_blob} ->
          png_binary = Base.decode64!(base64_blob, ignore: :whitespace, padding: false)
          with_temp_png(png_binary, fn tmp_path ->
            Papyrus.Bitmap.from_image(tmp_path, spec)
          end)

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e in [ErlangError] ->
        {:error, "chromic_pdf pool not running: #{inspect(e)}"}
    end
  else
    {:error,
     "chromic_pdf not available — add {:chromic_pdf, \"~> 1.17\"} to your deps and ensure it is started"}
  end
end

defp screenshot_opts(%DisplaySpec{width: w, height: h}) do
  [
    capture_screenshot: %{
      "clip" => %{"x" => 0, "y" => 0, "width" => w, "height" => h, "scale" => 1}
    }
  ]
end

defp to_chromic_source({:html, html}),  do: {:html, html}
defp to_chromic_source({:url, url}),    do: {:url, url}
defp to_chromic_source({:file, path}),  do: {:html, File.read!(path)}

defp with_temp_png(binary, fun) do
  tmp = Path.join(System.tmp_dir!(), "papyrus_#{:erlang.unique_integer([:positive])}.png")

  try do
    File.write!(tmp, binary)
    fun.(tmp)
  after
    File.rm(tmp)
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PhantomJS / wkhtmltopdf | ChromicPDF + Chromium | ~2020 | PhantomJS unmaintained; wkhtmltopdf uses outdated WebKit; Chromium has CSS Grid, Flexbox, modern fonts |
| Node.js + Puppeteer | ChromicPDF (pure Elixir, no Node) | 2020 (ChromicPDF v0.1) | Removes Node.js runtime dependency from Elixir projects |
| Full-page screenshot with downscale | Exact-pixel clip via CDP `Page.captureScreenshot` | CDP API, Chrome 91+ | Direct clip at target resolution avoids resize artifacts |

**Deprecated/outdated:**
- `wallaby`: Requires ChromeDriver separately; designed for browser interaction tests, not screenshot capture. Not appropriate here.
- `puppeteer` via `System.cmd`: Adds Node.js dependency. Explicitly forbidden in CLAUDE.md.
- `PhantomJS`: Abandoned project. Do not reference in docs.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Chromium / Google Chrome | `chromic_pdf` | ✗ (not on dev machine) | — | Feature degrades gracefully — `render_html/2` returns `{:error, …}` when ChromicPDF not running |
| `chromic_pdf` Hex package | `Papyrus.Renderer.Headless` | ✗ (not in deps yet) | 1.17.1 | Add to mix.exs as `optional: true` — no fallback needed, it IS the optional dep |
| `stb_image` | Bitmap pipeline (existing) | ✓ | 0.6.x | — |
| `elixir_make` | C port compilation | ✓ | 0.9.0 | — |

**Missing dependencies with no fallback:**
- Chromium must be installed on any system where `render_html/2` is expected to produce output. On Raspberry Pi OS Bullseye+, Chromium 111+ is available via `sudo apt install chromium-browser`. This is a runtime prerequisite, not a code blocker.

**Missing dependencies with fallback:**
- `chromic_pdf` is deliberately optional: the library compiles and runs without it; only the headless renderer is gated.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/papyrus/renderer/` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RENDER-04 | `render_html({:html, …}, spec)` returns `{:ok, binary}` of `spec.buffer_size` bytes | unit (mock ChromicPDF) | `mix test test/papyrus/renderer/headless_test.exs` | ❌ Wave 0 |
| RENDER-04 | `render_html/2` returns `{:error, "chromic_pdf not available…"}` when ChromicPDF not loaded | unit | `mix test test/papyrus/renderer/headless_test.exs` | ❌ Wave 0 |
| RENDER-04 | `display/3` calls `render_html/2` then `Display.display/2` and returns `{:ok, :sent}` | unit (mock Display) | `mix test test/papyrus/renderer/headless_test.exs` | ❌ Wave 0 |
| RENDER-04 | `{:url, …}`, `{:html, …}`, `{:file, …}` inputs all dispatched correctly | unit | `mix test test/papyrus/renderer/headless_test.exs` | ❌ Wave 0 |
| RENDER-04 | `Papyrus.Application` starts ChromicPDF child when module loaded | unit | `mix test test/papyrus/renderer/headless_test.exs` | ❌ Wave 0 |
| RENDER-04 | Hardware render test (manual) — HTML page renders on physical display | manual / @hardware | `mix test test/hardware/ --include hardware` | ❌ Wave 0 (optional) |

**Testing strategy for optional dep:** The test for `render_html/2` when ChromicPDF is absent should mock `Code.ensure_loaded?/1` OR set up a test that does not compile/start ChromicPDF. Simplest approach: test the "not available" path by passing `mock_chromic_available: false` to an internal helper, or by using `Application.put_env` to inject a test flag.

Alternatively, the "not available" branch can be tested by extracting the guard into a named private function `chromic_available?/0` that reads from `Application.get_env(:papyrus, :chromic_pdf_available, Code.ensure_loaded?(ChromicPDF))` — making it overridable in tests without Mox.

### Sampling Rate
- **Per task commit:** `mix test test/papyrus/renderer/`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/papyrus/renderer/headless_test.exs` — covers RENDER-04 unit paths
- [ ] `test/papyrus/renderer/` directory must be created

*(No new test framework installation required — ExUnit is sufficient.)*

---

## Open Questions

1. **Base64 padding/variant in ChromicPDF output**
   - What we know: `capture_screenshot/2` docs say it returns "Base64-encoded PNG"; Chrome CDP returns standard Base64
   - What's unclear: Whether ChromicPDF strips or preserves `=` padding; whether it inserts line breaks
   - Recommendation: Use `Base.decode64!(blob, ignore: :whitespace, padding: false)` defensively; add an integration test against real ChromicPDF to confirm the format

2. **`{:file, path}` — HTML string vs. file:// URL**
   - What we know: Both approaches are technically possible; reading and passing as HTML is simpler
   - What's unclear: Whether any relative asset references in the HTML file (images, CSS) would break with the HTML string approach vs. file:// URL (which preserves the base URL)
   - Recommendation: Default to reading file and passing as HTML string; document the limitation that relative asset paths won't resolve; if needed, `file://` URL with URI encoding is the upgrade path (deferred)

3. **ChromicPDF pool not running vs. module not loaded**
   - What we know: `Code.ensure_loaded?` checks module availability, not pool state; ErlangError with `:noproc` would surface if pool not running
   - What's unclear: Whether the exact exception is `ErlangError` with `:noproc` reason, or an `exit` from GenServer.call timeout
   - Recommendation: Wrap `capture_screenshot` call in `try/rescue ErlangError` and also catch `exit` signals with `catch :exit, _` pattern; surface a clear error message either way

---

## Sources

### Primary (HIGH confidence)
- https://hexdocs.pm/chromic_pdf/ChromicPDF.html — `capture_screenshot/2` signature, source() type, Base64 return format, OTP child startup pattern, `:capture_screenshot` map option for CDP passthrough
- https://hexdocs.pm/chromic_pdf/changelog.html — v1.10.0: `:full_page` added; v1.11.0: `--hide-scrollbars` default; confirms v1.17.1 is current stable
- https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot — CDP `Page.captureScreenshot` `clip` parameter (`x`, `y`, `width`, `height`, `scale`)
- https://nts.strzibny.name/soft-dependencies-in-elixir-projects/ — `Code.ensure_compiled?` / `Code.ensure_loaded?` pattern for Elixir optional dependencies
- Existing codebase: `lib/papyrus/bitmap.ex`, `lib/papyrus/application.ex`, `lib/papyrus/display.ex`, `lib/papyrus/display_spec.ex` — integration point signatures confirmed by direct file read

### Secondary (MEDIUM confidence)
- GitHub bitcrowd/chromic_pdf source review of `lib/chromic_pdf/api/protocol_options.ex` — confirmed that `stringify_map_keys` only stringifies top-level key, so nested CDP map params must use string keys
- `hex.pm` package info — `chromic_pdf` v1.17.1 confirmed as current; Apache-2.0 license

### Tertiary (LOW confidence)
- WebSearch results re: ChromicPDF viewport/clip — no direct documentation found for `clip` usage via `:capture_screenshot` map; inferred from CDP protocol spec + ChromicPDF's passthrough behavior

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — ChromicPDF version confirmed on hex.pm; already pre-selected in CLAUDE.md
- Architecture: HIGH — Integration points (Bitmap.from_image, Display.display, Application) confirmed by direct source read; ChromicPDF API confirmed via hexdocs
- Pitfalls: MEDIUM — Base64 variant and clip-vs-viewport behavior are inferred from docs; need integration test to validate
- Optional dep pattern: HIGH — `Code.ensure_loaded?` is the established Elixir pattern, confirmed by multiple sources

**Research date:** 2026-03-30
**Valid until:** 2026-06-30 (ChromicPDF is stable; CDP protocol is stable)
