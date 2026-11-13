# Check-log: gllvm masking of getLoadings/getLV (#1759)

**Goal:** Confirm that `getLoadings()` and `getLV()` keep their exported signatures and, after `library(gllvm)`, return the same values as `gllvmTMB::getLoadings()` and `gllvmTMB::getLV()`.

**Commands:**

    Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
    Rscript --vanilla -e 'devtools::test(filter = "fix-1759", stop_on_failure = TRUE)'
    Rscript --vanilla -e 'devtools::test(filter = "ordiplot-multi", stop_on_failure = TRUE)'
    Rscript --vanilla -e 'pkgdown::check_pkgdown()'
    bash tools/check-reader-surface.sh
    rg -n "FAM-|EXT-|4 x 5|4×5|gllvmTMB_wide" NEWS.md man/getLoadings.Rd man/getLV.Rd man/getResidualCov.Rd R/output-methods.R
    rg -n "^Imports:" -A 20 DESCRIPTION

**Results:**

- `devtools::document()` exited 0. It rewrote `man/getLoadings.Rd`, `man/getLV.Rd`, and `man/getResidualCov.Rd` with the new dispatch paragraphs. With roxygen2 8.1.1 it also reflowed `importFrom` lines in `NAMESPACE` and bumped `Config/roxygen2/version` to 8.1.1. Those two files were restored: the export and `S3method` lists were unchanged, and registration is done in `.onLoad`, not by a new `NAMESPACE` directive. Each regenerated Rd file still has one `\keyword{internal}`.
- `devtools::test(filter = "fix-1759")`: FAIL 0 / WARN 0 / SKIP 0 / PASS 73. `gllvm` 2.0.15 was installed, so the `skip_if_not_installed("gllvm")` test ran.
- `devtools::test(filter = "ordiplot-multi")`: FAIL 0 / WARN 0 / SKIP 0 / PASS 9.
- `pkgdown::check_pkgdown()`: no problems found.
- `bash tools/check-reader-surface.sh`: READER-SURFACE CHECK: PASS.
- The stale-wording `rg` on the touched reader files returned no matches. `DESCRIPTION` `Imports` does not list `gllvm` (`gllvm` stays in `Suggests`).

**Not run:** `devtools::test()` (full suite), `devtools::check()`, and `pkgdown::build_articles()`. This slice does not change formula parsing, likelihoods, or article examples.

**Claim boundary:** The tests show that a 20-by-3 Gaussian `latent(..., d = 1, unique = FALSE)` fit returns the same loadings, scores, residual covariance, and residual correlation from the search-path call and from `gllvm::` / `gllvmTMB::` after `gllvm` is attached. They do not show recovery of Lambda, coverage of score standard errors, or behaviour of a `gllvm` fit. `getLV(se = TRUE)` was not part of this comparison. Julia bridge fits are registered (`gllvmTMB_julia` is in `gllvm`'s S3 table) and were not fitted here.
