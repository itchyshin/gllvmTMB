# Check-log: kernel one-grouping cluster (#1752)

**Goal:** Show that `kernel_indep(unit, K = K)` and `kernel_latent(unit, K = K)` fail on the unfixed package when `cluster` is omitted, and pass after the grouping column inside the kernel term is used as `cluster`.

**Commands:**

Before, against the installed unfixed package (R 4.3.3, gllvmTMB 0.8.0.9000 built from `30304be42fda3fa1b852270e954b53d5a6669ed7`):

```sh
export R_LIBS_USER="$HOME/R/x86_64-pc-linux-gnu-library/4.3"
Rscript -e '.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths())); library(gllvmTMB); library(testthat); res <- test_file("tests/testthat/test-fix-1752-kernel-indep-unit.R", reporter = "summary"); print(as.data.frame(res)[, c("test","failed","error","passed")])'
```

After, with `pkgload::load_all()` on this branch (same test file, `NOT_CRAN` unset):

```sh
export R_LIBS_USER="$HOME/R/x86_64-pc-linux-gnu-library/4.3"
Rscript -e '.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths())); pkgload::load_all(".", quiet = TRUE); library(testthat); res <- test_file("tests/testthat/test-fix-1752-kernel-indep-unit.R"); print(as.data.frame(res))'
```

Neighbour files, same `load_all()`, after installing `tidyr` and `ape`, with `NOT_CRAN=true`:

```sh
export NOT_CRAN=true
Rscript -e '.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths())); pkgload::load_all(".", quiet = TRUE); library(testthat); for (f in c("tests/testthat/test-unused-grouping-slots.R","tests/testthat/test-species-unused-levels-guard.R","tests/testthat/test-temporal-sixth-source-engine.R","tests/testthat/test-issue-1580-message-text.R","tests/testthat/test-kernel-equivalence.R")) test_file(f, reporter = "summary")'
```

Also, before those two packages were installed: `test-kernel-latent-unique-bridge.R` and `test-dense-vcv-psd-check.R`.

Rd regeneration (DESCRIPTION and NAMESPACE churn from roxygen2 8.1.1 was reverted):

```sh
Rscript -e '.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths())); roxygen2::roxygenise(".", roclets = c("rd", "namespace"))'
```

**Results:**

- Before: the new file does not pass. `kernel_indep` errors at line 35 and `kernel_latent` errors at line 59 with `` `phylo_vcv` rownames do not cover all species levels `` and `placeholder`. The mismatched-`K` test has 6 failures (message names `phylo_vcv`, `placeholder`, and `tree`). The unnamed-`K` test has 3 failures and 2 passes (`expect_s3_class` and the absence of `placeholder`). The phylogenetic pin passes 4. testthat stops at 10 failures, so the unnamed-`K` `phylo_vcv` mismatch is the last failure printed.
- After: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 24 ]`. Both one-grouping fits converge (`convergence` 0) and match the explicit `cluster = "unit"` fit (`logLik`, tolerance `1e-8`).
- Neighbours after `tidyr` and `ape`: `test-unused-grouping-slots.R`, `test-species-unused-levels-guard.R` (one pre-existing implicit-`unit` warning), `test-temporal-sixth-source-engine.R`, `test-issue-1580-message-text.R`, and `test-kernel-equivalence.R` all finish with no failures. `test-dense-vcv-psd-check.R` passes 7. `test-kernel-latent-unique-bridge.R` passes its error tests and skips the Julia agreement test because `{JuliaCall}` is not installed.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, `pkgdown::build_articles()`, and a full `devtools::test()`. No article source changed. `src/gllvmTMB.cpp` was not edited, so the existing `src/gllvmTMB.so` was reused by `load_all()`.

**Claim boundary:** This is a grouping-slot bugfix for a call the keyword-grid article already shows. It does not change a validation-debt row, a likelihood, or the phylogenetic coverage wording. The `logLik` check is same-model agreement with `cluster = "unit"` on one Gaussian layout, not a recovery study and not a kernel-versus-phylo parity test.
