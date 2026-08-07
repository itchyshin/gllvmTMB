# S0a absolute-first scientific protocol (Gaussian)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s0a-gaussian`  
**Frozen Arc-2 authority:** Design 110 Arc-2 overall labels remain authoritative;
this protocol adds a **secondary** scientific ledger only.

## Cell geometry

| Item | Value |
| --- | --- |
| cell | `gaussian_identity` (exact VA route) |
| n, p | 120, 8 |
| q | {2, 5} |
| H | 7 (plan marker; exact cells ignore H) |
| estimators | `va`, `laplace` |
| VA match flag | `va_match_laplace_residual_sd = TRUE` on Gaussian VA rows |
| seeds | **10001:10300** (n=300; disjoint from Arc-2 1:500) |
| platform | Totoro (D-50) |

## Scoring rules (predeclared)

For each rank q separately:

1. **Completeness** — every planned seed×estimator row represented in export
   (missing = scheduler/infra failure; retain explicitly).
2. **Reliability (VA)** — among planned VA rows, failure rate Wilson 95% upper
   ≤ 0.10 → PASS; if interval straddles 0.10 → INCONCLUSIVE; if lower > 0.10 → FAIL.
3. **Absolute recovery (PRIMARY)** — among VA rows with finite β RMSE and Σ
   rel-Frobenius:
   - **abs-availability** = finite-metric count / planned VA seeds.
   - If abs-availability < 0.90 → `SCIENTIFIC_INCONCLUSIVE`.
   - Else if mean β RMSE ≤ **0.35** (default) **and** mean Σ rel Frob ≤ **0.50**
     (default) → `SCIENTIFIC_PASS`.
   - Else → `SCIENTIFIC_FAIL`.
4. **Paired Laplace ratios (SECONDARY, non-blocking)** — report when paired
   eligibility ≥ 0.90; otherwise `RATIO_NOT_ELIGIBLE` with LA fail/completion
   rates. Ratio ineligibility alone does **not** force SCIENTIFIC_FAIL.
5. **Calibration** — report Arc-2 labels only; do **not** set `calibrated=TRUE`.
6. **Frozen overall** — every ledger row reprints Arc-2
   `overall_point_route_verdict = INCONCLUSIVE` for Gaussian q=2 and q=5.

### Caps recorded

| Cap set | β RMSE | Σ rel Frob | Role |
| --- | ---: | ---: | --- |
| **default** | 0.35 | 0.50 | Design 110 Arc-2 absolute bounds |
| **alternate** | TBD if proposed | TBD if proposed | Only if default verdict is misleading; must be justified in ledger |

## Explicit non-goals

- Soft-PASS of Arc-2 INCONCLUSIVE
- Fence / threshold / `calibrated` package edits
- Pooling ranks or families
- Reusing Arc-2 confirmation seed rows as primary verdict
- Opening S0b without Shinichi G0b
