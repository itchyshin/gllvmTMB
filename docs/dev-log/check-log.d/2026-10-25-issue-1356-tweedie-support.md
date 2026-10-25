# Check-log: tweedie negative-y support (#1356)

**Goal:** Confirm `tweedie()` aborts on y < 0 before fitting.

**Commands:**

    Rscript -e 'devtools::test(filter = "family-support-checks")'
    rg -n "gllvmTMB_tweedie_negative_y" R tests NEWS.md

**Results:** recorded after the focused test run.

**Claim boundary:** Refs #1356 (tweedie comment only). Does not change
the poisson/nbinom2 checks already on main. Does not decide binomial
integrality. No full suite, no `R CMD check`.
