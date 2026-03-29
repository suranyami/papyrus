# Phase 4: Documentation and Hex.pm Readiness - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Papyrus usable by an Elixir developer who finds it on Hex.pm: ExDoc documentation with a getting-started guide and hardware wiring instructions, `examples/` directory with sample images and sequential loading scripts, hardware rendering tests that verify the image pipeline works end-to-end on real hardware, and Hex.pm packaging configuration.

The user's explicit additions to DOCS-03 scope: sample B&W images bundled in `examples/images/`, a Mix script that loads them sequentially onto the display, and a hardware test that verifies image rendering produces clean output on screen.

Headless browser rendering (Chromium) and 3-color/red display support are NOT in scope — those are future phases.

</domain>

<decisions>
## Implementation Decisions

### Sample Images (user-specified)
- **D-01:** Bundle 2 CC0/public domain B&W illustrations in `examples/images/` — specifically high-contrast illustrations that work well at 1-bit (clean edges, bold shapes). Fetch from Wikimedia Commons, Project Gutenberg, or similar. Target file size < 200KB each.
- **D-02:** B&W/Red illustration was requested by the user but deferred — 3-color display pipeline (`color_mode: :three_color`) is not built yet. Note this in examples README so the user knows why it's not there.
- **D-03:** Images should be in PNG format (already supported by `Papyrus.Bitmap.from_image/2`). Include images at a variety of aspect ratios to demonstrate the letterbox resize working correctly.

