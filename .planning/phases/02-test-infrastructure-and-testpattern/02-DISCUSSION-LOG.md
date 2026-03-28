# Phase 2: Test Infrastructure and TestPattern - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-28
**Phase:** 02-test-infrastructure-and-testpattern
**Areas discussed:** Mock port implementation, Two-tier test taxonomy, TestPattern buffer encoding, TEST-02 scope clarification

---

## Mock Port Implementation

**Question:** How should the mock port binary be built?

**Options presented:**
- A — Elixir script executable (zero compilation, Mac-safe)
- B — Tiny C stub with its own Makefile target (closest to production)
- C — Elixir Task peer (no binary, most flexible for error simulation)

**Selected:** C — Elixir Task

**Follow-up — Mock port responses:**

**Options presented:**
- Simple — always `{:ok, ""}`, no configuration
- Configurable — test-controlled responses for error simulation

**Selected:** Configurable

---

## Two-Tier Test Taxonomy

**Question:** How should CI-safe vs hardware-required tests be separated and documented?

**Options presented:**
- A — ExUnit `@tag :hardware` + `mix test --exclude hardware`
- B — Separate `test/hardware/` directory (CI never touches it)
- C — Markdown checklist only (no ExUnit hardware tests in v1)

**Selected:** B — Separate `test/hardware/` directory

---

## TestPattern Buffer Encoding

**Question 1:** White vs Black bit convention

**Options presented:**
- `full_white` = `0xFF` bytes
- `full_white` = `0x00` bytes
- Add `:bit_order` field to `DisplaySpec`

**Selected:** Add `:bit_order` to DisplaySpec (enforced, values `:white_high`/`:white_low`)

**Follow-up — field shape:**

**Options presented:**
- `:normal`/`:inverted` with default `:normal`
- `:white_high`/`:white_low` with default `:white_high`
- Enforce it (no default, every display module must declare)

**Selected:** `:white_high`/`:white_low`, enforced (no default)

**Question 2:** Checkerboard granularity

**Options presented:**
- Byte-level alternation (0xFF/0x00 — ~8-pixel-wide stripes)
- Bit-level alternation (0xAA/0x55 — true pixel checkerboard)

**Selected:** Bit-level (0xAA/0x55)

---

## TEST-02 Scope Clarification

**Question:** Does Phase 2 write Bitmap tests (module doesn't exist yet)?

**Options presented:**
- Skip — no Bitmap test file in Phase 2; Phase 3 adds it
- Stub — empty test file as placeholder
- Update REQUIREMENTS.md — fix TEST-02 wording

**Selected:** Skip + Update REQUIREMENTS.md
