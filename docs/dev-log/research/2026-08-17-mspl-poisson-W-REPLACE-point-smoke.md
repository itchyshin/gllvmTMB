# Local multi-seed Poisson MSPL point smoke — post \(W_*\) REPLACE

**Date:** 2026-08-17  
**Lane:** `cursor/mspl-poisson-W-REPLACE-impl`  
**Host:** local (not Totoro)  
**Authority:** G0 SIGNED REPLACE (#1102). Hard OUT: no NEWS `covered`, no public `se`.

## Grid

`dev/mspl-poisson-multiseed-point-smoke.R` (outputs retargeted to this note’s TSV):
healthy + sparse × `q ∈ {1,2}` × 8 seeds × {ML, MSPL} = **64 arms**.
`se = FALSE` throughout. Failure-inclusive denominators.

## Headline numbers

| cell | q | MSPL med relF vs G | MSPL closer to G than ML |
|---|---:|---:|---:|
| healthy | 1 | 0.430 | 5/8 |
| healthy | 2 | 0.524 | 4/8 |
| sparse | 1 | 1.219 | 7/8 |
| sparse | 2 | 1.008 | 8/8 |

- MSPL arms: **32/32** `convergence=0` + finite; **0** errors; **0** runaway (`max|Λ|≥15`)
- Registry on MSPL arms: **32 admitted / 0 planned** (REPLACE soft-default: keep experimental `admitted`)
- Grid wall ≈ 2.7 s on this machine (OMP=1)

## Script verdict vs REPLACE reality

The smoke script’s `OPERATIONAL_SMOKE` gate still requires `registry_status == "planned"` on every MSPL arm (pre-admit Phase-4 recipe). Under REPLACE that status is **admitted**, so the script prints `OPERATIONAL_SMOKE: FAIL` even though every operational criterion (seeds≥8, zero errors, all finite, no runaway) holds. Treat the printed FAIL as a **stale planned-status gate**, not as a fit failure.

`ADMIT_EVIDENCE: FAIL` is intentional and unchanged: finite count fits alone do not flip Phase-4 admit-evidence / NEWS `covered`. This note does **not** change the registry or NEWS.

## Companion A4 test

`tests/testthat/test-mspl-poisson-W-REPLACE-recovery.R` — 4 seeds, intercept MAE band — **22 pass / 0 fail** (re-run 2026-08-17 local private install).

## Artefacts

- TSV: `docs/dev-log/research/2026-08-17-mspl-poisson-W-REPLACE-point-smoke.tsv`
- RDS (local scratch only): `/tmp/mspl-poisson-W-REPLACE-point-smoke.rds`
