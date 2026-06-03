# Fix red nightly: SPDE-slope base-engine < 1e-9 cross-check tolerance

Date: 2026-06-03
Issue: #357 (part of #343)
Branch: `claude/fix-nightly-spde-tolerance`
Design ref: Design 35 (SPDE / spatial engine register), Design 55 §5 /
Design 56 §9.5e (augmented SPDE-slope base engine).

## Scope

Test-file-only fix for the scheduled `full-check.yaml` nightly red on
`tests/testthat/test-spde-slope-base-engine.R`. NO engine change:
`src/gllvmTMB.cpp` and the R fitting code were not touched. The engine is
verified correct (density reproduced to ~2.9e-11 via the independent
sparse-Q path, per the #326/#327 verification panels); the failure was
purely in the in-test analytic reference.

## Confirmed failure (nightly log)

Run 1 of `full-check.yaml` (event `schedule`, 2026-05-31, sha `1790eb63`,
the date #357 was filed) failed on all 3 OSes at
`test-spde-slope-base-engine.R:145:3` -- the FIRST cross-check,
`augmented SPDE prior matches analytic Sigma_field (x) Q^-1 density (<1e-9)`:

- ubuntu-latest: `abs(engine_prior - analytic_prior)` -- `Actual comparison:
  0.000000002 >= 0.000000001` (diff ~2e-9, ~2x the bound).
- macOS-latest: `Actual comparison: 0.000000001 >= 0.000000001` (diff ~1e-9,
  right at the boundary).
- windows-latest: `Actual comparison: 0.000000001 >= 0.000000001` (diff
  ~1e-9, boundary).

All three had `[ FAIL 1 | ... ]` -- this single dense-reference cross-check
was the only failure. Root cause: the in-test reference built a DENSE `Q^-1`
(`solve(Q)` + `kronecker(Sf, A)` + `determinant(BigCov)` + `solve(BigCov, .)`),
whose own float accumulation on the CI BLAS/LAPACK exceeds 1e-9.

## State on arrival

Commit `235f0d2` ("fix(test): sparse-Q reference for SPDE-slope density
self-check (unblock nightly)") had ALREADY converted that FIRST test (the
named #357 failure) to the sparse-Q method, which is why nightly runs 2 and
3 (2026-06-01, 2026-06-02) went green. Run 4 (2026-06-03) failed on
unrelated tests (`test-matrix-slope-spatial-unique.R`,
`test-phylo-dep-slope-gaussian.R`, `test-relmat-dep-slope-gaussian.R`) --
those are out of scope for #357 and are separate regressions.

The TWO sibling cross-checks in the same file still built a DENSE `solve(Q)`
reference and carried the identical 1e-9 float-accumulation risk on a
different BLAS. This task hardened them to match the converted first test.

## Fix applied (sparse conversion, both siblings)

Both kept the strict `< 1e-9` bound; neither was loosened.

1. `augmented SPDE prior log-determinant tracks kappa + Sigma_field (<1e-9)`
   (`ana_const`): replaced `A <- solve(Q)` + `determinant(kronecker(Sf, A))`
   with the sparse identity
   `logdet(Sigma_field (x) Q^-1) = n_mesh*logdet(Sf) - C*logdet(Q)`, where
   `logdet(Q)` comes from `Matrix::Cholesky(forceSymmetric(Q), LDL=FALSE,
   perm=TRUE)` + `determinant(chQ, sqrt=FALSE)`. The 2x2 `Sf` stays dense.

2. `slope-only (n_lhs_cols_spde == 1) collapses to a scaled GMRF prior`:
   replaced `A <- sd^2 * solve(Q)` + `determinant(A)` + `solve(A, om0)` with
   `A = sd^2 Q^-1` => `logdet(A) = n_mesh*log(sd^2) - logdet(Q)` (sparse
   Cholesky) and `om0' A^-1 om0 = (1/sd^2) * om0' Q om0` (sparse matvec
   `Q %*% om0`).

The field-simulation `solve(Q)` in the recovery test (a matrix-normal draw
with a 0.20 recovery tolerance) was left untouched -- it is not a 1e-9
density check.

Numerically verified the two sparse identities reproduce their dense
references to ~1e-14 (machine precision) in an offline check, confirming the
algebra before relying on CI.

## CI evidence

The three cross-checks are `skip_if_not_heavy()` + `skip_if_not_spatial()`,
so the standard PR R-CMD-check skips them. Added a temporary
`pull_request`-triggered gate
`.github/workflows/spde-slope-base-engine-check.yaml` (modelled on
`spatial-indep-slope-nongaussian-recovery.yaml`) that installs the package +
`fmesher`, sets `GLLVMTMB_HEAVY_TESTS=1`, and runs
`testthat::test_file("tests/testthat/test-spde-slope-base-engine.R")` with a
summary reporter that fails on any failure/error (and fails if every cell
skips, so the < 1e-9 assertions are proven non-skipped). Paths-filtered to
the test + the workflow. Kept as a regression guard.

## Follow-up

- Run 4 (2026-06-03) nightly failures in `test-matrix-slope-spatial-unique.R`
  (`n_lhs_cols`/`sd_b` expecting 2L, actual 1L/0) and the two fail-loud
  `test-phylo-dep-slope-*` / `test-relmat-dep-slope-*` cells are separate,
  NOT part of #357 -- flag to maintainer for a distinct issue.
