# After Task: Structural-Zero Sigma Interval Labelling

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Noether / Curie / Grace / Rose`

## 1. Goal

Make pure-diagonal Sigma interval outputs tell the same truth as the route
matrix: diagonal rows use the requested interval method, while off-diagonal
covariance rows are fixed structural zeros rather than profile or Wald
calculations.

## 2. Mathematical Contract

No likelihood, family, formula grammar, NAMESPACE, vignette, or pkgdown
navigation change.

For a pure-diagonal tier,
`Sigma = diag(s_1, ..., s_T)`, so `Sigma[i, j] = 0` for `i != j` by model
construction. This slice does not add an estimand or a new interval engine. It
only labels those off-diagonal rows as `method = "structural_zero"` with
`lower = upper = estimate = 0`.

## 3. Implemented

- Added `.mark_structural_sigma_zeros()` in `R/z-confint-gllvmTMB.R`.
- Applied it to pure-diagonal Sigma Wald and profile paths.
- Updated `confint.gllvmTMB_multi()` roxygen and regenerated
  `man/confint.gllvmTMB_multi.Rd`.
- Tightened route-matrix tests for `Sigma_cluster` / `Sigma_cluster2`.
- Tightened the pure-diagonal `Sigma_unit` profile/Wald test.
- Updated Design 73 and validation-debt row `CI-11`.

## 4. Files Changed

- `R/z-confint-gllvmTMB.R`
- `man/confint.gllvmTMB_multi.Rd`
- `tests/testthat/test-profile-route-matrix.R`
- `tests/testthat/test-profile-ci.R`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-structural-zero-sigma-interval-labelling.md`

## 5. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("tests/testthat/test-profile-route-matrix.R")); invisible(parse("tests/testthat/test-profile-ci.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", desc = "Sigma_cluster and Sigma_cluster2 routes use diagonal-only interval blocks")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R", desc = "Profile on Sigma_unit (pure-diag tier) gives finite bounds")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
tail -5 man/confint.gllvmTMB_multi.Rd && { grep -c '^\\keyword' man/confint.gllvmTMB_multi.Rd || true; }
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R")'
rg -n "structural_zero|structural zero|Sigma_cluster.*profile|Sigma_cluster2.*profile|off-diagonal.*profile|off-diagonals fall back" R/z-confint-gllvmTMB.R man/confint.gllvmTMB_multi.Rd docs/design/73-profile-likelihood-route-matrix.md docs/design/35-validation-debt-register.md tests/testthat/test-profile-route-matrix.R tests/testthat/test-profile-ci.R docs/dev-log/check-log.md
git diff --check
```

Outcomes:

- Parse check: `parse-ok`.
- Focused `Sigma_cluster` / `Sigma_cluster2` route test: 24 pass, 0 fail,
  0 skip.
- Focused pure-diagonal `Sigma_unit` heavy test: 15 pass, 0 fail, 0 skip under
  `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`.
- `devtools::document(quiet = TRUE)` rewrote `man/confint.gllvmTMB_multi.Rd`.
- Rd spot-check returned `0` `\keyword{}` lines.
- Full `test-profile-route-matrix.R`: 279 pass, 0 fail, 0 skip.
- Default `test-profile-ci.R`: 11 expected heavy skips, 0 fail.
- Claim scan found only the new structural-zero wording and expected
  reduced-rank fallback wording.
- `git diff --check` passed before this report was added.

## 6. Tests of the Tests

Boundary case: the tests now assert off-diagonal rows in pure-diagonal Sigma
tiers are fixed at zero and labelled `structural_zero`, rather than inheriting
the diagonal interval method.

Feature combination: `test-profile-route-matrix.R` covers both extra diagonal
grouping tiers (`cluster`, `cluster2`) while `test-profile-ci.R` covers the
ordinary pure-diagonal `Sigma_unit` route.

Failure-before-fix: before this slice, profile off-diagonal rows could carry
`method = "profile"` and Wald off-diagonal rows could carry `method = "wald"`
or unavailable bounds, even though no off-diagonal interval calculation was
being performed.

## 7. Consistency Audit

The route truth is now:

- diagonal pure-Sigma rows: interval method is `profile` or `wald`;
- off-diagonal pure-Sigma rows: exact fixed zeros labelled
  `structural_zero`;
- reduced-rank Sigma rows: still bootstrap fallback for nonlinear full-Sigma
  entries;
- cluster / cluster2 correlations: still point-only structural zeros, with no
  `rho:cluster` profile route.

No NEWS or roadmap change was made because this narrows labelling and
documentation; it does not promote a new capability.

## 8. Roadmap Tick

N/A. This updates validation row `CI-11` and the `confint()` return contract,
not a public roadmap phase.

## 9. GitHub Issue Ledger

No new GitHub issue was created. This was found during the cluster / cluster2
profile truth audit that followed the `unit_obs` profile canary slice.

## 10. What Did Not Go Smoothly

`air format` line-wrapped more of `R/z-confint-gllvmTMB.R` and
`test-profile-route-matrix.R` than this truth repair strictly needed. The
logic change remains narrow, but the diff is less compact than ideal.

## 11. Team Learning

Ada: the route matrix should drive return labelling, not just planning prose.

Fisher: a structural zero is exact model structure, not a profile or Wald
interval calculation.

Noether: the symbolic object is diagonal `Sigma`; off-diagonal covariance is
identically zero for this tier.

Curie: one mocked route test plus one fitted pure-diagonal Sigma test is enough
for this labelling slice; calibration remains separate.

Grace: no Totoro / DRAC run is appropriate here. Remote compute belongs to
later calibration, with host provenance kept separate.

Rose: this narrows claims. It does not add cluster correlations, full
cluster covariance, or non-Gaussian interval calibration.

## 12. Known Limitations And Next Actions

This does not calibrate intervals. It does not add bootstrap for
`Sigma_cluster` / `Sigma_cluster2`, `rho:cluster`, `rho:cluster2`, full
cluster covariance, augmented profile routes, source-specific profile routes,
or non-Gaussian profile evidence.

Next safest slice remains missing/mixed correctness or a Gamma/profile
inference-safety fix, depending on live issue priority.
