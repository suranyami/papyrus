# Phase 1: DisplaySpec and C Port Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Session:** 2026-03-28
**Areas selected for discussion:** pin_config field shape

---

## pin_config field shape

### Q1: What shape should the pin_config field take in DisplaySpec?

**Options presented:**
1. Plain map — `%{rst: 6, dc: 13, cs: 8, busy: 5}` flat atom-keyed map; complex displays use namespaced keys
2. Dedicated `%Papyrus.PinConfig{}` struct — typed with `@enforce_keys`
3. Sub-panel grouped map — `%{m1: %{cs: 8, busy: 5}, shared: %{sck: 11}}`

**Selected:** Plain map (option 1)

---

### Q2: Should pin_config be required (@enforce_keys) or optional with a nil default?

**Options presented:**
1. Required (`@enforce_keys`) — every display module must provide a pin_config map
2. Optional (default nil) — softer migration path
3. Optional with default empty map `%{}`

**Selected:** Required (`@enforce_keys`) (option 1)

---

### Q3: For Waveshare12in48, should the map use flat namespaced keys or pair keys?

**Options presented:**
1. Flat namespaced keys mirroring DEV_Config.h (e.g., `m1_cs: 8, m1s1_rst: 6`)
2. You decide — planner can work it out

**Selected:** Flat namespaced keys (option 1)

---

## Areas not discussed (Claude's Discretion)

- `partial_refresh` field type — user skipped; boolean default chosen by Claude
- `color_mode` completeness — user skipped; `:three_color` added for stable contract
- EOF detection scope — user skipped; implementation approach left to Claude

---

*Discussion conducted: 2026-03-28*
