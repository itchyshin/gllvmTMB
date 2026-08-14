# After Task: private LA-MSPL delete-one-site jackknife feasibility

> **WITHDRAWN — exploratory route (2026-08-14).** The original MSPL paper did
> not propose jackknife inference. Arc 3 removed the active helper and tests;
> this report is retained only as historical evidence and must not be used as
> a current method recommendation.

## 1. Goal

Determine whether an ordinary complete-Bernoulli LA-MSPL fit can be rebuilt
after each site deletion and yield a finite, aligned private fixed-effect
jackknife covariance. This is feasibility only, not an interval or calibration
claim.

## 2. Implemented

Added an unexported delete-one-site refit helper and covariance kernel. Every
deletion reconstructs `gllvmTMB(..., estimator = "mspl")`, verifies the active
penalised objective and rebuilt MSPL data dimensions, then forms the covariance
only if all deletion refits pass.

## 3. Mathematical Contract

For site-deletion estimates \(\hat\beta_{(-s)}\), the private candidate is
\[
\widehat V_J = \frac{S-1}{S}\sum_s
(\hat\beta_{(-s)}-\bar\beta_{(-\cdot)})(\hat\beta_{(-s)}-\bar\beta_{(-\cdot)})^\top.
\]
It is computed only for aligned, finite `b_fix` vectors from the active
penalised LA-MSPL refits. Each refit also constructs its ordinary penalty-off
provenance tape, but that tape is not a jackknife covariance target.

## 3a. Decisions and Rejected Alternatives

Keep the helper internal and fail closed on any deletion failure. Reject a
Godambe/sandwich substitution (its additive-score contract is unavailable),
partial deletion matrices, public `vcov()`/`confint()` wiring, calibrated-SE
wording, and coverage claims.

## 4. Files Touched

- `R/mspl.R`
- `tests/testthat/test-mspl-api.R`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-jackknife-admission.md`
- `docs/dev-log/check-log.md`
- this report

No export, NAMESPACE, public documentation, NEWS, Rd, release artifact, or
remote-compute output changed.

## 5. Checks Run

`devtools::test(filter = "mspl-api", stop_on_failure = TRUE)` completed in
162.3 seconds with 679 passing expectations and no failures, warnings, or
skips. A direct four-fixture smoke took 18.6 seconds: logit, probit, cloglog,
and low-prevalence cloglog each admitted all 24 deletion refits with a finite
private covariance. `git diff --check` passed.

## 6. Tests of the Tests

The test checks deletion count, estimator ID, rebuilt `N_eff`/`X_mspl`
alignment, named fixed-effect targets, covariance symmetry, and finite private
SE candidates. It also verifies that fits with dropped responses or
`Xcoef_fixed` constraints fail closed before any deletion refit; an invalid
deletion input returns `delete_site_refit_failure` with no covariance.

## 7a. Issue Ledger

No issue, PR, public claim, or validation-register status changed. The MSPL
lane remains separately owned and experimental.

## 8. Consistency Audit

The helper is dot-prefixed and is not dispatched by `vcov()`, `confint()`,
profile methods, or ordinary standard-error paths. Existing public MSPL
inference refusals remain the controlling contract.

## 9. What Did Not Go Smoothly

The first new assertion used an invalid `vapply()` signature. The focused suite
exposed it before any commit; replacing it with a proper per-deletion predicate
made the test pass.

## 10. Known Residuals

This does NOT establish jackknife consistency, calibration, coverage, tests,
or a public interval. It covers only one deterministic ordinary logit fixture,
and neither q > 1, missing data, fixed coefficients, offsets, multi-trial
binomial data, structured tiers, nor a repeated-sampling campaign.
Any such campaign requires a fresh estimate, smoke receipt, and explicit
Totoro approval if it exceeds 30 minutes.

## 11. Team Learning

Independent Gauss/Fisher/Rose-style review passed after the helper was made to
reject dropped responses and fixed coefficients, align targets by
`X_fix_names`, and distinguish the covariance target from penalty-off fit
provenance. The immediate lesson is that each deletion must rebuild, rather
than mutate, the active estimator data contract.

## 12. Cross-Product Coverage

This private helper covers only ordinary, complete, single-trial Bernoulli
MSPL fits with q = 1, one common supported link, zero offsets, and `b_fix`.
It **does NOT cover** REML, ridge/penalty alternatives, VA/AGHQ/EVA engines,
missingness, aggregation, multiple tiers, q > 1, non-Bernoulli families,
public inference providers, likelihood comparison, or release admission.
