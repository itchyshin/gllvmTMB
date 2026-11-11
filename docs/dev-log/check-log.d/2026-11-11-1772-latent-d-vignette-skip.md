# 2026-11-11 — #1770 latent-d teaching vignette skip under R CMD check

## Scope

`tests/testthat/helper-vignette-source.R`, `test-latent-d-identifiable-range-doc.R` (vignette `test_that` only), `test-fix-1772-latent-d-vignette-skip.R`, `NEWS.md`.

Revision 2 (reviewer BLOCKED on tautological test): planted `00_pkg_src` tree plus `_from` resolver so the skip-when-articles-absent test does not depend on `test_path()` seeing `local_dir()`.

Revision 3 (reviewer BLOCKED on test-fix-1772): drop untyped `expect_error(readLines(NA))`, drop the source-grep of `test-latent-d-identifiable-range-doc.R`, drop the planted `file.exists(../../vignettes)` setup assert. Main-vignette `expect_match` now runs unconditionally (hard-fail if `gllvmTMB.Rmd` is missing); skip applies only to the article block.

## Commands

```sh
git checkout cursor/fix-1772-latent-d-vignette-skip-e4ae
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1772-latent-d-vignette-skip.R", package = NULL, reporter = "check")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 13  (3 tests)
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-latent-d-identifiable-range-doc.R", package = NULL, reporter = "check")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 92  (5 tests; main vignette 2/2, articles 6/6, neither skipped)
```

## Deliberately not run

- Full `devtools::test()` / `devtools::check()` (CI verifier; this VM has no installed `gllvmTMB`).
- `pkgdown::check_pkgdown()` (NEWS citation only).

## Stale-wording scans

```sh
rg -n "not a source checkout|pkgdown article vignettes|gllvmTMB_skip_if_latent_d_teaching_vignettes_absent|skip_if_not" \
  tests/testthat/test-fix-1772-latent-d-vignette-skip.R \
  tests/testthat/test-latent-d-identifiable-range-doc.R \
  tests/testthat/helper-vignette-source.R NEWS.md
rg -n "expect_error\\(readLines|grepl\\(\\\"covariance-correlation|test-latent-d-identifiable-range-doc" \
  tests/testthat/test-fix-1772-latent-d-vignette-skip.R
rg -n "#1770|#1772" NEWS.md tests/testthat/helper-vignette-source.R tests/testthat/test-fix-1772-latent-d-vignette-skip.R
```

Verdict: B1/B2/nit asserts are gone. Skip gate keys only on the two article paths. R/`man/` `skip_if_not(..., "not a source checkout")` in the original file is unchanged (that is #1772's source-scan conversion, not this skip). NEWS cites #1770 and says the main vignette still scans under `R CMD check`.
