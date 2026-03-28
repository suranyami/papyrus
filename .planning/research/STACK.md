# Stack Research

**Domain:** Elixir ePaper display driver library (bitmap rendering, headless browser, port-process testing, Hex packaging)
**Researched:** 2026-03-28
**Confidence:** MEDIUM — core recommendations verified against official docs; dithering gap requires code-level validation

---

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

**Critical gap — dithering:** libvips has Floyd-Steinberg dithering only when saving PNG with a palette (`dither` param on `pngsave`), not as a standalone operation. For ePaper's specific need (arbitrary-threshold 1-bit conversion without a palette), implement dithering in Elixir using `Vix.Vips.Image.write_to_binary/1` to get the raw grayscale bytes then apply Floyd-Steinberg in pure Elixir bitstring operations. This is a deliberate implementation choice — no library provides ePaper-targeted dithering. Confidence: MEDIUM (based on libvips issue tracker #3010 and #278 confirming no standalone dither op).

#### Headless Browser

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `chromic_pdf` | ~> 1.17 | HTML → PNG screenshot via Chrome DevTools Protocol | **Primary choice** for `Papyrus.Renderer.Headless`; implements CDP directly without Node.js, ships as an OTP application with a pool of Chrome sessions, supports `capture_screenshot/2` returning Base64 PNG |

**chromic_pdf is the right choice because:**
- No Node.js dependency (communicates with Chrome via pipes directly)
- Returns PNG via `capture_screenshot/2` — matches exactly what the renderer needs
- Supervised OTP process pool — fits naturally into a supervised Papyrus application
- Active maintenance (v1.17.1 as of 2024-08-09)
- `capture_screenshot` supports `:full_page` and custom viewport dimensions — essential for ePaper fixed-resolution rendering

Chromium itself is a system dependency (not managed by the library). On Raspberry Pi OS this is `chromium-browser`. The renderer should be documented as optional infrastructure.

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

---

## Installation

```elixir
# mix.exs — production dependencies
defp deps do
  [
    {:elixir_make, "~> 0.9", runtime: false},

    # Bitmap rendering pipeline
    {:image, "~> 0.63"},        # PNG/JPEG load + colorspace ops
    # {:stb_image, "~> 0.6"},   # Alternative for Nerves minimal rootfs

    # HTML renderer (optional — only if using Papyrus.Renderer.Headless)
    {:chromic_pdf, "~> 1.17", optional: true},

    # Dev / test
    {:ex_doc, "~> 0.40", only: :dev, runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:mox, "~> 1.2", only: :test},
  ]
end
```

**Note on `image` and libvips on Raspberry Pi:**
`vix` (and therefore `image`) ships prebuilt libvips binaries for common platforms including `linux-arm64`. For Pi 4 (aarch64) this works out of the box. Pi 3 (armv7) may need `export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIB` and `apt install libvips-dev`. Verify before committing to `image` as the dependency — if Nerves support is required at the rootfs level, `stb_image` has fewer native dependencies.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `image` (libvips) | `Mogrify` (ImageMagick) | Never — ImageMagick is 2-3x slower and 5x higher memory; no benefit for this use case |
| `image` (libvips) | `stb_image` | Use `stb_image` when targeting Nerves minimal rootfs where installing libvips is impractical; trade-off: no built-in color ops, must implement grayscale and dithering entirely in Elixir |
| `chromic_pdf` | `Wallaby` | Use `Wallaby` only if you need browser interaction (clicking, form filling) — for pure screenshot capture it adds unnecessary overhead and requires ChromeDriver separately |
| `chromic_pdf` | `puppeteer` (via System.cmd) | Never — introduces Node.js runtime dependency; defeats the purpose of an Elixir library |
| Mox + Behaviour adapter | `mock` library (jjh42/mock) | Use `mock` only for legacy code without behaviour contracts; new code should always define behaviours |
| Pure Elixir dithering | libvips palette dither | libvips dithering only works during PNG save with palette quantization — not suitable for arbitrary 1-bit ePaper buffer conversion without palette |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `Mogrify` | Shell-outs to ImageMagick; poor performance; no raw buffer access; heavyweight system dependency | `image` (libvips via `vix`) |
| `mock` (jjh42/mock) | Modifies global module state; incompatible with async tests; not maintained to current Elixir standards | `Mox` with explicit behaviours |
| `:httpoison` / `:tesla` | Not relevant to this library — but avoid if any HTTP calls are ever added (e.g., remote render endpoint) | `Req` |
| PhantomJS / wkhtmltopdf | Abandoned or unmaintained headless browser projects | `chromic_pdf` + Chromium |
| NIFs for image processing | A C crash in a NIF kills the entire BEAM VM — inconsistent with the port-isolation design philosophy already established | Port process (existing) or safe NIF via `vix` (libvips manages its own crash isolation) |
| Pre-built C binaries in Hex package | Hex.pm packages must compile on the target; distributing binaries creates architecture/OS fragmentation problems and breaks Nerves cross-compilation | Ship `c_src/` source and compile via `elixir_make` |

