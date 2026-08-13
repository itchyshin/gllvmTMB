# After Task: Lane B LA-MSPL interval-feasibility Arc 1

**Branch:** `codex/lane-b-mspl-interval-feasibility`

## Goal

Extend the private LA-MSPL q = 1 fixed-effect feasibility trace from one
ordinary logit target to deterministic logit, probit, standard cloglog, and a
reflected-predictor standard-cloglog fixture. The outcome is finite-trace
evidence or a typed blocker, never a confidence interval.

## Implemented

The test-only fixture now accepts `direction = "base"` or `"reflected"`. The
reflected setting negates the complete fixed-effect-plus-latent predictor before
generating Bernoulli outcomes and then fits the ordinary cloglog link; it does
not recode outcomes or introduce a second link.

The new deterministic matrix test profiles all three resolved `b_fix`
coordinates for four q = 1 fixture contexts using the existing private,
nuisance-reoptimised penalised-objective helper. Eleven cells have matched
centres and two crossed sides. The third base-probit coordinate retains the
finite, converged terminal status `truncated` on its upper side under the fixed
six-step grid.

## Mathematical Contract

At every grid point, the target fixed effect is held at `b_j = t` while all
remaining outer coordinates are reoptimised against the active penalised
LA-MSPL objective `fit$tmb_obj` with `estimator_id = 1`. The retained quantity
is `f_pen(t, nuisance_hat(t)) - f_pen(b_hat)`. No public R API, likelihood,
formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown
navigation changed.

## Files Changed

- `tests/testthat/test-mspl-api.R`: deterministic reflected cloglog fixture and
  the 12-cell private feasibility regression.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  Arc Card actuals and typed blocker result.
- `docs/dev-log/check-log.md`: exact local verification receipt.
- `docs/dev-log/after-task/2026-08-13-lane-b-mspl-interval-feasibility-arc1.md`:
  this report.

No reader-facing examples, roxygen, Rd, README, NEWS, ROADMAP, design contract,
validation-debt row, or remote-compute artefact changed.

## Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'`
  -> PASS: 295 expectations, 0 failures, 0 warnings, 0 skips (39.1 seconds).
- Deterministic local profile probes using `step = 0.5`, `max_steps = 6L`, and
  `level = 0.95` -> 11 finite stable cells; one base-probit upper-side
  `truncated` cell; all retained rows finite and converged. The blocker ended
  at target `3.688368`, objective delta `1.764959`, convergence code zero, and
  message `relative convergence (4)`; the fixed crossing threshold was not met.
- `git diff --check` -> PASS.

Deliberately not run: package-wide tests, `R CMD check`, pkgdown, simulation or
coverage calibration, bootstrap, remote compute, CI, or any public API/docs
promotion.

## Tests Of The Tests

This is a feature-combination regression: it joins the admitted link fixtures,
the private penalised TMB profile path, fixed-effect constraints, nuisance
reoptimisation, and the existing inference fence. It would fail if a resolved
target count changed, a trace became non-finite or non-converged, the objective
identity drifted, the known probit blocker were silently relabelled as passing,
or a previously stable two-sided cell lost a crossing.

## Consistency Audit

`rg -n 'mspl|profile|confint|vcov|interval|nuisance' R/mspl.R R/profile-ci.R R/profile-targets.R R/z-confint-gllvmTMB.R tests/testthat/test-mspl-api.R`
confirmed that the only new surface is test support and that the public MSPL
guards remain present. No reader-facing wording changed, so no broader stale
prose scan or documentation cascade applied.

## What Did Not Go Smoothly

The sandbox could not create R temporary files, so deterministic local R/TMB
probes and tests used the approved local execution path. GitHub API access was
unavailable for `gh pr list`; local all-branch history and lane preflight were
used instead. The base-probit third target did not cross on the fixed upper grid;
the arc retained `truncated` rather than changing the grid or substituting an
approximation.

## Team Learning

Gauss's review criterion is operational here: the reflected fixture changes the
predictor direction while retaining the standard cloglog likelihood, so it does
not borrow a nonexistent response symmetry. Fisher's scope boundary is also
enforced: a crossing threshold is internal feasibility evidence, and the
probit non-crossing is a recorded blocker rather than a confidence interval.
Rose's scope check required Arc 0's formatter churn to be removed before this
matrix was added. Sol's read-only method/scope review found no P0, P1, or P2
finding: it confirmed penalised-objective identity, nuisance treatment, TMB
state restoration, the directional fixture, and the unchanged public fence.

## Known Limitations

This covers only ordinary complete-Bernoulli LA-MSPL q = 1 deterministic
fixtures and their three fixed effects. It does not establish a calibrated
interval, standard error, test, coverage, link-general inference result, q = 2
behaviour, spatial behaviour, bootstrap validity, or any public profile or
`confint()` route.

**Roadmap tick:** N/A; no advertised capability moved.

**GitHub issue ledger:** no relevant open issue could be inspected because the
GitHub API was unavailable; no issue was created or changed.

## Next Actions

Any next step requires separate approval. The smallest useful follow-up is a
read-only diagnosis of the base-probit third target's finite upper-side
non-crossing geometry; it must not enlarge the grid, infer a Wald interval, or
change the public MSPL fence.
