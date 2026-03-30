# Phase 5: Headless HTML Rendering - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `Papyrus.Renderer.Headless` — a module that captures HTML/URL/file → PNG screenshot via ChromicPDF (headless Chromium) and feeds the result through the existing `Papyrus.Bitmap` pipeline, producing a ready-to-display ePaper binary buffer.

`chromic_pdf` is an optional dependency. Users who only need image rendering do not need Chromium. The renderer is fully self-contained behind the optional dep guard.

</domain>

<decisions>
## Implementation Decisions

### API Surface
- **D-01:** Expose two public functions:
  - `Papyrus.Renderer.Headless.render_html(input, spec)` → `{:ok, bitmap_binary} | {:error, reason}`
  - `Papyrus.Renderer.Headless.display(input, display_pid, spec)` → `{:ok, :sent} | {:error, reason}` (calls `render_html/2` then `Papyrus.Display.display/2`)
- **D-02:** Error contract is `{:ok, binary} | {:error, reason}` throughout. No bang (`!`) variants.

### Input Types
- **D-03:** All inputs use tagged tuples — no bare string shorthand:
  - `{:html, html_string}` — render an HTML string directly
  - `{:url, url_string}` — navigate ChromicPDF to a URL and screenshot (e.g., local Phoenix endpoint)
  - `{:file, file_path}` — read an HTML file from disk and render it
- **D-04:** The tag always disambiguates — no implicit type inference.

### Viewport & Sizing
- **D-05:** Viewport dimensions are auto-derived from `spec.width` and `spec.height`. No user-facing override option. The DisplaySpec is the single source of truth for display resolution.
- **D-06:** The ChromicPDF screenshot is taken at exactly `spec.width × spec.height` pixels, then passed directly to `Papyrus.Bitmap.from_image/2` for grayscale conversion and 1-bit packing.

### Supervision / Optional Dep Integration
- **D-07:** `Papyrus.Application` checks whether `:chromic_pdf` application is available at startup. If present, it starts ChromicPDF as a child. If absent, it does nothing (no warning at startup).
- **D-08:** When `render_html/2` is called and ChromicPDF is not loaded/started, the function returns:
  ```
  {:error, "chromic_pdf not available — add {:chromic_pdf, \"~> 1.17\"} to your deps and ensure it is started"}
  ```
  Error lives at the call site, not at application startup.
- **D-09:** `chromic_pdf` is added to `mix.exs` deps with `optional: true` so it is not pulled transitively for users who don't need headless rendering.

### Claude's Discretion
- Internal implementation of the `{:file, path}` input (read file, pass as HTML string to ChromicPDF, or use file:// URL)
- Exact ChromicPDF `capture_screenshot/2` options (page dimensions, clip vs viewport)
- Module doc and `@since` tags
- Whether to expose a `Papyrus.Renderer` namespace module or just the `Headless` submodule directly

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement
- `.planning/REQUIREMENTS.md` §RENDER-04 — HTML → bitmap rendering requirement: optional chromic_pdf dep, render HTML to PNG screenshot, convert to ePaper buffer

### Existing pipeline (new module connects here)
- `lib/papyrus/bitmap.ex` — `from_image/2` and `from_image/3` accept a file path or binary; the rendered PNG screenshot feeds into this function
- `lib/papyrus/display.ex` — `Papyrus.Display.display/2` is what the `display/3` convenience wrapper calls
- `lib/papyrus/display_spec.ex` — `DisplaySpec` struct; `spec.width` and `spec.height` drive the viewport size

### Integration points to modify
- `lib/papyrus/application.ex` — add conditional ChromicPDF child start logic (D-07)
- `mix.exs` — add `{:chromic_pdf, "~> 1.17", optional: true}` to deps

### ChromicPDF API reference
- https://hexdocs.pm/chromic_pdf/ChromicPDF.html — `capture_screenshot/2`, supervised pool startup, CDP screenshot options

### Project constraints
- `CLAUDE.md` §Constraints — headless browser dependency is opt-in, not required for basic display use; `optional: true` in deps is mandatory

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Papyrus.Bitmap.from_image/2` — takes a PNG path or binary and `DisplaySpec`, returns packed 1-bit buffer; the renderer's output drops directly into this
- `Papyrus.Display.display/2` — called by the `display/3` convenience wrapper after bitmap conversion
- `Papyrus.Application` — existing OTP application module; ChromicPDF conditional start goes here

### Established Patterns
- Optional dep guard: check `Application.ensure_all_started(:chromic_pdf)` or `Code.ensure_loaded?(ChromicPDF)` at call site
- `{:ok, result} | {:error, reason}` tuples — consistent with `Papyrus.Bitmap.from_image/2` and `Papyrus.Display` API
- No NIFs — ChromicPDF uses a supervised port process (CDP via stdin/stdout), consistent with Papyrus's port process philosophy

### Integration Points
- `lib/papyrus/renderer/headless.ex` (new) — connects to `Papyrus.Bitmap.from_image/2` and `Papyrus.Display.display/2`
- `lib/papyrus/application.ex` — add ChromicPDF to children list if `:chromic_pdf` app is available

</code_context>

<specifics>
## Specific Ideas

- The "display HTML on ePaper" use case is the primary motivator — a developer building a dashboard should be able to pass an HTML string and get it on screen in two function calls
- The `{:url, url}` input type directly enables "render a local Phoenix endpoint" — point the URL at `http://localhost:4000/dashboard` and display it
- ChromicPDF was pre-selected in project CLAUDE.md as the library for this feature: no Node.js, pure Elixir OTP process pool, `capture_screenshot/2` returns Base64 PNG

</specifics>

<deferred>
## Deferred Ideas

- HiDPI/retina scaling — render at 2× resolution and downscale for sharper text; possible future enhancement, not needed for v1
- Viewport override option — `opts: [viewport: {w, h}]` for non-DisplaySpec-sized screenshots; deferred in favour of zero-config approach
- Streaming/progressive render — ChromicPDF pool exhaustion handling beyond simple `{:error, reason}`
- 3-color HTML rendering — dual-plane output for `color_mode: :three_color` displays; depends on Phase 3 color pipeline (RENDER-02)

</deferred>

---

*Phase: 05-add-headless-html-rendering-as-an-option-for-displaying-the-contents-on-the-epaper-display*
*Context gathered: 2026-03-30*
