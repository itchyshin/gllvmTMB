# Issue 1467 resolved trait-column follow-up

## 1. Goal

Make the actual long-format response-column name work inside ordinary predictor-informed latent terms. Finish the previously separate trait-name item in PR 1468, then prepare a reply for maintainer review without posting it.

## 2. Implemented

The resolved response-column selector now reaches the shared LHS classifiers, canonical rewrites, covariance parser, main fit entry point and screening path. This reconciles the previously unpushed local trait-selector lane with the output repair branch. The original column expression is preserved. The placeholder trait spelling remains accepted. The CSV example and runnable refit script now use the actual column name.

## 3a. Decisions and Rejected Alternatives

Do not globally substitute symbols or admit arbitrary predictor columns as loading bases. Carry the declared response-column factor through the existing formula classifiers. Prefer consistent actual-column spellings in fixed and random terms. Renaming the data column to trait gives the corresponding trait/trait workflow. Keep augmented predictor-informed random regressions rejected. Ridge remains explicit, with scale 2 suggested rather than imposed on every model.

## 4. Files Touched

R/brms-sugar.R, R/parse-multi-formula.R, R/gllvmTMB.R and R/screen-gllvmTMB.R; tests/testthat/test-lv-trait-column.R; README.md; docs/design/01-formula-grammar.md; vignettes/articles/explaining-latent-ecological-axes.Rmd; dev/issue-1467/refit.R and COMPLETION-PLAN.md; docs/dev-log/check-log.md; this report and its assessment.

## 5. Checks Run

The reported alternate spelling failed end to end before the correction. Synthetic paired fits test one LV, two LVs and ridge two LVs with an explicit binomial probit family. Dataset-specific refitting and comparisons are retained in a private verification record. Synthetic paired comparisons exercise the fitted parameters and effect tables without publishing supplied-data outcomes. The new trait-column test and neighbouring parser checks passed 93 expectations with zero failures and one inherited implicit-unit deprecation warning. The output/curvature/plot/factor regression files passed 189 expectations; the actionable-error checks passed 7 with NOT_CRAN=true. Package documentation checks and article rendering passed. Final remote checks will be linked in PR 1468 after the push.

## 6. Tests of the Tests

The new setup regression failed on the original unsupported-LHS classification, recorded before the repair. Paired fits compare parameters, objective, log likelihood, induced effects and LV design matrices. Custom column, common diagonal, loadings-only and unsupported augmented cases exercise both acceptance and rejection.

## 7a. Issue Ledger

This follow-up covers the remaining real-column spelling item in issue 1467. The earlier summary, factor-contrast, one-axis plotting and prior-curvature repairs remain in PR 1468. Syntax equivalence does not establish model health; existing diagnostic warnings remain active.

## 8. Consistency Audit

The root cause was downstream classification after successful formula parsing. The shared parser now uses the same resolved selector as formula validation and fitting. The screening path shares it. The README, worked article, runnable script and formula contract use consistent spellings. Independent review found no blocking issue in the reconciled four-file source patch; neighbouring parser/model checks passed.

## 9. What Did Not Go Smoothly

An earlier completion statement covered output repairs too broadly and failed to verify the separate trait-name lane. A paired real fit exposed that gap. The initial synthetic regression used the Gaussian default; it was corrected to the reported binomial probit family before completion.

## 10. Known Residuals

This report precedes final remote checks; PR 1468 will hold their exact-head receipt. Merge and release are outside this step. Loading-prior SDs remain approximate conditional posterior uncertainty; syntax acceptance does not certify an arbitrary fitted model. No interval-coverage or scientific rank-selection claim is made. The report structure validator passes; the repository-wide completion checker remains blocked by inherited unrelated ijsdm-response-information and temporal-ar1 ledgers. Those lanes are left untouched.

## 11. Team Learning

Formula acceptance is not proof of a fitting route. Verify renamed-column equivalence at the covariance classification and fitted-output levels. Memory receipt: the routed LOAD-FIRST manifest was read; its model-object and source-grounding lessons shaped the paired checks. Golden Set: not rerun; executable reported-failure tests provide the regression evidence. No new hub guard or memory update was added.

## 12. Cross-Product Coverage

This correction covers selector propagation in the shared parser and screen route, with end-to-end checks for the ordinary native predictor-informed long-format latent block, consistent actual-column spellings, the historical placeholder and the automatic diagonal companion. It does NOT cover new source-specific predictor-informed routes, augmented LV random regressions, scientific rank choice, uncertainty calibration, Julia parity, merge or release. The alias changes neither the likelihood nor the loading prior.
