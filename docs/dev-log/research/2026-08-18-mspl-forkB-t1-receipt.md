# T1 Totoro receipt — Design 125 fork B (measurement; T\* NOT-FROZEN)

- **Date:** 2026-08-19 00:02:08 UTC
- **Lane:** `cursor/mspl-fork-B-totoro-20260818`
- **Host:** `totoro.biology.ualberta.ca` (BatchMode SSH)
- **Deploy:** `~/gllvmtmb-mspl-forkB-t1-20260818`
- **Installed SHA:** `7187b7d` (`origin/main` at deploy; `R CMD INSTALL` into `.Rlib-campaign`)
- **Runner:** `dev/mspl-forkB-t1-smoke.R` (rsynced onto that tree; reuses `dev/mspl-forkB-l1-ademp.R`)
- **Workers:** 16 (`OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`). D-143 cap is 150; this job did not use it.
- **Elapsed:** 15.3 s for the 800-rep panel after the compiled DLL (optimistic clock).
- **Estimand:** E1 only (first-trait intercept / first `b_fix`). E2 is out.
- **Tape:** `Q_0` / Design 125 fork **B** on all 800 rows
- **calibrated:** FALSE
- **public_confint:** refused
- **coverage_claim:** none
- **tstar_status:** **NOT-FROZEN**
- **MSPL-04:** still `blocked`
- **#1077:** still draft

Grid declared in
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`.
This receipt records the 800 rows. It does **not** freeze T\*.

## Smoke-first (binding), inspected before the panel

Totoro load at smoke: `2.11 2.07 2.01` on 384 cores. One new cell only.

| Arc | Cell | seed_base | lo | hi | truth | tape | fork | covered | RDS bytes | LOG bytes |
|---|---|---|---:|---:|---:|---|---|---|---:|---:|
| T1 1-rep | `T1-anchor-n40-T8` | 20260830 | −0.250 | 1.462 | 0 | `Q_0` | B | yes | 724 | 698 |

`smoke_ok: TRUE`. Object:
`docs/dev-log/research/2026-08-18-mspl-forkB-t1-k2-T1-anchor-n40-T8-20260830-n1.rds`.
n_rep=1 is not a T1 gate.

## Numbers (honest; not a public claim)

800 rows, 200 unique seeds per cell, no empty cell. L1/L2 seeds
`20260818`–`20260821` were not re-walked.

| Role | Cell | seed_base | n_rep | avail. | refusal | cov_ret | cov_eff | Wilson 95% (eff) | MCSE | n_ret / n_ref / n_cov |
|---|---|---:|---:|---:|---:|---:|---:|---|---:|---|
| hold-out-nT | `T1-anchor-n40-T8` | 20260830 | 200 | 1.000 | 0.000 | 0.940 | 0.940 | [0.8981, 0.9653] | 0.0168 | 200 / 0 / 188 |
| n-expansion | `T1-anchor-n160-T8` | 20260831 | 200 | 1.000 | 0.000 | 0.975 | 0.975 | [0.9428, 0.9893] | 0.0110 | 200 / 0 / 195 |
| prev-x-n | `T1-neartail-n80-T8` | 20260832 | 200 | 0.995 | 0.005 | 0.714 | 0.710 | [0.6436, 0.7685] | 0.0321 | 199 / 1 / 142 |
| far-tail | `T1-fartail-n40-T4` | 20260833 | 200 | 0.930 | 0.070 | 0.624 | 0.580 | [0.5107, 0.6463] | 0.0349 | 186 / 14 / 116 |

Refusal pricing: every refusal is a non-cover in `cov_eff`. Near-tail has
one `R-NAVL`. Far-tail has 14 `R-NAVL` (no `R-SAT` in this draw). Dual
columns differ only on those cells.

**T1 verdict: RECORDED.** `tstar_status: NOT-FROZEN`. No FAIL band applied.

Inherited (do not rewrite): official L1 cov_eff **0.880** (#1128);
official L2 Seed B/C **0.900** / near-tail **0.780** (#1162). The companion
0.935 / 400-row walk is a different harness.

## Candidate rules (unfrozen; do not apply)

Proposal candidates, scored on the object and **not** used as a gate:

| Cell | C-L1 (Wilson upper ≥ 0.80) | C-lo80 (Wilson lower ≥ 0.80) | C-avail ≥ 0.95 | C-ref ≤ 0.10 |
|---|---|---|---|---|
| `T1-anchor-n40-T8` | yes | yes | yes | yes |
| `T1-anchor-n160-T8` | yes | yes | yes | yes |
| `T1-neartail-n80-T8` | no | no | yes | yes |
| `T1-fartail-n40-T4` | no | no | no | yes |

Far-tail is **RECORD-ONLY** in the declared table. Near-tail is tagged
RECORD in that table; the proposal still forbids copying an 0.80 FAIL band
onto it (L2 near-tail 0.780 would have failed the same copy). Neither
anchor “yes” is a T\* freeze.

## What this is not

- Not a T\* freeze and not a calibrated coverage claim.
- Not a licence for public `se` / `vcov` / `confint`.
- Not E2 (loadings) coverage.
- Not `NEWS` `covered`, not MSPL-04 promotion, not undraft of #1077.
- Not a rewrite of official L1 0.880 or official L2 0.900 / 0.780.
- Not the optional confirm `T1-confirm-n80-T8` / seed `20260834`.

Object: `docs/dev-log/research/2026-08-18-mspl-forkB-t1-panel.rds`.
