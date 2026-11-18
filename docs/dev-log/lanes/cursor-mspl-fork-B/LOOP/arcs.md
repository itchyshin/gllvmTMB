# Arcs — g0_unlock fork B (IDs match `LOOP/ultra-plan.md`)

Status: `todo` / `doing` / `done` / `blocked`. **Gate** = a human must act before it proceeds.
These IDs are the ultra-plan slices. A prior draft numbered L0-verify as A1 — that mapping is
**retired**.

This kit is the **conductor**. Campaign A0–A5 is **done**. Do not edit `R/` or `tests/`
from this kit. Do **not** start L2.

| # | Arc | Status | Owner | Gate? |
|---|-----|--------|-------|-------|
| A0 | Write this kit under `docs/dev-log/lanes/cursor-mspl-fork-B/` | **done** | [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) MERGED | — |
| A1 | Decision: G4c → **fork B** recorded | **done** | [#1129](https://github.com/itchyshin/gllvmTMB/pull/1129) MERGED | — |
| A2 | D-159 cites + PARK→REPLACE docs sync | **done** | same decision PR | — |
| A3 | PR hygiene | **done** | #1100 CLOSED; #1124 MERGED | — |
| A4 | **L0** — internal \(Q_0\) profile walk at fixed MSPL nuisance; `calibrated=FALSE`; public `confint`/`vcov`/`se=TRUE` still refuse | **done** | [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4` ( [#1126](https://github.com/itchyshin/gllvmTMB/pull/1126) CLOSED, superseded) | held: no public door |
| A5 | **L1** — local ADEMP smoke (grid freeze → smoke-first → score \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) + Wilson + MCSE) | **done** | [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) `715326af` — cov_eff 0.880 Wilson [0.762, 0.944] **PASS** (not calibrated / not public) | held: no Totoro |
| A6 | Docs kit + Rose fence (root `LOOP/` untouched; MSPL-04 `blocked`; #1077 draft) | **done** | [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) MERGED | — |
| Rec | Melissa plan-vs-actual + this checkpoint | **done** | `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md` | — |
| — | **L2** and every Totoro/DRAC / T\* / undraft #1077 / public se / MSPL-04→covered | **blocked** | Shinichi G0 | **OPEN GATE — never auto-start** |

**A4 landed as:** `objective = c("penalised", "unpenalized")` on
`.gllvmTMB_mspl_profile_feasibility()`, default penalised; `tape = "Q_P"` / `"Q_0"`
kept as synonym. Public inference still hits `.gllvmTMB_mspl_assert_inference`.

**A5 landed as:** one local anchor cell `L1-anchor-n80-T8`, \(n_{\mathrm{rep}}=50\),
seed_base `20260818`, E1 only. availability 1 / refusal 0 / cov_eff 0.880 /
Wilson [0.7620, 0.9438]. Near-tail + multi-seed = L2, not missing L1 work.
E2 remains NOT-EVALUABLE on the current probe (`b_fix` only).

**D-43 completion panel:** not fired. L1 PASS is a local ADEMP gate, not a
public-claim milestone.

**Reconcile:** `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md`.
