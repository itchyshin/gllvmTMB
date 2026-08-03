# After Task: Standardized-Loading Inference Repair

**Branch**: `codex/fix-loading-scale-inference`

**Date**: 2026-08-03
**Roles (engaged)**: Ada, Boole, Noether, Curie, Fisher, Pat, Rose, Grace

## 1. Goal

Close issue #921 by making every standardized-loading route target
`rho[t,k] = Lambda[t,k] / sqrt(Sigma_total[t,t])`, propagate the joint
fixed-parameter covariance, and label the returned scale. Preserve the existing
raw-Wald estimand and prepare, but do not post, a corrected reply to Ayumi.

## 2. Implemented

- Added one report-aware delta helper for raw or standardized loadings. The
  standardized Jacobian includes other axes, fitted Psi terms, and
  parameter-dependent link residuals through the complete fixed-parameter
  covariance.
- Made `loading_ci()` scale-explicit. Raw Wald remains the default;
  `wald_asym` is standardized-only; the current raw-Lambda profile refuses a
  standardized request.
- Added `loading_scale` provenance to loading CI, bootstrap, plotting, flagging,
  and `confint(..., parm = "Lambda")` outputs. Standardized `confint()` rows use
  `rho[...]`; raw rows retain `Lambda[...]`.
- Repaired `varimax_threshold` and `wald_retention` so decisions use
  trait-specific total-variance denominators. The fitted varimax rotation is
  treated as fixed for first-order Wald propagation.
- Deprecated the old scalar `sigma_d2` compatibility argument with a one-shot
  warning; it is ignored because total variance is now model-derived.
- Added deterministic algebra, exact routing-mask, malformed-input,
  pin-provenance, scale-mismatch, plot-label, bootstrap, and confint regression
  tests.

## 2a. Mathematical Contract

For trait `t` and latent axis `k`, the standardized loading is

`rho[t,k] = Lambda[t,k] / sqrt(V[t])`, where
`V[t] = Sigma_total[t,t]`.

Its first-order covariance is

`Cov(vec(rho_hat)) = J_rho Cov(theta_hat) J_rho'`,

where `J_rho` is evaluated numerically against every fixed TMB parameter. This
is not a likelihood, optimizer, TMB template, family, formula-grammar, or
covariance-parameterization change. Raw `Lambda` remains available and remains
the default target for symmetric Wald and profile intervals. Loading intervals
remain confirmatory/rotation-frame quantities; communality remains the
rotation-invariant headline for Ayumi's analysis.

## 4. Files Touched

Implementation:

- `R/loading-uncertainty-helpers.R`
- `R/loading-ci.R`
- `R/loading-ci-bootstrap.R`
- `R/suggest-lambda-constraint.R`
- `R/plot-loadings-confidence-eye.R`
- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-loading-ci.R`
- `tests/testthat/test-loading-ci-bootstrap.R`
- `tests/testthat/test-confint-lambda.R`

Generated help:

- `man/loading_ci.Rd`
- `man/flag_unreliable_loadings.Rd`
- `man/plot_loadings_confidence_eye.Rd`
- `man/suggest_lambda_constraint.Rd`
- `man/suggest_lambda_constraints.Rd`
- `man/confint.gllvmTMB_multi.Rd`

Design, status, and closeout:

- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/75-inference-route-truth-matrix.md`
- `docs/dev-log/known-limitations.md`
- `docs/dev-log/plans/2026-08-03-issue-921-standardized-loading-inference.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-03-standardized-loading-inference.md`
- `NEWS.md`

Public article:

- `vignettes/articles/lambda-constraint-suggest.Rmd`

No README, `_pkgdown.yml`, `ROADMAP.md`, NAMESPACE, TMB, or compiled source
changed. The affected roxygen examples were regenerated and checked; no other
example uses `sigma_d2` outside historical dev-log records. The one public
article that exercises both repaired constraint routes now states their common
standardised estimand, joint-covariance propagation, and remaining inference
boundaries.

## 3a. Decisions and Rejected Alternatives

