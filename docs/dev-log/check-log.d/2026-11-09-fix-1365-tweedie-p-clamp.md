# Check-log: clamp Tweedie p and warn on a pinned power outside the bound (#1365)

**Goal:** Confirm the Tweedie power stays strictly inside (1, 2) at extreme
`logit_p`, that a pinned power inside the clamp round-trips with no warning,
and that a pinned power such as 1.001 or 1.999 warns and is used at the bound.

**Commands:**

```
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1365.R")'
# NOT_CRAN=true, package installed from this branch

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tweedie-fixed-p.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-matrix-tweedie.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-family-constructor-contract.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-mixed-dispersion-pinning-1117.R")'

rg -n 'invlogit\(logit_p_tweedie' src/gllvmTMB.cpp
rg -n 'gll_tweedie_logit_p_clamped|GLL_TWEEDIE_LOGIT_P_MAX|\.tweedie_logit_p_max' src/gllvmTMB.cpp R/families.R R/fit-multi.R
rg -n 'censored_poisson|pgamma\(mu' src/gllvmTMB.cpp
rg -n '4 x 5|4 × 5|gllvmTMB_wide\(|meta_known_V|trio' NEWS.md R/families.R man/families.Rd docs/design/03-likelihoods.md
```

**Results:**

- `test-fix-1365.R`: FAIL 0 / 3 tests, 37 expectations passed (20 + 3 + 14), 0 skipped under `NOT_CRAN=true`.
- `test-tweedie-fixed-p.R`: FAIL 0 / 2 tests.
- `test-matrix-tweedie.R`: FAIL 0 / 3 tests, all 3 skipped as heavy.
- `test-family-constructor-contract.R`: FAIL 0 / 6 tests.
- `test-mixed-dispersion-pinning-1117.R`: FAIL 0 / 5 tests.
- `invlogit(logit_p_tweedie` in `src/gllvmTMB.cpp`: no matches. Density and `REPORT(p_tweedie)` both go through `gll_tweedie_logit_p_clamped`.
- Clamp constant 5 is defined once in the template and once as `.tweedie_logit_p_max()`.
- `censored_poisson` still uses `log(pgamma(mu, C, 1))` at the existing fid 21 branch. That branch was not edited.
- Stale-terminology hits in `NEWS.md` are older entries (`gllvmTMB_wide()`, `meta_known_V()`). The new Development bullet does not use them. No hits in `R/families.R`, `man/families.Rd`, or the Tweedie section of `docs/design/03-likelihoods.md`.

**Not run:** `devtools::test()` and `devtools::check()`. A two-shard `test_check()` in this image segfaulted inside `lme4::glmer` (`merPredDCreate`) after an apt `r-cran-lme4` install, before the suite finished. That crash is not a Tweedie failure. Heavy tests (`GLLVMTMB_HEAVY_TESTS`) were left unset. `roxygen2::roxygenise()` was not run; `man/families.Rd` was edited to match the `tweedie()` `@param p` text, and `man/families.Rd` still has a single trailing `\keyword{internal}`.

**Claim boundary:** This shows the clamp and the pinned-power warning on a small fixed-effects Tweedie fit. It does not change FAM-13 recovery evidence, and it does not admit a Tweedie power of 1 or below, or of 2 or above. The variational prototype in `inst/tmb/gllvmTMB_va_r3.cpp` is unchanged.
