# Check-log: #1757 intercept review (PR #1774)

**Goal:** Apply the code-review BLOCKED items on draft PR #1774 without
weakening tests: drop the `shared()` intercept skip, keep slope-only
screen parity, tighten the #1757 regexes, and write explicit `1 +` in
the named heavy / screen formulas.

**Commands:**

```sh
# R is not on this VM PATH (`R` / `Rscript` not found under /usr,
# /usr/local, /opt, or $HOME). No package install was run (task rule).
# Targeted tests that would have been run if R were present:
#   tests/testthat/test-fix-1757-traits-implicit-intercept.R
#   tests/testthat/test-column-coef-foundation.R
#   tests/testthat/test-screen-separation.R
#   tests/testthat/test-screen-gllvmTMB.R
#   tests/testthat/test-traits-keyword.R

rg -n "traits_rhs_contains_shared" R tests
rg -n "shorthand follows" R/traits-keyword.R man/traits.Rd
rg -n "traits\\(a, b\\) ~ 0 \\+ x" tests/testthat/test-screen-separation.R
rg -n "\\^0 \\\\\\+ trait" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "1 \\+ z \\+ mi\\(" tests/testthat/test-missing-predictor-binary.R tests/testthat/test-missing-predictor-categorical.R tests/testthat/test-missing-predictor-ordered.R tests/testthat/test-missing-predictor-gaussian.R
```

**Results:** R unavailable — no testthat pass/fail counts. The `rg`
patterns above confirmed the review edits are in the tree (shared
helper gone; grammar comma present; screen slope-only formula;
anchored intercept regexes; explicit `1 + z + mi(` in the four heavy
files).

**Not run:** `devtools::test()`, `devtools::document()`,
`pkgdown::check_pkgdown()`, `devtools::check()`, any `R CMD INSTALL`.
Manually aligned `man/traits.Rd` with the roxygen grammar sentence.

**Claim boundary:** These edits do not change `column_data` main-effect
errors (`gllvmTMB_rank_deficient_design` on `~ pathway` / `~ leaf_area`)
and do not edit Design 131 §4. Fail-on-main / pass-on-branch for the
tightened intercept counts was not executed here.
