# After Task: confint Proportion Component Docs

Date: 2026-07-05

## Goal

Align the `confint.gllvmTMB_multi()` documentation with the existing
proportion-token parser. The parser already accepts `unique_cluster` and
`unique_cluster2`, but the roxygen component list omitted them.

## Files Changed

- `R/z-confint-gllvmTMB.R`
- `man/confint.gllvmTMB_multi.Rd`
- `docs/dev-log/check-log.md`

## Implementation

- Added `unique_cluster` and `unique_cluster2` to the documented component list
  for `parm = "proportion:<component>"`.
- Regenerated Rd with `devtools::document()`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-proportions.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-proportions-cluster-components.R", reporter = "summary")'
git diff --check
```

The parse/documentation commands passed. `test-profile-proportions.R` ran in
non-heavy mode and skipped its heavy blocks as expected; the parser/cluster
component coverage in `test-proportions-cluster-components.R` passed.

## Claim Boundary

Documentation only. No new proportion interval behavior or calibration claim
changed.
