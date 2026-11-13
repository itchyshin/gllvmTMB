# Check-log: coverage shard 3 runaway-warning capture (G0)

**Goal:** Make the main coverage job green without masking a failed test.
Run 42653382670, shard 3/4, failed in `tests/testthat/test-runaway-warning.R`
lines 63-65. The workflow and `tools/run-covr-coverage.R` already fail the
shard when testthat reports `FAIL > 0`, and they were left unchanged.

**Commands:**

```
gh pr list --repo itchyshin/gllvmTMB --state open
gh run view 42653382670 --repo itchyshin/gllvmTMB
git rev-parse HEAD   # 02c0aa0bca1d05e5d48d7310551a570c092236ef before the branch

NOT_CRAN=true Rscript -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-runaway-warning.R", stop_on_failure = TRUE)'
# before the edit, same file, package not attached: FAIL 1 (check_gllvmTMB
# not on the search path) | WARN 1 | PASS 11. Lines 63-65 did not fail at -O2.

NOT_CRAN=true Rscript -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-runaway-warning.R", stop_on_failure = TRUE)'
# after the edit, -O2, R 4.3.3: FAIL 0 | WARN 1 | SKIP 0 | PASS 19

PKG_CXXFLAGS="-O0" PKG_CFLAGS="-O0" MAKEFLAGS=-j1 R CMD INSTALL --no-docs --no-multiarch --preclean .
NOT_CRAN=true Rscript -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-runaway-warning.R", stop_on_failure = TRUE)'
# same file against that build: FAIL 0 | WARN 1 | SKIP 0 | PASS 19
# the WARN is the existing once-per-session implicit unit = "site" deprecation,
# printed because this file was the first fit in the session
```

Local R is 4.3.3. The `-O0` link line still carried R's `-flto=auto`, so this
is not covr's `--coverage` build. The pull request's `test-coverage` run is
that build.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, a full
`covr::package_coverage()` (the four shards run on the pull request). No edit
to `R/` or `src/`. `docs/dev-log/check-log.md` was not appended: open PR #1065
already touches that file.

**rg:**

```
rg -n "stop_on_failure|nocov|covrignore|skip_on_covr" tests/testthat/test-runaway-warning.R .github/workflows/test-coverage.yaml tools/run-covr-coverage.R
rg -n "tryCatch\\(\\s*\\{" tests/testthat/test-runaway-warning.R
rg -n "loading_ridge|warn_runaway|MAP\\|penalised" tests/testthat/test-runaway-warning.R
```
