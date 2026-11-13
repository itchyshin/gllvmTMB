# Check-log: predict() missing species column (#1787)

**Goal:** Confirm `predict(newdata)` stops when the fitted species column is absent and phylogenetic random effects would be re-added, instead of returning fixed effects while reporting that they were re-added.

**Commands:**

```sh
# origin/main predict() body swapped in (a5ee7652):
Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-1787-predict-missing-species.R", load_package="source", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

# Source tree with the fix:
Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "1787-predict-missing-species", load_package = "source", reporter = "summary"); print(as.data.frame(res)[, c("test","nb","failed","error")])'

Rscript --vanilla -e 'res <- testthat::test_dir("tests/testthat", filter = "predict-simulate-refusal", load_package = "source", reporter = "summary")'

rg -n "gllvmTMB_predict_newdata_species_missing" R tests man NEWS.md
rg -n "Fixes |Closes |Resolves " NEWS.md docs/dev-log/check-log.d/2026-11-13-1787-predict-missing-species.md docs/dev-log/after-task/2026-11-13-1787-predict-missing-species.md
```

**Results:** On origin/main predict code the missing-column test failed 2 expectations (the call succeeded and printed that `diag_B` and `phylo_rr` were re-added). The unseen-level guard passed. On the source fix: FAIL 0 / ERROR 0 / 2 tests / 7 expectations.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, and the full test suite. No likelihood or default changed.

**Claim boundary:** This covers a phylogenetic Gaussian fit whose species (`cluster`) column is dropped, kept with an unseen level, or kept for `re_form = ~0`. It does not change which tiers `predict()` can re-add, and it does not change a validation-debt row.
