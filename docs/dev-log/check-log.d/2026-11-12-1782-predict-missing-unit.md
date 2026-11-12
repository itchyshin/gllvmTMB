# Check-log: predict() missing unit column (#1782)

**Goal:** Confirm `predict(newdata)` stops when the fitted unit column is absent and unit-level random effects would be re-added, instead of returning fixed effects while reporting that they were re-added.

**Commands:**

```sh
# Installed main (5b1f98ca):
Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-1782-predict-missing-unit.R", package = "gllvmTMB", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

# Source tree with the fix:
Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "1782-predict-missing-unit", load_package = "source", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "predict-wide-newdata-error", load_package = "source", reporter = "summary")'
Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "predict-newdata-alignment", load_package = "source", reporter = "summary")'

rg -n "gllvmTMB_predict_newdata_unit_missing" R tests man NEWS.md
rg -n "Fixes |Closes |Resolves " NEWS.md docs/dev-log/check-log.d/2026-11-12-1782-predict-missing-unit.md docs/dev-log/after-task/2026-11-12-1782-predict-missing-unit.md
```

**Results:** On installed main the missing-column test failed 2 expectations (the call succeeded and printed that `rr_B` and `diag_B` were re-added). The unseen-level guard passed. On the source fix: FAIL 0 / ERROR 0 / 2 tests / 6 expectations. Neighbours: `test-predict-wide-newdata-error.R` FAIL 0 / 1 test / 3 expectations; `test-predict-newdata-alignment.R` FAIL 0 / 12 tests / 33 expectations.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, and the full test suite. No likelihood or default changed.

**Claim boundary:** This covers a latent Gaussian fit whose unit column is dropped, kept with an unseen level, or kept for `re_form = ~0`. It does not change which tiers `predict()` can re-add, and it does not change a validation-debt row.
