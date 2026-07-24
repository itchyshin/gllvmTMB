# After-task report -- Design 97 full-covariance JJ discrimination stop

## 1. Goal

Implement a new private q=2 full-covariance Jaakkola--Jordan discriminator
against a two-dimensional Gaussian-Hermite marginal-likelihood comparator.

## 2. Implemented

Only `dev/design97-fullcov-jj/` and Design-97 developer records changed. No
package source, R API, documentation surface, EVA comparator, structured prior,
campaign, cluster computation, merge, push, or PR work occurred.

## 3a. Decisions and Rejected Alternatives

`docs/design/97-fullcov-jj-discrimination.md` freezes the estimator, DGP,
starts, health conditions, quadrature use, telemetry, and ordered closeout
labels. Design 96 remains an immutable predecessor, not input or evidence.

## 4. Files Touched

- `dev/design97-fullcov-jj/`: private TMB objective, R oracle, Gate-1 test,
  one-shot runner/finalizer, and immutable JSON results.
- `docs/design/97-fullcov-jj-discrimination.md`: contract.
- `docs/dev-log/handover/2026-07-24-codex-handover-design97.md`: resume record.
- `docs/dev-log/check-log.md` and this report: closure records.

The private objective uses an unconstrained per-unit Cholesky factor. The
profiled JJ omega terms are algebraically cancelled before AD; this makes the
zero global start finite. Independent R code supplies the same objective,
31/41/61-node GH calculations, fixed-global diagonal/full comparisons, and
the GH marginal comparator.

## 5. Checks Run

Ran:

```sh
Rscript --vanilla dev/design97-fullcov-jj/run-gate1-tests.R
Rscript --vanilla dev/design97-fullcov-jj/run-discriminator.R
Rscript --vanilla dev/design97-fullcov-jj/finalize-interrupted.R
git diff --check
```

Gate 1 compiled with Apple clang and TMB 1.9.21 and passed R/C++ equality,
central-gradient agreement, zero-start AD safety, GH-bound convergence,
positive-definiteness, diagonal/sign-flipped covariance checks, and row
permutation invariance.

## 6. Tests of the Tests

The `fixed` fixture and Gate-2 record were written. Both local fits were
healthy: diagonal GH gap `0.427110200998`; full-covariance GH gap
`0.426107003066`, an improvement of `0.001003197932`. This is only the
predeclared approximation comparison.

The one-shot runner stopped after Gate 2, before producing Gate 3 or a summary.
It was not rerun. `finalize-interrupted.R` exclusively created the missing
Gate-3 stop receipt and terminal `summary.json` with
`SMOKE_STOP / RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD`.

## 7a. Issue Ledger

No package issue was opened. The Design-97 runner interruption is retained as
the local private issue: `RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD`; it is closed
for this design by the immutable stop receipt, not repaired in place.

## 8. Consistency Audit

`dev/design97-fullcov-jj/results/` contains six immutable JSON records:
manifest, two fixtures, Gate 2, Gate-3 interruption receipt, and summary. The
manifest source SHA-256 is
`444275a2920c90992c2282f7d54e5a9183242340cf7fbc118e298ed2d3760f37`.

## 9. What Did Not Go Smoothly

The runner did not create its Gate-3 record or summary after retaining Gate 2.
The execution was not replayed. The dedicated exclusive-create finalizer
preserved the incomplete state as `SMOKE_STOP`.

## 10. Known Residuals

It does not establish free-global recovery, mean-field causality, JJ bias,
fixture information, calibration, EVA parity, or any public capability. The
small fixed-global gap improvement cannot be promoted because the free-global
discriminator was not recorded.

The exact cause of the interruption is not established from retained output.
It is a lead for a different design, never a reason to amend or retry Design 97.

## 11. Team Learning

Gauss/Noether's early zero-curvature review prevented a potentially undefined
AD path at the global start. Rose's review made the fixture, telemetry, and
mutually exclusive closeout contract concrete before execution.

## 12. Cross-Product Coverage

`git diff 1e113e32 -- src R man NAMESPACE DESCRIPTION inst vignettes README.md
NEWS.md _pkgdown.yml` is empty. Earlier Design 72/85/86/90/91/94/95/96 paths
are unchanged.

This arc covers only a private q=2 Bernoulli-logit Cholesky-q objective,
independent GH oracle, and one incomplete fixed-global comparison. It does NOT cover the package engine, public controls, EVA, Laplace, structured priors,
long-format mapping, missing data, REML, aggregation, recovery, calibration,
or any inference/provider surface.

## Next safe action

Design 97 is terminal at `SMOKE_STOP`; never rerun this fixture/root or fill in
Gate 3. A new approved design may inspect the runner interruption without using
Design 97 as free-global evidence.
