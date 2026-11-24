# Check-log: kernel named unit grouping (#1805)

**Goal:** Confirm `kernel_indep(K = K, unit = g)` with `cluster` omitted groups by `g`, and that a missing `g` is named in the error rather than `K`.

**Commands:**

    Rscript -e 'testthat::test_file("tests/testthat/test-fix-1805-kernel-named-unit.R")'

R is not installed on this machine (`Rscript: command not found`). The command was not run. CI on the draft PR is the check.

**Results:** Not run locally. No package test, `devtools::check()`, or pkgdown build was run here.

**Claim boundary:** No likelihood, estimand, default, or validation-debt change. The positional form `kernel_indep(unit, K = K)` is unchanged. An explicit `cluster` is unchanged.
