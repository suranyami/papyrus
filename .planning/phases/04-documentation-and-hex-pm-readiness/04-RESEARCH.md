# Phase 4: Documentation and Hex.pm Readiness - Research

**Researched:** 2026-03-30
**Domain:** ExDoc configuration, elixir_make packaging, Mix scripts, Hex.pm packaging, CC0 image sourcing
**Confidence:** HIGH

## Summary

Phase 4 is a documentation and packaging phase with minimal new Elixir logic. The deliverables are: updated `mix.exs` (elixir_make version bump + `make_error_message` + ExDoc extras), three new guides in `guides/`, two converted example scripts (`hello_papyrus.exs` and `load_images.exs`) replacing the existing `examples/hello_papyrus/` Mix app, two CC0 PNG images in `examples/images/`, and a hardware test file in `test/hardware/bitmap_render_test.exs`.

The existing codebase is already well-structured: `guides/` and `examples/` directories exist, `mix.exs` already has `docs:` and `package:` blocks, `test/hardware/` exists (with `.gitkeep`), and the two-tier test taxonomy is fully documented in `TESTING.md`. Phase 4 fills in real content where stubs currently live.

One important discovery: the existing `examples/hello_papyrus/` is a full Mix project (with its own `mix.exs`) demonstrating a 3-color pattern. D-09 replaces this with a standalone `.exs` script demonstrating the simpler 1-bit lifecycle. The existing Mix app should be removed or superseded — the planner must handle this transition.

**Primary recommendation:** The phase is well-scoped and technically low-risk. The only non-trivial implementation decision is `make_error_message` wiring, which requires a `mix.exs` version constraint bump (`~> 0.7` → `~> 0.9`) alongside the new option.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sample Images (user-specified)**
- D-01: Bundle 2 CC0/public domain B&W illustrations in `examples/images/` — high-contrast illustrations that work well at 1-bit (clean edges, bold shapes). Fetch from Wikimedia Commons, Project Gutenberg, or similar. Target file size < 200KB each.
- D-02: B&W/Red illustration deferred — 3-color display pipeline not built yet. Note this in examples README so the user knows why it's not there.
- D-03: Images in PNG format. Include variety of aspect ratios to demonstrate letterbox resize.

**Hardware Rendering Test (user-specified)**
- D-04: Hardware test in `test/hardware/bitmap_render_test.exs` using `@tag :hardware`.
- D-05: Test loads each sample image from `examples/images/`, calls `Papyrus.Bitmap.from_image/2`, sends buffer to display via `Papyrus.Display`, prints visual inspection prompt. Pass/fail = no errors raised; user inspects screen manually.
- D-06: Test parameterized over display model — reads from application config or accepts test tag. Default: `Papyrus.Displays.Waveshare12in48`.

**Examples Directory (user-specified)**
- D-07: Structure: `examples/images/`, `examples/load_images.exs`, `examples/hello_papyrus.exs`
- D-08: `load_images.exs` is a Mix script (`mix run examples/load_images.exs`). Accepts `--model` argument. Loops PNGs in `examples/images/`, calls `Papyrus.Bitmap.from_image/2`, displays each with configurable delay (default 3s). Prints image name and buffer size.
- D-09: `hello_papyrus.exs` demonstrates: init display, display TestPattern, clear, sleep. Simple enough to read in < 1 minute.

**Documentation**
- D-10: ExDoc guides in `guides/` directory (standard ExDoc convention).
- D-11: Guides: `guides/getting-started.md`, `guides/loading-images.md`, `guides/hardware-testing.md`.
- D-12: README.md updated for Hex.pm: installation snippet, hardware requirements, link to guides. Short — guides do heavy lifting.

**Hex.pm Packaging**
- D-13: `mix.exs` package config: `description`, `licenses: ["MIT"]`, `links`, `files` list includes `c_src/` and `priv/.gitkeep`.
- D-14: `make_error_message` for missing `liblgpio` on macOS. Message: "C port not compiled — lgpio is Linux/Raspberry Pi only. Display hardware requires Raspberry Pi."
- D-15: `mix hex.build --output /tmp/papyrus.tar` dry run in verification to confirm package contents before publish.

