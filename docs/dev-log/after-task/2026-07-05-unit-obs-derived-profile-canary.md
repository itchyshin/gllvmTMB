# After Task: Fitted Unit-Obs Derived Profile Canary

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Noether / Curie / Grace / Rose`

## 1. Goal

Add fitted evidence for observed-unit (`unit_obs` / W-tier) derived profile-LR
routes before widening the profile-likelihood arc to cluster, cluster2,
augmented, source-specific, mixed-family, or non-Gaussian intervals.

## 2. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change.

The fitted canary uses an existing Gaussian observed-unit latent-plus-diagonal
model:

```r
value ~ 0 + trait +
  latent(0 + trait | site_species, d = 1) +
  unique(0 + trait | site_species)
```

The tested target is the existing W-tier covariance
`Sigma_unit_obs = Lambda_W Lambda_W^T + diag(psi_W)`. The profile-LR canary
checks selected derived targets only: `communality:unit_obs:trait_1`,
`rho:unit_obs:1,2`, `shared_unit_obs`, and `unique_unit_obs`.

## 3. Implemented

- Added a cached fitted W-tier Gaussian fixture to
  `test-confint-derived.R`.
- Added fitted `confint(..., method = "profile")` canaries for
  `communality:unit_obs:trait_1` and `rho:unit_obs:1,2`.
- Added a cached fitted W-tier proportions fixture to
  `test-profile-proportions.R`.
- Added a fitted `profile_ci_proportions()` canary for `shared_unit_obs` and
  `unique_unit_obs`, including agreement with `extract_proportions()`.
- Updated validation-debt rows `CI-06` and `CI-11`.

## 4. Files Changed

- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-profile-proportions.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-unit-obs-derived-profile-canary.md`

## 5. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("tests/testthat/test-confint-derived.R")); invisible(parse("tests/testthat/test-profile-proportions.R")); cat("parse-ok\n")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-proportions.R", desc = "profile_ci_proportions() profiles shared and unique unit_obs components on a fitted W tier")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", desc = "confint(fit, parm = '\''communality:unit_obs'\'') profiles fitted W-tier latent covariance")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", desc = "confint(fit, parm = '\''rho:unit_obs'\'') profiles fitted W-tier latent covariance")'
air format tests/testthat/test-confint-derived.R tests/testthat/test-profile-proportions.R
rg -n "cluster.*profile.*covered|cluster2.*profile.*covered|source-specific.*profile.*covered|non-Gaussian.*profile.*covered|unit_obs.*only route-ledger|route-ledger-only gap" docs/design/35-validation-debt-register.md tests/testthat/test-confint-derived.R tests/testthat/test-profile-proportions.R docs/dev-log/check-log.md docs/dev-log/after-task
git diff --check
```

Outcomes:

- Parse check: `parse-ok`.
- `profile_ci_proportions()` fitted `unit_obs` canary: 13 pass, 0 fail,
  0 skip under `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`.
- `communality:unit_obs` fitted profile canary: 10 pass, 0 fail, 0 skip under
  `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`.
- `rho:unit_obs` fitted profile canary: 10 pass, 0 fail, 0 skip under
  `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`.
- Claim scan found the new `unit_obs` evidence text and the intentional
  cluster / cluster2 boundaries; it did not find stale promotion of
  source-specific or non-Gaussian profile coverage.
- `git diff --check` passed.
- No local `tools/check-after-task.R` script exists in this tree; this report
  was checked manually against `docs/design/10-after-task-protocol.md`.

## 6. Tests of the Tests

Feature combination: the new tests exercise profile-LR selected derived targets
on a fitted Gaussian model that has W-tier reduced-rank loadings and W-tier
diagonal uniqueness at the same grouping level.

Boundary value: the fixture has no unit-tier reduced-rank term, so the tests
cannot accidentally pass by reading the B-tier latent covariance.

Comparator: the proportions test checks the profiled point estimates against
`extract_proportions()` for the same fitted object and component keys.

## 7. Consistency Audit

The validation register now distinguishes three truths:

- fitted `unit_obs` communality, correlation, and W-tier proportion canaries are
  covered for existing Gaussian routes;
- cluster / cluster2 profile evidence remains diagonal-route and
  denominator-limited, not broadly calibrated;
- source-specific, augmented, mixed-family, and non-Gaussian profile claims stay
  gated.

No README, NEWS, roxygen, generated Rd, vignette, or pkgdown navigation change
was needed because no user-facing API or public example changed.

## 8. Roadmap Tick

N/A. This is validation-debt evidence for `CI-06` and `CI-11`, not a public
roadmap capability promotion.

## 9. GitHub Issue Ledger

No directly scoped open issue was found for the fitted `unit_obs` profile gap.
The live issue search:

```sh
gh issue list --state open --limit 50 --search "profile unit_obs OR profile likelihood OR confidence interval"
```

returned profile-related issue #643, plus broader roadmap / missing-data /
kernel issues. #643 is about `profile_cross_rho` tie handling and was already
closed locally by an earlier commit, so no issue was closed or commented from
this slice.

## 10. What Did Not Go Smoothly

The first selector attempt used `test_file(..., filter = "unit_obs")`, but this
local `testthat` exposes `desc=`, not `filter=`. The next attempt used
`desc = "unit_obs"`, but `desc` is an exact-match selector. Both failed before
running tests. The final commands use exact test descriptions.

## 11. Team Learning

Ada: use fitted canaries to turn route-matrix truth into executable evidence
without expanding the whole interval agenda.

Fisher: profile-LR remains the primary uncertainty engine for this slice, but
the claim is selected-target and Gaussian W-tier only.

Noether: the tested symbolic target is W-tier total covariance
`Lambda_W Lambda_W^T + diag(psi_W)`, not a borrowed B-tier or source-specific
target.

Curie: the fixture is deliberately small and deterministic, with focused
`desc=` runs to avoid triggering the full slow profile suite.

Grace: no Totoro / DRAC compute is needed for this canary. Larger calibration
will need a separate denominator plan before remote compute starts.

Rose: this closes one evidence gap but does not promote cluster, cluster2,
source-specific, mixed-family, augmented, or non-Gaussian intervals.

## 12. Known Limitations And Next Actions

This is not coverage calibration. It does not prove robust endpoint behavior
near boundaries and it does not validate non-Gaussian, source-specific, mixed
family, augmented random-slope, cluster, or cluster2 profile intervals.

Next safest profile slice: audit cluster / cluster2 profile targets separately,
starting with their diagonal-only routes and denominator definitions before any
full-Sigma or non-Gaussian promotion.
