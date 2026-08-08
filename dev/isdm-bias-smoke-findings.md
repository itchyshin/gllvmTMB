# Phase C preflight and paired smoke

Date: 2026-08-08

Branch: `claude/experiment-integrated-sdm`

Design: `dev/isdm-phase-c-design.md`

Status: **GO to the pre-registered pilot on Totoro. This is not a campaign result.**

## Provenance

The inherited workflow journal completed Scout, Design, and Build. Smoke, Run,
Analyse, and Verify had not returned when Codex resumed the lane. Build was
committed as `30129160` with the explicit status `UNSMOKED, UNRUN`; the journal
reconciliation is `b06ec2c4`.

While recovery was in progress, the still-live workflow drafted
`dev/isdm-bias-run-reduced.R` and committed it in `0dbc7ec3`. That C-lite script
is **not the plan**: it drops G2--G6 and was never approved as a deviation from
the frozen 21,300-fit design. The inherited workflow subsequently ran an S = 4
C-lite timing slice anyway (192 fits in 7.2 minutes), leaving the untracked
`dev/isdm-bias-pilot-lite.rds`. It then launched an S = 30 reduced run. Codex
terminated the 19 exact R processes before a result file appeared. Neither
C-lite run is analysed, staged, or used in any Phase C decision.

All commands below used `NOT_CRAN=true`, `devtools::load_all()` through the
harness, and `extract_Sigma(..., link_residual = "none")`. Phase A and Phase B
were not rebuilt.

## Paired low/high-bias smoke

The diagnostic smoke used the same RNG seed and design stream at `n = 100`,
`T = 6`, `d_fit = 2`, `rho = 0`, and `omega = 1`, changing only `kappa` from 0
to 2. The frozen NO-GO was `|dD_bias(A1)| < 0.05`; the observed A1 movement was
`+0.8382`.

| arm | `D_bias`, kappa 0 | `D_bias`, kappa 2 | paired high - low |
|---|---:|---:|---:|
| A1 PO only | -0.01921 | 0.81899 | **0.83820** |
| A2 PA only | -0.01884 | -0.01884 | 0.00000 |
| A3 naive pooled | 0.04774 | 0.63736 | 0.58962 |
| A4 integrated, no offset | 0.06463 | 0.71315 | 0.64851 |
| A5 integrated, misspecified bias | 0.00188 | 0.72281 | 0.72092 |
| A6 bias-field oracle | 0.00188 | 0.00127 | -0.00061 |

The PA-only invariance and near-zero oracle movement are useful DGP controls.
This is one seed and licenses the pilot only; it does not license a Phase C
scientific claim.

The smoke was reproduced on Totoro at exact checkout `0dbc7ec3` under R 4.5.3.
The local R 4.6.0 and Totoro results agreed to the displayed precision.

## Frozen preflight gates

P0-1, P0-2, P0-3, and P0-6 passed at the reference geometry (`n = 400`,
`T = 8`, `d_fit = 2`, `k = 3`):

- 6,400 long rows (`n * T * 2`);
- `family_id_vec` mapped cleanly to source (3,200 PA rows under family 1;
  3,200 PO rows under family 2);
- A5 `diag_B_skip = 0`;
- A5 returned an `8 x 8` correlation matrix with no missing values and
  `max |off-diagonal| = 0.7166`;
- `n_trials` mapped cleanly to source (PA = 3, PO = 1);
- all six arms fit without error and A6 had eight `trait:bstar` columns.

P0-4 passed over the pre-registered 10 A5 null seeds:

| quantity | observed | frozen bound |
|---|---:|---:|
| mean `D_rmse` | 0.0516 | < 0.15 |
| mean `D_bias` | -0.0044 | within 3 MCSE of 0 |
| MCSE(`D_bias`) | 0.0043 | 3 MCSE = 0.0128 |
| pooled PA prevalence | 0.3316 | [0.25, 0.50] |

P0-5 measured **21.235 seconds per A5 fit** on the local host. This exceeds the
pre-registered 10-second threshold, so the pilot and campaign route to
**Totoro**, with `OPENBLAS_NUM_THREADS=1` and no more than 150 processes.

## Execution notes

Two operational problems were caught before the pilot:

1. `parallel::detectCores()` returned `NA` in the Codex sandbox. The dispatcher
   now falls back to one core instead of propagating `NA` into `mclapply`.
2. The first serial P0-4 attempt was terminated by the host (`exit 143`) before
   completion. Re-running the identical frozen gate at four explicit local
   processes produced the passing values above. The subsequent `saveRDS()`
   failed because the sandbox cannot create a new binary in this external
   worktree; the completed stdout values are recorded here. The Totoro smoke
   RDS is retained in the isolated remote checkout.

Next action: inspect the 1,500-fit pilot result, report its measured seconds per
fit and `sd(dD_bias)` at REF, then apply the seed-count decision frozen in P1
before launching G1--G6. No reduced C-lite result may substitute for that gate.
