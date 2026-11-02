# After-task: edge pins for chibar2_pvalue(), variance_lrt(), diagnostic_table()

Scope: test-only. New file `tests/testthat/test-lrt-and-diagnostic-table-edges.R`;
nothing under `R/`, `src/`, `man/` or `NEWS.md` changed.

Outcome: the tests pin today's behaviour (classed errors plus advice text,
closed-form agreement, stable column names). Findings, none fixed here:

- `variance_lrt()` does not clamp a negative LRT (it reports it as computed;
  only the p-value is 1) and does no nestedness check.
- `variance_lrt()` accepts a `logLik` object although its error advice calls a
  `logLik` "not a bare numeric" (`is.numeric()` is TRUE for it).
- `diagnostic_table()` with an unknown `table` raises a base `simpleError`
  from `match.arg()`, not a package-classed condition; it also runs before the
  metadata check.

Checks: the file passes locally with `NOT_CRAN=true`.
Follow-up: decide whether the `logLik` advice text or the check should change.
