# Check-log: uncalled family constructor (#1781)

**Goal:** Confirm `family = gaussian` (the function) no longer dies in `expand_multinomial_response()` with `as.character()` on a closure, and that `family = multinomial` (the function) is still expanded.

**Commands:**

```sh
# Installed main (5b1f98ca), before the source fix was loaded:
Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-1781-family-constructor.R", package = "gllvmTMB", reporter = "silent"); print(as.data.frame(res)[, c("test","failed","error")])'

# Source tree with the fix (pkgload, compile = FALSE):
Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "1781-family-constructor", load_package = "source", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

rg -n "as.character\(f\)" R/gllvmTMB.R
rg -n "gllvmTMB_family_constructor" R tests NEWS.md
rg -n "Fixes |Closes |Resolves " NEWS.md docs/dev-log/check-log.d/2026-11-12-1781-family-constructor.md docs/dev-log/after-task/2026-11-12-1781-family-constructor.md
```

**Results:** On installed main, the character-family guard passed (2 expectations) and the three constructor tests errored (`cannot coerce type 'closure'`). On the source fix: FAIL 0 / ERROR 0 / 4 tests / 8 expectations. The closing-keyword scan's only NEWS hit is a pre-existing sentence ("Fixes include:"), not this bullet.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, the full test suite, and a neighbour mixed-family file. No likelihood, formula grammar, or default changed.

**Claim boundary:** This shows the constructor is called before the multinomial scan on the tiny Gaussian and multinomial examples. It does not change a validation-debt row and does not claim a new family.
