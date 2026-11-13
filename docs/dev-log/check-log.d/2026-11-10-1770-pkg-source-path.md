# 2026-11-10 — #1770 package-root source scans under R CMD check

Branch: `cursor/fix-1770-pkg-source-path-efc6`

## Change

- `tests/testthat/helper-gllvmTMB-cpp-source.R` — one resolver for the dev tree, the two-level `*.Rcheck/00_pkg_src` layout, and the three-level layout. A missing file stops. `gllvmTMB_cpp_source_*()` stays the C++ wrapper.
- Source scans that used `test_path("..", "..", ...)` and `skip_if*()` when the file was missing now call that resolver. Scan patterns are unchanged.
- `tests/testthat/test-fix-1770-pkg-source-path.R` — planted `*.Rcheck` guard. On main the new resolver is missing and the old skip strings are still in the scan files, so this file fails there.
- `NEWS.md` — one development bullet. No model or likelihood change. `vignettes/articles` stays out of the built package, so the latent-rank article scan errors under `R CMD check` instead of skipping.

## Commands

```text
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1770-pkg-source-path.R", reporter = "summary")'
# DONE, 0 failures

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1758-cpp-source-path.R", reporter = "summary")'
# DONE, 0 failures

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R", reporter = "summary")'
# DONE, 0 failures (dev tree)

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-latent-d-identifiable-range-doc.R", reporter = "summary")'
# DONE, 0 failures in the git checkout (articles are present)

# Planted two-level *.Rcheck with vignettes/articles omitted (tarball layout):
# test-latent-d-identifiable-range-doc.R
# Error: Package file vignettes/articles/covariance-correlation.Rmd is not available
# ad-safe clamps, julia Rd, profile_targets Rd, tmbprofile_wrapper Rd: DONE, 0 skips
```

Source-scan tests that do not need a fitted model were also run from a planted `tests/testthat` whose only sources were `00_pkg_src/gllvmTMB/` (no `../../src` or `../../R`). The source-scan expectations passed. Fit tests in those files failed locally because `gllvmTMB` is not installed in this VM. `test-bfgs-compiled-objectives.R`, `test-g2n-compiled-cloglog-unit.R`, and `test-g3-compiled-cloglog-unit.R` were not executed here (no TMB toolchain). CI `R CMD check` is the run that compiles them.

## Stale-wording scan

```text
rg -n "fit-multi\\.R not in this test context|not a source checkout|production cloglog header unavailable|package sources not available|man/ not available|R/ not present" tests/testthat/test-beta-response-support.R tests/testthat/test-zz-mspl-fenced-family-tapes.R tests/testthat/test-latent-d-identifiable-range-doc.R tests/testthat/test-rotate-compare-loadings.R tests/testthat/test-no-deprecated-recommendations.R tests/testthat/test-mspl-nb2-fenced-tape.R tests/testthat/test-mspl-W-onesided-oracles.R tests/testthat/test-mspl-poisson-phase4-oracles.R
# no matches
```

## Deliberately not run

`devtools::test()`, `devtools::check()`, `pkgdown::check_pkgdown()`. No exported function, roxygen, or article change. The VM has R 4.3.3 and testthat, not a compiled `gllvmTMB`.