### Claude's Discretion
- Exact wording of getting-started guide prose
- Choice of specific CC0 illustrations (pick 2 visually distinct ones with clear contrast)
- ExDoc `groups_for_modules` structure for the display model reference
- Exact delay between images in `load_images.exs` (3–5 seconds reasonable)

### Deferred Ideas (OUT OF SCOPE)
- B&W/Red illustration and 3-color rendering — 3-color pipeline not built yet
- Automated visual verification — pixel-readback from ePaper not possible with current hardware interface
- Headless browser rendering examples — `Papyrus.Renderer.Headless` out of scope for this milestone
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-01 | ExDoc API docs generated with getting-started, hardware setup, and display model reference guides | ExDoc extras/groups_for_extras/groups_for_modules config documented; existing `guides/` stub files exist |
| DOCS-02 | Hex.pm package configured with `make_error_message` for missing `liblgpio`, `c_src/` in package files | `make_error_message` option confirmed in elixir_make 0.9.0; `c_src/` is in default Hex file list; version constraint needs bump |
| DOCS-03 | `examples/hello_papyrus` demonstrates basic `init → clear → display → sleep` flow | Existing `examples/hello_papyrus/` Mix app needs replacement with `.exs` script; API (`Papyrus.start_display`, `clear`, `sleep`) fully implemented |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExDoc | ~> 0.31 (current: 0.40.1) | Documentation generation | Already in `mix.exs`; version in project is low — note below |
| elixir_make | ~> 0.9 (currently ~> 0.7 in mix.exs) | C port compilation + `make_error_message` | `make_error_message` exists in 0.7+ but lock file already resolves to 0.9.0; update constraint to `~> 0.9` |
| ExUnit | built-in | Hardware test framework | Two-tier taxonomy already established; `@tag :hardware` pattern in place |
| StbImage | ~> 0.6 (lock: 0.6.10) | PNG loading in `load_images.exs` and hardware test | Already a project dep; `Papyrus.Bitmap.from_image/2` uses it |

**Version note:** `mix.exs` has `{:ex_doc, "~> 0.31"}` but CLAUDE.md recommends `~> 0.40`. The lock file doesn't show ex_doc — it's a dev-only dep and likely resolves to a newer patch. Update constraint to `~> 0.34` (minimum for `groups_for_extras` regex support). MEDIUM confidence — exact minimum version for regex in `groups_for_extras` is inferred from changelog, not a hard requirement.

**elixir_make version:** `mix.exs` has `~> 0.7` but lock file has `0.9.0`. Update `mix.exs` constraint to `~> 0.9` to match what's installed and to document the `make_error_message` feature correctly. `make_error_message` is present in both 0.7 and 0.9 per the source code review.

**Installation note:** No new dependencies needed. All libraries are already installed.

## Architecture Patterns

### Files Affected

```
mix.exs                              # update: elixir_make version, make_error_message, ExDoc extras
README.md                            # update: Hex.pm-ready content
CHANGELOG.md                         # update: add unreleased section for v0.2
guides/
├── getting-started.md               # new (replaces guides/getting_started.md stub)
├── loading-images.md                # new
└── hardware-testing.md              # new
examples/
├── images/                          # new directory + 2 CC0 PNG files
│   └── (two .png files)
├── hello_papyrus.exs                # new .exs script (replaces examples/hello_papyrus/ Mix app)
└── load_images.exs                  # new Mix script
examples/hello_papyrus/              # REMOVE or document as superseded
test/hardware/
└── bitmap_render_test.exs           # new hardware test
```

### Pattern 1: make_error_message in mix.exs

**What:** Adds a custom error message shown when `make` compilation fails.
**When to use:** Always set when the C dependency is platform-specific.
**Behavior:** `make_error_message` is appended to the standard "Could not compile with make (exit status: N)" error. It does NOT suppress the error; it augments it. Shown on make failure, not on success or skip.

