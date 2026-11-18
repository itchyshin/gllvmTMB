# After Task: Name only the random-effect tiers a new row actually receives

**Branch**: `cursor/fix-1791-predict-unseen-species-7b3a`
**Date**: 2026-11-18
**Roles (engaged)**: Pat, Curie

## 1. Goal

`predict(newdata = )` listed `phylo_rr` / `phylo_diag` as re-added when the species column was present and every species level was unseen. `propto`, `diag_species`, `rr_B` and `diag_B` had the same all-out-of-range report.

## 2. Implemented

A tier is named in the re-added message only when at least one row's grouping level was in the fit. The same tiers stay in the set `predict()` knows how to re-add, so an unseen level does not produce the "omitted tier" warning. The `re_form` help sentence now says the drop is per tier: an unseen species drops the species and phylogenetic tiers, and a seen unit level still contributes its unit random effect.

## 3. Files Changed

- `R/methods-gllvmTMB.R`
- `man/predict.gllvmTMB_multi.Rd`
- `NEWS.md`
- `tests/testthat/test-1791-predict-unseen-species-message.R`
- `docs/dev-log/check-log.d/2026-11-18-1791-predict-unseen-species.md`
- `docs/dev-log/after-task/2026-11-18-1791-predict-unseen-species.md`

No README, vignette, or design-doc change. The likelihood and the formula grammar are unchanged.

## 4. Checks Run

Pre-fix installed package: 2 failures on `test-1791-predict-unseen-species-message.R`.

Source fix: that file FAIL 0 / ERROR 0 / 2 tests / 8 expectations. `test-1787-predict-missing-species.R` FAIL 0 / ERROR 0 / 3 tests / 7 expectations.

Not run: `devtools::check()` and the full suite.

## 5. Review

- Pat: the help sentence matches the per-tier behaviour.
- Curie: the new test separates a seen unit level from a row whose every grouping level is unseen.
