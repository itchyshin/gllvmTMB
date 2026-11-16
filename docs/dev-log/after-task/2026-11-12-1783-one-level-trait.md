# After Task: classed abort for a one-level fixed factor (#1783)

## 1. Goal

`y ~ 0 + trait` with a one-level trait died in `model.matrix()` with `contrasts can be applied only to factors with 2 or more levels`. The same data with `y ~ 1` fits.

## 2. Implemented

After the fixed-effect model frame is built, a factor predictor with fewer than two levels stops the fit with class `gllvmTMB_one_level_factor`. The message names the factor and its level, and points at `~ 1` or at glmmTMB for a single-response model. Two-or-more-level traits are unchanged.

## 3. Files Changed

- `R/fit-multi.R` — `.abort_one_level_fixed_factors()`
- `tests/testthat/test-1783-one-level-trait.R`
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-12-1783-one-level-trait.md`
- `docs/dev-log/after-task/2026-11-12-1783-one-level-trait.md`

No README, roxygen, Rd, design-doc, or validation-debt edit.

## 3a. Decisions and Rejected Alternatives

**Decision**: Abort before `model.matrix()` on any fixed-effect factor with fewer than two levels, not only the trait column.
**Rationale**: Base R raises the same contrasts error for every such factor. Naming the column covers the issue's `0 + trait` case and the same failure on another covariate (#1783).
**Rejected alternative**: Special-case only a one-level trait, and let other one-level factors keep the base-R error.
**Confidence**: high.

## 4. Checks Run

Installed main: the one-level test errored in `stats::model.matrix()`; the intercept-only and two-level tests passed. Source fix: FAIL 0 / 3 tests / 5 expectations. Neighbour `test-sanity-multi.R`: FAIL 0 / 14 tests / 84 expectations.

## 5. Tests of the Tests

- `#1783 one-level 0 + trait aborts with gllvmTMB_one_level_factor` — failure-before-fix. On main the error is the contrasts `simpleError`, so the class does not match.
- `#1783 one-level data still fits with an intercept-only formula` — boundary. Passes on main and with the fix.
- `#1783 two-level 0 + trait still fits` — boundary. Passes on main and with the fix.

## 6. Consistency Audit

`rg -n "gllvmTMB_one_level_factor" R tests NEWS.md` matches the abort and the test. The closing-keyword scan's only NEWS hit is the pre-existing "Fixes include:" sentence. This slice's NEWS bullet does not use those words.

## 7. Roadmap Tick

N/A.

## 8. What Did Not Go Smoothly

Nothing in the fit path. `screen_gllvmTMB()` still records the raw contrasts message in its design table, because that path catches `model.matrix()` and stores the message instead of stopping the fit.

## 9. Team Learning

- Boole: the formula is still refused; the message now names the factor and the working `~ 1` form.
- Pat: a one-trait data set is told to use an intercept, or glmmTMB if there is no trait structure.

## 10. Known Limitations and Next Actions

This does not add a T = 1 likelihood. `screen_gllvmTMB()` can still show the base-R contrasts string in `fixed_error`. Full `R CMD check` was not run. No validation-debt row changes.