```elixir
# Source: hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html + source code review
def project do
  [
    app: :papyrus,
    compilers: [:elixir_make | Mix.compilers()],
    make_cwd: "c_src",
    make_error_message: """
    C port not compiled — lgpio is Linux/Raspberry Pi only.
    Display hardware requires Raspberry Pi.
    On macOS, `mix compile` succeeds but `Papyrus.Display.start_link/1` will fail
    at runtime if you attempt to use real hardware.
    Install liblgpio-dev on Raspberry Pi: sudo apt install liblgpio-dev
    """,
    ...
  ]
end
```

**Important:** The Makefile already skips compilation on non-Linux platforms silently. `make_error_message` only fires on actual make *failure* (non-zero exit), not on the macOS skip path. Since the macOS skip path exits 0, `make_error_message` will NOT appear on macOS — the Makefile's `@echo` message is the only feedback there.

**Implication for D-14:** If the goal is a clear macOS message, the right place to put it is in the Makefile's `else` branch (already has `@echo`), possibly also in a `Mix.raise` from an `after_compile` hook or a README note. The `make_error_message` option itself only shows on actual failure, not on the graceful skip. Document this distinction in the plan.

### Pattern 2: ExDoc extras and groups_for_extras

**What:** Controls which extra Markdown files appear in the docs sidebar and how they're grouped.
**Verified from:** hexdocs.pm/ex_doc/ExDoc.html

```elixir
# Source: hexdocs.pm/ex_doc/ExDoc.html
defp docs do
  [
    main: "getting-started",
    source_url: @source_url,
    source_ref: "v#{@version}",
    extras: [
      "README.md",
      "CHANGELOG.md",
      "guides/getting-started.md",
      "guides/loading-images.md",
      "guides/hardware-testing.md"
    ],
    groups_for_extras: [
      "Guides": ~r/guides\//
    ],
    groups_for_modules: [
      "Public API": [Papyrus, Papyrus.Bitmap, Papyrus.TestPattern],
      "Display Specs": [Papyrus.DisplaySpec, Papyrus.Displays.Waveshare12in48],
      "Internals": [Papyrus.Display, Papyrus.Protocol, Papyrus.Application]
    ]
  ]
end
```

**Filename convention:** Existing stubs use `getting_started.md` (underscores). CONTEXT.md D-11 uses `getting-started.md` (hyphens). Standard ExDoc convention is hyphens — use hyphens for new files. The existing `guides/getting_started.md` and `guides/hardware_setup.md` stubs need to be renamed or replaced.

**`main: "readme"` vs `main: "getting-started"`:** Current `mix.exs` has `main: "readme"`. For a library, pointing to the getting-started guide is better UX for new users. Change to `main: "getting-started"`.

### Pattern 3: Mix script that starts and uses a GenServer

**What:** A `.exs` file run via `mix run examples/load_images.exs` that starts `Papyrus.Display`, calls display functions, then exits.
**When `mix run` is used:** `mix run` starts the application (including `Papyrus.Application`). The application supervisor has no children by default, so `Papyrus.Display` must be started manually in the script.

```elixir
# Source: Elixir docs for mix run + existing test/support/generate_fixtures.exs pattern
# mix run starts the application — all Papyrus modules are available

# Parse arguments
{opts, _args, _} = OptionParser.parse(System.argv(), strict: [model: :string, delay: :integer])
model_name = opts[:model] || "Papyrus.Displays.Waveshare12in48"
delay_ms = (opts[:delay] || 3) * 1000

# Resolve display module
display_module = String.to_existing_atom("Elixir.#{model_name}")

# Start the display GenServer (not supervised — script owns it)
{:ok, display} = Papyrus.Display.start_link(display_module: display_module)

# Load and display each image
images_dir = Path.join(__DIR__, "images")
images = Path.wildcard(Path.join(images_dir, "*.png"))

Enum.each(images, fn path ->
  name = Path.basename(path)
  IO.puts("Loading #{name}...")
  spec = Papyrus.Display.spec(display)
  {:ok, buffer} = Papyrus.Bitmap.from_image(path, spec)
  IO.puts("  Buffer: #{byte_size(buffer)} bytes")
  :ok = Papyrus.Display.display(display, buffer)
  IO.puts("  Displayed. Waiting #{div(delay_ms, 1000)}s...")
  Process.sleep(delay_ms)
end)

Papyrus.Display.sleep(display)
IO.puts("Done.")
```

