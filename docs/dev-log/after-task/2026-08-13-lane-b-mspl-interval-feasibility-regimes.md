# After Task: Lane B LA-MSPL q = 1 regime feasibility matrix

**Branch:** `codex/lane-b-mspl-interval-feasibility`  
**Date:** 2026-08-13

## 1. Goal

Map private nuisance-reoptimised penalised-objective feasibility for the
ordinary complete-Bernoulli q = 1 LA-MSPL fixture across predeclared prevalence
and latent-signal regimes, the logit/probit/cloglog links, and every resolved
fixed-effect target.

## 2. Implemented

The test fixture now accepts explicit `beta` and `Lambda` values. The new
matrix holds the model class fixed and visits baseline; `beta - 1.5`;
`beta + 1.5`; and `1.75 * Lambda`. It profiles all three resolved `b_fix`
coordinates for each regime/link pair on the same 25-point grid. The expected
table retains 32 finite-stable two-sided crossings and four lower-side
`optimizer_failed` cells rather than concealing them behind a blanket pass.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the predeclared 36-cell regime/link/target matrix and
record its four non-passing cells as typed blockers. **Rationale:** the fixed
grid is the experimental contract; 32 finite-stable cells do not license an
adaptive retry for the remaining four. **Rejected alternatives:** widening a
single grid, changing optimiser controls, substituting a Wald interval, or
promoting public profiling. **Confidence:** high for this bounded internal
trace claim; no claim about calibration or general data regimes.

## Mathematical Contract

At target value \(t\), the trace remains
\(f_{pen}(t, \widehat{nuisance}(t)) - f_{pen}(\widehat b)\), where
\(f_{pen}\) is `fit$tmb_obj`, the active penalised LA-MSPL objective with
`estimator_id = 1`. All remaining outer parameters are reoptimised. No public
R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette,
or pkgdown navigation changed. A finite crossing is feasibility evidence only;
it is neither a calibrated standard error nor a confidence interval.

## 4. Files Touched

- `tests/testthat/test-mspl-api.R`: regime arguments for the local fixture and
  static 36-cell internal trace map.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  actuals for the regime continuation.
- `docs/dev-log/check-log.md`: focused verification receipt.
- `docs/dev-log/after-task/2026-08-13-lane-b-mspl-interval-feasibility-regimes.md`:
  this report.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'`
  -> PASS: 617 expectations, 0 failures, 0 warnings, 0 skips (161.6 seconds).
- `git diff --check` -> PASS.
- Static fence audit -> PASS: only test and dev-log artifacts changed; the
  helper is unexported and public MSPL `vcov()`, `confint()`,
  `tmbprofile_wrapper()`, and `profile_targets()` remain fail-closed.

## 6. Tests of the Tests

The regression fails if a regime/link/target row changes, a fixed 12-step grid
is shortened or selectively widened, `fit$tmb_obj` is replaced, a centre loses
convergence, a finite-stable trace loses nuisance convergence, or any retained
terminal status differs from the static map.

## 8. Consistency Audit

`rg -n 'unpenalized_tmb_obj|estimator_id|mspl_profile_feasibility|confint\\(|profile_targets\\(|tmbprofile_wrapper\\(|vcov\\(' R/mspl.R R/profile-ci.R R/profile-targets.R R/z-confint-gllvmTMB.R R/vcov-coef.R tests/testthat/test-mspl-api.R`

The only new profile call is test-only and asserts the penalised objective;
existing penalty-off poison and public-refusal tests remain present.

## 9. What Did Not Go Smoothly

Four standard-cloglog lower walks report `optimizer_failed` within the fixed
budget. Their objectives and deltas stay finite, but the side is not a finite
stable crossing. The result is retained as a typed blocker; this arc did not
retry with a larger grid or different optimiser budget.

## 11. Team Learning

Rose's fence audit found no violation: the helper remains private, the
penalty-off poison regression remains separate, and every public refusal stays
in place. Fisher/Gauss gave a P2 narrow-scope approval: the objective and
nuisance treatment are coherent, but `level = 0.95` supplies only a
threshold-crossing convention. Future prose must call these profile-feasibility
traces, never intervals or calibration evidence.

## Design and Documentation Updates

No design, validation-debt, public documentation, roxygen, Rd, NEWS, README,
ROADMAP, vignette, or pkgdown update applies because no advertised capability
changed.

**Roadmap tick:** N/A; no public roadmap row changed.

## 7a. Issue Ledger

No relevant open issue was inspected or changed; this
was an isolated local experimental evidence arc with no public claim.

## 10. Known Residuals

The map covers only these four deterministic q = 1 regimes and does not test
their joint extremes, q = 2, structured effects, calibrated SEs, coverage,
bootstrap, or public profile/confint/vcov methods. The four retained cloglog
optimizer blockers mean the selected fixture envelope does not support an
all-36-cell finite-stable claim.

## 12. Cross-Product Coverage

This arc covers the product of four deterministic DGP regimes, three ordinary
binary links, and three resolved fixed-effect targets under q = 1 with no free
Psi. It does NOT cover q = 2, free-Psi covariance forms, spatial or
phylogenetic providers, missing responses, random slopes, joint
prevalence-and-signal extremes, alternative optimiser budgets, repeated-sample
calibration, bootstrap, `vcov()`, public profile/confint dispatch, or coverage.
