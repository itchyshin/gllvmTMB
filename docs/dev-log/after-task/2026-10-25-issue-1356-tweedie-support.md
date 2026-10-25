# After Task: refuse a negative tweedie response

**Branch**: `cursor/issue-1356-tweedie-support-c93d`
**Date**: `2026-10-25`
**Roles (engaged)**: Curie, Gauss, Rose

## 1. Goal

Close the remaining #1356 tweedie report: a negative `y` on `tweedie()`
fitted and reported convergence 0, even though the density is not
defined for y < 0.

## 2. Implemented

`gllvmTMB()` now aborts on observed tweedie rows with y < 0, class
`gllvmTMB_tweedie_negative_y`, before MakeADFun. Zeros remain allowed
(the compound Poisson-Gamma point mass).

## 3. Files Changed

- `R/fit-multi.R`: tweedie support check
- `tests/testthat/test-family-support-checks.R`
- `NEWS.md`
- `docs/dev-log/after-task/2026-10-25-issue-1356-tweedie-support.md`
- `docs/dev-log/check-log.d/2026-10-25-issue-1356-tweedie-support.md`

## 3a. Decisions and Rejected Alternatives

Decision: y >= 0 only; no integrality requirement. Rationale: Tweedie
admits continuous positive mass. Rejected: also refuse non-integers
(wrong support). Confidence: high.

Binomial / beta-binomial integrality is still a maintainer ruling and
is not in this slice.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-25-issue-1356-tweedie-support.md`.

## 5. Tests of the Tests

The new test fails if a negative y still reaches the optimiser. It
does not fit a valid tweedie model.

## 6. Consistency Audit

- `rg -n "gllvmTMB_tweedie_negative_y" R tests NEWS.md`
- `rg -n "tweedie_rows" R/fit-multi.R`

## 7. Roadmap Tick

N/A

## 7a. GitHub Issue Ledger

- Inspected #1356. Poisson / nbinom2 already closed. This slice is the
  tweedie comment. Binomial integrality remains, so the PR uses
  Refs #1356.

## 8. What Did Not Go Smoothly

None.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Gauss: the check matches the Tweedie support y >= 0 used by the
existing Gamma/lognormal positive-y gate's neighbour families.

Curie: the test reuses the #1356 fixture so the abort is the same
shape as the poisson/nbinom2 pins.

Rose: NEWS names the class and does not claim the whole issue closed.

## 10. Known Limitations And Next Actions

Still open on #1356: binomial / beta-binomial integrality when
proportions are supplied with weights.
