# S0b exact-route absolute-first scientific ledger

Generated: 2026-08-07 12:21:23 UTC
Export: `/private/tmp/va-s0b-exact-evidence-20260807/final-export-s0b.csv`
Cells: poisson_log, lognormal_log, gamma_log
Arc-2 frozen CSV: `/private/tmp/va-gh-h7-final-evidence/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv`

## Caps
- Default: β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50
- Abs-availability floor: 0.90
- Alternate: not proposed

## Verdicts

cell | q | scientific | β RMSE | Σ rel Frob | abs avail | reliability | LA done | frozen Arc-2
--- | --- | --- | --- | --- | --- | --- | --- | ---
poisson_log | 2 | SCIENTIFIC_FAIL | 0.1106 | 0.6259 | 1.000 | PASS | 275/300 | FAIL
poisson_log | 5 | SCIENTIFIC_PASS | 0.1216 | 0.4820 | 1.000 | PASS | 278/300 | PASS
lognormal_log | 2 | SCIENTIFIC_PASS | 0.0700 | 0.3723 | 1.000 | PASS | 155/300 | INCONCLUSIVE
lognormal_log | 5 | SCIENTIFIC_PASS | 0.0828 | 0.3475 | 1.000 | PASS | 179/300 | INCONCLUSIVE
gamma_log | 2 | SCIENTIFIC_FAIL | 0.0796 | 0.4227 | 1.000 | FAIL | 0/300 | FAIL
gamma_log | 5 | SCIENTIFIC_FAIL | 0.1253 | 0.4589 | 1.000 | FAIL | 0/300 | FAIL

## Frozen Arc-2 labels
Each cell×q reprints Arc-2 `overall_point_route_verdict` unchanged.
This ledger does **not** soft-PASS or mutate those labels.

## Secondary Laplace diagnostics
Paired ratios are non-blocking for SCIENTIFIC_PASS. See CSV `ratio_secondary`.