---

## Stack Patterns by Variant

**For `Papyrus.Bitmap` (PNG/BMP → 1-bit buffer):**
1. Load with `Image.open/2` (uses libvips)
2. Convert to grayscale with `Image.to_colorspace(image, :bw)` (verify API — may be `:VIPS_INTERPRETATION_B_W`)
3. Extract raw bytes with `Vix.Vips.Image.write_to_binary/1` — gives 8-bit grayscale HWC binary
4. Apply Floyd-Steinberg in pure Elixir (custom implementation — no library covers this)
5. Pack 8 pixels-per-byte via `<<bit::1>>` bitstring operations → ePaper buffer binary

**For `Papyrus.Renderer.Headless` (HTML → bitmap):**
1. Start `ChromicPDF` as an OTP application in the consuming app's supervision tree
2. Set viewport to display resolution before capture
3. `ChromicPDF.capture_screenshot/2` → Base64 PNG
4. Decode Base64 → binary
5. Pass binary to `Papyrus.Bitmap` pipeline above

**For testing `Papyrus.Display` (port process) without hardware:**
1. Define `Papyrus.PortDriver` behaviour with callbacks matching the port commands
2. Implement `Papyrus.PortDriver.Port` (real, uses `Port.open`)
3. Implement `Papyrus.PortDriver.Mock` using `Mox.defmock`
4. Inject via Application config: `config :papyrus, port_driver: Papyrus.PortDriver.Port`
5. In tests: `config :papyrus, port_driver: Papyrus.PortDriver.Mock` — no real port spawned

**Alternative for port testing (no Mox):**
Spawn a stub executable — a simple shell/Elixir script that reads the length-prefixed protocol and responds with canned bytes. Use `Port.open({:spawn_executable, stub_path}, [:binary, :use_stdio, {:packet, 4}])`. This tests the full wire protocol without hardware and without behaviour abstractions. Most appropriate for protocol-level tests; Mox is better for GenServer-level tests.

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `elixir_make ~> 0.9` | Elixir ~> 1.15, Mix ~> 1.15 | No known breakage; `make_cwd` option stable since 0.7 |
| `image ~> 0.63` | `vix ~> 0.38` (pulled as transitive dep) | `image` pins its own `vix` constraint; don't add `vix` explicitly unless you need lower-level ops |
| `chromic_pdf ~> 1.17` | Chrome/Chromium >= 91 | `full_page` screenshot requires Chrome 91+; Raspberry Pi OS Bullseye+ ships Chromium 111+ |
| `mox ~> 1.2` | Elixir ~> 1.13 | Concurrent mock support; verify `allow/3` usage for GenServer-owned mocks |
| `ex_doc ~> 0.40` | Elixir ~> 1.13 | Livebook `.livemd` integration available in this version range |

---

## Hex Package Checklist (library-specific)

These are packaging requirements beyond the defaults already in mix.exs:

- `c_src/` must be listed in `package: [files: [...]]` — already done in v0.1.0
- `priv/` must NOT exist in source tree — use `priv/.gitkeep` pattern already in place; Makefile must copy binary to `$MIX_APP_PATH/priv/` at compile time
- Mark `chromic_pdf` as `optional: true` in deps so consumers who don't need HTML rendering don't pull Chromium tooling
- Set `@since` module doc tags on public API functions — ExDoc renders these in the sidebar
- Use `groups_for_modules` (already in mix.exs) — expand when adding display spec modules for 40+ Waveshare models

---

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

---

*Stack research for: Papyrus ePaper library — bitmap rendering, headless browser, port testing, Hex packaging*
*Researched: 2026-03-28*
