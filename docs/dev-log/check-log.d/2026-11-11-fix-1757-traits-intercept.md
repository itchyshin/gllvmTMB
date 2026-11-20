## 2026-11-11 — #1757: traits() compact RHS implicit intercept

**Branch:** `cursor/fix-1757-traits-implicit-intercept-0b8b`

```sh
R_LIBS=~/R/library R CMD INSTALL -l ~/R/library --no-multiarch .
R_LIBS=~/R/library Rscript -e 'testthat::test_file("tests/testthat/test-fix-1757-traits-implicit-intercept.R")'
R_LIBS=~/R/library Rscript -e 'testthat::test_file("tests/testthat/test-traits-keyword.R")'
```

Regression test fails on `main` traits-keyword (coef 3 vs 6; logLik mismatch). Deliberately not run: full `devtools::test()`, pkgdown.
