# Arcs — Totoro T1 RECORD only (IDs match `LOOP/ultra-plan.md`)

Status: `todo` / `doing` / `done` / `blocked`. **Gate** = a human must act before it proceeds.

Closed g0_unlock A0–A5 (L0 #1130, L1 #1128) and closed L2 K0–K5 (#1162 /
#1168) are **done on other kits**. Do not re-run them. Do not edit `R/`
or those folders.

| # | Arc | Status | Owner | Gate? |
|---|-----|--------|-------|-------|
| R0 | Prior-work sweep (closed L2 + ADEMP T1 + locked 800-fit grid) | **done** | kit sitting | — |
| K0 | Write this NEW kit under `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/` | **doing** | this sitting (docs PR) | — |
| K1 | Thin T1 runner: four locked cells + `far_tail` on `dev/mspl-forkB-l1-ademp.R` | todo | `/goal` | — |
| K2a | Smoke-first local 1-rep × 4 (`T1-anchor-n40-T8`, `T1-anchor-n160-T8`, `T1-neartail-n80-T8`, `T1-fartail-n40-T4`) | todo | `/goal` | held: inspect object, not exit code |
| K2b | Totoro BatchMode + deploy + 1-rep × 4 | todo | `/goal` | held: Totoro SSH must succeed before 800 |
| K3 | Totoro 800-fit panel: seeds 20260830–33 × 200; 16 cores | todo | `/goal` | held: no T\* freeze; abort if first cell empty |
| K4 | Official T1 receipt — dual coverage + refusal + Wilson + MCSE; candidates unfrozen | todo | `/goal` | held: `tstar_status: NOT-FROZEN` |
| K5 | After-task + check-log + receipt PR | todo | `/goal` | — |
| V1 | Mechanical fence verify (#1077 draft; MSPL-04 blocked; closed kits untouched; T\* not frozen) | todo | `/goal` | — |
| Rec | Melissa plan-vs-actual | todo | `/goal` | — |
| — | T\* freeze / undraft #1077 / public se / MSPL-04→covered / NEWS covered | **blocked** | Shinichi G0 | **OPEN GATE — never auto-start** |

**Inherited L1 (not an arc here):** #1128 — cov_eff 0.880 Wilson
[0.7620, 0.9438] on `L1-anchor-n80-T8` / seed `20260818`.

**Inherited L2 (not an arc here):** #1162 / #1168 — Seed B/C cov_eff
0.900; near-tail 0.780; all `Q_0` / fork B; `calibrated: FALSE`.

**Locked T1 grid (this kit):** 4 cells × 200 = 800; seeds `20260830`–
`20260833`; RECORD only; no T\* freeze.

**D-43 completion panel:** not fired. T1 recorded is a Totoro ADEMP
measurement, not a public-claim milestone.
