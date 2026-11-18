# Check-log: censored Poisson left tail (#1748)

**Goal:** Confirm a right-censored `censored_poisson` row has a finite objective and gradient when `C * eta` is very negative, and still matches `log(pgamma())` where that value is finite.

**Commands:**

```sh
# Pre-fix installed package:
R_LIBS=/tmp/r-lib NOT_CRAN=true Rscript --vanilla -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-1748-censored-poisson-tail.R", load_package = "none", reporter = "summary")'

# After R CMD INSTALL of this branch:
R_LIBS=/tmp/r-lib NOT_CRAN=true Rscript --vanilla -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-1748-censored-poisson-tail.R", load_package = "none", reporter = "summary"); testthat::test_file("tests/testthat/test-censored-poisson.R", load_package = "none", reporter = "summary")'
# #1603 uncensored left tail, helpers plus that one test:
R_LIBS=/tmp/r-lib NOT_CRAN=true Rscript --vanilla -e 'library(gllvmTMB); library(testthat); test_file("/tmp/test-1603-only.R", load_package = "none", reporter = "summary")'
```

**Results:** Pre-fix: 17 failures, 0 errors. `fn` and `gr` were NaN (for C = 1 at eta = -800 the objective was NaN against 12800). After install: `test-1748` FAIL 0 / ERROR 0 / 1 test / 62 expectations / 0 warnings. `test-censored-poisson.R` FAIL 0 / ERROR 0 / 15 tests. The #1603 uncensored left-tail test FAIL 0 / ERROR 0 / 72 expectations, including the `1e-10` comparison.

**Not run:** `devtools::check()` and the full suite.

**Claim boundary:** Finite objective and gradient for censoring limits 1, 2 and 3 at eta in {-5, -50, -150, -250, -300, -400, -800} on a fixed-effect Gaussian-free `cbind(y, censored) ~ 0 + trait` fit, plus agreement with `log(pgamma())` wherever that reference is finite. The uncensored Poisson row is the previous formula.
