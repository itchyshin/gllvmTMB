## 2026-11-26 — #1938 residuals(type) refusal (cursor/1126fx-1938)

- **Change:** `residuals.gllvmTMB_multi()` refuses unknown `type` values with `cli::cli_abort()` naming `randomized_quantile` and `simulation_rank` before raw `match.arg()` fires.
- **Test:** `tests/testthat/test-issue-1938-residuals-type-refusal.R`
- **Run (local):** `NOT_CRAN=true R_LIBS_USER=~/R/... pkgload::load_all(); testthat::test_file("tests/testthat/test-issue-1938-residuals-type-refusal.R")` — PASS (6 assertions).
- **Not run:** full `devtools::test()`, `R CMD check`, pkgdown.