**Key patterns:**
- `__DIR__` for path resolution (established in Phase 2 decisions)
- `String.to_existing_atom/1` for dynamic module resolution — safe because the module must already be loaded by the app
- No `start_supervised!/1` — this is a script, not a test; direct `start_link` is correct
- `mix run` starts the application, so all modules are compiled and available

### Pattern 4: Hardware test structure

**What:** A test that exercises the real display hardware.
**Based on:** Existing `@tag :hardware` convention in `test/hardware/` and TESTING.md.

```elixir
# Source: established pattern from TESTING.md + Phase 2 decisions
defmodule Papyrus.Hardware.BitmapRenderTest do
  use ExUnit.Case, async: false

  @moduletag :hardware

  @images_dir Path.join([__DIR__, "..", "..", "examples", "images"]) |> Path.expand()

  setup do
    display_module = Application.get_env(:papyrus, :test_display_module,
      Papyrus.Displays.Waveshare12in48)
    {:ok, display} = Papyrus.Display.start_link(display_module: display_module)
    on_exit(fn -> if Process.alive?(display), do: Papyrus.Display.sleep(display) end)
    {:ok, display: display, display_module: display_module}
  end

  test "renders each sample image without error", %{display: display, display_module: _mod} do
    spec = Papyrus.Display.spec(display)
    images = Path.wildcard(Path.join(@images_dir, "*.png"))

    assert images != [], "No images found in #{@images_dir}"

    Enum.each(images, fn path ->
      name = Path.basename(path)
      IO.puts("\n  Loading: #{name}")
      {:ok, buffer} = Papyrus.Bitmap.from_image(path, spec)
      IO.puts("  Buffer: #{byte_size(buffer)} bytes")
      assert :ok == Papyrus.Display.display(display, buffer)
      IO.puts("  Inspect screen — press Enter to continue")
      IO.read(:line)
    end)
  end
end
```

**Note on D-06 (parameterized display model):** Reading from `Application.get_env/3` with a default is the simplest approach. An alternative is `@tag display: Papyrus.Displays.Waveshare12in48` but test tags aren't easily used to pass module references. Stick with Application config.

### Pattern 5: hello_papyrus.exs lifecycle script

The existing `examples/hello_papyrus/lib/hello_papyrus.ex` demonstrates 3-color rendering which is deferred. The new `hello_papyrus.exs` should be a simple standalone script:

```elixir
# examples/hello_papyrus.exs
# Demonstrates the Papyrus init → display → clear → sleep lifecycle.
# Run on a Raspberry Pi with a connected display:
#   mix run examples/hello_papyrus.exs
#
# By default, uses Papyrus.Displays.Waveshare12in48.
# Override with: mix run examples/hello_papyrus.exs --model Papyrus.Displays.MyDisplay

{opts, _, _} = OptionParser.parse(System.argv(), strict: [model: :string])
display_module = opts[:model]
  |> then(fn
    nil -> Papyrus.Displays.Waveshare12in48
    name -> String.to_existing_atom("Elixir.#{name}")
  end)

IO.puts("Starting display: #{inspect(display_module)}")
{:ok, display} = Papyrus.Display.start_link(display_module: display_module)

spec = Papyrus.Display.spec(display)
IO.puts("Display: #{spec.width}×#{spec.height}, #{spec.buffer_size} bytes/frame")

IO.puts("Displaying checkerboard test pattern...")
pattern = Papyrus.TestPattern.checkerboard(spec)
:ok = Papyrus.Display.display(display, pattern)

IO.puts("Waiting 3 seconds...")
Process.sleep(3_000)

IO.puts("Clearing to white...")
:ok = Papyrus.Display.clear(display)

IO.puts("Sleeping display...")
:ok = Papyrus.Display.sleep(display)

IO.puts("Done.")
```

