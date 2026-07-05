# After Task: LV Missing-Response Compatibility Gate

**Branch**: `codex/lv-missing-response-20260628`
**Date**: `2026-06-29`
**Roles (engaged)**: `Ada / Boole / Noether / Fisher / Curie / Rose / Grace`

## 1. Goal

Move the Design 73 `latent(..., lv = ~ x)` arc one step closer to V1 by
proving that ordinary Gaussian response masks do not break the unit-level LV
predictor design when the `lv` predictors are observed, complete, and constant
within unit.

The scope is intentionally narrow: ordinary unit-tier native TMB Gaussian fits,
observed numeric `lv` predictors, `miss_control(response = "include")`, and
`se = FALSE`. This does not admit missing `lv` predictors, `mi()` inside `lv`,
non-Gaussian masks, factor-valued masks, mixed-family masks, Julia bridge masks
with `X_lv`, tier-expanded masks, structured-source masks, or interval claims.

## 2. Mathematical Contract

No public R API, likelihood parameterisation, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation change.

The new test exercises the existing ordinary LV model with a response mask:

- `z_i = x_i alpha + e_i`, with `e_i ~ N(0, 1)`;
- `eta_it = beta_t + lambda_t z_i`;
- `y_it ~ Gaussian(eta_it, psi_t)` only when the response is observed;
- `miss_control(response = "include")` keeps masked rows and sends
  `is_y_observed = 0`, so masked rows contribute no likelihood;
- the recovery target is `B_lv = Lambda alpha^T`, surfaced by
  `extract_lv_effects(type = "trait_effect")`.

## 3. Implemented

- Added `tests/testthat/test-lv-missing-response.R`.
- The test builds a three-trait Gaussian DGP with observed unit-level `x`.
- It fits the same data two ways: retained masked rows with
  `miss_control(response = "include")`, and the matching complete-case data
  with `miss_control(response = "drop")`.
- It checks optimizer convergence, gradient size, LV report dimensions,
  finite `alpha_lv_B`, `U_lv_mean_B`, `U_B_total`, and `B_lv_unit`, plus the
  report identity `B_lv_unit = Lambda_B * alpha_lv_B` for rank 1.
- It verifies masked rows are retained with `is_y_observed = 0`, sentinel
  `y = 0`, and correct `missing_data$counts`.
- It verifies `X_lv_B`, log likelihood, and fitted parameters match the
  complete-case fit.
- It checks trait-scale `B_lv` recovery, extractor status metadata, and
  `total = innovation + mean` score decomposition.
- It keeps the existing fail-loud boundary for missing `lv` predictor values.

## 4. Files Changed

Tests:

- `tests/testthat/test-lv-missing-response.R`

Evidence records:

- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-29-lv-missing-response.md`

## 4a. Decisions and Rejected Alternatives

Decision: move `LV-03` from `blocked` to `partial`, not `covered`.
Rationale: the test proves only ordinary Gaussian native TMB masks with
observed, complete unit-level `lv` predictors. Missing predictors, non-Gaussian
masks, factor-valued masks, bridge masks, tiers, and structured sources still
need their own derivations and tests.
Rejected alternative: mark all missing-response LV support covered.
Confidence: high.

Decision: compare the retained-mask fit to the complete-case fit.
Rationale: the strongest evidence that masked response rows are likelihood
neutral is equality of `X_lv_B`, log likelihood, and fitted parameters after
dropping the same rows.
Rejected alternative: only check that the retained-mask fit converges.
Confidence: high.

Decision: keep missing `lv` predictors as an explicit rejection test.
Rationale: response masks are not predictor imputation. Allowing missing
predictors through this slice would silently widen Design 73 beyond its
derivation.
Rejected alternative: recycle the missing-predictor `mi()` layer inside `lv`.
Confidence: high.

## 5. Checks Run

- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; no open gllvmTMB PRs after PR #574 merged.
- `git log --all --oneline --since='6 hours ago' -- docs/dev-log/check-log.md docs/dev-log/after-task tests/testthat R docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`
  -> REVIEWED; recent nearby work was limited to merged Bernoulli,
  source-guard, and factor-runtime LV slices.
- `git fetch origin +refs/heads/main:refs/remotes/origin/main`
  -> PASS; refreshed `origin/main` at `5e708740`.
- `git rebase origin/main`
  -> PASS; branch rebased cleanly after PR #574.
- `git diff --check origin/main...HEAD`
  -> PASS; no whitespace errors before evidence edits.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-missing-response", reporter = "summary")'`
  -> PASS; focused missing-response tests completed with no failures.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; parser guard remained green with the existing informational
  sigma-eps auto-suppression message.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m49.3s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.
- `gh run view 28414994265 --repo itchyshin/gllvmTMB --json status,conclusion,workflowName,event,headSha,createdAt,updatedAt,url,jobs`
  -> PASS; PR #574 post-merge pkgdown completed successfully at
  2026-06-30T02:19:25Z.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "lv missing response" --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned issue #348 only.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "latent missing response" --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned the missing-data umbrella #332 plus roadmap issues.
- `gh issue view 332 --repo itchyshin/gllvmTMB --json number,title,state,url,labels,body`
  -> REVIEWED; #332 is not closed by this narrow LV slice.
