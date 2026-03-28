# Phase 2: Test Infrastructure and TestPattern - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish hardware-free CI testing: an Elixir Task-based mock port peer, a `test/hardware/` directory convention for hardware-required tests, and `Papyrus.TestPattern` with `full_white/1`, `full_black/1`, and `checkerboard/1` functions. `Papyrus.Bitmap` is Phase 3 — no Bitmap tests or stubs are created here.

A small DisplaySpec extension (`:bit_order` enforced field) is required before TestPattern can be implemented correctly.

</domain>

<decisions>
## Implementation Decisions

### Mock Port (TEST-01)

- **D-01:** The mock port is an Elixir Task (not a compiled binary) that speaks the length-prefixed protocol as a port peer — zero compilation, works on Mac and Linux, no new build step
- **D-02:** Mock responses are configurable per-test — a test can tell the mock what to return for the next command, enabling error-path testing of `Papyrus.Display`
- **D-03:** Happy-path default is `{:ok, ""}` for every command unless overridden by the test

### Two-Tier Test Taxonomy (TEST-03)

- **D-04:** Hardware-required tests live in `test/hardware/` — CI never touches this directory
- **D-05:** CI-safe tests live in `test/papyrus/` as today — `mix test` runs only these
- **D-06:** The taxonomy is documented (contributor guide or README) so contributors know where to place new tests

### DisplaySpec `:bit_order` Field (prerequisite for TestPattern)

- **D-07:** Add `:bit_order` to `Papyrus.DisplaySpec` as an `@enforce_keys` field — no default, every display module must declare it
- **D-08:** Values are `:white_high` (0xFF = white, most common Waveshare B&W convention) and `:white_low` (0x00 = white)
- **D-09:** `Waveshare12in48` gets `bit_order: :white_high`
- **D-10:** This is a small extension to Phase 1 work; planner must update `DisplaySpec` and `Waveshare12in48` before implementing TestPattern

### TestPattern Buffer Encoding (PATTERN-01, PATTERN-02, PATTERN-03)

- **D-11:** `full_white/1` returns a buffer sized to `spec.buffer_size` where "white" bytes match `spec.bit_order` — `0xFF` for `:white_high`, `0x00` for `:white_low`
- **D-12:** `full_black/1` is the inverse — `0x00` for `:white_high`, `0xFF` for `:white_low`
- **D-13:** `checkerboard/1` uses bit-level alternation: `0xAA` and `0x55` bytes alternating — true pixel-level checkerboard (not 8-pixel-wide byte stripes)

### TEST-02 Scope Clarification

- **D-14:** `Papyrus.Bitmap` tests are **not** written in Phase 2 — the module does not exist yet. Phase 3 adds Bitmap tests when it builds the module
- **D-15:** REQUIREMENTS.md TEST-02 must be updated to remove `Papyrus.Bitmap` from Phase 2 scope — it should read: "ExUnit tests cover `Papyrus.Protocol`, `Papyrus.DisplaySpec`, and `Papyrus.TestPattern`"

### Claude's Discretion

- How the configurable mock stores and serves per-test responses (Agent, GenServer, or test process mailbox pattern)
- Whether `test/hardware/` is excluded via `.gitignore` config, mix alias, or `ExUnit.configure/1` in `test_helper.exs`
- Whether the taxonomy doc is a `TESTING.md` file or a section in the README

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### DisplaySpec (being extended)
- `lib/papyrus/display_spec.ex` — Current struct; `:bit_order` field and type must be added here
- `lib/papyrus/displays/waveshare_12in48.ex` — Must add `bit_order: :white_high` to the spec

### Existing tests (reference for patterns)
- `test/papyrus/display_spec_test.exs` — Current test style; follow this pattern for new tests
- `test/test_helper.exs` — Minimal ExUnit.start(); may need `test/hardware/` exclusion wired here

### Protocol (being tested)
- `lib/papyrus/protocol.ex` — encode/decode for the length-prefixed binary protocol; mock port must implement the same wire format

### Display GenServer (integration target for mock)
- `lib/papyrus/display.ex` — Accepts `:port_binary` option; mock port Task must be compatible with how this GenServer opens and communicates with the port

### Requirements being modified
- `.planning/REQUIREMENTS.md` §TEST-02 — Must be updated to remove `Papyrus.Bitmap` from Phase 2 scope
- `.planning/REQUIREMENTS.md` §TEST-01, §TEST-03, §PATTERN-01–03 — Requirements this phase satisfies

### Roadmap
- `.planning/ROADMAP.md` §Phase 2 — Success criteria (5 items) that define "done"

No external ADRs — all constraints captured in PROJECT.md and REQUIREMENTS.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Papyrus.Protocol.encode_request/2` and `decode_response/1` — mock port Task must use these to speak the wire format correctly
- `Papyrus.Display` `:port_binary` option — the injection point for the mock; already designed in

### Established Patterns
- `@enforce_keys` in `DisplaySpec` — pattern already established for required fields; `:bit_order` joins the list
- Pure-Elixir struct tests in `test/papyrus/` — existing test style to follow
- `test_helper.exs` is minimal — safe to extend with `test/hardware/` exclusion config

### Integration Points
- `Papyrus.Display.init/1` calls `display_module.spec()` — adding `:bit_order` to `@enforce_keys` means any display module missing it will fail at compile time (good — forces the update)
- Mock port Task connects to `Papyrus.Display` via the `:port_binary` option in `start_link/1`

</code_context>

<specifics>
## Specific Ideas

- Checkerboard is bit-level (0xAA/0x55), not byte-level (0xFF/0x00) — user specifically wants a true pixel-level pattern
- `:bit_order` values are `:white_high` / `:white_low` — explicit semantic names preferred over `:normal`/`:inverted`
- `:bit_order` is enforced (no default) — every display module must declare it, same as `pin_config`

</specifics>

<deferred>
## Deferred Ideas

- Bitmap tests — Phase 3 adds `test/papyrus/bitmap_test.exs` when `Papyrus.Bitmap` is built
- Error simulation beyond configurable mock responses — any deeper fault injection is Phase 3+ concern
- Hardware test execution in CI via remote Pi runner — out of scope for v1

</deferred>

---

*Phase: 02-test-infrastructure-and-testpattern*
*Context gathered: 2026-03-28*
