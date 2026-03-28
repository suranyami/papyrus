# Phase 1: DisplaySpec and C Port Foundation - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `Papyrus.DisplaySpec` with `color_mode`, `pin_config`, and `partial_refresh` fields so it becomes the stable, complete Elixir↔C contract for all future display drivers. Harden `c_src/epd_port.c` with `select()`-based stdin polling so the OS process exits cleanly when the BEAM VM is killed.

The existing Waveshare 12.48" B&W display must continue working end-to-end after both changes.

Multi-display C port dispatch (runtime display selection, new driver ports) is Phase 2+, not this phase.

</domain>

<decisions>
## Implementation Decisions

### pin_config field shape
- **D-01:** `pin_config` is a plain flat atom-keyed map — `%{rst: 6, dc: 13, cs: 8, busy: 5}` for simple displays; namespaced keys for multi-panel displays
- **D-02:** `pin_config` is a required `@enforce_keys` field in `Papyrus.DisplaySpec` — every display module must provide one, no nil default
- **D-03:** The `Waveshare12in48` `pin_config` map uses flat namespaced keys mirroring `DEV_Config.h` naming exactly:
  ```elixir
  %{
    sck: 11, mosi: 10,
    m1_cs: 8,  s1_cs: 7,  m2_cs: 17, s2_cs: 18,
    m1s1_dc: 13, m2s2_dc: 22,
    m1s1_rst: 6, m2s2_rst: 23,
    m1_busy: 5, s1_busy: 19, m2_busy: 27, s2_busy: 24
  }
  ```

### Claude's Discretion
- `partial_refresh` field type — boolean (`partial_refresh: false` default) seems appropriate for Phase 1; the type can be enriched in a later phase when partial refresh is actually implemented
- `color_mode` type completeness — add `:three_color` to the type now so the stable contract covers all v1 variant types, even if no `:three_color` driver is implemented this phase
- EOF detection scope — success criterion specifies "exits within one select timeout cycle"; implementation approach (select() in idle loop only vs also patching BUSY-pin loops) is Claude's call; favour the simplest approach that satisfies the criterion
- `color_mode` default value for existing `Waveshare12in48` — no change needed (stays `:black_white`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Elixir contracts (files being modified)
- `lib/papyrus/display_spec.ex` — Current `DisplaySpec` struct and `@type` definitions; fields being extended
- `lib/papyrus/displays/waveshare_12in48.ex` — Existing display module; needs `pin_config` and `partial_refresh` added
- `lib/papyrus/display.ex` — GenServer that owns the port; verify no breakage from struct changes

### C port (file being modified)
- `c_src/epd_port.c` — Current main loop; location of stdin sentinel change

### Pin configuration source of truth
- `c_src/waveshare/epd12in48/DEV_Config.h` — Defines all GPIO pin numbers for the 12.48" display; pin_config map values MUST match these constants

### Project requirements and goals
- `.planning/REQUIREMENTS.md` §DRIVER-01, §DRIVER-02 — The two requirements this phase satisfies
- `.planning/ROADMAP.md` §Phase 1 — Success criteria (4 items) that define "done"

No external ADRs or design docs — project is pre-v1 and all constraints are captured in PROJECT.md and REQUIREMENTS.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Papyrus.Protocol` — Already handles encode/decode; no changes needed for Phase 1 (protocol extension is Phase 2+)
- `DEV_Config.h` pin constants — Direct source for `pin_config` map values in `Waveshare12in48`

### Established Patterns
- `@enforce_keys` pattern — Already used in `DisplaySpec` for `:model`, `:width`, `:height`, `:buffer_size`; `pin_config` joins this list
- Port exit on stdin close — `epd_port.c` already breaks the main loop when `read_exact()` returns non-zero; the `select()` change extends this to catch EOF during the idle wait itself (not after a partial read)

### Integration Points
- `Papyrus.Display.init/1` — Calls `display_module.spec()` and opens the port; struct field additions are transparent here as long as the struct is valid
- `DEV_ModuleInit()` / `DEV_ModuleExit()` in `epd_port.c` — Called at startup/shutdown; `select()` loop wraps the existing `read_exact` call in the main loop

</code_context>

<specifics>
## Specific Ideas

- Pin config keys mirror `DEV_Config.h` naming (e.g., `m1s1_rst` not `rst_m1s1`) — keeps the Elixir↔C mapping readable when debugging

</specifics>

<deferred>
## Deferred Ideas

- Multi-display C port dispatch (runtime display selection via init payload) — Phase 2+
- Wire protocol extension for `:dual_plane` and `:partial_refresh` — design needs validation against Waveshare driver sources before C coding; Phase 2+
- Partial refresh implementation — depends on stable multi-display dispatch; v2 milestone

</deferred>

---

*Phase: 01-displayspec-and-c-port-foundation*
*Context gathered: 2026-03-28*
