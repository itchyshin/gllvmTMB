# Check-log: MSPL cloglog y = 0 kink (#1020)

**Goal:** Confirm that LA-MSPL cloglog fits at low prevalence with many units return a clean inner mode, and that a y = 0 row keeps the exact slope exp(eta) below eta = log(1e-4).

**Commands:**

```sh
# Pre-fix: main @ 0d065c39, R CMD INSTALL -l ~/Rlib .
NOT_CRAN=true Rscript -e 'library(testthat); library(gllvmTMB); test_file("tests/testthat/test-mspl-cloglog-kink-1020.R", reporter = "summary")'

# After R CMD INSTALL of this branch: the new file plus every MSPL test file
# that mentions binomial or cloglog, inside the installed namespace.
NOT_CRAN=true Rscript /tmp/run1020.R
#   test_file(f, reporter = "silent", package = "gllvmTMB", load_package = "installed")
```

**Results:** Pre-fix: the kernel block failed (the y = 0 rows contributed no slope below log(1e-4), so the gradient did not match the exact cloglog derivative), and both end-to-end fits stopped with `gllvmTMB_mspl_decomposition_failure` (residual 0.827679 at B124 outer 1, as in the issue; 0.0220877 at B048 outer 2). After install: `test-mspl-cloglog-kink-1020.R` FAIL 0 / ERROR 0 / 16 expectations. Existing MSPL files, FAIL 0 / ERROR 0 for each: `test-mspl-api.R` 356, `test-mspl-registry.R` 81, `test-mspl-gaussian-heywood-oracles.R` 76, `test-zz-mspl-bernoulli-se-feasibility.R` 50, `test-zz-mspl-profile-ci-stub.R` 48, `test-zz-mspl-nbinom-se-feasibility.R` 62, `test-zz-mspl-tweedie-beta-se-feasibility.R` 32 (3 heavy skips), `test-mspl-betabinomial-phase4-oracles.R` 27, `test-mspl-multinomial-phase4-oracles.R` 23, `test-zz-mspl-fenced-family-tapes.R` 21, `test-zz-mspl-rest-families-se-feasibility.R` 20 (13 heavy skips), `test-zz-mspl-rest-family-prepare-fence.R` 15.

**Not run:** `devtools::check()`, the full suite, and the B1 campaign cells beyond the two pinned here.

**Claim boundary:** The y = 0 cloglog branch of `gll_mspl_bernoulli_loglik()` (MSPL tapes only, `estimator_id != 0`). Passing the decomposition check does not make these fits healthy: the issue records that the patched B124 fits are reproducible but degenerate, so these cells are not recovery evidence.
