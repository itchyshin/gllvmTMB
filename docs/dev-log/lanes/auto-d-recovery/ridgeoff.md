# Diagnostic arm: binomial with the loading ridge off (2026-09-30)

## Why
Phase A showed `bic_sites` under-selecting heavily on single-trial binomial data (for example 0 of 200 correct at n = 50, p = 8, true d = 2). The guard was not the cause: the d = 2 fit was `ok` in 200 of 200 of those datasets. Every binomial fit in the sweep carries the loading ridge (`binary_ridge = 2`), and the criteria are scored on the unpenalised log-likelihood at the ridge's MAP point (documented at `R/select-lv.R:571-586`), which falls short of the maximum by more at larger d. The question was how much of the deficit that explains.

## What was run
Binomial, all 18 cells, reps 1-50 (the same seeds as the main run, so the comparison is paired), `select_lv(..., binary_ridge = Inf)`, 8 workers on Totoro, `~/autod-recovery/ridgeoff/`. Estimate 20-40 min; it overran and was stopped at 09:45 MDT with 756 of 900 datasets done, per the overrun rule. The 144 missing datasets are all at n = 400, p = 16 (44 at d = 1, 50 at d = 2, 50 at d = 3), the slowest ridge-off cell. Not resumed: the finding below does not depend on them.

## Result (paired, proportion correct; "abort" = no eligible fit, counted as not correct)

| n | p | d | bic_sites ridge on | bic_sites ridge off | aic ridge on | aic ridge off | abort ridge off | k |
|---|---|---|---|---|---|---|---|---|
| 50 | 8 | 1 | 1.00 | 0.34 | 1.00 | 0.34 | 0.66 | 50 |
| 150 | 8 | 1 | 1.00 | 0.84 | 0.98 | 0.84 | 0.14 | 50 |
| 400 | 8 | 1 | 1.00 | 0.90 | 0.90 | 0.90 | 0.08 | 50 |
| 50 | 16 | 1 | 1.00 | 0.62 | 0.90 | 0.62 | 0.38 | 50 |
| 150 | 16 | 1 | 1.00 | 0.94 | 1.00 | 0.94 | 0.06 | 50 |
| 400 | 16 | 1 | 1.00 | 1.00 | 1.00 | 1.00 | 0.00 | 6 |
| 50 | 8 | 2 | 0.00 | 0.00 | 0.24 | 0.00 | 0.64 | 50 |
| 150 | 8 | 2 | 0.16 | 0.02 | 0.62 | 0.26 | 0.28 | 50 |
| 400 | 8 | 2 | 0.42 | 0.30 | 0.76 | 0.70 | 0.08 | 50 |
| 50 | 16 | 2 | 0.18 | 0.04 | 0.66 | 0.12 | 0.36 | 50 |
| 150 | 16 | 2 | 0.48 | 0.28 | 0.94 | 0.46 | 0.18 | 50 |
| 50 | 8 | 3 | 0.00 | 0.00 | 0.02 | 0.00 | 0.72 | 50 |
| 150 | 8 | 3 | 0.00 | 0.00 | 0.08 | 0.00 | 0.42 | 50 |
| 400 | 8 | 3 | 0.00 | 0.04 | 0.18 | 0.12 | 0.18 | 50 |
| 50 | 16 | 3 | 0.00 | 0.00 | 0.26 | 0.00 | 0.38 | 50 |
| 150 | 16 | 3 | 0.28 | 0.02 | 0.90 | 0.12 | 0.20 | 50 |

Guard statuses over all ridge-off fits: ok 1,250, runaway 1,247, warm_start 85, nonmonotone 8. Median seconds per dataset: 3.7 ridge on, 21.4 ridge off.

MCSE at k = 50 is at most 0.071.

## Reading
- The ridge is not what makes binomial selection conservative. Turning it off makes recovery worse in almost every cell, because a third of the fits run away and many datasets end with no eligible fit at all. The ridge is doing its job (a stable, eligible fit) and should stay the default.
- The under-selection is a property of the information in binary data at these sizes with this signal (loadings N(0, 1) on the logit scale): at n = 150, p = 8, true d = 2, the second factor improves the log-likelihood by a median of about 8 units for 7 extra parameters, against a `bic_sites` penalty of about 17.5.
- AIC recovers the true rank far more often than `bic_sites` on binomial data with the ridge on. That is a candidate for a family-specific default, a decision for Shinichi, not for this lane.
- Inference, not tested here: the result depends on signal strength. Stronger loadings would raise every binomial number; this DGP is a moderate-signal case.

## Not covered
- The 144 ridge-off datasets at n = 400, p = 16.
- Ridge scales other than 2 and Inf.
- Multi-trial binomial (the ridge does not apply there).
