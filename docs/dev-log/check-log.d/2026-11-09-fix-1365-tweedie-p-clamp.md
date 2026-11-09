# Check-log: pin Tweedie p at the bound and warn (#1365)

**Goal:** A user-pinned Tweedie power outside [1.006693, 1.993307] warns once
and the fit uses that endpoint. A pin inside the range is unchanged. A free
power is the unclamped template on main. `src/` matches main.

**Commands:**

```
git diff --stat origin/main -- src/
rg -n 'gll_tweedie_logit_p_clamped|GLL_TWEEDIE_LOGIT_P_MAX' src/gllvmTMB.cpp

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1365.R")'
# NOT_CRAN=true, package installed from this branch

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tweedie-fixed-p.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-matrix-tweedie.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-family-constructor-contract.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-mixed-dispersion-pinning-1117.R")'

rg -n '4 x 5|4 × 5|gllvmTMB_wide\(|meta_known_V|trio' NEWS.md R/families.R man/families.Rd docs/design/03-likelihoods.md
```

**Results:**

- `git diff origin/main -- src/`: empty. `src/gllvmTMB.cpp` has no Tweedie logit clamp.
- `test-fix-1365.R`: FAIL 0, PASS 23. A free interior power matches `p = 1 + plogis(logit_p)` and the template objective within 1e-10. `tweedie(p = 1.5)` does not warn. `p = 1.001` and `p = 1.999` warn once and the reported power is the endpoint.
- `test-tweedie-fixed-p.R`: FAIL 0, PASS 10.
- `test-matrix-tweedie.R`: FAIL 0, SKIP 3 (heavy), PASS 0.
- `test-family-constructor-contract.R`: FAIL 0, PASS 113.
- `test-mixed-dispersion-pinning-1117.R`: FAIL 0, PASS 20.
- Stale-terminology hits in `NEWS.md` are older entries. The #1365 bullet does not use them.

**Not run:** `devtools::test()` and `devtools::check()`. A two-shard `test_check()` on this image segfaulted inside `lme4::glmer` after an apt `r-cran-lme4` install. That is not a Tweedie failure. Heavy tests stayed off. `roxygen2::roxygenise()` was not run; `man/families.Rd` was edited to match the `tweedie()` `@param p` text.

**Claim boundary:** The pin is an R fixed-parameter value shared by Laplace, MSPL and VA. Free `logit_p` is not bounded. FAM-13 recovery evidence is unchanged. A power of 1 or below, or of 2 or above, is still refused at `tweedie()`.
