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

Identical to S0a `lanes/va-s0a-gaussian/protocol/absolute-first.md`:

1. Completeness of planned seed×estimator rows.
2. VA reliability Wilson upper ≤ 0.10.
3. Absolute recovery PRIMARY: abs-availability ≥ 0.90 and mean β RMSE ≤ 0.35
   and mean Σ rel Frob ≤ 0.50 → `SCIENTIFIC_PASS` (else FAIL / INCONCLUSIVE).
4. Paired Laplace ratios SECONDARY / non-blocking.
5. Do not set `calibrated=TRUE`.
6. Reprint frozen Arc-2 `overall_point_route_verdict` per cell×q unchanged.

## Explicit non-goals

- Soft-PASS of Arc-2 labels
- Fence / threshold / `calibrated` package edits
- Pooling ranks or families
- Reusing Arc-2 or S0a seed rows as primary verdict
- Opening S1 without Shinichi G0c
