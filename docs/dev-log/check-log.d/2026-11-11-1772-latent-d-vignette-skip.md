# 2026-11-11 — #1770 latent-d teaching vignette skip under R CMD check

## Scope

`tests/testthat/helper-vignette-source.R`, `test-latent-d-identifiable-range-doc.R` (vignette `test_that` only), `test-fix-1772-latent-d-vignette-skip.R`, `NEWS.md`.

Revision (reviewer BLOCKED on tautological test): planted `00_pkg_src` tree plus `_from` resolver so the skip-when-articles-absent test does not depend on `test_path()` seeing `local_dir()`. Original `expect_match` checks in `test-latent-d-identifiable-range-doc.R` unchanged.

## Commands

```sh
git checkout cursor/fix-1772-latent-d-vignette-skip-e4ae
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1772-latent-d-vignette-skip.R", reporter = "check")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 16
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-latent-d-identifiable-range-doc.R", reporter = "check")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 92 (vignette scan 8/8, not skipped)
```

Failure-before-fix (inline, not committed): a helper that returns NA paths without `skip()` fails `expect_condition(..., class = "skip")`; a helper that `skip("not a source checkout")` fails the `pkgdown article vignettes` message match.

## Deliberately not run

- Full `devtools::test()` / `devtools::check()` (CI verifier; this VM has no installed `gllvmTMB`).
- `pkgdown::check_pkgdown()` (NEWS citation only).

## Stale-wording scans

```sh
rg -n "not a source checkout|pkgdown article vignettes|gllvmTMB_skip_if_latent_d_teaching_vignettes_absent|skip_if_not" \
  tests/testthat/test-fix-1772-latent-d-vignette-skip.R \
  tests/testthat/test-latent-d-identifiable-range-doc.R \
  tests/testthat/helper-vignette-source.R NEWS.md
rg -n "grepl\(\"covariance-correlation" tests/testthat/test-fix-1772-latent-d-vignette-skip.R
rg -n "#1770|#1772" NEWS.md tests/testthat/helper-vignette-source.R tests/testthat/test-fix-1772-latent-d-vignette-skip.R
```

Verdict: tautological `grepl` checkout test is gone. R/`man/` `skip_if_not(..., "not a source checkout")` in the original file is unchanged (that is #1772's source-scan conversion, not this skip). NEWS cites #1770.