### Hardware Rendering Test (user-specified)
- **D-04:** Hardware test lives in `test/hardware/bitmap_render_test.exs` using `@tag :hardware` (consistent with existing two-tier taxonomy from Phase 2).
- **D-05:** Test loads each sample image from `examples/images/`, calls `Papyrus.Bitmap.from_image/2`, sends the buffer to the display via `Papyrus.Display`, and prints a visual inspection prompt. Programmatic pass/fail is not possible (can't read a display), so the test succeeds if no errors are raised — the user inspects the screen manually.
- **D-06:** Test is parameterized over display model — reads the configured display model from application config or accepts it as a test tag. Default target: `Papyrus.Displays.Waveshare12in48`.

### Examples Directory (user-specified)
- **D-07:** Directory structure:
  ```
  examples/
    images/           # sample PNG files (CC0)
    load_images.exs   # Mix script: loads images sequentially onto display
    hello_papyrus.exs # init → clear → display test pattern → sleep
  ```
- **D-08:** `load_images.exs` is a Mix script (`mix run examples/load_images.exs`). Accepts `--model` argument for display module name. Loops through all PNGs in `examples/images/`, calls `Papyrus.Bitmap.from_image/2`, displays each with a configurable delay (default: 3s). Prints image name and buffer size as it goes.
- **D-09:** `hello_papyrus.exs` demonstrates the full lifecycle: init display, display a TestPattern, clear, sleep. This is DOCS-03 scope — simple enough that a new user can read it in < 1 minute.

### Documentation
- **D-10:** ExDoc guides live in `guides/` directory (standard ExDoc convention). Add to `mix.exs` `extras:` list.
- **D-11:** Guides to create:
  - `guides/getting-started.md` — hardware wiring, install, first test pattern on screen
  - `guides/loading-images.md` — how to use `Papyrus.Bitmap.from_image/2`, run `load_images.exs`, hardware verification steps
  - `guides/hardware-testing.md` — how to run `@tag :hardware` tests, what to look for on screen
- **D-12:** README.md updated to be Hex.pm-ready: installation snippet, hardware requirements, link to guides. Keep it short — guides do the heavy lifting.

### Hex.pm Packaging
- **D-13:** `mix.exs` package config: `description`, `licenses: ["MIT"]`, `links`, `files` list must include `c_src/` and `priv/.gitkeep`.
- **D-14:** `make_error_message` (via `elixir_make`) for missing `liblgpio` on macOS — currently silently skips C compilation; should print a clear message: "C port not compiled — lgpio is Linux/Raspberry Pi only. Display hardware requires Raspberry Pi."
- **D-15:** `mix hex.build --output /tmp/papyrus.tar` dry run in verification to confirm package contents before publish.

### Claude's Discretion
- Exact wording of getting-started guide prose
- Choice of specific CC0 illustrations (pick 2 visually distinct ones with clear contrast)
- ExDoc `groups_for_modules` structure for the display model reference
- Exact delay between images in `load_images.exs` (3–5 seconds reasonable)

</decisions>

<specifics>
## Specific Ideas

From the user:
- "a pure black/white illustration" — high contrast, will threshold cleanly at 128
- "a black/white/red illustration" — deferred; noted for future 3-color phase
- "convenient scripts to load them sequentially" — the `load_images.exs` Mix script
- "hardware test that we can run to verify it has rendered cleanly on the screen" — `test/hardware/bitmap_render_test.exs` with visual inspection
- The hardware test should make it easy for the user to verify rendering is clean — print the image name, show buffer stats, pause between images

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing conventions
- `.planning/phases/02-test-infrastructure-and-testpattern/02-CONTEXT.md` — Two-tier test taxonomy decisions (D-04 through D-06 in Phase 2); hardware test location and @tag :hardware convention
- `test/TESTING.md` — Two-tier taxonomy documented; hardware test runner instructions
- `test/hardware/.gitkeep` — Confirms `test/hardware/` directory exists

### Phase requirements
- `.planning/REQUIREMENTS.md` §DOCS-01 — ExDoc requirements
- `.planning/REQUIREMENTS.md` §DOCS-02 — Hex.pm packaging requirements
- `.planning/REQUIREMENTS.md` §DOCS-03 — examples/hello_papyrus requirements (now extended)

### Existing API surface to document
- `lib/papyrus/bitmap.ex` — `blank/1`, `from_image/2`, `from_image/3` — primary user-facing API for image loading
- `lib/papyrus/display.ex` — GenServer API (`start_link/1`, `display/2`, `clear/1`, `sleep/1`)
- `lib/papyrus/display_spec.ex` — `DisplaySpec` struct — every user needs this for configuration
- `lib/papyrus/test_pattern.ex` — `TestPattern` API — useful in getting-started examples

### mix.exs current state
- `mix.exs` — Read before editing; check existing `package:`, `docs:`, `deps:` sections

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Papyrus.Bitmap.from_image/2` — core function the hardware test and load script will exercise
- `Papyrus.TestPattern.full_white/1` — useful in hello_papyrus.exs for the clear-screen step
- `test/support/generate_fixtures.exs` — reference for Mix scripts that use StbImage to create PNG files; similar pattern for load_images.exs

### Established Patterns
- Hardware tests use `@tag :hardware` + live in `test/hardware/` (established in Phase 2)
- Mix scripts via `mix run file.exs` (established for fixture generation)
- `test_spec/1` helper pattern in tests for building `DisplaySpec` structs without hardware

### Integration Points
- `test/hardware/bitmap_render_test.exs` connects to: `Papyrus.Bitmap.from_image/2` + `Papyrus.Display` (requires hardware)
- `examples/load_images.exs` connects to: `Papyrus.Bitmap.from_image/2` + `Papyrus.Display.start_link/1`
- `mix.exs` → `package:` block needs `files:` list and `description:`

</code_context>

<deferred>
## Deferred Ideas

- **B&W/Red illustration and 3-color rendering** — User requested this but `Papyrus.Bitmap` only supports 1-bit (B&W) output. A 3-color pipeline would need a separate color-plane buffer and display commands. Defer to a future "3-color display support" phase.
- **Automated visual verification** — Programmatic pixel-readback from an ePaper display is not possible with the current hardware interface. If a camera-based verification approach were desired, that's a separate project.
- **Headless browser rendering examples** — `Papyrus.Renderer.Headless` (Chromium path) is out of scope for this milestone entirely.

</deferred>

---

*Phase: 04-documentation-and-hex-pm-readiness*
*Context gathered: 2026-03-30*
