---
phase: 04
slug: documentation-and-hex-pm-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-30
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` (excludes `:hardware` by default) |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix test && mix docs` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test`
- **After every plan wave:** Run `mix test && mix docs`
- **Before `/gsd:verify-work`:** `mix test && mix docs && mix hex.build --output /tmp/papyrus.tar`
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | DOCS-02 | smoke | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 04-01-02 | 01 | 1 | DOCS-03 | smoke | `elixir -e "Code.compile_file(\"examples/hello_papyrus.exs\")"` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | DOCS-03 | smoke | `elixir -e "Code.compile_file(\"examples/load_images.exs\")"` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | DOCS-01 | smoke | `mix docs 2>&1 \| grep -v "^$" \| tail -5` | ✅ | ⬜ pending |
| 04-02-02 | 02 | 2 | DOCS-02 | smoke | `mix hex.build --output /tmp/papyrus.tar && tar -tf /tmp/papyrus.tar \| grep c_src` | ✅ | ⬜ pending |
| 04-03-01 | 03 | 2 | DOCS-03 | hardware | `mix test test/hardware/ --include hardware` (requires Pi) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `examples/hello_papyrus.exs` — create file before syntax validation can run
- [ ] `examples/load_images.exs` — create file before syntax validation can run
- [ ] `test/hardware/bitmap_render_test.exs` — stubs for DOCS-03 hardware verification

*Existing 107-test CI suite covers all prior phase behavior; no framework changes needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `make_error_message` displays on lgpio build failure | DOCS-02 | Requires intentionally broken Linux build environment | On Pi, remove liblgpio-dev and run `mix compile`; verify error message appears |
| Display renders images correctly on hardware | DOCS-03 | Cannot read pixels from ePaper display programmatically | Run `mix test test/hardware/ --include hardware`; inspect each image on screen |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
