# S0b exact-route absolute-first scientific ledger

Generated: 2026-08-07 12:42:15 UTC
Export: `/private/tmp/va-s0b-exact-evidence-20260807/final-export-s0b.csv`
Cells: poisson_log, lognormal_log, gamma_log
Arc-2 frozen CSV: `/private/tmp/va-gh-h7-final-evidence/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv`

## Caps
- Default: β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50
- Abs-availability floor: 0.90
- Alternate: not proposed

## Dual report (Shinichi G0 2026-08-07)

- **(A) Frozen reliability** — Wilson / healthy as before; drives
  `scientific_verdict_default` (reliability FAIL/INCONCLUSIVE blocks PASS).
- **(B) Abs-on-completed-even-if-unhealthy** — among finished fits
  (`status %in% {completed, unhealthy}` with finite β/Σ); same abs caps;
  **no** healthy=TRUE and **no** reliability PASS required.
  Label: `ABS_ON_COMPLETED_{PASS,FAIL,INCONCLUSIVE}`.
- **(B) does not soft-PASS Arc-2, change Design 110 thresholds, or move the fence.**

## Verdicts (A)

cell | q | (A) scientific | β RMSE | Σ rel Frob | abs avail | reliability | LA healthy | frozen Arc-2
--- | --- | --- | --- | --- | --- | --- | --- | ---
poisson_log | 2 | SCIENTIFIC_FAIL | 0.1106 | 0.6259 | 1.000 | PASS | 275/300 | FAIL
poisson_log | 5 | SCIENTIFIC_PASS | 0.1216 | 0.4820 | 1.000 | PASS | 278/300 | PASS
lognormal_log | 2 | SCIENTIFIC_PASS | 0.0700 | 0.3723 | 1.000 | PASS | 155/300 | INCONCLUSIVE
lognormal_log | 5 | SCIENTIFIC_PASS | 0.0828 | 0.3475 | 1.000 | PASS | 179/300 | INCONCLUSIVE
gamma_log | 2 | SCIENTIFIC_FAIL | 0.0796 | 0.4227 | 1.000 | FAIL | 0/300 | FAIL
gamma_log | 5 | SCIENTIFIC_FAIL | 0.1253 | 0.4589 | 1.000 | FAIL | 0/300 | FAIL

## Verdicts (B) abs-on-completed (secondary)

cell | q | (B) abs-on-completed | β RMSE | Σ rel Frob | avail | finished (unhealthy) | LA (B) | LA β | LA Σ
--- | --- | --- | --- | --- | --- | --- | --- | --- | ---
poisson_log | 2 | ABS_ON_COMPLETED_FAIL | 0.1106 | 0.6259 | 1.000 | 300 (0) | ABS_ON_COMPLETED_FAIL | 0.1133 | 0.6573
poisson_log | 5 | ABS_ON_COMPLETED_PASS | 0.1216 | 0.4820 | 1.000 | 300 (2) | ABS_ON_COMPLETED_FAIL | 0.1265 | 0.5012
lognormal_log | 2 | ABS_ON_COMPLETED_PASS | 0.0700 | 0.3723 | 1.000 | 300 (0) | ABS_ON_COMPLETED_PASS | 0.0700 | 0.3723
lognormal_log | 5 | ABS_ON_COMPLETED_PASS | 0.0828 | 0.3475 | 1.000 | 300 (0) | ABS_ON_COMPLETED_PASS | 0.0828 | 0.3475
gamma_log | 2 | ABS_ON_COMPLETED_PASS | 0.0796 | 0.4227 | 1.000 | 300 (51) | ABS_ON_COMPLETED_PASS | 0.0766 | 0.4025
gamma_log | 5 | ABS_ON_COMPLETED_PASS | 0.1253 | 0.4589 | 1.000 | 300 (235) | ABS_ON_COMPLETED_PASS | 0.1030 | 0.4009

## Frozen Arc-2 labels
Each cell×q reprints Arc-2 `overall_point_route_verdict` unchanged.
This ledger does **not** soft-PASS or mutate those labels.
Column (B) is diagnostic only — not a Design 110 / fence rewrite.

## Secondary Laplace diagnostics
Paired ratios are non-blocking for SCIENTIFIC_PASS. See CSV `ratio_secondary`.
LA abs-on-completed columns answer 'is LA hopeless on recovery?' without
changing reliability FAIL (gamma LA: 0/300 healthy under frozen rule).

## gllvm comparator (standing rule 2026-08-07)

This Totoro ledger remains gllvmTMB-only. Matched 4-arm probe delivered
2026-08-07 on confirmation `022b4eab` (8 seeds; poisson+gamma; q=2,5):

- Audit: `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md`
- Totoro: `/home/snakagaw/gllvm_work/va-gllvm-h2h-4arm-022b4eab-20260807/`
- Local: `/private/tmp/va-gllvm-h2h-4arm-20260807/totoro-results/`

Headlines: poisson q=2 fails abs Σ on **all four** arms together; poisson q=5
favours gllvmTMB VA on Σ; **gllvm LA is not hopeless on β/Σ for gamma**
(contrast: this ledger's gamma LA healthy 0/300 under frozen reliability).
Shape/φ is unmatched and often explodes in gllvm at gamma q=5.
Protocol: `lanes/va-s0b-exact/protocol/gllvm-comparator.md`.
