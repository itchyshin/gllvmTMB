# Delta Family Boundary Truth Lock

**Date:** 2026-07-05
**Branch:** `codex/r-bridge-grouped-dispersion`

## Goal

Make the delta-family claim match the runtime surface: standard
`delta_lognormal()` and `delta_gamma()` are admitted fixed-effect two-part
families; the other exported delta constructors are compatibility constructors
that must fail loudly until likelihood wiring and recovery tests land.

## Changes

- Reordered the delta-family runtime gate in `R/fit-multi.R` so unsupported
  delta constructors produce the explicit `Unsupported delta family` boundary.
- Extended `test-enum-runtime-ids.R` to include delta mixture,
  `delta_gengamma()`, `delta_beta()`, and delta-truncated NB constructor-only
  guards.
- Updated the delta recovery tests to fixed-effect formulas, consistent with
  Design 62's "two-part families are response distributions only" boundary.
- Narrowed `docs/design/02-family-registry.md` and FAM-17 in
  `docs/design/35-validation-debt-register.md`.
- Regenerated `man/families.Rd`.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("R/families.R")); invisible(parse("tests/testthat/test-enum-runtime-ids.R")); invisible(parse("tests/testthat/test-delta-gamma-recovery.R")); invisible(parse("tests/testthat/test-delta-lognormal-recovery.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-enum-runtime-ids.R")'
Rscript --vanilla -e 'Sys.setenv(GLLVMTMB_HEAVY_TESTS="1", NOT_CRAN="true"); devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-delta-gamma-recovery.R")'
Rscript --vanilla -e 'Sys.setenv(GLLVMTMB_HEAVY_TESTS="1", NOT_CRAN="true"); devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-delta-lognormal-recovery.R")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'tools::checkRd("man/families.Rd")'
git diff --check
```

Results:

- Parse check passed.
- Constructor/runtime guard: 15 pass.
- Heavy `delta_gamma()` fixed-effect recovery: 13 pass.
- Heavy `delta_lognormal()` fixed-effect recovery: 13 pass.
- Rd regeneration succeeded; `checkRd()` reported only existing non-ASCII
  reference page-range warnings.
- `git diff --check` passed.

## Boundary

The old latent `delta_lognormal()` recovery cell was probed before the test was
realigned. It returned `convergence = 1` with `pdHess = TRUE`; BFGS returned
`convergence = 0` but `pdHess = FALSE`; multiple starts did not rescue the
latent claim. The same DGP as a fixed-effect delta fit returned clean
convergence and tight recovery. This is evidence to keep FAM-17 fixed-effect
only, not evidence to promote latent/random delta support.

## Review

- **Fisher:** fixed-effect delta recovery is supported by the heavy files;
  latent/random delta covariance and mixed-family delta correlation remain out
  of scope.
- **Rose:** the old "10 variants covered" language is removed from active
  truth files. Historical audit prose remains historical, not operating truth.
- **Grace:** focused checks are green; no broad compute, Totoro, DRAC, pkgdown,
  or full `devtools::check()` was run in this slice.