### Anti-Patterns to Avoid

- **Using `main: "readme"` in docs config:** For a library, this dumps users on the raw README instead of a guided onboarding path. Use `main: "getting-started"`.
- **Guides with underscores in filenames:** ExDoc generates URLs from filenames. Use hyphens (`getting-started.md`) for URL-friendly output. The existing `guides/getting_started.md` and `guides/hardware_setup.md` stubs are underscore-named — rename them.
- **Keeping `examples/hello_papyrus/` Mix app:** It's a full Mix project demonstrating 3-color rendering that's deferred. Its `mix.exs` refers to `path: "../.."` and demonstrates 3-color mode. It should be removed and replaced with the `.exs` scripts to avoid user confusion.
- **`make_error_message` for the macOS skip:** The message fires only on non-zero exit. The macOS Makefile path exits 0 (graceful skip). For macOS user guidance, the `@echo` in the Makefile and a note in the README are the right tools.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Documentation generation | Custom doc scripts | `mix docs` (ExDoc 0.31+) | Already configured; handles API docs, extras, grouping |
| Package tar inspection | Custom file listing | `mix hex.build --output /tmp/papyrus.tar && tar -tf /tmp/papyrus.tar` | Exact verification of what Hex would publish |
| Image loading in scripts | Custom PNG reader | `Papyrus.Bitmap.from_image/2` (uses StbImage) | Already implemented; the whole point of Phase 3 |
| CC0 image sourcing | AI-generated images | Wikimedia Commons (CC0 tag) or rawpixel.com public domain | License clarity for Hex.pm; user needs to trust the source |

**Key insight:** This phase is almost entirely configuration and prose, not new logic. The risk of over-engineering is low; the risk of inconsistency (stale stubs, wrong filenames, wrong versions) is higher.

## Common Pitfalls

### Pitfall 1: make_error_message fires only on failure, not on macOS skip
**What goes wrong:** Developer sets `make_error_message` and expects macOS users to see it when compiling. They don't — the Makefile's else branch exits 0, which is success.
**Why it happens:** Confusing "skip" (exit 0) with "failure" (exit non-zero).
**How to avoid:** Put the macOS message in `Makefile`'s `@echo` (already there). Keep `make_error_message` for genuine failure cases (missing `liblgpio` on Linux but lgpio not installed, permissions issues).
**Warning signs:** The message never appears on macOS during testing.

### Pitfall 2: ExDoc extras filenames vs. actual guide filenames
**What goes wrong:** `extras:` list in `mix.exs` references `"guides/getting-started.md"` but the file is `guides/getting_started.md` (underscore from the old stub). `mix docs` silently skips missing files or errors.
**Why it happens:** Existing stubs use underscores; CONTEXT.md D-11 uses hyphens.
**How to avoid:** Rename stubs when creating new guides. Verify with `mix docs` immediately after updating `extras:`.
**Warning signs:** Guide not appearing in generated docs sidebar.

### Pitfall 3: Hex default files already include c_src/
**What goes wrong:** Developer explicitly lists `c_src` in `package: [files: [...]]` — but Hex's default list also includes `c_src`. If the explicit list is incomplete (e.g., missing `guides/`), the package will be missing files.
**Why it happens:** Overriding `files:` requires you to list everything — no merge with defaults.
**How to avoid:** When overriding `files:`, start from the Hex default list: `["lib", "priv", ".formatter.exs", "mix.exs", "README*", "LICENSE*", "CHANGELOG*", "c_src", "Makefile*"]` and add `guides/` and `examples/`.
**Warning signs:** `mix hex.build --unpack` shows missing directories.

