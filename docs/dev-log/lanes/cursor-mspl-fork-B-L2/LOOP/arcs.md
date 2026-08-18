# Arcs — local L2 only (IDs match `LOOP/ultra-plan.md`)

Status: `todo` / `doing` / `done` / `blocked`. **Gate** = a human must act before it proceeds.

Closed g0_unlock A0–A5 (L0 #1130, L1 #1128) are **done on another kit**. Do not
re-run them. Do not edit `R/` or the closed folder.

| # | Arc | Status | Owner | Gate? |
|---|-----|--------|-------|-------|
| R0 | Prior-work sweep (closed kit + ADEMP L2 + official L1 0.880) | **done** | kit sitting | — |
| K0 | Write this NEW kit under `docs/dev-log/lanes/cursor-mspl-fork-B-L2/` | **done** | [#1155](https://github.com/itchyshin/gllvmTMB/pull/1155) | — |
| K1 | Thin L2 runner reusing `dev/mspl-forkB-l1-ademp.R` | **done** | `/goal` | — |
| K2a | Smoke-first 1-rep near-tail `L1-neartail-n40-T4` | **done** | `/goal` | — |
| K2b | Smoke-first 1-rep interior seed `20260819` | **done** | `/goal` | — |
| K3 | Local L2 panel: seeds 20260819/20 × 50 + near-tail 20260821 × 50; inherit 20260818 | **done** | `/goal` | held: no Totoro |
| K4 | Official L2 receipt — dual coverage + refusal pricing + Wilson + MCSE | **done** | `/goal` | held: no calibrated / public brand |
| K5 | After-task + check-log + receipt PR | **done** | `/goal` | merge is a later human/CI gate |
| V1 | Mechanical fence verify (#1077 draft; MSPL-04 blocked; closed kits untouched) | **done** | `/goal` | — |
| Rec | Melissa plan-vs-actual | **done** | `/goal` | — |
| — | Totoro / T\* / undraft #1077 / public se / MSPL-04→covered | **blocked** | Shinichi G0 | **OPEN GATE — never auto-start** |

**Inherited L1 (not an arc here):** #1128 `715326af` — cov_eff 0.880
Wilson [0.7620, 0.9438] PASS on `L1-anchor-n80-T8` / seed `20260818`.

**L2 recorded (this sitting):** Seed B/C cov_eff 0.900 (50/0/45);
near-tail 0.780 (50/0/39); all `Q_0` / fork B; `calibrated: FALSE`.

**D-43 completion panel:** not fired. L2 recorded is a local ADEMP gate, not a
public-claim milestone.
