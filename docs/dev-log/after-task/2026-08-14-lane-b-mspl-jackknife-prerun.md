# After Task: private LA-MSPL jackknife repeated-sampling pre-run

## 1. Goal

Turn the admitted private delete-one-site jackknife covariance into a
failure-retaining repeated-sampling candidate and measure calibration cost
without making an interval or public-inference claim.

## 2. Implemented

Added `jackknife_only` to the private uncertainty runner. It uses the existing
active-objective deletion helper, records a typed jackknife status, candidate
SE, and diagnostic-band inclusion for every target row, and leaves Hessian and
profile routes unrun in this procedure.

## 3. Mathematical Contract

The candidate is the standard complete delete-one-site covariance
\(\widehat V_J=(S-1)S^{-1}\sum_s(\widehat\beta_{(-s)}-\bar\beta)
(\widehat\beta_{(-s)}-\bar\beta)^\top\). A failed deletion gives no covariance;
it is retained as unavailable and non-covering in the unconditional diagnostic
denominator.

## 3a. Decisions and Rejected Alternatives

The procedure is distinct from numerical-Hessian and profile routes. It does
not call the penalty-off provenance tape, calculate a reduced-deletion
covariance, substitute another method after failure, expose public inference,
or label its nominal diagnostic band a confidence interval.

## 4. Files Touched

- `inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R`
- `tests/testthat/test-mspl-uncertainty-runner.R`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-jackknife-calibration-prerun.md`
- `docs/dev-log/check-log.md`
- this report

## 5. Checks Run

`test-mspl-uncertainty-runner.R` passed 13 expectations. The direct four-cell
x four-replicate local pre-run wrote exactly 48 unique receipts; all full fits,
all 384 deletion refits, and all private covariance candidates were finite and
admitted. Re-running the summary after provenance hardening passed. `git diff
--check` passed.

## 6. Tests of the Tests

The runner test constructs retained failed jackknife rows and asserts zero
availability and unconditional coverage. It then changes `source_sha` and
asserts that the summary refuses the stale receipt.

## 7a. Issue Ledger

No issue, validation-register status, public documentation, export, or public
claim changed.

## 8. Consistency Audit

The runner calls `.gllvmTMB_mspl_jackknife_feasibility()`, which rebuilds every
deletion with `estimator = "mspl"` and checks the active penalised objective.
The manifest binds every receipt's procedure, campaign ID, and source hash.

## 9. What Did Not Go Smoothly

The first implementation checked receipt keys but not receipt provenance. A
fresh Fisher/Gauss review caught this P1 defect; the summary now rejects a
procedure, campaign, or source mismatch, with a regression test.

## 10. Known Residuals

Four repeated datasets cannot calibrate coverage. The 83-second local pre-run
projects a 500-replicate four-cell campaign to roughly 45 minutes on four
workers, so remote execution remains approval-gated. q > 1, structured or
missing-data regimes, bootstrap, public inference, and release claims remain
outside scope.

## 11. Team Learning

Fisher/Gauss review passed after provenance and failed-candidate regressions
were added. A receipt-key bijection alone is insufficient: source/procedure
identity must be bound to the frozen manifest too.

## 12. Cross-Product Coverage

The private candidate covers only the four ordinary complete-Bernoulli q = 1
fixtures and their three fixed effects. It does NOT cover calibrated
uncertainty, q > 1, REML, alternative penalties or engines, missingness,
aggregation, multi-trial data, structured/spatial tiers, bootstrap, public
`vcov()`/`confint()`/profile providers, a general link or family, or any
public-API claim.
