# Feature Research

**Domain:** Elixir/Nerves ePaper display driver library (Waveshare, Hex.pm target)
**Researched:** 2026-03-28
**Confidence:** MEDIUM — Ecosystem is sparse in Elixir; Python ecosystem well-documented; hardware behavior well-understood from Waveshare docs and community posts.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Full-frame display (send buffer, refresh) | Core operation — the only thing any display library must do | LOW | Already in v0.1.0 as `Display.display/2` |
| Clear to white | Hardware reset operation; every driver tutorial starts with "clear first" | LOW | Already in v0.1.0 as `Display.clear/1` |
| Sleep mode | ePaper panels degrade if left powered without sleep; users expect this | LOW | Already in v0.1.0 as `Display.sleep/1` |
| Display model config (resolution, buffer size, color mode) | Users cannot form a buffer without knowing dimensions | LOW | `DisplaySpec` behaviour exists; needs more fields (pin assignments, partial refresh support) |
| Multiple display model support (>1 Waveshare model) | Library advertising 40+ models must deliver more than one | HIGH | Currently only `Waveshare12in48`; the primary active requirement |
| PNG/BMP → display buffer conversion | Users have images; they need them on the display. Without this they must hand-craft bit buffers. | MEDIUM | `Papyrus.Bitmap` — not yet built; Elixir `image` library (vix/libvips) is the right foundation |
| 1-bit (B&W) buffer format | All Waveshare B&W displays use 1-bit packed binary; required for any image rendering | MEDIUM | Depends on bitmap pipeline |
| Supervised crash isolation | BEAM library for IoT must survive hardware faults without crashing the VM | LOW | Already achieved via Port process model; must be preserved across refactors |
| ExDoc documentation | Hex.pm packages without docs are unusable; users will not adopt undocumented IoT libraries | MEDIUM | Getting-started guide, hardware setup instructions, display model reference |
| Working example app | Nerves projects require real examples showing wiring, supervision tree setup, and config | MEDIUM | `examples/hello_papyrus` in scope |

### Differentiators (Competitive Advantage)

