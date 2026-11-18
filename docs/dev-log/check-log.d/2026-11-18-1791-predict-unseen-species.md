# Check-log: unseen species predict message (#1791)

**Goal:** Confirm `predict(newdata = )` names a random-effect tier in the re-added message only when a row's grouping level was in the fit.

**Commands:**

```sh
R_LIBS=/tmp/r-lib NOT_CRAN=true Rscript --vanilla -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-1791-predict-unseen-species-message.R", load_package = "none", reporter = "summary")'

R_LIBS=/tmp/r-lib NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE, quiet = TRUE); testthat::test_file("tests/testthat/test-1791-predict-unseen-species-message.R", load_package = "none", reporter = "summary"); testthat::test_file("tests/testthat/test-1787-predict-missing-species.R", load_package = "none", reporter = "summary")'
```

**Results:** Installed package (pre-fix `predict`): 2 failures, 0 errors. The unseen-species message still contained `phylo_`, and the all-unseen call still emitted a re-added message. Source fix: `test-1791` FAIL 0 / ERROR 0 / 2 tests / 8 expectations / 0 warnings. `test-1787` FAIL 0 / ERROR 0 / 3 tests / 7 expectations / 0 warnings.

**Not run:** `devtools::check()` and the full suite.

**Claim boundary:** The message and the fixed-effects comparison cover one Gaussian `phylo_indep` plus `indep` fit. `propto` and `diag_species` use the same "name the tier only on a matched row" gate and were not given their own fit in this slice.
