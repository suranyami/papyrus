---
phase: 3
slug: bitmap-rendering-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-29
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/papyrus/bitmap_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/papyrus/bitmap_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | BITMAP-01 | unit | `mix test test/papyrus/bitmap_test.exs:XX` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | BITMAP-01 | unit | `mix test test/papyrus/bitmap_test.exs:XX` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 1 | BITMAP-02 | unit | `mix test test/papyrus/bitmap_test.exs:XX` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/papyrus/bitmap_test.exs` — stubs for BITMAP-01, BITMAP-02
- [ ] `test/support/fixtures/` — sample PNG and BMP test fixtures

*Wave 0 must create test file and fixtures before implementation tasks run.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Buffer renders correctly on hardware | BITMAP-01 | Requires physical ePaper display | Load buffer via `Papyrus.Display.render/2` and visually verify image orientation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
