# After Task: AGHQ conditional predictions

**Branch:** `codex/fixed-effect-normal-priors`
**Date:** 2026-11-05
**Status:** Local candidate. The package check failed on seven previously observed assertions; no merge has occurred.

## 1. Goal

Correct AGHQ conditional point predictions and diagnostic residuals while preserving fixed-effects-only predictions. Refuse missing-response uncertainty routes that have not been validated for AGHQ.

## 2. Implemented

Prediction and conditional simulation reconstruct the latent contribution using the final modes retained in the quadrature tape. Exact randomized-quantile residuals and ordinal missing-response reconstruction use the same conditional predictor. Missing or malformed modes trigger a classed error. All five `predict_missing(se = TRUE)` routes refuse AGHQ fits.

## Mathematical Contract

For unit i and trait t, the conditional linear predictor is `eta_it = eta_base_it + sum_k lambda_tk zhat_ik`, where `zhat` is the conditional mode at the fitted AGHQ parameters. The reconstruction changes reported conditional predictions, not the quadrature likelihood or posterior uncertainty. It does not claim a posterior mean or calibrated interval.

## 3a. Decisions and Rejected Alternatives

Use the final mode already stored in the fitted TMB object's quadrature data. A newer explicit `aghq$z_B_mode` slot is accepted as a fallback. Return an error if neither slot provides finite modes of the expected dimensions. Do not substitute fixed effects for missing conditional modes. Keep all missing-response uncertainty routes unavailable until separately validated.

## 4. Files Touched

`R/aghq-report.R`, `R/methods-gllvmTMB.R`, `R/predictive-diagnostics.R`, `tests/testthat/test-aghq-conditional-prediction.R`, `man/predict.gllvmTMB_multi.Rd`, `man/predict_missing.Rd`, `man/simulate.gllvmTMB_multi.Rd`, and this report. No example syntax, exported function, family, formula, or likelihood changed.

## 5. Checks Run

- Focused tests: 29 assertions passed in `test-aghq-conditional-prediction.R` before the final wording-only change. The test covers actual converged rank-one, rank-two, and ordinal missing-response fits, along with a deterministic rank-two indexing case.
- Neighbour tests: `test-aghq-report-estimator-level-helpers.R`, `test-predict-newdata-alignment.R`, `test-predict-wide-newdata-error.R`, `test-predict-simulate-refusal-classes.R`, `test-predictive-diagnostics.R`, `test-predictive-residual-limits.R`, `test-simulate-families.R`, and `test-fixed-effect-priors.R` passed. After adding the uncertainty guard, `test-predict-missing-se.R`, `test-predict-missing-categorical.R`, `test-predictive-diagnostics.R`, and `test-fixed-effect-priors.R` passed.
- A disposable combination with PR #1727 head `335b116f46302ee99e5a49e6871284bf6c05be0f` and PR #1734 head `8206174a85b58ac7c38235e23e104424af87e828` passed 17 focused assertions before the later ordinal and uncertainty additions. Neither PR was changed.
- `pkgdown::check_pkgdown()` passed after the final wording additions; the final help files were regenerated with `roxygen2::roxygenise(..., roclets = "rd")` in a disposable source copy. `git diff --check` passed. The after-task structure check passed, but its broader validator reported three unrelated unmet ledgers (`ijsdm-response-information-forensics`, `ijsdm-response-information`, and `temporal-ar1`).
- Clean archive SHA-256 `54751b6fb8dad6cdbaca6811c228bedccf91f00ef90608941fc327f6e62fc327`; private empirical paths were absent. Exact `R CMD check --no-manual --ignore-vignettes` with `NOT_CRAN=true` finished in 1,507 seconds: 29,695 passes, 7 failures, 64 warnings, 1,279 skips, 1 ERROR and 2 NOTEs. The same seven failure locations occurred in the previous clean check. They concern three visual snapshots, restart selection, profile retention and two VA prototype assertions. Prior receipts also reproduced them on earlier base `a40edca4a`; this does not establish a current-main comparison.

## 6. Tests of the Tests

The conditional prediction assertion failed before the repair, with an omitted contribution as large as 0.4979223 on the test fit. The randomized residual and ordinal missing-response assertions each failed before their fixes. The missing-response uncertainty refusal test failed before its guard. Positive tests include saved fits, known reordered and duplicated rows, unseen units, fixed-only predictions, response scale, and conditional simulation.

## 7. Roadmap Tick

N/A. No roadmap status changed.

## 7a. Issue Ledger

No issue or PR was changed. PR #1727 owns related AGHQ extractor and automatic-refit work and has a NEWS conflict; PR #1734 owns the start-count change. PRs #1715 and #1717 also change `R/methods-gllvmTMB.R` and were not modified.

## 8. Consistency Audit

`rg -n -i 'aghq.{0,70}(predict|fitted|simulate|residual)|predict.{0,70}aghq|does not currently include' R vignettes NEWS.md man`: checked the updated prediction and simulation help and found the retained internal legacy warning helper. The helper is no longer called by the repaired methods.

`rg -n '\\$report\\$eta' R`: identified other raw-predictor consumers. AGHQ saturation screening and Poisson link-residual variance remain unresolved in separately owned files. Prediction-uncertainty routes for missing responses now refuse AGHQ; no calibrated-uncertainty claim is made.

## 9. What Did Not Go Smoothly

A first rank-two fixture and a first ordinal fixture did not meet AGHQ convergence criteria. A distinct rank-two fixture and an ordinal fixture with more observed traits converged and passed; the failed fits are retained in the local prototype receipts. The other raw-predictor reads were identified during independent review and confirmed on fitted examples.

## 10. Known Residuals

The current Poisson link-residual variance and saturation screen can still omit AGHQ latent modes. Prototypes and fit results are saved under `dev/fixed-effect-priors/package-finish/aghq-prediction-prototype/`; applying them to their shared files awaits the ownership decision. The seven full-check failures, cross-platform checks, and PR integration remain outstanding. AGHQ interval coverage is not validated.

## 11. Team Learning

The read-only reviewer checked the reconstructed predictor against the TMB likelihood, found the ordinal and uncertainty gaps, and identified the two remaining raw-predictor summaries. The reviewer rechecked the repairs and noted that strict convergence tests still need cross-platform evidence. The exact artifact check failed on the seven listed assertions, so the candidate is not ready to merge.

## 12. Cross-Product Coverage

The checks cover ordinary one- and two-axis AGHQ fits, fixed priors, conditional predictions, original and new rows, conditional simulation, randomized residuals, and an ordinal masked-response example. This work does NOT cover general AGHQ interval coverage, structured covariance sources, all response families, or the two separately owned summary paths. It does not establish cross-platform package-check success.
