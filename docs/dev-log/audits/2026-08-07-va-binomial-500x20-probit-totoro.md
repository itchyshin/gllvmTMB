# Audit — Totoro probit 500×20 smoke launch (2026-08-07)

## Ask

Run binomial **probit** n=500 p=20 q=2 H=7 smoke on Totoro in parallel with the local job at `/private/tmp/va-s1-binomial-500x20-probit-smoke-20260807/` (do not stop local; do not flip fence).

## Launched

| Item | Value |
|------|--------|
| Started | **Y** |
| Host | `totoro` |
| Remote root | `/home/snakagaw/gllvm_work/va-s1-binomial-500x20-probit-smoke-20260807` |
| Checkout | `…/va-gh-h7-totoro-confirmation-022b4eab-20260806/checkout` |
| PID (at launch) | `2753035` |
| Log | `…/logs/full.log` |
| Results | `…/results/` (D-50 raw off-git) |
| Local pointer | `/private/tmp/va-s1-binomial-500x20-probit-totoro-20260807/` |

## Spec

- Family/link: binomial probit, trials=1, `unique=FALSE`, VA H=7
- Size: n=500, p=20, q=2
- Arms: `gtmb_va_gh`, `gtmb_va_ac`, `gtmb_la`, `gllvm_va`
- Seeds: 12 (`11001`..`11012`), `PILOT_CORES=12`
- Warm: one `.va_r3_load_dll()` pre-warm on Totoro + again inside probe master before `mclapply` fork

## Scripts (repo)

- `lanes/va-s1-binomials/scripts/probe-binomial-500x20-probit-smoke.R`
- `lanes/va-s1-binomials/scripts/launch-totoro-s1-500x20-probit.sh`

## Completed (Totoro summary landed)

| arm | n_seed | β RMSE | Σ rf | pass_abs | secs |
| --- | ---: | ---: | ---: | ---: | ---: |
| **gtmb_va_gh** | 12 | 0.065 | **0.468** | **0.67 (8/12)** | 140 |
| gtmb_va_ac | 12 | 0.062 | 0.770 | 0 | 36 |
| gtmb_la | 12 | 0.065 | 0.444 | 0.75 | 1.3 |
| gllvm_va | 12 | 0.062 | 0.783 | 0 | 1.8 |

Scientific H2H vs cloglog: `docs/dev-log/audits/2026-08-07-va-binomial-500x20-cloglog-vs-probit.md`.

## Not done here

- No fence change
- Raw CSV not committed (D-50)