Features that set Papyrus apart. Not expected by default, but high value when present.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| HTML → bitmap via headless Chromium | Opens entire web stack for content generation — Phoenix templates, LiveView snapshots, CSS-styled dashboards. No other Elixir ePaper library offers this. | HIGH | `Papyrus.Renderer.Headless`; renderer can run on-device or as a remote sidecar pushing bitmaps over the network. Chromium must be opt-in dependency. |
| Dithering (Floyd-Steinberg + threshold) | Grayscale photos and gradients on 1-bit/4-gray displays look poor without dithering. Waveshare's own wiki documents Floyd-Steinberg as the recommended algorithm for ePaper. | MEDIUM | Part of `Papyrus.Bitmap`; needs both error-diffusion (photos) and threshold (text/line art) modes |
| Config-driven display abstraction (no C changes for new models) | The key architectural promise: adding a new display = define an Elixir config module, not touch C. Most Python drivers require a new Python module per display; Go drivers are typically single-display. | HIGH | Config-driven C port; `DisplaySpec` extended with pin assignments, command bytes, timing |
| Built-in visual test patterns | Hardware bring-up is painful without visual verification tools. No existing Elixir library provides this; Python drivers leave it to the user. | MEDIUM | `Papyrus.TestPattern` — fill tests, border alignment, gray ramp, color layer, font probe |
| Hardware-free development (mock port) | IoT library development without physical hardware is currently impossible in the Elixir ecosystem. Inky (the only other Elixir eInk library) explicitly documents that host-side simulation is "underway" and unfinished. | MEDIUM | Mock port binary that logs commands and returns success; enables CI and host-side development without Raspberry Pi |
| 3-color (red/yellow accent) buffer format | 3-color displays are popular but require two-plane buffers (B&W plane + accent plane). Python drivers support this; no Elixir library does. | MEDIUM | Adds `:three_color` to `color_mode` in DisplaySpec; bitmap pipeline produces two-plane binary |
| 4-gray buffer format | 4-gray displays (2 bits/pixel) offer more visual fidelity for images. Popular for larger displays. | MEDIUM | Adds `:four_gray` to color_mode; already typed in DisplaySpec but not implemented end-to-end |
| Partial refresh support | Selective region updates (~0.5s vs 4s full refresh) are transformative for dashboard use cases. Complex to implement correctly — ghosting, mandatory full-refresh intervals, sleep-before-partial rules. | HIGH | Not in v0.1.0; requires both C port support and Elixir-side region specification |
| Remote render path (bitmap over network) | Headless Chromium is too heavy for low-RAM Pi Zero. A separate machine renders HTML, returns bitmap over TCP/HTTP, Pi writes it. Solves real resource constraints. | MEDIUM | Part of `Papyrus.Renderer.Headless` design; Elixir's networking strengths apply here |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems or are deliberately out of scope.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Bespoke bitmap font renderer | Users want text on displays without the headless browser | Massive scope — encoding, metrics, kerning, Unicode. At best partial; at worst broken. System fonts via headless browser handle this correctly with zero extra code. | Use `Papyrus.Renderer.Headless` for text; it handles system fonts, emoji, RTL, sizing |
| Animation / video | ePaper refresh cycles make motion appealing to mention | 1–30s refresh makes real animation impossible. Partial refresh at best gives ~2fps on tiny regions. Advertising this invites bug reports about "flickering". | Document refresh rate expectations clearly; partial refresh covers legitimate clock/ticker use cases |
| Pre-built binaries | Users may ask to avoid compiling C on device | Cross-architecture binaries are a maintenance and security liability; Nerves projects always compile on target anyway | `elixir_make` + `c_src/` in the Hex package; the consuming Nerves project handles cross-compilation |
| Non-Waveshare display drivers (v1) | Generic ePaper library sounds more useful | Each vendor uses different command protocols, pin assignments, timing. Bundle means maintenance burden for hardware nobody on the team has tested. | `DisplaySpec` behaviour is generic enough to accept third-party display modules as a community extension point |
| NIF-based driver | Some users believe NIFs = performance | ePaper refreshes take 1–30s and involve hardware I/O that can fault. A NIF crash kills the VM. Port crash isolation is a deliberate safety property, not a limitation. | Port process model — already correct; document rationale explicitly in README |
| Persistent display state / image layers | Layered compositing in the library sounds convenient | This belongs in the consuming application, not the library. Libraries that own state make testing harder and tie users to one composition model. | Keep the library stateless w.r.t. image content; users build compositing in their OTP application |
| Auto-refresh timers | "Display should update every N seconds" is a common request | Timer ownership belongs to the consuming application's supervision tree, not the library. Built-in timers conflict with application-specific scheduling, OTA updates, sleep cycles. | Provide clean `display/2` API; users compose timers via `Process.send_after` or Oban in their app |

---

## Feature Dependencies

```
[PNG/BMP input]
    └──requires──> [Papyrus.Bitmap]
                       ├──requires──> [1-bit buffer format]
                       ├──requires──> [3-color buffer format] (for 3-color displays)
                       ├──requires──> [4-gray buffer format] (for 4-gray displays)
                       └──requires──> [Dithering]
                                          └──requires──> [Papyrus.Bitmap] (same module)

[HTML → bitmap]
    └──requires──> [Papyrus.Renderer.Headless]
                       └──requires──> [Papyrus.Bitmap] (to consume rendered pixels)

[Test patterns]
    └──requires──> [Papyrus.Bitmap] (to generate buffers) OR direct buffer construction
    └──requires──> [Display model config] (to know resolution and color mode)

[Multiple display model support]
    └──requires──> [Config-driven C port] (to parameterise display variants)
    └──requires──> [Extended DisplaySpec] (pin assignments, command bytes, timing)

[Partial refresh]
    └──requires──> [Multiple display model support] (to know which models support it)
    └──requires──> [Config-driven C port] (partial refresh mode command bytes differ per model)
    └──conflicts──> [Sleep without re-init] (must re-init after sleep before partial refresh)

[Hardware-free development / mock port]
    └──enhances──> [ExUnit test suite] (enables CI without hardware)
    └──enhances──> [Multiple display model support] (test all configs without owning hardware)

[Remote render path]
    └──requires──> [Papyrus.Renderer.Headless] (same module, different transport)
    └──enhances──> [HTML → bitmap] (makes it practical on Pi Zero class hardware)
```