### Pitfall 4: examples/hello_papyrus/ Mix app conflict
**What goes wrong:** Both the old `examples/hello_papyrus/` directory and the new `examples/hello_papyrus.exs` file exist. The directory's `mix.exs` has a `path:` dep to `"../.."` — it might interfere if someone runs `mix deps.get` from inside it.
**Why it happens:** The old directory was a full Mix project stub from the initial commit.
**How to avoid:** Remove `examples/hello_papyrus/` when creating `examples/hello_papyrus.exs`. Document the removal explicitly in the plan.
**Warning signs:** Confusion between the Mix app and the `.exs` script in guides.

### Pitfall 5: Waveshare12in48 is color_mode: :three_color
**What goes wrong:** `hello_papyrus.exs` uses `Papyrus.TestPattern.checkerboard(spec)` which returns `spec.buffer_size` bytes. But `Papyrus.Display.display/2` checks against `2 * spec.buffer_size` for `:three_color` displays. The call will fail with `{:error, {:bad_buffer_size, ...}}`.
**Why it happens:** `Waveshare12in48` has `color_mode: :three_color` (set in Phase 1 for future use), so Display expects a concatenated black+red plane.
**How to avoid:** In `hello_papyrus.exs` and `load_images.exs`, construct a full two-plane buffer: `pattern <> pattern` (both planes identical for a B&W display). Or document that the scripts require the B&W variant of the 12.48" panel.
**Warning signs:** `{:error, {:bad_buffer_size, expected: 320784, got: 160392}}` at runtime.

**This is the critical implementation pitfall for this phase.** The display module spec says `:three_color` but the current pipeline only produces 1-bit B&W buffers. The workaround is: for `hello_papyrus.exs` and `load_images.exs`, pass `buffer <> buffer` to satisfy the two-plane expectation, with a comment explaining the duplication. The planner must include this workaround explicitly.

## Code Examples

### mix.exs — updated package, docs, and make_error_message

```elixir
# Source: hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html (confirmed v0.9.0)
# Source: hexdocs.pm/ex_doc/ExDoc.html (confirmed v0.40.1)
# Source: hexdocs.pm/hex/Mix.Tasks.Hex.Build.html (file list defaults)

def project do
  [
    app: :papyrus,
    version: @version,
    elixir: "~> 1.15",
    compilers: [:elixir_make | Mix.compilers()],
    make_cwd: "c_src",
    make_error_message: """
    C port compilation failed.
    lgpio (liblgpio-dev) is required on Linux/Raspberry Pi.
    Install it with: sudo apt install liblgpio-dev
    On macOS, compilation is skipped — display hardware requires Raspberry Pi.
    """,
    start_permanent: Mix.env() == :prod,
    deps: deps(),
    package: package(),
    docs: docs(),
    description: "Elixir/Nerves library for driving Waveshare ePaper displays via a supervised OS port process",
    name: "Papyrus",
    source_url: @source_url,
    homepage_url: "https://hexdocs.pm/papyrus"
  ]
end

defp package do
  [
    files: [
      "lib",
      "c_src",
      "priv/.gitkeep",
      "guides",
      "examples",
      "mix.exs",
      "README.md",
      "CHANGELOG.md",
      "LICENSE",
      "Makefile",        # if Makefile is at root — check actual location
      ".formatter.exs"
    ],
    licenses: ["MIT"],
    links: %{
      "GitHub" => @source_url,
      "HexDocs" => "https://hexdocs.pm/papyrus"
    }
  ]
end

defp docs do
  [
    main: "getting-started",
    source_url: @source_url,
    source_ref: "v#{@version}",
    extras: [
      "README.md",
      "CHANGELOG.md",
      "guides/getting-started.md",
      "guides/loading-images.md",
      "guides/hardware-testing.md"
    ],
    groups_for_extras: [
      "Guides": ~r/guides\//
    ],
    groups_for_modules: [
      "Public API": [Papyrus, Papyrus.Bitmap, Papyrus.TestPattern],
      "Display Specs": [Papyrus.DisplaySpec, Papyrus.Displays.Waveshare12in48],
      "Internals": [Papyrus.Display, Papyrus.Protocol, Papyrus.Application]
    ]
  ]
end
```

