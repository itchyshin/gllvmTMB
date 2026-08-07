# S0b absolute-first scientific protocol (exact routes)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s0b-exact`  
**Frozen Arc-2 authority:** Design 110 Arc-2 overall labels remain authoritative;
this protocol adds a **secondary** scientific ledger only.

## Cell geometry

| Item | Value |
| --- | --- |
| cells | `poisson_log`, `lognormal_log`, `gamma_log` (exact VA routes) |
| n, p | 120, 8 |
| q | {2, 5} |
| H | 7 (plan marker; exact cells ignore H) |
| estimators | `va`, `laplace` |
| VA match flag | `match_laplace_residual_sd` on lognormal (and gaussian) VA rows per driver |
| seeds | **10301:10600** (n=300; disjoint from Arc-2 1:500 and S0a 10001:10300) |
| platform | Totoro (D-50) |
| planned rows | 3 × 300 × 2 × 2 = **3600** |

## Scoring rules (predeclared)

Identical to S0a `lanes/va-s0a-gaussian/protocol/absolute-first.md`, plus the
**dual-report** extension below (Shinichi G0 2026-08-07):

1. Completeness of planned seed×estimator rows.
2. VA reliability Wilson upper ≤ 0.10 (**frozen** Design 110 / Arc-2 rule;
   S0b also counts `healthy=FALSE` / `status=="unhealthy"` as reliability fails).
3. Absolute recovery PRIMARY: abs-availability ≥ 0.90 and mean β RMSE ≤ 0.35
   and mean Σ rel Frob ≤ 0.50 → `SCIENTIFIC_PASS` (else FAIL / INCONCLUSIVE).
   Reliability FAIL/INCONCLUSIVE still blocks `scientific_verdict_default` PASS
   (**ledger column A**).
4. Paired Laplace ratios SECONDARY / non-blocking.
5. **gllvm comparator (STANDING):** report gllvm VA (and gllvm Laplace if
   available) vs planted truth where feasible — see `gllvm-comparator.md`.
6. Do not set `calibrated=TRUE`.
7. Reprint frozen Arc-2 `overall_point_route_verdict` per cell×q unchanged.

### Dual report (A) + (B) — G0 2026-08-07

| Lane | What | Drives |
| --- | --- | --- |
| **(A) Frozen reliability** | Wilson / healthy as above | `scientific_verdict_default` (unchanged conjunction) |
| **(B) Abs-on-completed-even-if-unhealthy** | Among finished fits with finite β/Σ — in the S0b export that is `status %in% c("completed","unhealthy")` — mean β RMSE, mean Σ rel Frob, availability among planned seeds, same caps 0.35 / 0.50 and avail floor 0.90; **no** `healthy=TRUE` and **no** reliability PASS required | Secondary label `ABS_ON_COMPLETED_{PASS,FAIL,INCONCLUSIVE}` |

**(B) does not soft-PASS Arc-2, amend Design 110 thresholds, or move the public fence.**
It answers “is recovery hopeless once we ignore the healthy gate?” (motivating
case: gamma VA reliability FAIL with abs-on-completed PASS; gamma LA 0/300
healthy under (A) but may still show finite abs recovery under (B)).

S0a Gaussian is already healthy under (A); dual columns are optional there.

## Explicit non-goals

- Soft-PASS of Arc-2 labels
- Fence / threshold / `calibrated` package edits
- Pooling ranks or families
- Reusing Arc-2 or S0a seed rows as primary verdict
- Opening S1 without Shinichi G0c
- Stopping at gllvmTMB-only tables when a matched gllvm compare is feasible
- Treating (B) `ABS_ON_COMPLETED_PASS` as Design 110 / Arc-2 PASS

## Local compute (Shinichi 2026-08-07)

Local diagnosis / gllvm-compare probes: **≤10 cores** (`CORES` / `mc.cores` / `xargs -P`). Prefer sequential probes; do not stack parallel campaigns on this machine.
