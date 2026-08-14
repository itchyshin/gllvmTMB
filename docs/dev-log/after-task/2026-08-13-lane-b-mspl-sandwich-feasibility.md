# After Task: LA-MSPL private Godambe/sandwich feasibility

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** `2026-08-13`
**Roles (engaged):** Ada, Gauss, Fisher, Rose

## 1. Goal

Determine whether the active penalised LA-MSPL objective admits the additive
score contributions required for a private Godambe/sandwich covariance that
could address the low-prevalence cloglog numerical-Hessian scale defect.

## 2. Implemented

An unexported `.gllvmTMB_mspl_sandwich_feasibility()` diagnostic records the
typed result for an admitted MSPL fit. It verifies the active penalised tape
(`fit$tmb_obj`, `estimator_id = 1`) and records
`score_decomposition_unavailable`; it computes neither a covariance nor an
interval. The status records the absence of a validated, exposed decomposition,
not an impossibility theorem about every future estimator construction.

## 3. Mathematical Contract

The required identity would be an additive active-objective score
\(\nabla f_{pen}(\theta)=\sum_s u_s(\theta)\). No validated, exposed form is
available here:
TMB adds the Laplace log determinant outside `joint_nll_penalized`, and the
MSPL information and structural penalties depend on global `N_eff` and
`X_mspl`. The fitted tape exposes a total outer gradient, not validated
per-unit scores.

## 3a. Decisions and Rejected Alternatives

**Decision:** return `score_decomposition_unavailable` for the sandwich route.
**Rejected:** assigning global penalties to sites ad hoc; using reported joint
NLL as a marginal score; using the penalty-off provenance tape; treating a
delete-one-site refit as a Godambe score; widening Hessian bands; or activating
public inference.

## 4. Files Touched

- `R/mspl.R`: unexported blocker diagnostic.
- `tests/testthat/test-mspl-api.R`: four-fixture active-objective contract.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  plan-versus-actual record.
- `docs/dev-log/check-log.md`: focused check receipt.
- This report.

No export, NAMESPACE, public `vcov()`, `confint()`, profile dispatch, user
documentation, likelihood, formula grammar, or simulation runner changed.

## 5. Checks Run

See the corresponding dated check-log entry. The focused MSPL test suite and
`git diff --check` are the only required mechanical checks.

## 6. Tests of the Tests

The four-fixture test poisons the penalty-off `fn`, so the blocker diagnostic
cannot silently evaluate that provenance tape. It asserts active-objective
identity, total-only gradient status, absence of reported per-unit score
fields, and the typed blocker in logit, probit, standard cloglog, and
low-prevalence standard cloglog fixtures.

## 7a. Issue Ledger

Pre-edit coordination checks were rerun. GitHub CLI output was unavailable in
this local sandbox, so local branch/history evidence was retained; no issue or
PR was created.

## 8. Consistency Audit

The helper is dot-prefixed and has no NAMESPACE export. Existing MSPL
`vcov()`, `confint()`, profile, and standard-error refusals remain the public
surface. A sandwich blocker is not a user-facing capability claim.

## 9. What Did Not Go Smoothly

The first focused R invocation could not create its sandbox temporary file;
the same local command was rerun with the minimum temporary-directory
permission. No source or campaign data were changed by that recovery.

## 10. Known Residuals

A genuine delete-one-site jackknife candidate would need a separately defined
estimand, complete TMB-data rebuild equivalence checks, and repeated-sampling
calibration. It is not a continuation of this sandwich result.

## 11. Team Learning

**Gauss:** a C++ conditional/joint objective report is not automatically a
score decomposition for a Laplace-marginal TMB fit. **Fisher:** a total
gradient and an additive estimating-equation score are distinct objects.
**Rose:** the typed blocker preserves the fail-closed public inference fence.

## 12. Cross-Product Coverage

The diagnostic contract covers four deterministic ordinary complete-Bernoulli
q = 1 fixtures. It does not cover q = 2, spatial or other structured effects,
missing data, bootstrap, calibration, or public uncertainty methods.

## 13. Next Action

Do not develop a conventional LA-MSPL Godambe covariance from the present
objective. If needed, plan a distinct private delete-one-site jackknife arc
from first principles, with no public inference claim.
