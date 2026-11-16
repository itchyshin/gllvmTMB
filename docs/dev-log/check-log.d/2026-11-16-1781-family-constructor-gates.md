# Check-log: resolve family constructors at gllvmTMB() entry (refs #1781)

**Goal:** Confirm `family = gaussian` (the function) is resolved before the `temporal_latent()` and `column_coef()` gates, and that those routes match `family = gaussian()`.

**Commands:**

```sh
Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-1781-family-constructor.R", package = "gllvmTMB", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

rg -n "gllvmTMB_resolve_family_constructors" R/gllvmTMB.R
rg -n "Fixes |Closes |Resolves " NEWS.md tests/testthat/test-1781-family-constructor.R docs/dev-log/check-log.d/2026-11-16-1781-family-constructor-gates.md docs/dev-log/after-task/2026-11-16-1781-family-constructor-gates.md
```

**Results:** FAIL 0 / ERROR 0 / 6 tests / 22 expectations. The four existing tests are unchanged. The two new tests (`temporal_latent`, `column_coef`) each compare `family = gaussian` against `family = gaussian()`. The closing-keyword scan's only NEWS hit is the pre-existing sentence ("Fixes include:"), not this bullet.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, the full suite, and neighbour temporal / column-coef files. No likelihood, formula grammar, or default changed.

**Claim boundary:** This shows an uncalled constructor is called before the wide/traits rewrite and before the `column_coef` and `temporal_latent` gates on the tiny Gaussian examples. It does not change a validation-debt row. Character `family = "gaussian"` is unchanged and is not claimed here.