**Note on Makefile location:** The C source Makefile is in `c_src/Makefile`, not the root. Hex default pattern `Makefile*` applies to root. If the `package: [files: [...]]` list is explicit, add `"c_src"` (which includes the Makefile in that subdir).

### Hex package contents verification

```bash
# Verify package contents before publish
mix hex.build --output /tmp/papyrus-$(mix run --no-halt --eval "IO.puts(Mix.Project.config()[:version])").tar
# or simpler:
mix hex.build --unpack --output /tmp/papyrus-check
ls -la /tmp/papyrus-check
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `extras: ["file.md"]` only | `groups_for_extras` + regex grouping | ExDoc ~0.28+ | Sidebar sections for multi-guide libraries |
| `main: "readme"` | `main: "getting-started"` for library onboarding | Best practice, not versioned | Users land on guided install path, not raw README |
| underscore guide filenames | hyphen guide filenames | ExDoc convention | Better URL generation |

**Note:** The existing `guides/getting_started.md` and `guides/hardware_setup.md` were created in the initial commit (2026-03-10) as stubs. They use underscores. Phase 4 replaces them with properly-named hyphenated files per D-11.

## Open Questions

1. **CC0 image selection**
   - What we know: Wikimedia Commons and rawpixel.com public domain are both reliable CC0 sources; high-contrast B&W illustrations are available.
   - What's unclear: Specific image filenames/URLs — these need to be located and downloaded at execution time.
   - Recommendation: Use Wikimedia Commons. Search for woodcuts, engravings, or lithographs (inherently high contrast). Two good candidate categories: botanical illustrations (complex organic shapes, strong edges) and mechanical/engineering drawings (bold lines, clear geometry). Target: JPEG or PNG at source, convert to grayscale PNG for storage. File size < 200KB is easily met for raster PNG at display resolution.

2. **examples/hello_papyrus/ directory removal**
   - What we know: The directory contains a full Mix project demonstrating 3-color rendering (which is deferred).
   - What's unclear: Whether `git rm -r examples/hello_papyrus/` is the right move or if a README noting the deprecation is preferred.
   - Recommendation: Remove the directory entirely and replace with `examples/hello_papyrus.exs`. The 3-color demo logic can be recovered from git history if needed later.

3. **three_color buffer workaround for Waveshare12in48**
   - What we know: `Waveshare12in48.spec()` returns `color_mode: :three_color`; `Papyrus.Display.display/2` requires `2 * buffer_size` for three_color displays.
   - What's unclear: Is the intent that the examples should use `buffer <> buffer` (duplicate the plane) or that a dedicated B&W-only display module should be created?
   - Recommendation: Use `buffer <> buffer` in the scripts with an inline comment explaining the duplication. This is the simplest approach that doesn't require new code. Add a note in the guide that the 12.48" hardware is a 3-color panel but the current pipeline only produces B&W output — the second plane is all-white (redundant).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| mix (Elixir) | All tasks | ✓ | 1.15+ (via .mise.toml) | — |
| mix docs (ExDoc) | DOCS-01 | ✓ | 0.31+ installed | — |
| mix hex.build | DOCS-02 dry-run | Likely ✓ | Bundled with Hex | `mix hex.info` to verify |
| liblgpio-dev | DOCS-02 (macOS message test) | ✗ on macOS | — | Message tested by reading Makefile output |
| Raspberry Pi + display | DOCS-01/DOCS-03 hardware test | Not on dev machine (macOS) | — | Hardware test tagged @tag :hardware; excluded from CI |
| Internet (for CC0 images) | DOCS-03 (examples/images) | ✓ | — | Manual download |

**Missing dependencies with no fallback:**
- Real Raspberry Pi hardware for running `test/hardware/bitmap_render_test.exs` — but this is intentional; the `@tag :hardware` design accommodates this.

**Missing dependencies with fallback:**
- `mix hex.build` — if not present, `mix hex.info papyrus` can verify package metadata. Hex is bundled with Elixir/Mix installs.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` (excludes `:hardware` by default) |
| Quick run command | `mix test` |
| Full suite command | `mix test --include hardware test/hardware/` (requires Pi) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | `mix docs` generates without errors | smoke | `mix docs` | ✅ ExDoc configured |
| DOCS-02 | Package contains `c_src/`, `guides/`, `examples/` | smoke | `mix hex.build --output /tmp/papyrus.tar && tar -tf /tmp/papyrus.tar` | ✅ (command only) |
| DOCS-02 | `make_error_message` appears in compile failure | manual | Intentionally trigger failure on Linux | N/A |
| DOCS-03 | `hello_papyrus.exs` executes without syntax errors | unit | `elixir --no-halt examples/hello_papyrus.exs --help` or dry parse | ❌ Wave 0 |
| DOCS-03 | `load_images.exs` loads and converts images | unit | N/A — requires hardware for Display.display call | ❌ Wave 0 |
| DOCS-03 | Hardware bitmap render test | hardware | `mix test test/hardware/ --include hardware` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test` (CI-safe suite, 107 tests)
- **Per wave merge:** `mix test && mix docs` (verify docs generate cleanly)
- **Phase gate:** `mix test && mix docs && mix hex.build --output /tmp/papyrus.tar` before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/hardware/bitmap_render_test.exs` — covers DOCS-03 hardware verification
- [ ] `examples/hello_papyrus.exs` — needs to exist before syntax can be validated
- [ ] `examples/load_images.exs` — needs to exist before syntax can be validated

