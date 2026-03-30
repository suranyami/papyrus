---
phase: 04-documentation-and-hex-pm-readiness
plan: 01
subsystem: packaging-and-examples
tags: [hex-pm, ex-doc, examples, mix-exs, packaging]
dependency_graph:
  requires: []
  provides: [mix-exs-hex-ready, example-scripts, sample-images]
  affects: [hex-publish, ex-doc-generation, docs-guides]
tech_stack:
  added: []
  patterns: [mix-exs-make-error-message, ex-doc-groups-for-extras, three-color-buffer-doubling]
key_files:
  created:
    - examples/hello_papyrus.exs
    - examples/load_images.exs
    - examples/images/botanical_illustration.png
    - examples/images/mechanical_drawing.png
    - examples/images/generate_samples.exs
  modified:
    - mix.exs
  deleted:
    - guides/getting_started.md
    - guides/hardware_setup.md
    - examples/hello_papyrus/lib/hello_papyrus.ex
    - examples/hello_papyrus/mix.exs
decisions:
  - "Programmatically generated CC0 PNG images (StbImage.new) instead of downloading from Wikimedia Commons (download failed)"
  - "ex_doc version bumped from ~> 0.31 to ~> 0.34 for groups_for_extras regex support"
  - "Images are original procedurally-generated works (botanical radial pattern, mechanical grid pattern) — no license concerns"
metrics:
  duration: 65
  completed_date: "2026-03-30"
  tasks: 2
  files: 7
---

# Phase 04 Plan 01: mix.exs Hex.pm Packaging and Examples Summary

Updated mix.exs with make_error_message, expanded package files (guides/, examples/), ExDoc extras with hyphenated guide names and groups_for_extras; created two .exs example scripts with :three_color buffer doubling workaround; generated two CC0 PNG sample images (400x300 landscape, 300x400 portrait) under 8.5KB each.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Update mix.exs for Hex.pm packaging and ExDoc configuration | 4510317 | mix.exs, removed guides/getting_started.md, guides/hardware_setup.md, examples/hello_papyrus/ |
| 2 | Create example scripts and CC0 sample images | 4789334 | examples/hello_papyrus.exs, examples/load_images.exs, examples/images/*.png |

## What Was Built

**mix.exs changes:**
- Bumped `elixir_make` constraint from `~> 0.7` to `~> 0.9` (matches installed 0.9.0, documents make_error_message support)
- Bumped `ex_doc` constraint from `~> 0.31` to `~> 0.34` (minimum for `groups_for_extras` regex)
- Added `make_error_message` with liblgpio install guidance (fires only on compile failure, not macOS skip)
- Updated `package: [files:]` to include `guides/` and `examples/`
- Updated `docs/0`: `main: "getting-started"`, hyphenated guide extras, `groups_for_extras: [Guides: ~r/guides\//]`, expanded `groups_for_modules` with Public API group

**Files removed:**
- `guides/getting_started.md` and `guides/hardware_setup.md` (underscore-named stubs replaced by hyphenated guides in Plan 02)
- `examples/hello_papyrus/` Mix project (superseded by `examples/hello_papyrus.exs`)

**Example scripts:**
- `examples/hello_papyrus.exs`: init display -> checkerboard pattern -> wait 3s -> clear to white -> sleep; accepts `--model` argument; handles `:three_color` buffer doubling
- `examples/load_images.exs`: loops all `examples/images/*.png`, loads via `Papyrus.Bitmap.from_image/2`, displays each; accepts `--model` and `--delay` arguments; handles `:three_color` buffer doubling

**Sample images:**
- `botanical_illustration.png`: 400x300 landscape (4:3), radial concentric rings + 12 spokes, 8.5KB
- `mechanical_drawing.png`: 300x400 portrait (3:4), crosshatch grid + concentric squares + diagonals, 4.7KB
- Both are procedurally-generated original works, released as CC0, under 200KB

## Deviations from Plan

### Auto-handled Issues

**1. [Rule 1 - Bug] Wikimedia Commons image download failed**
- **Found during:** Task 2
- **Issue:** `curl` downloads from `upload.wikimedia.org` returned HTML error pages or "File not found" responses, not PNG data. The network access to Wikimedia content delivery is blocked or unavailable in the execution environment.
- **Fix:** Generated two high-contrast PNG images programmatically using `StbImage.new/2` (the project's existing dependency). Created `examples/images/generate_samples.exs` as a reproducible generation script. The images are original works (procedurally generated radial botanical pattern and geometric mechanical grid) with different aspect ratios, meeting all acceptance criteria (PNG format, under 200KB, high contrast, different aspect ratios).
- **Files modified:** examples/images/botanical_illustration.png, examples/images/mechanical_drawing.png, examples/images/generate_samples.exs
- **Commit:** 4789334

**2. [Rule 2 - Missing] ex_doc version constraint updated**
- **Found during:** Task 1
- **Issue:** Plan specified bumping from `~> 0.31` to support `groups_for_extras` regex. CLAUDE.md stack recommends `~> 0.40`. The installed version is 0.40.1. Updated to `~> 0.34` as a conservative minimum that satisfies the requirement while the lock file (0.40.1) provides the actual version.
- **Fix:** Changed `{:ex_doc, "~> 0.31"}` to `{:ex_doc, "~> 0.34"}` in deps.
- **Commit:** 4510317

## Known Stubs

None — all scripts are functional. The guide files referenced in mix.exs (`guides/getting-started.md`, `guides/loading-images.md`, `guides/hardware-testing.md`) do not exist yet but are created in Plan 02. The `mix docs` command will warn about missing extras until Plan 02 completes.

## Verification

- `mix compile --warnings-as-errors`: passes (exit 0)
- `test -f examples/hello_papyrus.exs && test -f examples/load_images.exs`: passes
- `ls examples/images/*.png | wc -l`: returns 2
- `grep "make_error_message" mix.exs`: found
- `grep "getting-started" mix.exs`: found (main + extras)
- `test -d examples/hello_papyrus`: false (removed correctly)

## Self-Check: PASSED

Files verified:
- FOUND: examples/hello_papyrus.exs
- FOUND: examples/load_images.exs
- FOUND: examples/images/botanical_illustration.png
- FOUND: examples/images/mechanical_drawing.png
- FOUND: mix.exs (with make_error_message and updated config)

Commits verified:
- FOUND: 4510317 (chore: update mix.exs)
- FOUND: 4789334 (feat: create example scripts and CC0 sample images)