**Decision**: evaluate the complete report-derived standardized vector at each
fixed-parameter perturbation. **Rationale**: dividing a raw marginal SE by a
point denominator omits denominator uncertainty and cross-axis covariance.
**Rejected**: the old entrywise `lambda / sqrt(lambda^2 + sigma_d2)` transform.
**Confidence**: high; deterministic `d = 1`, `d = 2`, non-diagonal covariance,
and raw-covariance oracles plus independent Noether review support it.

**Decision**: keep profile inference raw-only. **Rationale**: the current
profile fixes a raw Lambda coordinate; it does not profile the derived ratio
`rho`. **Rejected**: silently labelling raw-profile bounds as standardized.
**Confidence**: high.

**Decision**: retain `pinned = TRUE` as provenance on standardized rows without
forcing their derived SE to zero. **Rationale**: a fixed numerator can still
vary as a ratio through its total-variance denominator. **Rejected**: reusing
the raw-pinned collapse rule on derived standardized loadings. **Confidence**:
high, with a public-path deterministic test.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> completed and
  regenerated six Rd topics. It repeated pre-existing unresolved internal-CV
  roxygen links and AIC/BIC S3 export-tag diagnostics; none is in this diff.
- `Rscript --vanilla -e 'devtools::test(filter = "^loading-ci$", stop_on_failure = TRUE)'`
  -> PASS: 48 assertions, 29 deliberate heavy-test skips, 0 failures.
- `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=false Rscript --vanilla -e 'devtools::test(filter = "^loading-ci$", stop_on_failure = TRUE)'`
  -> PASS: 0 failures and four deliberate CRAN-only skips.
- `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=false Rscript --vanilla -e 'devtools::test(filter = "^(confint-lambda|loading-ci-bootstrap)$", stop_on_failure = TRUE)'`
  -> `FAIL 0 | WARN 0 | SKIP 6 | PASS 65`; the skips are deliberate CRAN
  profile/bootstrap gates.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'` ->
  `FAIL 0 | WARN 2 | SKIP 799 | PASS 9030` in 1623.0 seconds. The two warnings
  are known `gllvm` comparator warnings about response rows containing only
  zeros.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors | 0 warnings | 2 notes` in 12m43s. The notes are environmental:
  remote clock verification was unavailable and macOS left `xcrun_db` in the
  temporary directory.
- `git diff --check` -> PASS.
- After the coordinated NEWS addition,
  `Rscript --vanilla -e 'devtools::test(filter = "reader-facing-no-register-codes|loading-ci", reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS with 34 deliberate heavy-test skips and no failures;
  `pkgdown::check_pkgdown()` again found no problems; `git diff --check` again
  passed.
- `R_USER_CACHE_DIR=/private/tmp/gllvmtmb-r-cache Rscript --vanilla -e 'pkgdown::build_article("articles/lambda-constraint-suggest")'`
  -> PASS; the public constraint article rendered successfully with the
  standardised-loading equation and inference boundaries. An initial call with
  the incomplete article key (`"lambda-constraint-suggest"`) stopped before
  rendering and was replaced by the registered pkgdown key above.
- `rg -n "\\b(FG|FAM|MIX|CI|EXT|KER|MIS|RE)-[0-9]{2}\\b|\\b(Stage|Gate) [A-Z0-9]+\\b|\\b(Ada|Boole|Gauss|Noether|Curie|Pat|Darwin|Rose|Grace|Emmy|Fisher|Jason|Shannon)\\b" vignettes/articles/lambda-constraint-suggest.Rmd`
  -> no matches; the public article contains no internal register codes, stage
  labels, or agent-role names.
- Targeted `lintr::lint()` could not run because `lintr` is not installed in
  this R library; package tests/check and `git diff --check` remain the style
  and syntax gates.

## 6. Tests of the Tests

The `d = 2` point fixture fails the old entrywise denominator because the
correct point is `1 / sqrt(3)`, not `1 / sqrt(2)`. The non-diagonal covariance
fixture has a hand-computed variance `0.006675925926`, so it fails a marginal-SE
rescaling. A separate raw fixture verifies that `Cov(vec(Lambda))` remains the
known loading block even when a correlated nuisance parameter is present.

