# Check-log: screen one-level fixed factor (#1783)

**Goal:** `screen_gllvmTMB()` records class `gllvmTMB_one_level_factor` when a fixed-effect factor has one level (the #1783 `0 + trait` case), without aborting. The design table names the factor instead of the bare contrasts string.

## Commands

```sh
Rscript --vanilla -e 'pkgload::load_all("."); res <- testthat::test_file("tests/testthat/test-1783-screen-one-level-trait.R", reporter = "summary"); print(as.data.frame(res)[, c("test","failed","error")])'
Rscript --vanilla -e 'pkgload::load_all("."); res <- testthat::test_file("tests/testthat/test-1783-one-level-trait.R", reporter = "summary"); print(as.data.frame(res)[, c("test","failed","error")])'
```

**Main (pre-fix) screen test:** `#1783 screen records gllvmTMB_one_level_factor` fails — no classed warning; `fixed_effect_design` is `NOT_CHECKED` with the contrasts text.

**Branch:** both screen and fit one-level files PASS 0 / FAIL 0.

## Scans

```sh
rg -n "gllvmTMB_one_level_factor" R tests NEWS.md
rg -n "Fixes |Closes |Resolves " NEWS.md docs/dev-log/check-log.d/2026-11-13-1783-screen-one-level-trait.md
```

**Not run:** `devtools::check()`, full suite, `pkgdown::check_pkgdown()`. No formula grammar, likelihood, or default change beyond the screen diagnostic.
