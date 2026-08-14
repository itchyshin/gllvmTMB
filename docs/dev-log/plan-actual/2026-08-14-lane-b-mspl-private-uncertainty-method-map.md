# LA-MSPL private uncertainty-method map

## Scope and invariant

This reconciliation covers only ordinary, complete, single-trial Bernoulli
LA-MSPL fits with `q = 1`, three resolved fixed effects, common logit, probit,
or standard cloglog links, and zero offsets. Every inference candidate targets
the active penalised `fit$tmb_obj` (`estimator_id = 1`); the retained
penalty-off tape is fit provenance, never an inference objective.

## Route map

| Route | Private evidence | Current state | Blocking fact / next gate |
| --- | --- | --- | --- |
| Nuisance-reoptimised penalised profile | Four-regime deterministic matrix; finite grid and typed endpoints | **Typed blocker for calibrated/public profile intervals** | 32/36 traces crossed; four cloglog lower sides ended `optimizer_failed`. A finite crossing is not a likelihood-ratio or confidence-interval result. |
| Numerical outer Hessian | 500-replicate gate plus disjoint 1,000-replicate confirmation over four fixtures | **Private diagnostic candidate; public promotion blocked** | Availability was 0.991--0.999 and diagnostic coverage 0.950--0.979, but low-prevalence cloglog mean-SE / empirical-SD ratios reached 1.35. This fails estimator-scale calibration. |
| Godambe/sandwich | Active-objective/TMB decomposition audit in four fixtures | **Typed blocker: `score_decomposition_unavailable`** | The Laplace log determinant and global MSPL penalties prevent use of the reported joint NLL as additive active-objective site scores; no validated site-score decomposition is exposed. |
| Delete-one-site jackknife | Rebuild admission plus four-fixture deterministic smoke and four-replicate failure-retaining pilot | **Private candidate admitted; calibration pending** | All 16 pilot fits and 384 deletion refits were active-objective/aligned and finite. Four replicates cannot calibrate coverage; the frozen 500-replicate Totoro gate is estimated at about 45 minutes on four workers and remains awaiting explicit compute approval. |

## Evidence reconciliation

The profile and numerical-Hessian routes are not interchangeable: their
failures and coverage diagnostics stay attributed to their own candidate. The
jackknife is not a sandwich approximation, since it re-estimates complete
site-deleted data contracts rather than summing scores. Every route retains
failure states; no row is repaired with a Wald substitution, a wider adaptive
grid, or the penalty-off tape.

## Public fence

The package's MSPL `vcov()`, `confint()`, `profile_targets()`,
`tmbprofile_wrapper()`, and standard-error paths remain fail-closed. This map
does not change `MSPL-04` from `blocked`, expose a user-facing candidate, or
claim calibrated standard errors or confidence intervals.

## Completion condition

The method map will close in one of two ways: the predeclared jackknife
calibration gate yields a reproducible fixture-specific private candidate with
availability, unconditional and conditional diagnostic coverage, Monte Carlo
error, SE/empirical-SD ratios, and all failures retained; or it yields typed
jackknife availability/calibration blockers. Neither result activates public
inference without a later, separate promotion decision.