The exact `varimax_threshold` fixture uses a rotated row `(0.4, 2)` with
residual variance one: `rho[1] = 0.4 / sqrt(5.16) < 0.30`, while the old
one-axis cutoff left `0.4` free. The exact `wald_retention` fixture supplies a
known rho/SE matrix and checks the full pin mask. Acceptance and rejection
boundaries cover zero, Fisher-z boundary refusal, non-positive total variance,
invalid thresholds/probabilities, valid and mixed scale-labelled data frames,
and pinned raw versus standardized behavior.

## 8. Consistency Audit

- `rg -n "threshold_lambda|lambda\\^2.*sigma_d2|sigma_d2.*sqrt|sqrt\\([^)]*lambda[^)]*\\^2" R/loading-ci.R R/loading-uncertainty-helpers.R R/suggest-lambda-constraint.R tests/testthat/test-loading-ci.R man/loading_ci.Rd man/suggest_lambda_constraint.Rd docs/design/06-extractors-contract.md docs/design/75-inference-route-truth-matrix.md`
  -> no matches; the obsolete one-axis standardization formula is gone from the
  changed contract surfaces.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\\\\\bf S|meta_known_V|gllvmTMB_wide|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" R/loading-ci.R R/loading-uncertainty-helpers.R R/plot-loadings-confidence-eye.R R/suggest-lambda-constraint.R R/z-confint-gllvmTMB.R man/loading_ci.Rd man/flag_unreliable_loadings.Rd man/plot_loadings_confidence_eye.Rd man/suggest_lambda_constraint.Rd man/suggest_lambda_constraints.Rd man/confint.gllvmTMB_multi.Rd docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/75-inference-route-truth-matrix.md docs/dev-log/known-limitations.md`
  -> no stale notation in the changed API/help surfaces; hits in the broad
  status documents are intentional compatibility/register records for
  `meta_known_V()` and `gllvmTMB_wide()`.
- `rg -n "loading_scale|Sigma_total|joint-delta|Fisher-z|profile.*standardized|sigma_d2" R/loading-ci.R R/loading-ci-bootstrap.R R/loading-uncertainty-helpers.R R/plot-loadings-confidence-eye.R R/suggest-lambda-constraint.R R/z-confint-gllvmTMB.R man/loading_ci.Rd man/flag_unreliable_loadings.Rd man/plot_loadings_confidence_eye.Rd man/suggest_lambda_constraint.Rd man/suggest_lambda_constraints.Rd man/confint.gllvmTMB_multi.Rd docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/75-inference-route-truth-matrix.md docs/dev-log/known-limitations.md`
  -> source, generated help, design contracts, register, and limitations all
  expose the same scale distinction and raw-profile boundary.
- `_pkgdown.yml` already lists every affected exported topic; no navigation
  edit is needed. The repository-wide loading-inference sweep found one public
  article that exercises both repaired constraint routes; it was updated and
  rendered. README and the remaining vignettes contain only scope/navigation or
  point-estimate loading references and did not need inference wording changes.
  Generated Rd tails and keyword placement were spot-checked.

Rose pre-publish verdict: PASS. The final NEWS entry states the estimand,
limitations, and deprecation without internal register codes. No method list,
exported name, argument default, or scope claim
disagrees across source, generated help, design docs, and tests.

## 7. Roadmap Tick

N/A. This repairs an issue-linked inference route without changing a ROADMAP
phase or progress bar.

## 7a. Issue Ledger

