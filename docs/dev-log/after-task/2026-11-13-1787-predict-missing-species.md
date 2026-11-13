# After Task: stop predict() when newdata drops the species column (#1787)

## 1. Goal

`predict(newdata)` without the fitted species column returned the fixed-effects prediction and still reported that `phylo_rr` and/or `phylo_diag` had been re-added.

## 2. Implemented

When those phylogenetic tiers would be re-added and the species column is absent, `predict()` stops with class `gllvmTMB_predict_newdata_species_missing` and points at `re_form = ~0`. `re_form = ~0` still returns the fixed-effects prediction without that column. An unseen level of a column that is present is unchanged.

## 3. Files Changed

- `R/methods-gllvmTMB.R` — the abort, and one sentence on `re_form`
- `man/predict.gllvmTMB_multi.Rd` — the same sentence
- `tests/testthat/test-1787-predict-missing-species.R`
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-13-1787-predict-missing-species.md`
- `docs/dev-log/after-task/2026-11-13-1787-predict-missing-species.md`

No README, design-doc, or validation-debt edit. `roxygen2` is not installed here; the Rd sentence was edited to match the roxygen block.

## 3a. Decisions and Rejected Alternatives

**Decision**: Stop, rather than warn and return fixed effects.
**Rationale**: The returned numbers matched `re_form = ~0` while the message said the random effects were included (#1787). A warning is easy to miss on that path.
**Rejected alternative**: Only stop claiming the tiers were added, and still return fixed effects. That keeps the silent wrong predictor.
**Confidence**: high.

## 4. Checks Run

Installed main: failed expectations on the missing-column test; the unseen-level test passed. Source fix: FAIL 0 / 2 tests / 6 expectations.

## 5. Tests of the Tests

- `#1787 predict() stops when newdata omits the species column` — failure-before-fix. The two `expect_error` calls fail on main because `predict()` succeeds. The `re_form = ~0` and full-versus-fixed checks pass on both.
- `#1787 an unseen species level is not the missing-column error` — boundary. Passes on main and with the fix.

## 6. Consistency Audit

`rg -n "gllvmTMB_predict_newdata_species_missing" R tests man NEWS.md` matches the abort and the test. The class name is not in the help text; the help states the stop in plain language.

## 7. Roadmap Tick

N/A.

## 8. What Did Not Go Smoothly

`roxygen2` is not installed in this environment, so `man/predict.gllvmTMB_multi.Rd` was updated by hand to the same sentence as the roxygen block.

## 9. Team Learning

- Pat: the error names the missing column and the `re_form = ~0` alternative.
- Emmy: unseen levels stay on the existing allow-unseen path. Only a missing column aborts.

## 10. Known Limitations and Next Actions

Other species-indexed tiers (`propto`, `diag_species`) already guard on `any(!is.na(sp_id))` before claiming re-addition. Unit-level tiers are unchanged. A fit with no phylogenetic tiers does not require the species column for this check. Full `R CMD check` was not run.
