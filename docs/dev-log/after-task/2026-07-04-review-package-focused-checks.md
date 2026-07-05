# After Task: Review Package Focused Checks

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Grace / Rose / Curie / Ada`

## 1. Goal

Execute the first focused checks from the completion branch review package map.

## 2. Implemented

No code changed. This slice records validation evidence for the review package.

## 3. Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-review-package-focused-checks.md`

## 3a. Decisions and Rejected Alternatives

Decision: run focused local checks before release-level checks.

Reason: the branch is large enough that focused failures should be found before
`pkgdown::check_pkgdown()` or `devtools::check()`.

## 4. Checks Run

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
```

Outcome: all tests skipped without `GLLVMTMB_HEAVY_TESTS=1`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
```

Outcome: all tests skipped without `GLLVMTMB_HEAVY_TESTS=1`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
```

Outcome: passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-covariance-tables.R", reporter = "summary")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-rotate-compare-loadings.R", reporter = "summary")'
```

Outcome: passed.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Outcome: pure bridge tests passed; 13 live GLLVM.jl tests skipped because no
`GLLVM_JL_PATH` was configured.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-keyword-grid.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R", reporter = "summary")'
```

Outcome: all passed. The canonical-keywords run had three INLA-only spatial
skips.

```sh
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
```

Outcome: both JSON files valid.

## 5. Tests of the Tests

The rerun with `NOT_CRAN=true` mattered: `test-keyword-grid.R` and several
ordinary latent random-regression tests skip under CRAN-like defaults.

## 6. Consistency Audit

This evidence does not prove release readiness. It covers the first local
review-package check set only.

## 7. Roadmap Tick

Route-matrix, plotting, bridge-pure, and formula-grammar focused checks now have
fresh local evidence.

## 7a. GitHub Issue Ledger

No issue was closed or commented.

## 8. What Did Not Go Smoothly

The first formula-check pass was too weak because `NOT_CRAN=true` was omitted;
the intended local checks were rerun and passed.

## 9. Team Learning

For this branch, skip-heavy tests should be recorded as weak evidence unless the
required opt-in flags are set.

## 10. Known Limitations And Next Actions

- Live GLLVM.jl bridge tests were not run.
- Release-level `devtools::document()`, `pkgdown::check_pkgdown()`, and
  `devtools::check(args = "--no-manual")` were not run.
- Coevolution/kernel focused checks remain to be scheduled.
