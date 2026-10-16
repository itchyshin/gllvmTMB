# After Task: predict()/fitted() no longer return internal sentinels (#1406)

**Branch**: `claude/jolly-lovelace-b8qzyl` (stacked on #1480)
**Date**: 2026-10-16

## 1. Goal
In-sample `predict()` / `fitted()` returned `species = "placeholder"` (a column
`gllvmTMB()` synthesises when no species/cluster grouping is given) and, on wide
mixed-family fits, the auto-generated `.family_wide_` column. Neither was supplied
by the user.

## 2. Implemented
`predict.gllvmTMB_multi()` (in-sample branch) drops the species column when every
value is `"placeholder"`, and does not carry a `.family_wide_`-style label.
User-supplied species columns and user/iSDM family labels are unchanged.

## 3. Files Changed
- `R/methods-gllvmTMB.R`
- `tests/testthat/test-predict-sentinel-leak.R` (new)
- this report

## 4. Checks Run
No R is available in this sandbox (CRAN and apt blocked), so nothing ran locally,
including `devtools::document()`. No roxygen block changed, so no `man/` output is
expected. Verification is CI only: red proof on the base, green on this head.

## 5. Tests of the Tests
Failure-before-fix: the two fit-based tests assert the exact column names from the
issue repro, which on base include `species` and `.family_wide_`.
