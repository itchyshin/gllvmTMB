# Arcs — Design 125 fork B (L0 → L1, stop at L2)

Status: `todo` / `doing` / `done` / `blocked`. **Gate** = a human must act before it proceeds.
Detail for every row lives in `LOOP/ultra-plan.md` §4.

| # | Arc | Status | Gate? |
|---|-----|--------|-------|
| A0 | Reattach lane; read `GOAL → checkpoint → ultra-plan → AGENTS.md`; confirm L0's `R/mspl.R` state **without editing it** | todo | — |
| A1 | **L0 verify** — probe runs both `objective` arms on a toy binomial MSPL fit; fork A byte-identical to prior default; unexported, uncalibrated, binomial-fenced | todo | — |
| A2 | **L0 tests** — both arms + refusal codes R-NAVL / R-Q0 / R-FENCE + default-A identity + family fence *(specs into the receipt if L0 still holds `tests/`)* | todo | — |
| A3 | **L0 GATE** — receipt `docs/dev-log/research/2026-08-18-mspl-fork-B-L0-receipt.md`, PASS/FAIL per pre-reg §P5 | todo | **FAIL ⇒ STOP; docs/scaffold fixes only** |
| A4 | **L1 grid freeze** — pre-reg DGP verbatim: \(n_{\text{site}}\in\{40,80\}\), \(T\in\{4,8\}\), \(q=1\), anchor \(\pi\approx0.5\) + one near-tail cell, \(n_{\mathrm{rep}}\in[50,100]\), **fresh seeds written down** | todo | **widening the grid = NEW G0** |
| A5 | **L1 smoke** — 1 cell × 3 reps first (non-empty, non-NA, in-range; inspect one fit past its guards), then the frozen grid. **LOCAL compute only** | todo | **any Totoro/DRAC ⇒ STOP** |
| A6 | **L1 scoring** — \(\widehat{\mathrm{cov}}_{\mathrm{ret}}\), refusal rate by code, priced \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\), Wilson + MCSE on both, availability P2, usability floor | todo | — |
| A7 | **L1 GATE** — verdict against the frozen rule + Rose fence-honesty sweep (MSPL-04 `blocked`, #1077 draft, no `covered` anywhere) | todo | **FAIL ⇒ do NOT escalate; record and stop** |
| A8 | **Close** — after-task, check-log (commands run **and** deliberately not run), docs PR | todo | **push / merge = HUMAN GATE** |
| A9 | **Reconcile** — Melissa, planned vs actual → `docs/dev-log/plan-actual/2026-08-18-mspl-fork-B.md` | todo | — |
| — | **L2 and every Totoro/DRAC gate** | **blocked** | **OPEN GATE — needs Shinichi G0. Never auto-start.** |

**Batch barrier:** after **A5**. The smoke arc is the heavy one; land the checkpoint, commit, and
recommend a fresh chat before scoring.

**D-43 completion panel:** fires **once**, at A7, and **only if the verdict reads PASS** — two fresh
build-tier reviewers plus one ceiling reviewer, distinct lenses. A FAIL needs no panel; it needs a
receipt.
