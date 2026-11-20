# Check-log: #1757 reviewer regex + rank fixture (PR #1774)

**Goal:** Fix the two mechanical Code Reviewer blockers on draft PR
#1774: match the real `~ z + shared(x)` deparse, and use a
non-collinear `z` so the expanded design is full rank with 7 columns.

**Commands:**

```sh
rg -n "seq_len\\(8\\) / 8" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "\\(0 \\\\\\+ trait\\\\\\):z \\\\\\+ x" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "0 \\+ trait \\+ \\(\\((0 \\+ trait\\):z \\+ x\\)" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "ncol\\(X_shared_plus\\), 7L" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "traits\\(.*\\) ~ pathway|~ leaf_area" tests
```

Standalone rewrite runner (sourced `R/traits-keyword.R`,
`R/column-coef-foundation.R`, `R/weights-shape.R`; no TMB DLL):

```sh
Rscript /tmp/run-fix-1757-rewrite.R
```

Registered-namespace eval of the first `test_that()` in
`tests/testthat/test-fix-1757-traits-implicit-intercept.R` (15
assertions):

```r
# makeNamespace + sys.source(R/*.R) + eval(parse(...)[[1]])
```

**Results:**

- `rg seq_len(8) / 8`: no remaining hit in the test file.
- Old un-parenthesised regex: no remaining hit.
- Exact deparse string and `ncol == 7L` / `qr()$rank == 7L`: present.
- `traits(...) ~ pathway` / `~ leaf_area`: no hits under `tests/`.
- Standalone runner: ALL REWRITE ASSERTIONS PASSED. `shared_plus_rhs`
  is `0 + trait + ((0 + trait):z + x)`; model matrix 7 columns, rank 7;
  collinear control `z = x/8` is 7 columns, rank 6.
- First `test_that()`: FAIL 0 / PASS 15.
- Second `test_that()` (fit / coef-count): not run here — `gllvmTMB()`
  needs the compiled TMB DLL. Unchanged from `75c0b0ea`, where CI shard
  3/4 recorded that block as passing and failed only line 90.

**Not run:** `devtools::test()`, `devtools::document()`,
`pkgdown::check_pkgdown()`, `devtools::check()`, `R CMD INSTALL` of
this package. No `column_data` main-effect fits.

**Claim boundary:** Test-only. Does not change intercept injection,
`shared()` expansion, or `column_data` main-effect
`gllvmTMB_rank_deficient_design` behaviour. Design 131 §4 not edited.
