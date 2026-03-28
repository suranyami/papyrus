<!-- GSD:project-start source:PROJECT.md -->
## Project

**Papyrus**

Papyrus is a public Elixir/Nerves library for driving Waveshare ePaper/eInk displays via supervised OS port processes. It provides hardware drivers for 40+ display models, a bitmap rendering pipeline, an HTML-to-bitmap rendering path (via headless browser), and built-in visual test patterns for hardware verification. The target audience is Elixir and Nerves developers building dashboards, signage, and IoT devices with ePaper displays.

**Core Value:** Any Waveshare ePaper display should be driveable from Elixir in under 10 lines of code, with the hardware abstraction solid enough that adding a new display model requires only a config module — not C code changes.

### Constraints

- **Tech stack:** Elixir + C (via `elixir_make`); no NIFs; no Rust; liblgpio for GPIO/SPI on Raspberry Pi
- **C compilation:** Must compile on the target (Raspberry Pi / Nerves); cross-compilation is the consuming project's concern
- **HTML rendering:** Headless browser dependency (Chromium) is optional — `Papyrus.Renderer.Headless` should be an opt-in dependency, not required for basic display use
- **Hex.pm packaging:** `c_src/` must be included in the package so consumers compile the C port themselves; pre-built binaries are not distributed
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir | ~> 1.15 | Host language | Already established in v0.1.0; matches existing mix.exs constraint |
| elixir_make | ~> 0.9 | C port compilation | Standard for Elixir libraries shipping C source; integrates with Mix compilers pipeline and Nerves cross-compilation. v0.9.0 is current. |
| ExUnit | built-in | Test suite | No alternative; built-in, excellent process/message assertion primitives |
| Mox | ~> 1.2 | Behaviour-based mocking | The canonical Elixir mock library (José Valim); enables concurrent async tests; requires explicit Behaviour contracts, which forces good design on `Papyrus.PortDriver` |
### Supporting Libraries
#### Bitmap / Image Processing
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `image` | ~> 0.63 | PNG/JPEG load, colorspace conversion, grayscale, color reduction | Primary image processing — wraps libvips via `vix`; `Image.write/3` with `output: :binary` and `Vix.Vips.Image.write_to_binary/1` extract raw pixel bytes |
| `vix` | ~> 0.38 | Direct libvips NIF bindings | Use when `image` lacks a needed operation — `Vix.Vips.Image.write_to_binary/1` is the exit hatch for raw pixel buffers |
| `stb_image` | ~> 0.6 | Lightweight PNG/BMP reader for NxML/Nerves contexts | Use instead of `image` if libvips is unavailable on target hardware (Nerves minimal rootfs); returns raw HWC binary with known bit depth |
#### Headless Browser
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `chromic_pdf` | ~> 1.17 | HTML → PNG screenshot via Chrome DevTools Protocol | **Primary choice** for `Papyrus.Renderer.Headless`; implements CDP directly without Node.js, ships as an OTP application with a pool of Chrome sessions, supports `capture_screenshot/2` returning Base64 PNG |
- No Node.js dependency (communicates with Chrome via pipes directly)
- Returns PNG via `capture_screenshot/2` — matches exactly what the renderer needs
- Supervised OTP process pool — fits naturally into a supervised Papyrus application
- Active maintenance (v1.17.1 as of 2024-08-09)
- `capture_screenshot` supports `:full_page` and custom viewport dimensions — essential for ePaper fixed-resolution rendering
#### Library Quality / Packaging
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ex_doc` | ~> 0.40 | Documentation generation | Already in mix.exs; v0.40.1 current; add `groups_for_modules` and `groups_for_extras` for the display model reference |
| `credo` | ~> 1.7 | Static analysis | Dev-only; enforce consistent style across the growing driver surface area |
| `dialyxir` | ~> 1.4 | Typespec checking | Dev-only; catches behaviour callback mismatches early — critical when adding 40+ display spec modules |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| `elixir_make` | Compiles `c_src/` during `mix deps.compile` | Already configured. Ensure `make_cwd: "c_src"` and Makefile copies binary to `$MIX_APP_PATH/priv/` — not to `priv/` in source tree (elixir_make v0.9 requirement) |
| `mix hex.publish` | Hex.pm release | Use `mix hex.publish package` and `mix hex.publish docs` separately; docs auto-publish from ExDoc |
| Chromium (system) | HTML rendering backend | Document as optional system dep; version >= 91 required for `full_page` screenshot support |
## Installation
# mix.exs — production dependencies
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `image` (libvips) | `Mogrify` (ImageMagick) | Never — ImageMagick is 2-3x slower and 5x higher memory; no benefit for this use case |
| `image` (libvips) | `stb_image` | Use `stb_image` when targeting Nerves minimal rootfs where installing libvips is impractical; trade-off: no built-in color ops, must implement grayscale and dithering entirely in Elixir |
| `chromic_pdf` | `Wallaby` | Use `Wallaby` only if you need browser interaction (clicking, form filling) — for pure screenshot capture it adds unnecessary overhead and requires ChromeDriver separately |
| `chromic_pdf` | `puppeteer` (via System.cmd) | Never — introduces Node.js runtime dependency; defeats the purpose of an Elixir library |
| Mox + Behaviour adapter | `mock` library (jjh42/mock) | Use `mock` only for legacy code without behaviour contracts; new code should always define behaviours |
| Pure Elixir dithering | libvips palette dither | libvips dithering only works during PNG save with palette quantization — not suitable for arbitrary 1-bit ePaper buffer conversion without palette |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `Mogrify` | Shell-outs to ImageMagick; poor performance; no raw buffer access; heavyweight system dependency | `image` (libvips via `vix`) |
| `mock` (jjh42/mock) | Modifies global module state; incompatible with async tests; not maintained to current Elixir standards | `Mox` with explicit behaviours |
| `:httpoison` / `:tesla` | Not relevant to this library — but avoid if any HTTP calls are ever added (e.g., remote render endpoint) | `Req` |
| PhantomJS / wkhtmltopdf | Abandoned or unmaintained headless browser projects | `chromic_pdf` + Chromium |
| NIFs for image processing | A C crash in a NIF kills the entire BEAM VM — inconsistent with the port-isolation design philosophy already established | Port process (existing) or safe NIF via `vix` (libvips manages its own crash isolation) |
| Pre-built C binaries in Hex package | Hex.pm packages must compile on the target; distributing binaries creates architecture/OS fragmentation problems and breaks Nerves cross-compilation | Ship `c_src/` source and compile via `elixir_make` |
## Stack Patterns by Variant
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `elixir_make ~> 0.9` | Elixir ~> 1.15, Mix ~> 1.15 | No known breakage; `make_cwd` option stable since 0.7 |
| `image ~> 0.63` | `vix ~> 0.38` (pulled as transitive dep) | `image` pins its own `vix` constraint; don't add `vix` explicitly unless you need lower-level ops |
| `chromic_pdf ~> 1.17` | Chrome/Chromium >= 91 | `full_page` screenshot requires Chrome 91+; Raspberry Pi OS Bullseye+ ships Chromium 111+ |
| `mox ~> 1.2` | Elixir ~> 1.13 | Concurrent mock support; verify `allow/3` usage for GenServer-owned mocks |
| `ex_doc ~> 0.40` | Elixir ~> 1.13 | Livebook `.livemd` integration available in this version range |
## Hex Package Checklist (library-specific)
- `c_src/` must be listed in `package: [files: [...]]` — already done in v0.1.0
- `priv/` must NOT exist in source tree — use `priv/.gitkeep` pattern already in place; Makefile must copy binary to `$MIX_APP_PATH/priv/` at compile time
- Mark `chromic_pdf` as `optional: true` in deps so consumers who don't need HTML rendering don't pull Chromium tooling
- Set `@since` module doc tags on public API functions — ExDoc renders these in the sidebar
- Use `groups_for_modules` (already in mix.exs) — expand when adding display spec modules for 40+ Waveshare models
## Sources
- https://hexdocs.pm/image/Image.html — image v0.63.0 API surface (MEDIUM confidence; dithering not confirmed via API docs)
- https://hexdocs.pm/vix/Vix.Vips.Image.html — `write_to_binary/1` confirmed (HIGH confidence)
- https://github.com/libvips/libvips/issues/3010 — libvips dithering limitation confirmed (HIGH confidence)
- https://hexdocs.pm/stb_image/StbImage.html — StbImage v0.6.10, PNG/BMP/grayscale support (HIGH confidence)
- https://hexdocs.pm/chromic_pdf/ChromicPDF.html — v1.17.1, `capture_screenshot/2` PNG support (HIGH confidence)
- https://hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html — v0.9.0 configuration options (HIGH confidence)
- https://hexdocs.pm/mox/Mox.html — Mox v1.2.0 concurrent mock patterns (HIGH confidence)
- https://hexdocs.pm/ex_doc/readme.html — ExDoc v0.40.1 (HIGH confidence)
- https://hex.pm/docs/publish — Hex publishing requirements (HIGH confidence)
- WebSearch: libvips dithering support (MEDIUM confidence — verified against GitHub issues, not API docs)
- WebSearch: ChromicPDF screenshot PNG format (MEDIUM confidence — verified against hexdocs)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
