# Check-log: mesh outside triangulation (#1753)

**Goal:** Split `.gllvm_validate_mesh()` `A_st` checks; add typed test file that fails on main.

**Commands:**

```sh
Rscript --vanilla -e 'library(testthat); library(gllvmTMB); test_file("tests/testthat/test-fix-1753-mesh-outside.R", reporter = "summary")'
Rscript --vanilla -e 'library(testthat); library(gllvmTMB); test_file("tests/testthat/test-mesh.R", reporter = "summary")'
```

**Results (main, before `R/mesh.R` change):** `test-fix-1753-mesh-outside.R` — 2 failed tests (typed class / split validation).

**Results (branch `cursor/fix-1753-mesh-outside-4c51`):** `test-fix-1753-mesh-outside.R` — 11 passed; `test-mesh.R` — 44 passed.

**Deliberately not run:** full `devtools::test()`, `devtools::check()`, pkgdown.

**Claim boundary:** Error-message UX only; no validation-debt or capability promotion.