- `gh issue view 348 --repo itchyshin/gllvmTMB --json number,title,state,url,labels,body`
  -> REVIEWED; #348 is not closed by this ordinary Gaussian mask slice.
- `git diff --check`
  -> PASS; no whitespace errors after evidence edits.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-29-lv-missing-response.md`
  -> PASS; validator returned successfully.

## 6. Tests of the Tests

This test would fail if response-mask preprocessing dropped unit levels needed
for `X_lv_B`, if retained masked rows contributed to the likelihood, if
`is_y_observed` or sentinel `y = 0` handling drifted, if the retained-mask fit
stopped matching the complete-case log likelihood or fitted parameters, if
`extract_lv_effects()` or `extract_ordination()` stopped working after a mask,
or if missing `lv` predictor values slipped through preflight.

This satisfies the test-contract boundary-case rule: retained missing responses
plus predictor-informed latent scores are a neighbouring feature combination
and a mask boundary, not a happy-path-only smoke.

## 7. Consistency Audit

- `rg -n 'no missing-response compatibility|Future tests must show|LV-03.*blocked|missing-response compatibility, Julia|missing-response compatibility,|response masks with `X_lv`|response mask, and no calibrated CIs' docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md NEWS.md README.md ROADMAP.md docs/dev-log/known-limitations.md`
  -> REVIEWED; remaining hits are bridge-boundary wording, not stale `LV-03`
  blocked wording.
- `rg -n 'LV-03.*covered|missing-response.*covered|response-mask compatibility.*covered|missing-response.*complete|non-Gaussian.*response masks.*validated|mixed-family.*response masks.*validated|Julia.*response mask.*admit|bridge.*response mask.*admit|missing `lv` predictors.*validated|mi\(\).*inside `lv`.*validated' docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-lv-missing-response.R`
  -> REVIEWED; hits are ordinary-Gaussian limited evidence or explicit
  limitations. No broad mask / missing-predictor support is claimed.
- `rg -n "LV-03|missing response|missing-response|response mask|miss_control\\(response = \\\"include\\\"\\)|is_y_observed|X_lv_B|test-lv-missing-response" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md ROADMAP.md NEWS.md README.md docs/dev-log/known-limitations.md tests/testthat/test-lv-missing-response.R | head -n 260`
  -> REVIEWED; expected hits show `LV-03` partial evidence, bridge and
  missing-response boundaries, and the new test.

## 8. Roadmap Tick

`LV-03` moves from `blocked` to `partial`. The overall Design 73 arc is still
partial: `LV-06` and `LV-07` remain blocked, while non-Gaussian masks,
missing `lv` predictors, bridge masks, and interval calibration remain gated.

## 8a. GitHub Issue Ledger

Issue #332 (`Missing-data layer -- shared contract`) remains open because it is
the broader missing-data umbrella. Issue #348 (`Family-validation completion`)
also remains open because this slice is ordinary Gaussian and does not move the
non-Gaussian family-validation roadmap. No issue was closed or commented on by
this branch.

## 9. Documentation And Pkgdown

No roxygen, generated Rd, vignette, README, NEWS, or `_pkgdown.yml` files
changed. The validation-debt register, capability-status synthesis, and Design
73 were updated to record the new evidence and to keep the unsupported masks
explicit. `devtools::document()` and local `pkgdown::check_pkgdown()` were not
run because no roxygen or pkgdown navigation changed.

The post-merge pkgdown run from the previous factor-runtime PR (#574) completed
successfully while this branch was being prepared, so the next PR lane is clear.

## 10. What Did Not Go Smoothly

One stale top-level synthesis line in `docs/design/61-capability-status.md`
still grouped `LV-03` with blocked rows after the first patch. The stale scan
caught it and it was corrected before commit.

One draft `rg` command used backticks inside a double-quoted shell string, which
the shell tried to execute. The scan was rerun with single-quoted patterns and
the exact reproducible commands are recorded above.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

Ada: this is a good V1-progress slice because it removes a real ordinary
Gaussian mask blocker without dragging in missing-predictor design.

Boole: the formula grammar does not move. `lv = ~ x` remains ordinary
unit-tier only, and missing predictors still fail loudly.

Noether: the likelihood contract is the same as the complete-data LV model with
`is_y_observed` gating the response contribution.

Fisher: the strongest evidence is equality to the complete-case likelihood and
parameters, plus bounded `B_lv` recovery. No interval or non-Gaussian inference
claim moves.

Curie: this test exercises both the mask boundary and the missing-predictor
rejection boundary, so it is not merely a convergence smoke.

Grace: focused tests, parser guard, and full local R CMD check passed after the
branch was rebased onto current `origin/main`.

Rose: the ledger now moves `LV-03` to partial and names every mask regime that
still remains outside the claim.

## 12. Known Limitations And Next Actions

- Missing `lv` predictors and `mi()` inside `lv` remain rejected.
- Non-Gaussian response masks with `lv` are not admitted.
- Factor-valued masks, mixed-family masks, Julia bridge masks with `X_lv`,
  source/tier-expanded masks, and interval coverage are not admitted.
- Next safest action: validate the after-task report, commit this evidence, open
  the next PR only after confirming GitHub has no active conflicting PRs, then
  monitor CI before merging.
