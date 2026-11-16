# After Task: screen records one-level fixed factor (#1783)

## 1. Goal

After #1786, `gllvmTMB()` aborts with class `gllvmTMB_one_level_factor`. `screen_gllvmTMB()` still stored the base-R contrasts string under `NOT_CHECKED` and did not surface the classed message.

## 2. Implemented

Before `model.matrix()`, the screen reuses `.abort_one_level_fixed_factors()` inside `tryCatch`. When a one-level fixed factor is present, the screen emits a classed warning (`gllvmTMB_one_level_factor`), continues, and writes a `fixed_effect_design` row with status `FAIL`, severity `one_level_factor`, and the same text as the fit path. The screen object still returns; it does not abort.

## 3. Files Changed

- `R/screen-gllvmTMB.R`
- `tests/testthat/test-1783-screen-one-level-trait.R`
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-13-1783-screen-one-level-trait.md`
- `docs/dev-log/after-task/2026-11-13-1783-screen-one-level-trait.md`

No README, roxygen, Rd, design-doc, or validation-debt edit.

## 3a. Decisions and Rejected Alternatives

**Decision:** Reuse the fit-path abort helper inside `tryCatch` rather than duplicating factor-level logic in the screen file.
**Rationale:** The fit and screen messages stay byte-identical; any future message edit in `.abort_one_level_fixed_factors()` applies to both paths.
**Rejected alternative:** Parse the contrasts `simpleError` after `model.matrix()` fails — brittle and keeps the unclassed string on other one-level covariates.
**Confidence:** high.

## 4. Checks Run

Branch: `test-1783-screen-one-level-trait.R` PASS 0 / 2 tests / 7 expectations; `test-1783-one-level-trait.R` PASS 0 / 3 tests. Main screen code (reverted locally): first screen test fails on class and design severity.

## 5. Tests of the Tests

- `#1783 screen records gllvmTMB_one_level_factor for one-level 0 + trait` — failure-before-fix on main screen path (no classed warning; contrasts text).
- `#1783 screen still checks a two-level 0 + trait fixed design` — boundary; passes on main and branch.

## 6. Consistency Audit

`rg -n "gllvmTMB_one_level_factor" R tests NEWS.md` lists fit abort, screen warn, and both test files. No `Fixes`/`Closes` in commit or NEWS bullet.

## 7. Roadmap Tick

N/A.

## 8. What Did Not Go Smoothly

Nothing blocking. Response-side binomial screening needed `y_raw` from `model.frame()` even when `model.matrix()` is skipped.

## 9. Team Learning

- Boole: screen and fit now share one factor-level guard; design severity `one_level_factor` is distinct from unit-tier `one_level_group`.
- Pat: pre-fit screen warns with the same intercept-only advice as `gllvmTMB()`, without stopping the screen call.

## 10. Known Limitations and Next Actions

Screen does not attempt to fit. Full `R CMD check` not run on this slice. refs #1783.
