# After Task: preserve qualified VA starts during polishing

**Branch:** `codex/fixed-effect-normal-priors`
**Date:** 2026-11-05
**Status:** Local package check passed. Three-platform CI and merge are pending.

## 1. Goal

Repair a reproduced variational-optimizer failure that made a package regression test lose a qualified start during polishing.

## 2. Implemented

A polish candidate no longer replaces an already eligible start when the candidate fails the existing health rule and improves the objective by no more than an absolute `1e-6`. The optimizer records the rejected candidate's objective, convergence code, gradient and reason. Materially lower candidates retain the existing selection behavior. The TMB state is re-evaluated at the retained parameters after a rejection.

## Mathematical Contract

The likelihood, variational objective and health limits are unchanged. For a current point with objective `F_old` and a candidate `F_new`, the narrow retention rule applies only if the current point passes the existing eligibility rule, the candidate fails it, and `F_old - F_new <= 1e-6`. A close objective does not prove equal parameters or calibrated uncertainty. The final adjudication considers eligible starts and does not establish that all lower ineligible points are harmless.

## 3a. Decisions and Rejected Alternatives

Use an absolute bound, which is more conservative here than the scale-adjusted consensus tolerance and is unaffected by adding an objective constant. Do not increase the gradient threshold, rewrite the regression to accept fewer starts, or discard candidate diagnostics.

## 4. Files Touched

`R/va-r3-proto.R`, `tests/testthat/test-va-r3-polish-health.R`, and this report. The existing `test-va-r3-prototype.R` fixture was not weakened. No public formula, family, argument, or generated help file changed.

## 5. Checks Run

On the exact-main seed-12 truncated-NB2 fixture, start 4 had objective `1201.086795275519` and maximum gradient `0.0005588165` before polishing. A polish candidate improved the objective by about `1.26e-7` but increased the gradient to `0.005852645`, above the unchanged `0.005` health limit. The old code replaced the qualified point and reported three eligible starts. The repaired run retained it, returned four eligible starts, and preserved the three-start consensus with a strict-convergence anchor.

`test-va-r3-polish-health.R` passed 23 assertions covering the objective boundary, materially lower candidates, missing values, both polish solvers, rejection metadata, and state restoration for profiled and nonprofiled objectives. The existing `test-va-r3-prototype.R` passed 645 assertions, including the original fixture, and `test-va-optimizer-selection.R` passed. An independent read-only review assessed the rule and its limits.

The clean integration candidate also contains the fixed-prior and AGHQ changes and the exact heads of PRs #1727 and #1734. Its combined targeted regression tests passed. The package check is running and flagged binary long-versus-wide assertions that had assumed Laplace. The integration candidate now keeps the original strict comparison with automatic refitting disabled and adds an AGHQ comparison at a common parameter vector and common frozen quadrature adaptation. Both tests passed 21 assertions. On candidate `d85cb2a70ab05cf9b0952c3389038790152027d3`, a CI-style `R CMD check --no-manual --ignore-vignettes` passed with 29,809 assertions, 67 test warnings and 1,285 skips. The check reported two existing notes: long snapshot filenames and an unexported TMB call. The source archive SHA-256 was `24dbdb36d1d77caacc91068b65fbf38e6be86a0ab66f4bc666da93fc67a79aae`.

## 6. Tests of the Tests

The new helper test failed before implementation. The original seed-12 fixture failed on exact main and on the previous candidate, and passed after the repair with its assertions unchanged. The mock-solver tests exercise routing and state, not numerical optimizer recovery; the real fixture is the numerical evidence.

## 7. Roadmap Tick

N/A. No roadmap status changed.

## 7a. Issue Ledger

No issue or PR was modified. PRs #1727 and #1734 are combined in a temporary integration candidate; neither source branch was edited. The long-versus-wide regression is also changed in that candidate to test Laplace and automatic AGHQ separately.

## 8. Consistency Audit

`rg -n 'VA_R3_HEALTH_GRADIENT_TOL|polish|agreement_eligible' R/va-r3-proto.R tests/testthat/test-va-r3-prototype.R`: the existing health threshold and original regression assertions remain unchanged. Both polish solvers call the bounded rule; the tests separately exercise their rejected-candidate records.

## 9. What Did Not Go Smoothly

The regression appeared to be a platform-sensitive test failure. Inspecting all four optimizer traces showed that a qualified primary point was actually replaced by a point with a worse gradient after an almost negligible objective improvement. The initial package-only patch also needed a whitespace-normalized synthetic evidence transcript; the original transcript hash is retained alongside it.

## 10. Known Residuals

The objective bound is a narrow selection policy, not a proof that tied parameter vectors are equivalent. Other data sets, recovery, uncertainty calibration and all cross-platform results remain unvalidated. The current start adjudication excludes ineligible starts from its consensus, so a materially lower ineligible candidate is recorded but may not determine the final fit. Three-platform CI and merge remain outstanding. Two developer-local fitted-figure snapshots differ on this machine; both are skipped in CI, and the reviewed reference images were left unchanged.

## 11. Team Learning

An independent reviewer checked the bounded rule, the two solver paths, rejection records and restored state. The reviewer highlighted that mocked optimizers do not establish numerical recovery, so this report treats the seeded fitted example as the numerical evidence.

## 12. Cross-Product Coverage

The checks cover an ordinary truncated-NB2 variational fixture, synthetic optimizer-boundary tests and profiled/nonprofiled state restoration. This work does NOT cover other families or structured providers, general VA recovery, calibrated uncertainty, three-platform CI or a released package.
