# M4 → M5 runbook — the gate sequence to a submitted 0.6.0

**Purpose.** M5 is almost entirely *maintainer* sign-off gates, in a strict order, with one
non-obvious trap (the exact-tag rule). This runbook puts that sequence on disk so no session
re-derives it and no gate is skipped. It does **not** authorise anything — every 🛑 is Shinichi's.

**Standing rung (D-49 / D-66):** the honest release rung is **NOT READY, below `source-clean`**. The
gap is **evidence, not capability**. Never say "ready" unqualified; always name the rung.

---

## Where the boundary sits

Everything up to and including "candidate freeze" is M4. Everything from the RC tag on is M5. A single
fact governs the whole of M5:

> **Any source edit re-mints the package identity and invalidates every platform receipt taken before
> it.** M1's chain qualified a pre-bump identity; M3's bump forfeited it; each M4 fence forfeited it
> again. So M5's evidence must be taken at the **exact tag**, after the last source edit — not
> inherited from a branch-head chain, however green.

## The sequence

| # | Step | Who | Gate |
|---|---|---|---|
| M4-a | Apply approved reader fences; sweep the claim-string class | agent | — (additive-safe only) |
| M4-b | `document()`; `check_pkgdown()`; re-earn the chain at the new SHA | agent | — |
| M4-c | **Page-by-page reader review** — every pkgdown page + function doc | **Shinichi** | his hours |
| M4-d | Apply review outcomes; final `document()` + chain | agent | — |
| M4-e | **🛑 CANDIDATE FREEZE** — no further source edits after this point | **Shinichi** | freeze |
| M5-a | Cut **RC tag** (e.g. `v0.6.0-rc.1`) at the frozen SHA | agent, on **🛑 approval** | RC tag |
| M5-b | Exact-**tag** 3-OS `R CMD check --as-cran` + heavy + CRAN-config **at the tag** | agent | — |
| M5-c | NOT-READY-default review (Rose/Shannon/Ada lens); name the rung | agent | — |
| M5-d | **🛑 FINAL tag** `v0.6.0` — only if M5-b is clean and M5-c holds | **Shinichi** | final tag |
| M5-e | Exact-tag platform + pkgdown evidence at the final tag | agent | — |
| M5-f | Build the submission tarball; `cran-comments.md` reconciled | agent | — |
| M5-g | **🛑 CRAN submission** — Shinichi's act alone | **Shinichi** | submission |

## Traps, each already paid for

- **`cran-comments.md` is stale and `.Rbuildignore`d.** It still reads `0.5.0` and claims `0/0/0` from
  a run that skipped tests; no `R CMD check` will catch it because it does not ship. **M5-f must
  rewrite it** to `0.6.0` with the real CRAN-config result (0/0/1, `New submission`).
- **A failed RC is retained, not hidden.** If M5-b fails, return to the responsible earlier arc; do
  **not** patch inside M5.
- **win-builder R-devel + macbuilder** belong at M5 — CRAN checks first submissions on r-devel while
  the 3-OS matrix pins `release`. Budget them before M5-g.
- **CI concurrency:** the group is `workflow + ref`. Different-ref runs coexist; only same-workflow +
  same-ref cancels. A tag push (`refs/tags/v*`) is its own ref, so it will not cancel a branch run.
- **Do not delete the M1 evidence branch.** Receipts under `~/gllvmTMB-0.6-evidence/` reference it by
  name; the register, checkpoints and handovers anchor on it.

## What M5 does NOT include

No EVA (cut to 0.7). No new capability. No Julia parity, methods paper, or the full coverage campaign —
those are the 1.0 maturity milestone, not this release. M5 ships the experimental 0.6.0 with the
honesty fencing intact and the rung named.

> Related: `LOOP/ultra-plan.md` §M5 · `docs/dev-log/2026-07-22-m3-api-freeze.md` ·
> `docs/dev-log/2026-07-22-m4-overclaim-audit-dossier.md` · `protocols/cran-release-gate.md`
