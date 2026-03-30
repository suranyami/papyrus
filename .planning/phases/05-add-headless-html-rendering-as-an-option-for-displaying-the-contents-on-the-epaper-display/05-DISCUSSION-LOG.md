# Phase 5: Headless HTML Rendering - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Downstream agents read CONTEXT.md, not this file.

**Date:** 2026-03-30
**Areas discussed:** API Surface, Input Types, Viewport & Sizing, Supervision Model

---

## Area 1: API Surface

**Q: How should `Papyrus.Renderer.Headless` expose its functionality?**

Options presented:
1. Bitmap only — `render_html(html, spec)` returns `{:ok, bitmap_binary}`
2. Bitmap + convenience display wrapper — same `render_html/2` plus `display/3`
3. Display wrapper only

**Selected:** 2 — Bitmap + convenience display wrapper

---

**Q: What should the error return look like?**

Options presented:
1. `{:ok, binary} | {:error, reason}` tuples — matches existing Papyrus conventions
2. Bang-style `render_html!/2` — raises on failure
3. Both — tuple variant + bang variant

**Selected:** 1 — `{:ok, binary} | {:error, reason}` throughout, no bang variants

---

## Area 2: Input Types

**Q: What input types should `render_html` accept?**

Options presented:
1. HTML string only
2. HTML string + URL
3. HTML string + URL + file path via tagged tuples

**Selected:** 3 — tagged tuples for all three: `{:html, string}`, `{:url, url}`, `{:file, path}`

---

**Q: Should bare HTML strings also work without a tag?**

Options presented:
1. Tagged only — always `{:html, "..."}`
2. Both — bare string shorthand + tagged form

**Selected:** 1 — tagged only, no bare string shorthand

---

## Area 3: Viewport & Sizing

**Q: How should viewport dimensions be determined?**

Options presented:
1. Auto from DisplaySpec — reads `spec.width` and `spec.height`
2. Auto from DisplaySpec + user override via `opts`
3. Always explicit — user must pass `viewport: {w, h}`

**Selected:** 1 — auto from DisplaySpec only, zero config

---

## Area 4: Supervision Model

**Q: Who starts ChromicPDF?**

Options presented:
1. User's responsibility — documented, nothing automatic
2. Papyrus starts it conditionally — `Papyrus.Application` checks if chromic_pdf is loaded
3. Opt-in via config — `config :papyrus, start_chromic_pdf: true`

**Selected:** 2 — Papyrus.Application starts ChromicPDF automatically if present

---

**Q: What happens when `chromic_pdf` is not in the user's deps at all?**

Options presented:
1. Silent skip at startup; fails with `{:error, :chromic_pdf_not_loaded}` at runtime
2. `Logger.warning` at startup if absent
3. Clear runtime error at call site with actionable message

**Selected:** 3 — clear runtime error at the call site with dep installation hint
