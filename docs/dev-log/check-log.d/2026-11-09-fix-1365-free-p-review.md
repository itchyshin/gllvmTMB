# Check-log: free Tweedie p review follow-up (#1365)

**Goal:** Rebase the smooth Tweedie-power bound onto #1747, store a fixed power with the smooth inverse on `[p_lo, p_hi]`, and warn when a free fit at the bound has dispersion below 0.1.

**Commands:**

    git rebase origin/cursor/fix-1365-tweedie-p-clamp-fae3
    Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-fix-1365.R"); testthat::test_file("tests/testthat/test-fix-1365-free-p.R")'
    Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); for (f in c("tests/testthat/test-tweedie-fixed-p.R", "tests/testthat/test-matrix-tweedie.R", "tests/testthat/test-mixed-dispersion-pinning-1117.R", "tests/testthat/test-tweedie-recovery.R", "tests/testthat/test-mspl-tweedie-phase4-oracles.R", "tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R", "tests/testthat/test-va-all-family-compiled.R", "tests/testthat/test-va-all-family-light-fits.R", "tests/testthat/test-va-all-family-oracles.R")) testthat::test_file(f)'
    bash tools/check-reader-surface.sh

**Results:** `test-fix-1365.R` FAIL 0 / PASS 34. `test-fix-1365-free-p.R` FAIL 0 / PASS 135, including the `expect_warning(..., class = "gllvmTMB_tweedie_p_boundary")` match on "TMB's Tweedie density accuracy degrades". The other Tweedie files, run before the dispersion sentence was made conditional, were FAIL 0: fixed-p 10, matrix-tweedie 0 pass / 3 heavy skips, mixed-dispersion 20, recovery 0 pass / 3 heavy skips, mspl phase4 72, zz-mspl 32 pass / 3 skips, va compiled 109, va light fits 174, va oracles 87. Reader-surface check PASS. The conditional dispersion sentence does not change those likelihood comparisons.

**Not run:** the full shard 4 (the free-p file's shard), `devtools::check()`, and `GLLVMTMB_HEAVY_TESTS=1`. Shard 4 on this machine previously failed tests that need `tidyr`, `ape`, or `tools::sha256sum`, and a beta-clamp regex that already fails on main.

**Claim boundary:** The fixed and estimated power share `[1 + plogis(-12), 1 + plogis(12)]`. A pin inside that interval round-trips. A pin outside it uses the nearer end and warns. Dispersion below 0.1 is still outside the density grid; the new line only says so when a free fit has already reached the power bound.
