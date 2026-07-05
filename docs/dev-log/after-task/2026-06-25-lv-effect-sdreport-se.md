# After Task: LV Effect sdreport SE Extraction

**Branch**: `codex/lv-effect-sdreport-se-20260625`
**Date**: `2026-06-25`
**Roles (engaged)**: `Ada / Gauss / Noether / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Expose standard errors for the admitted ordinary unit-tier
`latent(..., lv = ~ x)` latent-predictor trait effect when the fitted
object already has a trustworthy TMB `sdreport()` for
`ADREPORT(B_lv_unit)`, without claiming confidence intervals or coverage
calibration.

## 2. Implemented

- Added `.lv_trait_effect_se()` as an internal helper for
  `extract_lv_effects(type = "trait_effect")`.
- `extract_lv_effects()` now copies `Std. Error` from
  `summary(fit$sd_report, "report")` rows named `B_lv_unit` only when
  `fit$sd_report$pdHess` is `TRUE`, the row count matches the trait by
  predictor effect table, and all SEs are finite.
- Added explicit uncertainty statuses for skipped, failed,
  non-positive-definite, missing, mismatched, and non-finite sdreport
  cases.
- Kept the status conservative: successful Wald SE extraction is labelled
  `wald_sdreport_no_ci_validation`, so users see that no CI coverage
  validation has moved.
- Added a focused `se = TRUE` test that checks extractor estimates and
  SEs against TMB's reported `ADREPORT(B_lv_unit)` table.
- Updated NEWS, extractor contract, Design 73, the capability status
  page, validation row `EXT-31`, and the generated help topic so public
  prose no longer says the SE column is always `NA`.

## 2a. Mathematical Contract

For the admitted C1 target, the latent score is
`u_i = X_lv,i alpha + e_i`, with `e_i` the zero-mean latent innovation.
The public trait-scale effect is
`B_lv = Lambda alpha^T`, implemented as TMB `ADREPORT(B_lv_unit)`.

This task does not change the likelihood, family dispatch, formula
grammar, random-effect prior, score decomposition, or estimator. It only
uses the existing TMB delta-method covariance for the derived
`B_lv_unit` report when the Hessian is positive-definite. The result is
a Wald standard error on the fitted link/linear-predictor scale, not a
confidence interval and not coverage-calibrated evidence.

## 3. Files Changed

Implementation:

- `R/extractors.R`

Tests:

- `tests/testthat/test-lv-parser-guard.R`

Documentation and status:

- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `man/extract_lv_effects.Rd`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-25-lv-effect-sdreport-se.md`

No README, vignette, article, `_pkgdown.yml`, or `ROADMAP.md` file was
changed. No public example syntax changed.

## 3a. Decisions and Rejected Alternatives

Decision: use `ADREPORT(B_lv_unit)` rather than recomputing the delta
method in R.

Rationale: the C++ report already owns the derived target
`B_lv = Lambda alpha^T` and TMB's `sdreport()` already computes the
joint covariance. Copying the named report rows keeps the extractor
aligned with the fitted object.

Rejected alternative: always return SEs from `summary(sd_report,
"report")` even when `pdHess` is false.

Rationale: weak or non-positive-definite Hessians are exactly where
uncertainty output is most misleading. The extractor now returns `NA`
SEs with a specific status in those cases.

Rejected alternative: add Wald confidence intervals now.

Rationale: intervals need recovery and coverage evidence, especially for
binary link-scale interpretation. This PR only moves standard-error
display when the underlying sdreport is valid.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open `gllvmTMB` PRs before editing shared docs.
- `git log --all --oneline --since='6 hours ago'`
  -> REVIEWED; only `4a4c468 lv: admit binary standard links (#560)`
  was recent in this clean worktree.
- `air format R/extractors.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; no output.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); testthat::test_file("tests/testthat/test-lv-parser-guard.R")'`
  -> FIRST RUN FAILED with 3 failures because the deterministic algebra
  fixture produced a non-positive-definite sdreport and non-finite
  `B_lv_unit` SEs; after switching the SE test to the stochastic
  Gaussian recovery fixture and adding a two-predictor `lv = ~ x + z`
  matrix-order check, the rerun passed with 199 pass, 0 fail, 0 warn,
  0 skip.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); testthat::test_file("tests/testthat/test-extractors.R")'`
  -> PASS; 17 pass, 0 fail, 0 warn, 0 skip.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'parse("R/extractors.R"); parse("tests/testthat/test-lv-parser-guard.R"); cat("parse ok\n")'`
  -> PASS; parsed cleanly.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); devtools::document(quiet = TRUE)'`
  -> BLOCKED; `devtools` is not installed in the active R 4.6 library
  stack.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); roxygen2::roxygenise(".", roclets = "rd")'`
  -> BLOCKED; `roxygen2` is not installed in the active R 4.6 library
  stack.
- `tail -n 8 man/extract_lv_effects.Rd`
  -> PASS; generated Rd details paragraph matches the edited roxygen
  text.