*(Existing CI test infrastructure (107 tests) covers all prior phases; no framework changes needed)*

## Sources

### Primary (HIGH confidence)
- [hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html](https://hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html) — `make_error_message` option, full config list, v0.9.0
- [github.com/elixir-lang/elixir_make compile.make.ex source](https://github.com/elixir-lang/elixir_make/blob/82c53a2cf0c7a5a063e045c31015b9206f3a3217/lib/mix/tasks/compile.make.ex) — exact behavior: `raise_build_error/3` appends message to failure output only
- [hexdocs.pm/ex_doc/ExDoc.html](https://hexdocs.pm/ex_doc/ExDoc.html) — `extras`, `groups_for_extras`, `groups_for_modules` syntax and regex support
- [hexdocs.pm/hex/Mix.Tasks.Hex.Build.html](https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html) — default file list: `["lib", "priv", ".formatter.exs", "mix.exs", "README*", ...]`
- [hex.pm/docs/publish](https://hex.pm/docs/publish) — required fields: `description`, `licenses`, `links`
- Project codebase — `mix.exs`, `lib/papyrus/display.ex`, `lib/papyrus/bitmap.ex`, `test/test_helper.exs`, `TESTING.md` — all read directly

### Secondary (MEDIUM confidence)
- [elixirforum.com mix run + GenServer patterns](https://elixirforum.com/t/command-line-elixir-vs-mix-how-to-write-a-script-that-has-access-to-all-an-apps-modules/29750) — `mix run` starts application, modules available; verified against Mix docs
- [rawpixel.com public domain](https://www.rawpixel.com/search/public%20domain) — CC0 illustration source confirmed; specific images not verified (MEDIUM — requires manual selection at execution time)

### Tertiary (LOW confidence)
- ExDoc minimum version for `groups_for_extras` regex syntax — inferred from changelog review; minimum is likely 0.25+ (not verified against exact release notes)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already installed; versions confirmed from mix.lock
- Architecture patterns: HIGH — `make_error_message` behavior confirmed from source code; ExDoc config confirmed from hexdocs
- Pitfalls: HIGH for three_color buffer issue (confirmed from existing code); HIGH for make_error_message scope (confirmed from source); MEDIUM for filename conventions (inferred from ExDoc behavior)
- CC0 image selection: MEDIUM — sources confirmed, specific images require execution-time selection

**Research date:** 2026-03-30
**Valid until:** 2026-09-30 (stable ecosystem; ExDoc and elixir_make APIs are stable)
