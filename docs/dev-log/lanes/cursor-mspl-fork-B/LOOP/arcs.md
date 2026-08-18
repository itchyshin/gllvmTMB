# Arcs — g0_unlock fork B (IDs match `LOOP/ultra-plan.md`)

Status: `todo` / `doing` / `done` / `blocked`. **Gate** = a human must act before it proceeds.
These IDs are the ultra-plan slices. A prior draft numbered L0-verify as A1 — that mapping is
**retired**. Launch prompts use the table below.

This kit is the **conductor**. L0/L1 execute in sibling worktrees; do not edit `R/` or
`tests/` from `cursor/mspl-fork-B-goal-kit`.

| # | Arc | Status | Owner | Gate? |
|---|-----|--------|-------|-------|
| A0 | Write this kit under `docs/dev-log/lanes/cursor-mspl-fork-B/` | **done** | this PR [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) | — |
| A1 | Decision: G4c → **fork B** recorded | doing | `cursor/mspl-forkB-decision` | — |
| A2 | D-159 cites + PARK→REPLACE docs sync | doing | same decision lane | — |
| A3 | PR hygiene | **done** | #1100 CLOSED; #1124 MERGED | — |
| A4 | **L0** — internal \(Q_0\) profile walk at fixed MSPL nuisance; `calibrated=FALSE`; public `confint`/`vcov`/`se=TRUE` still refuse | doing | [#1126](https://github.com/itchyshin/gllvmTMB/pull/1126) `cursor/mspl-forkB-l0-20260818` | **FAIL ⇒ STOP**; no public door |
| A5 | **L1** — local ADEMP smoke (grid freeze → 1×3 smoke-first → score \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) + Wilson + MCSE) | doing | `cursor/mspl-forkB-l1-smoke-20260818` | **Totoro/DRAC ⇒ STOP**; widening grid = NEW G0 |
| A6 | This docs PR + Rose fence (root `LOOP/` untouched; MSPL-04 `blocked`; #1077 draft) | doing | [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) | **merge = HUMAN GATE** |
| — | **L2** and every Totoro/DRAC / T\* / undraft #1077 / public se / MSPL-04→covered | **blocked** | Shinichi G0 | **OPEN GATE — never auto-start** |

**A4 sub-checks** (receipt, not extra IDs): both `objective` arms typed success/refuse on a toy
binomial MSPL fit; fork A default byte-identical to prior behaviour; unexported; codes
R-NAVL / R-Q0 / R-FENCE. Write
`docs/dev-log/research/2026-08-18-mspl-fork-B-L0-receipt.md` when L0 lands.

**A5 sub-checks** (receipt, not extra IDs): pre-reg DGP verbatim
\(n_{\text{site}}\in\{40,80\}\), \(T\in\{4,8\}\), \(q=1\), anchor \(\pi\approx 0.5\) + one
near-tail cell, \(n_{\mathrm{rep}}\in[50,100]\), **fresh seeds written down**; first cell
inspected early; priced \(\widehat{\mathrm{cov}}_{\mathrm{eff}}=(1-\widehat r)\,\widehat{\mathrm{cov}}_{\mathrm{ret}}\);
verdict vs frozen L\* (`cov_eff` Wilson not entirely below 0.80; availability ≥0.90;
refusal ≤0.15) — PASS **or** FAIL, stated plainly. FAIL does not escalate.

**Batch barrier:** after **A5** smoke. Land the checkpoint, commit, recommend a fresh chat
before scoring.

**D-43 completion panel:** fires **once**, after A5, and **only if the verdict reads PASS**.
A FAIL needs a receipt, not a panel.

**Reconcile:** Melissa after A5 → `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md`.
