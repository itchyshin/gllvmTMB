# After Task: Lane B LA-MSPL interval-feasibility Arc 2

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** 2026-08-13

## Goal

Complete the private deterministic ordinary q = 1 fixed-effect trace matrix
across the selected logit, probit, and standard/reflected cloglog fixtures by
resolving the sole finite base-probit upper-side truncation. This is interval
feasibility only, not a confidence-interval or calibration claim.

## Implemented

The test matrix gives only the base-probit third resolved `b_fix` coordinate a
predeclared `max_steps = 12L` continuation at the existing `step = 0.5`; the
other 11 matrix cells remain at six steps. The regression records this budget
for every cell, checks its trace length, and requires matched centres plus two
crossed finite sides across all 12 cells.

## Mathematical Contract

For each grid value `t`, the retained quantity remains
`f_pen(t, nuisance_hat(t)) - f_pen(b_hat)`, where `f_pen` is the active
penalised LA-MSPL `fit$tmb_obj` with `estimator_id = 1`. The continuation does
not change the estimator, likelihood, parameterisation, formula grammar, or
public R API. A finite crossing is internal feasibility evidence, not a
calibrated confidence interval.

## Files Changed

- `tests/testthat/test-mspl-api.R`: the single predeclared endpoint continuation
  and 12/12 matrix expectation.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  Arc 2 actuals.
- `docs/dev-log/check-log.md`: exact verification receipt.
- `docs/dev-log/after-task/2026-08-13-lane-b-mspl-interval-feasibility-arc2.md`:
  this report.

No R implementation, export, roxygen, Rd, README, NEWS, ROADMAP, vignette,
pkgdown configuration, validation-debt row, public inference dispatch, or
remote-compute artefact changed.

## Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'`
  -> PASS: 307 expectations, 0 failures, 0 warnings, 0 skips (38.4 seconds).
- `git diff --check` -> PASS.
- Mechanical public-fence audit -> PASS: `R/mspl.R` unchanged, internal helper
  unexported, and `confint()`, `tmbprofile_wrapper()`, and `profile_targets()`
  retain their MSPL guards.
- Method/scope review -> no P0/P1/P2 finding: the sole 12-step cell is
  base-probit `b_fix[3]`; all other cells remain at six steps, and the
  penalised objective/nuisance-reoptimisation contract is intact.

Deliberately not run: package-wide tests, `R CMD check`, pkgdown, simulation or
coverage calibration, bootstrap, remote compute, CI, or public API/docs work.

## Tests Of The Tests

This boundary-case regression would fail if the sixth matrix cell lost its
predeclared 12-step budget, any other cell silently received it, the trace
length did not match its fixed grid, the finite crossed state regressed, or the
existing penalised-objective and convergence assertions failed.

## Consistency Audit

`rg -n 'mspl|profile|confint|vcov|interval|nuisance' R/mspl.R R/profile-ci.R R/profile-targets.R R/z-confint-gllvmTMB.R tests/testthat/test-mspl-api.R`
-> PASS: private helper/test support only and public MSPL guards remain present.
No reader-facing wording changed, so no documentation cascade or
validation-debt status change applies.

## What Did Not Go Smoothly

The original six-step base-probit upper trace was finite and converged but did
not cross the fixed threshold. The separately approved, finite 12-step
continuation crossed at its first added upper point; the arc did not perform an
adaptive unbounded retry.

## Team Learning

Gauss's method review confirmed that the continuation changes only a fixed
endpoint budget, not the objective or link semantics. Fisher's claim boundary
remains enforced: the result is finite profile feasibility, not a calibrated
confidence interval. Rose's mechanical fence audit confirmed that the public
MSPL inference surface remains fail-closed.

## Known Limitations

This completes only the selected deterministic ordinary complete-Bernoulli q =
1 fixture matrix. It does not establish interval calibration, standard errors,
tests, coverage, all-data-regime behaviour, q = 2 or spatial feasibility,
bootstrap validity, or any public `profile()`/`confint()` method.

**Roadmap tick:** N/A; no advertised capability changed.

**GitHub issue ledger:** GitHub API availability was not needed for this private
local continuation; no issue was created, changed, or closed.

## Next Actions

No immediate public-inference action follows. Any broadened fixture cohort or
calibration study requires separate scope and approval.