- Created and implemented [#921](https://github.com/itchyshin/gllvmTMB/issues/921);
  leave open until the fix PR lands.
- Inspected [#917](https://github.com/itchyshin/gllvmTMB/pull/917), which edits
  `NEWS.md`. Posted two coordination comments. After confirming the exact hunk
  was disjoint, added this fix's bounded NEWS entry without touching #917's
  paragraph; also flagged #917's stale positive-diagonal assertion for its
  owner.
- Inspected [#923](https://github.com/itchyshin/gllvmTMB/pull/923); it touches a
  handover file only and does not overlap this lane.
- Inspected Ayumi's urbanisation-map issue #14 and its linked comment. No reply
  was posted; the maintainer asked to fix gllvmTMB first and reply afterward.

## 9. What Did Not Go Smoothly

The original checkout was 689 commits behind `origin/main` and contained
unrelated user changes, so implementation moved to a clean worktree. The GitHub
connector returned HTTP 403 when posting the #917 coordination note; the
authenticated `gh` fallback succeeded. A first deterministic delta test needed
a realistic finite-difference tolerance. An early direct `testthat::test_file()`
call omitted `devtools::load_all()` and produced package-not-loaded errors; it
was discarded and rerun through `devtools::test()`. The first package-wide run
was intentionally interrupted so reviewer-requested tests would be included in
the authoritative run. `devtools::document()` also surfaced unrelated existing
CV-link and S3-tag diagnostics. During the later documentation sweep, the first
single-article render used an incomplete pkgdown key and stopped before
rendering; the registered `articles/lambda-constraint-suggest` key passed. A
separate inherited `reader-facing-no-register-codes` test filter matched no
test file, so it was not treated as evidence and was replaced by the exact
reader-facing token scan recorded above.

## 11. Team Learning

**Ada** kept the task on a clean issue-linked branch, separated the NEWS
collision from the implementation lane, and used a lightweight ultra-plan. A
deterministic API repair did not need a multi-day ultra-plan or a compute
campaign.

**Boole**'s API lens made the scale a returned column rather than an inference
from the method name. Invalid method-scale pairs and ambiguous data-frame scales
now stop explicitly; the obsolete scalar denominator is deprecated rather than
silently honored.

**Noether** independently verified the full fixed-parameter Jacobian, raw versus
standardized route separation, fixed-rotation approximation, and pinned-ratio
semantics. The review also caught stale comments and missing bounded-input
validation.

**Curie** required exact public routing masks instead of shape-only tests,
removed a mathematically invalid ordering assertion between hard-threshold and
Wald-retention pins, and added an independent raw covariance oracle.

**Fisher** kept the evidential claim bounded: deterministic algebra and routing
are covered, but standardized-loading interval coverage is not calibrated.
Profile inference remains raw-only because a derived-ratio profile has not been
implemented.

**Pat**'s user lens drove explicit plot labels, scale-aware null regions, and
`rho[...]` versus `Lambda[...]` confint row names. A table can no longer look
comparable while silently mixing scales.

**Rose** swept neighboring help, design, register, limitations, plotting,
flagging, bootstrap, confint, and NEWS surfaces. The active #917 NEWS hunk was
kept intact and this task's entry was added in a disjoint location.

**Grace** required regenerated Rd, `pkgdown::check_pkgdown()`, focused heavy
tests, the full package suite, and a local package check before publication.
No simulation campaign was sent to GitHub Actions; empirical calibration remains
a separate Totoro/DRAC lane if promoted later.

## 10. Known Residuals

- Standardized Wald/Fisher-z coverage is not calibrated; CI-13 remains partial
  for empirical interval calibration. Any campaign belongs on Totoro or DRAC.
- The varimax rotation matrix is treated as fixed in `wald_retention`; rotation
  uncertainty is not propagated.
- Standardized profile intervals and standardized bootstrap intervals are not
  implemented. Raw profile/bootstrap routes remain clearly labelled raw.
- Merge the focused PR for #921 after CI passes. Keep #917 under its current
  owner's review; its NEWS hunk is disjoint from this repair.
- After the fix is available, send Ayumi a concise reply that names the corrected
  standardized route and keeps bootstrap communality as the headline result.

## 12. Cross-Product Coverage

This repair covers ordinary loading extraction for raw and standardized Wald
inference, the existing raw profile and bootstrap labels, Lambda `confint()`
routing, scale-aware flagging/plotting, and the two constraint-suggestion routes
for currently admitted fitted models. It also covers `d = 1` and `d = 2`
deterministic algebra, non-diagonal fixed-parameter covariance, fitted
denominator components, parameter-dependent link residuals, pinned numerators,
and malformed scale combinations.

It does NOT cover empirical standardized-interval calibration, uncertainty in
the fitted varimax rotation, standardized profile intervals, standardized
bootstrap intervals, a likelihood or TMB-template change, a new response
family, formula grammar, model fitting, or any new covariance provider. Those
negative cells are stated in NEWS, the inference truth matrix, the validation
register, and known limitations rather than implied by the deterministic tests.