- `grep -c '^\\keyword' man/extract_lv_effects.Rd`
  -> PASS; printed `0`, confirming no stray generated keyword entries.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); if (!requireNamespace("pkgdown", quietly = TRUE)) stop("pkgdown not available in this R library stack"); pkgdown::check_pkgdown()'`
  -> BLOCKED; `pkgdown` is not installed in the active R 4.6 library
  stack.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-25-lv-effect-sdreport-se.md`
  -> PASS; no output.

## 5. Tests of the Tests

The new SE test failed before the fixture repair when the deterministic
algebra smoke fit had `pdHess = FALSE` and non-finite `B_lv_unit` SEs.
That confirmed the test would catch an extractor that exposes SEs
without a valid sdreport.

The final test fixture is a stochastic Gaussian `lv` fit with `se =
TRUE`; it checks that `fit$sd_report$pdHess` is true, that the
`B_lv_unit` report rows have finite `Std. Error`, and that
`extract_lv_effects()` returns exactly the same estimates and SEs with
status `wald_sdreport_no_ci_validation`. It also fits `lv = ~ x + z`
to check the multi-predictor `B_lv_unit` row count, predictor order,
estimate order, SE order, and status labels.

The existing no-SE smoke test still checks the opposite boundary:
`se = FALSE` returns `NA` standard errors with
`sdreport_skipped_no_lv_se`.

## 6. Consistency Audit

- `rg -n 'std\.error.*NA|standard errors are `?NA|standard errors are NA|point_estimate_only_no_ci_validation|standard errors and interval|ADREPORT uncertainty|no_lv_se|wald_sdreport_no_ci_validation|B_lv_unit' NEWS.md docs/design/06-extractors-contract.md docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md man/extract_lv_effects.Rd R/extractors.R tests/testthat/test-lv-parser-guard.R`
  -> REVIEWED; stale `extract_lv_effects()` "SE is always NA" wording
  was removed. Remaining `no_lv_se` hits are intentional status labels,
  and the unrelated `Xcoef_fixed` NEWS bullet still correctly reports
  `std.error = NA` for fixed coefficients.
- `rg --files tests/testthat | rg 'extract|lv'`
  -> REVIEWED; selected `test-lv-parser-guard.R` for the changed
  feature path and `test-extractors.R` for extractor-neighbour coverage.
- `sed -n '512,532p' R/extractors.R && sed -n '36,46p' man/extract_lv_effects.Rd`
  -> REVIEWED; roxygen and generated Rd details agree.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'lv OR latent predictor OR extract_lv_effects' --json number,title,state,url,updatedAt --limit 20`
  -> REVIEWED; returned broad or unrelated open issues (#337, #332,
  #526, #348), with no dedicated `extract_lv_effects()` SE issue to
  close.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. Validation register row `EXT-31` remains
`partial`; the row now records Wald SE extraction from positive-definite
`ADREPORT(B_lv_unit)` output, while interval and coverage evidence stay
gated.

## 7a. GitHub Issue Ledger

- `Ayumi-495/urbanisation_map#8`
  (<https://github.com/Ayumi-495/urbanisation_map/issues/8>) was
  inspected and commented from the maintainer account before this slice.
  The comment explained that `B_lv` is a compact internal/math label for
  the latent-predictor trait effect, that point estimates are currently
  admitted, and that we will write back once SE/CI support is available.
- No directly relevant open `gllvmTMB` issue was found by the targeted
  issue search above. No issue was closed or created in this PR because
  the remaining work is already captured in validation rows `EXT-31`,
  `LV-01`, `LV-02`, and `LV-05`.

## 8. What Did Not Go Smoothly

The first SE fixture used the deterministic smoke/algebra data. That fit
is useful for checking `B_lv = Lambda alpha^T`, but it produced
`pdHess = FALSE` and `NaN` standard errors. The test failure was kept as
useful evidence, and the SE test was moved to the stochastic Gaussian
fixture that produces positive-definite sdreport output.

The active temporary R library lacks `devtools`, `roxygen2`, and
`pkgdown`. I manually synchronized `man/extract_lv_effects.Rd` with the
roxygen details paragraph and ran the generated-Rd spot checks, but this
does not replace a full `devtools::document()` run on a complete
developer stack.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the slice to one promise: expose existing SEs for the named
`B_lv_unit` derived target when the sdreport is healthy. No interval,
coverage, or broader family claim moved.

Gauss and Noether kept the target aligned with the fitted object:
`B_lv = Lambda alpha^T` is the ADREPORTed derived quantity, so the
extractor should use TMB's named report covariance rather than a
separate R-side delta-method reconstruction.

Curie caught the fixture quality problem through the first failing test.
The deterministic algebra fixture remains valuable, but uncertainty
tests need data with genuine residual variation and a positive-definite
Hessian.

Fisher kept the status language explicit. A finite Wald SE is not a
confidence interval, not a coverage claim, and not CI-08 or CI-10
evidence.

Grace recorded the missing local tooling instead of silently pretending
`devtools::document()` or `pkgdown::check_pkgdown()` ran. CI and a
complete developer stack should provide those broad gates.

Rose checked that NEWS, the extractor contract, Design 73, the status
synthesis, the validation row, roxygen, and generated Rd all tell the
same partial-capability story.

Shannon confirmed the work was in the clean `/private/tmp` worktree, not
the dirty Dropbox checkout, and that no open `gllvmTMB` PR existed
before shared-doc edits.

## 10. Known Limitations And Next Actions

- `EXT-31`, `LV-01`, and `LV-05` remain `partial`.
- Wald SEs are available only for `extract_lv_effects(type =
  "trait_effect")` when `se = TRUE` and the sdreport is
  positive-definite.
- No confidence intervals, profile intervals, bootstrap intervals,
  coverage calibration, CI-08/CI-10 promotion, Bernoulli single-trial
  depth, ordinal/count/Gamma/Beta/mixed-family support, tier/source
  expansion, or Julia bridge parity moved in this task.
- After this PR lands and CI is green, reply again on
  `Ayumi-495/urbanisation_map#8` to say SE support is available in dev
  and invite her to rerun the applied binary example.