### Dependency Notes

- **Bitmap pipeline is the central dependency:** Test patterns, HTML rendering, image loading, and color mode support all flow through or alongside `Papyrus.Bitmap`. It should be built before any rendering feature.
- **Config-driven C port must precede multi-model support:** The display abstraction work is the blocker for 3-color, 4-gray, and partial refresh, which all require different command sets.
- **Dithering is part of the bitmap pipeline, not separate:** It is an option on the conversion functions, not a standalone module. Do not build it as an independent phase.
- **Partial refresh conflicts with naive sleep handling:** Waveshare docs are explicit — after sleep, you must re-init before partial refresh, not just call the partial API directly. This is a pitfall, not a feature dependency to resolve architecturally.
- **Mock port is a multiplier:** Delivering it early makes everything else testable without hardware. Worth prioritising higher than its complexity suggests.

---

## MVP Definition

### Launch With (this milestone — v0.2.0)

Minimum scope to be a genuinely useful public Hex.pm library.

- [ ] Extended `DisplaySpec` with pin assignments, command bytes, color mode, partial refresh flag — foundation for all multi-model work
- [ ] Config-driven C port — width/height/pins/commands as runtime parameters, not compile-time constants
- [ ] At least 3 display model configs: standard B&W (12.48"), a 3-color model, a partial-refresh capable model — validates the abstraction covers all structural variants
- [ ] `Papyrus.Bitmap` with PNG/BMP → 1-bit buffer conversion — users can display images without hand-crafting binaries
- [ ] Dithering (Floyd-Steinberg + threshold) as options on bitmap conversion — required for usable image quality on 1-bit displays
- [ ] `Papyrus.TestPattern` with fill, border, and gray ramp patterns — hardware bring-up requires visual verification
- [ ] Hardware-free mock port for ExUnit — enables CI and host-side development
- [ ] ExDoc documentation with getting-started guide and display model reference
- [ ] `examples/hello_papyrus` example app

### Add After Validation (v0.3.0)

- [ ] 3-color buffer format + at least one 3-color display module — adds second color mode
- [ ] 4-gray buffer format + end-to-end pipeline — adds third color mode
- [ ] `Papyrus.Renderer.Headless` — HTML → bitmap via headless Chromium (opt-in dependency)
- [ ] Remote render path within `Papyrus.Renderer.Headless` — solves Pi Zero memory constraint

### Future Consideration (v1.0+)

- [ ] Partial refresh — high value but complex; correctness requirements (ghosting, mandatory full refresh intervals, sleep/init ordering) make it risky to rush
- [ ] Community-contributed display modules for non-Waveshare panels — ecosystem expansion after the abstraction is validated
- [ ] Color test pattern for 3-color displays — depends on 3-color buffer support landing first

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Extended DisplaySpec | HIGH | LOW | P1 |
| Config-driven C port | HIGH | HIGH | P1 |
| Multiple display model configs | HIGH | MEDIUM | P1 |
| `Papyrus.Bitmap` (PNG/BMP → 1-bit) | HIGH | MEDIUM | P1 |
| Dithering (Floyd-Steinberg + threshold) | HIGH | MEDIUM | P1 |
| `Papyrus.TestPattern` | HIGH | LOW | P1 |
| Hardware-free mock port | MEDIUM | MEDIUM | P1 |
| ExDoc + example app | HIGH | MEDIUM | P1 |
| 3-color buffer format | MEDIUM | MEDIUM | P2 |
| 4-gray buffer format | MEDIUM | MEDIUM | P2 |
| `Papyrus.Renderer.Headless` (HTML → bitmap) | HIGH | HIGH | P2 |
| Remote render path | MEDIUM | MEDIUM | P2 |
| Partial refresh | HIGH | HIGH | P3 |
| Community display modules | MEDIUM | LOW (per module) | P3 |

**Priority key:**
- P1: Must have for this milestone (v0.2.0)
- P2: Should have, add in v0.3.0
- P3: Nice to have, future milestone

---

## Competitor Feature Analysis

| Feature | Inky (Elixir, pappersverk) | Waveshare Python SDK | epdlib (Python) | Papyrus approach |
|---------|---------------------------|---------------------|-----------------|------------------|
| Display models | Pimoroni pHAT/wHAT only | 50+ Waveshare models (one Python file each) | 50+ Waveshare (via abstraction) | 40+ Waveshare via config-driven C port |
| Image input | Pixel callback / coordinate map | Pillow Image → buffer | Block/layout system | PNG/BMP → `Papyrus.Bitmap` |
| Dithering | None | None (user responsibility) | None documented | Floyd-Steinberg + threshold (built in) |
| HTML rendering | None | None | None | Headless Chromium (opt-in, differentiator) |
| Test patterns | None | Examples only | None | Built-in `Papyrus.TestPattern` module |
| Hardware-free dev | Planned, unfinished | Virtual display via TKInter | None | Mock port binary |
| Partial refresh | None | Model-specific, not abstracted | Not documented | P3 (future) |
| 3-color support | Red (for Pimoroni red variant) | Yes (separate Python file per model) | Yes | Planned v0.3.0 |
| 4-gray support | None | Yes (some models) | IT8951 only | Planned v0.3.0 |
| Crash isolation | Not documented (presumably NIF-free) | N/A (Python process) | N/A (Python process) | Port process — deliberate design |
| Hex.pm package | Yes | N/A (PyPI) | N/A (PyPI) | Yes (target) |

**Key competitive position:** Papyrus is the only Elixir library targeting Waveshare displays (vs Inky's Pimoroni-only scope), the only one with a bitmap pipeline, the only one with built-in dithering, and the only one with HTML rendering. The mock port and test patterns are also differentiators vs both the Elixir and Python ecosystems. Inky is the nearest Elixir competitor but is narrow in scope and has stalled development.

---

## Sources

- [pappersverk/inky — Elixir eInk library (Hex.pm)](https://github.com/pappersverk/inky)
- [Underjord — Getting started with Inky on Nerves](https://underjord.io/an-eink-display-with-nerves-elixir.html)
- [Waveshare ePaper API Analysis](https://www.waveshare.com/wiki/E-Paper_API_Analysis)
- [waveshareteam/e-Paper — Official Waveshare driver repository](https://github.com/waveshareteam/e-Paper)
- [txoof/epdlib — Python ePaper layout library](https://github.com/txoof/epdlib)
- [soonuse/epd-library-python — Python ePaper series](https://github.com/soonuse/epd-library-python)
- [Fixing Waveshare ePaper partial updates (2025)](https://thoughts.gohu.org/posts/2025/epaper-partial-updates/)
- [E Ink / GooDisplay — dithering recommendations for ePaper](https://www.good-display.com/news/194.html)
- [Waveshare E-Paper Floyd-Steinberg wiki](https://www.waveshare.com/wiki/E-Paper_Floyd-Steinberg)
- [elixir-image/image — Elixir image processing library (vix/libvips)](https://github.com/elixir-image/image)
- [E-Ink display recommendations — Elixir Forum](https://elixirforum.com/t/e-ink-display-recommendations-for-a-nerves-project/14620)
- [Ben Krasnow — Fast partial refresh on 4.2" ePaper](https://benkrasnow.blogspot.com/2017/10/fast-partial-refresh-on-42-e-paper.html)

---
*Feature research for: Papyrus — Elixir/Nerves ePaper driver library*
*Researched: 2026-03-28*
