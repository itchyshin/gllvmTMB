# Recovery checkpoint — private LA-MSPL jackknife admission

> **WITHDRAWN — exploratory route (2026-08-14).** The original MSPL paper did
> not propose jackknife inference. Arc 3 removed the active helper, tests, and
> runner route. This checkpoint is retained only as historical evidence and
> does not describe the current private method map.

## Repository state

- Worktree: `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`
- Branch: `codex/lane-b-mspl-interval-feasibility`
- HEAD: `a525ba0a test: harden MSPL jackknife admission`
- Status: clean; branch is one commit ahead of its remote tracking branch.

## Landed work

`73a4aacc` adds the unexported delete-one-site MSPL jackknife feasibility seam.
`a525ba0a` adds a typed failed-deletion regression and reconciles the local
four-fixture smoke. The helper rebuilds each subset with
`gllvmTMB(..., estimator = "mspl")`, retains only active penalised-objective
fits, and computes no covariance unless every deletion is successful.

## Evidence already run

- `Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'`
  passed: 679 expectations, 0 failures/warnings/skips, 162.3 seconds.
- Direct four-fixture smoke passed in 18.6 seconds: base logit, base probit,
  base cloglog, and low-prevalence cloglog each had 24 successful deletions and
  a finite private covariance.
- Forced invalid deletion input returned `delete_site_refit_failure` with
  `covariance = NULL`.
- `git diff --check` and `check-after-task.R` passed.
- Fisher/Rose-style read-only review passed; no P0/P1 blocker.

## Deliberate non-runs and next safe action

No repeated-sampling calibration, Totoro/DRAC compute, bootstrap, public
`vcov()`/`confint()`/profile change, q > 1, structured/missing-data regime, or
package-wide check has run. The next arc is a private repeated-sampling
pre-run: first inspect and extend the existing local MSPL uncertainty runner,
then run a tiny deterministic pilot to measure runtime and retain typed
availability/coverage receipts. Do not launch a greater-than-30-minute Totoro
campaign until that pilot's result and a concrete campaign plan are shown to
the maintainer.
