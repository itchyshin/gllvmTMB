# Paper 2 local pre-run receipt — S = 6

**Authority:** evidence-transition approval, 2026-08-12.
**State:** immutable pre-run receipt; one local fit is authorised below the
30-minute rule.

## Exact run

| Field | Frozen value |
| --- | --- |
| Commit | `c7aa1f2c05c1333f4f9c16f5ceb5839f8bab9968` |
| Cell | S = 6; C = 360; r = 3; b = 1; d = 1; N = 8,640; P = 36; R = 1 |
| Seed | `86122` |
| Runner | `dev/isdm-package-recovery/run-g2n-local-prerun.R` with `--mode=prerun` |
| Output | fresh private `dev/isdm-package-recovery/results/paper2-s6-local-prerun-c7aa1f2c` |
| Model | frozen GBIF Poisson plus three PA cloglog observations, shared ecological state, rank-one `Lambda`, free diagonal `Psi`, GBIF-only bias column |
| Optimisation | three frozen starts; `nlminb`; no AGHQ; no ridge; no retry beyond existing Case-B rule |
| Case-C rule | unique non-boundary `b_fix` or `theta_rr_B` residual is `NO_CANDIDATE`/HOLD |

## Bound inputs (SHA-256)

| Input | SHA-256 |
| --- | --- |
| `g2h-360cell-fixture.R` | `701ba79e88a354c7285ac4786d9464b3b8b31edf8789e5fb71ed1f887bee9969` |
| `run-g2n-local-prerun.R` | `3255abc91a612f52bf28f1ebc10a01e14fb1e3e241b036a7e872f76a275c9f6d` |
| `run-g2i-recovery-prerun.R` | `06681f6ea57e3b906f7abd6008eeefd3e242cb54ce28a6eae33afb4e9767cb32` |
| G2m protocol | `11b62af5817b7e6dac25c8da8f047970c6a149e6d8be0df42d540ee390bb5a9c` |
| G2n decision | `2506daaebff2b2de183ffab9dadd95267e3b271ed9fd03c6bf47dc09cedee7ae` |

## Estimate and stop rule

The retained identical S = 6 run recorded 48.254 seconds fitting plus 393.251
seconds profiles (444.587 seconds wrapper elapsed). No engine or runner file
differs between G2o base and this receipt commit. Estimated wall time is 8–12
minutes; hard stop/report threshold is 20 minutes. This is below the 30-minute
approval threshold. If it reaches 20 minutes, stop and report; do not continue
or substitute a different run.

## Required retained outcome

Keep every raw start and selected start, objective, full gradient and block,
Hessian/SE and boundary state, profiles, maps, metrics, warnings/errors,
package/DLL/TMB/R versions, runner log, file manifest, and final provenance
closure. The result is an all-attempt single-replicate evidence receipt, not a
recovery rate, scale claim, or reader-facing capability claim.

The protected `G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD` are not altered by this run.
