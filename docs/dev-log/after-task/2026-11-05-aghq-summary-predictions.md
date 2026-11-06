# After Task: AGHQ fitted summaries

**Branch:** `codex/fixed-effect-normal-priors`
**Date:** 2026-11-05
**Status:** Local candidate. The exact package check failed on seven existing assertions; this change is not merged.

## 1. Goal

Use the AGHQ conditional predictor in the Poisson link-residual variance and binomial saturation screen, without changing the work in the other lanes that touch the same source files.

## 2. Implemented

The link-residual calculation recovers the conditional predictor only when a homogeneous trait has a family whose variance formula needs it. Constant-variance families and traits with mixed families do not need modes. The saturation screen uses conditional fitted probabilities. If an older AGHQ object lacks modes, the saturation result is labelled `INFO` and its diagnostic hint says it was not evaluated; independent loading warnings remain visible.

## Mathematical Contract

The conditional predictor is `eta_it = eta_base_it + sum_k lambda_tk zhat_ik`, using the fitted AGHQ mode `zhat`. The Poisson link-residual approximation remains `log(1 + 1 / mean(exp(eta_it)))`, evaluated per trait. The saturation screen uses the family link inverse applied to the same conditional predictor. Neither change modifies the likelihood or establishes AGHQ interval coverage.

## 3a. Decisions and Rejected Alternatives

Reconstruct modes lazily inside the family branches that need them. Reconstructing for every AGHQ fit made constant binomial and intentionally rejected mixed-family summaries fail unnecessarily when modes were missing. A diagnostic must not silently use fixed-only probabilities or report saturation as checked when the modes are unavailable.

## 4. Files Touched

`R/diagnose.R`, `R/extract-sigma.R`, `tests/testthat/test-aghq-summary-predictions.R`, and this report. No formula, public function signature, generated help file or examples changed. The maintainer explicitly approved narrow edits in the isolated worktree despite the other lanes' overlapping files; their branches were not changed.

## 5. Checks Run

The focused summary test passed 19 assertions, including real converged Poisson and probit fits, legacy objects without modes, mixed families and preservation of independent warnings. Before the fixes, the same Poisson and saturation assertions failed; the Poisson example differed by up to 0.06553959 and the saturation share by 0.133 on its test threshold.

The affected AGHQ conditional-prediction, summary, diagnostic, categorical, link-residual and runaway-warning tests passed together. An independent read-only review checked all eight eta-dependent variance branches and the legacy diagnostic path. The after-task structure passed, but the validator exited 1 on the unrelated `ijsdm-response-information-forensics`, `ijsdm-response-information`, and `temporal-ar1` acceptance ledgers.

The `R/extract-sigma.R` changes from PR #1715 head `bba57bb392737728dab837d6a9d19eb063ea6b93` and PR #1692 head `60a89322e23977adb984d9663fcd6fefc20fafd8` applied sequentially to a disposable copy containing this patch. In that copy, the AGHQ summary tests and the affected message, multinomial-phylogeny and coevolution tests passed; six heavy recovery tests were skipped. This does not establish the pull requests' full CI status. Neither branch was modified.

A clean archive was built from the committed feature branch plus these exact changes, SHA-256 `09aed9069d8a8ab290866f4bc184d3c5d2701160f8779bf1333ea1833c0abd25`. `R CMD check --no-manual --ignore-vignettes` with `NOT_CRAN=true` completed in 1,633 seconds: 29,714 passes, 7 failures, 64 warnings, 1,279 skips, 1 ERROR and 2 NOTEs. The same seven assertions failed in the preceding candidate check; no new failure was observed. The four non-visual failures also reproduced in focused tests on exact main `58c46f8ec01e7e3070d9eea6817c89153d7dbf8a`: restart selection, profile retention and two variational-approximation assertions. The three visual snapshot tests explicitly skip on CI. In a separate disposable copy, PR #1734 head `8206174a85b58ac7c38235e23e104424af87e828` and these changes passed the restart-selection and profile-retention test files. The two variational-approximation assertions remain outside this comparison.

## 6. Tests of the Tests

The real-fit Poisson and saturation assertions were demonstrated failing before the repair and passing afterward. The tests also check that a constant probit variance remains available without modes, that mixed-family traits retain their warnings and `NA` result, and that a homogeneous Poisson trait without modes errors instead of using incomplete fitted values. Diagnostic tests verify that an unavailable saturation screen is visible in the table and printed hints, and that a separate loading warning is preserved.

## 7. Roadmap Tick

N/A. No roadmap row changed.

## 7a. Issue Ledger

No issue or pull request was changed. PRs #1715 and #1692 overlap `R/extract-sigma.R`; their branches were not edited. PR #1727 contains separate AGHQ extractor work and remains a dependency for complete ordination support.

## 8. Consistency Audit

`rg -n '\\$report\\$eta' R`: identified the two summary reads and the earlier prediction, simulation, residual and missing-response reads. This slice changes the two summaries only. Other raw predictor consumers remain subject to their own model-route restrictions and were not broadly certified here.

`rg -n 'fid ==|fid %in%|eta\\[' R/extract-sigma.R`: reviewed the eight family branches that actually use eta. Reconstruction occurs only inside those branches after mixed-family handling.

## 9. What Did Not Go Smoothly

An initial implementation requested modes for every AGHQ family. A legacy binomial test and independent review showed that this needlessly refused constant-variance families. The implementation now delays reconstruction until a family formula needs it. A second review found the unavailable-saturation `INFO` row was missing from printed diagnostic hints; a regression test now covers that output.

## 10. Known Residuals

The package-wide check is not green; cross-platform CI and integration with the separately owned extractor work remain outstanding. The seven failures in the previous package check have not been repaired in this slice. AGHQ interval coverage remains unvalidated. The local candidate is not a release or merge.

## 11. Team Learning

The independent reviewer identified the legacy-object, mixed-family and printed-diagnostic cases, and checked that all eight eta-dependent family formulas use the reconstructed predictor. This review was read-only; the focused tests were run separately.

## 12. Cross-Product Coverage

The fitted examples cover Poisson and probit AGHQ, with fixed-effect priors in the probit example. Tests cover constant and mixed-family handling and unavailable modes. This work does NOT cover recovery across all response families, AGHQ uncertainty calibration, cross-platform convergence or full ordination extraction.
