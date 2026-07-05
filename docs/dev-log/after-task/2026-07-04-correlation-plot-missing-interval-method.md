# After Task: Correlation Plot Missing Interval Method

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Grace / Rose / Shannon`

## 1. Goal

Fix issue #702's interval-metadata inconsistency: correlation plot rows whose
requested bootstrap interval is missing should not retain
`interval_method = "none"`.

## 2. Implemented

- `.correlation_merge_bootstrap_intervals()` now sets
  `interval_method = "missing"` when a bootstrap object has no matching tier.
- The same helper now sets `interval_method = "missing"` for row-level key
  misses inside a non-empty bootstrap table.
- Added a plot-level regression using a B-only bootstrap object so unit-obs rows
  are marked as missing consistently.

## 3. Files Changed

- `R/plot-gllvmTMB.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-correlation-plot-missing-interval-method.md`

## 3a. Decisions and Rejected Alternatives

Decision: use `interval_method = "missing"` for requested-but-absent bootstrap
intervals.

Rejected alternative: leave method as `"none"` and rely only on
`interval_status`.

Reason rejected: downstream code may key on either field; the pair should be
internally consistent.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/plot-gllvmTMB.R")); invisible(parse("tests/testthat/test-plot-gllvmTMB.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-gllvmTMB.R", reporter = "summary")'
```

Outcome: passed; `plot-gllvmTMB` completed with no failures.

```sh
git diff --check
```

Outcome: passed.

## 5. Tests of the Tests

The regression constructs a bootstrap object with only B-tier correlation
intervals and verifies the W-tier rows carry both `interval_status = "missing"`
and `interval_method = "missing"`.

## 6. Consistency Audit

No plotting claim or interval method changed. The patch only reconciles row
metadata for intervals requested but absent.

## 7. Roadmap Tick

Plot/interval metadata truth: issue #702 addressed locally.

## 7a. GitHub Issue Ledger

Issue #702 was not closed or commented because this branch has not been pushed.

## 8. What Did Not Go Smoothly

No blocker.

## 9. Team Learning

Interval rows need method and status to agree; otherwise downstream summaries
can misclassify missing intervals as point-only rows.

## 10. Known Limitations And Next Actions

- This does not optimize bootstrap batching or add new bootstrap coverage.
- It does not change figure rendering beyond metadata consistency.
