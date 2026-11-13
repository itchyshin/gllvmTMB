# Check-log: one-level 0 + trait contrasts error (#1783)

**Goal:** Confirm `y ~ 0 + trait` with a one-level trait stops with class `gllvmTMB_one_level_factor`, naming the factor, instead of the bare base-R contrasts error. `y ~ 1` on the same data, and a two-level `0 + trait`, still fit.

**Commands:**

```sh
# Installed main (5b1f98ca):
Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-1783-one-level-trait.R", package = "gllvmTMB", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

# Source tree with the fix:
Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "1783-one-level-trait", load_package = "source", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "sanity-multi$", load_package = "source", reporter = "summary")'

rg -n "gllvmTMB_one_level_factor" R tests NEWS.md
rg -n "Fixes |Closes |Resolves " NEWS.md docs/dev-log/check-log.d/2026-11-12-1783-one-level-trait.md docs/dev-log/after-task/2026-11-12-1783-one-level-trait.md
```

**Results:** On installed main the one-level test errored with `contrasts can be applied only to factors with 2 or more levels` from `model.matrix()` inside `gllvmTMB_multi_fit()`. The intercept-only and two-level tests passed. On the source fix: FAIL 0 / ERROR 0 / 3 tests / 5 expectations. Neighbour `test-sanity-multi.R`: FAIL 0 / ERROR 0 / 14 tests / 84 expectations (one pre-existing implicit-`unit` deprecation warning).

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, `screen_gllvmTMB()`, and the full test suite. No likelihood, formula grammar, or default changed.

**Claim boundary:** This is an earlier, classed stop for a fixed-effect factor with fewer than two levels. It does not add a single-response model, and it does not change a validation-debt row.
