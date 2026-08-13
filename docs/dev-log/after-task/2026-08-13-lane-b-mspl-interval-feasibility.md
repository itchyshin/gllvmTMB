# After Task: Lane B LA-MSPL interval feasibility Arc 0

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** 2026-08-13
**Audience:** gllvmTMB maintainers and statistical-method developers.

## 1. Goal

Construct one local, internal nuisance-reoptimised profile trace for an ordinary
logit q = 1 LA-MSPL fixed-effect coordinate, or retain an exact blocker. This
arc asks only whether finite, stable profile bounds can be constructed; it does
not claim calibrated frequentist inference.

## 2. Implemented

`.gllvmTMB_mspl_profile_feasibility()` is an unexported fixed-grid instrument.
It fixes one resolved `b_fix` coordinate at each grid value, reoptimises every
other outer LA-MSPL coordinate with `nlminb()`, and records the penalised
objective, objective delta, optimiser status, and finite status. It explicitly
requires `fit$tmb_obj` with `estimator_id = 1`; the separate penalty-off tape
(`estimator_id = 2`) is rejected as a profile source.

The existing ordinary logit q = 1 deterministic fixture has a centre refit
that matches the fitted penalised objective, finite converged profile points,
and threshold crossings on both sides.
With a deliberately insufficient one-step budget, both sides return
`"truncated"`. These are feasibility diagnostics, not returned confidence
intervals.

## 3. Files Changed

- `R/mspl.R`: internal penalised-objective profile-feasibility helper.
- `tests/testthat/test-mspl-api.R`: finite/crossed trace, truncation,
  penalty-off exclusion, and TMB-state restoration checks.

No examples, roxygen, Rd files, public API, NEWS, README, vignette, pkgdown
configuration, validation-debt row, or remote-compute artifact changed.

## 3a. Decisions and rejected alternatives

- Profile the active LA-MSPL TMB object, not the penalty-off provenance object.
  The latter is evaluated at the selected point and is not the estimator being
  investigated.
- Keep the helper unexported and separate from `confint()`,
  `profile_targets()`, and `tmbprofile_wrapper()`. A finite profile trace does
  not establish calibrated SEs, tests, coverage, or a user-facing CI route.
- Use a fixed finite grid and typed side statuses. A non-crossing side is
  `"truncated"`, `"nonfinite"`, or `"optimizer_failed"`; it is never
  substituted with a Wald interval.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::test(filter="mspl-api", stop_on_failure=TRUE)'`
  -> PASS: 238 expectations, 0 failures, 0 warnings, 0 skips (17.3 seconds).
- A local direct probe of the logit q = 1 fixture with `step = 0.5` and
  `max_steps = 6` -> all 13 trace points finite and converged; both sides
  crossed the threshold.
- `git diff --check` -> PASS.

Deliberately not run: package-wide tests, `R CMD check`, pkgdown checks,
coverage/calibration simulations, bootstrap, remote computation, or CI.

## 5. Tests of the tests

The acceptance fixture combines the experimental LA-MSPL objective, a
fixed-effect constraint, nuisance reoptimisation, and existing TMB state. The
test would fail if the helper invoked the penalty-off tape, failed to restore
the active TMB state, returned a non-finite point, failed to improve a displaced
target over fixed nuisances, or claimed a two-sided result without two threshold
crossings. The one-step run is the paired budget boundary: it must report
`"truncated"`, not manufacture a bound.

## 6. Consistency audit

`rg -n 'mspl|profile|confint|vcov|interval|nuisance' R/mspl.R R/profile-ci.R R/profile-targets.R R/z-confint-gllvmTMB.R tests/testthat/test-mspl-api.R`
confirmed that the new helper is private while all existing public MSPL
inference entry points retain their fail-closed guard. No reader-facing wording
was added, so no capability claim or validation-debt status changed.

## 7. Roadmap tick

None. This is an internal experimental feasibility result and does not promote
an advertised capability.

## 8. What did not go smoothly

The sandbox cannot create R temporary files, so local R/TMB probes and focused
tests required the approved local execution path. The GitHub PR-list check was
unavailable because the environment could not reach the GitHub API; no GitHub
state was modified.

## 9. Team learning

Ada: a TMB profile must identify its exact objective tape and verify its centre
before any numerical result is interpreted. Noether's fresh review added the
centre-match and nuisance-reoptimisation checks. Rose review remains required
before a later promotion: the present result is a finite trace only, not
inference evidence.

Noether's final read-only re-review found no P0 or P1 issue after those repairs.

## 10. Known limitations and next actions

- Evidence covers one deterministic ordinary complete-Bernoulli logit q = 1
  fixture and one `b_fix` coordinate only.
- It does not establish link transfer to probit or complementary log-log,
  spatial structures, coverage, standard-error calibration, tests, or any
  public `profile()`/`confint()` route.
- The current public MSPL inference fence remains mandatory. A later arc must
  be separately approved before adding fixtures or considering any promotion.
