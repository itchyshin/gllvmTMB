# After-task: covr trace-file loss in the coverage shards (refs #1785)

## 1. Goal

Stop the Ubuntu coverage shards from failing after a clean test run when
covr cannot read `covr_counters.rds`.

## 2. Implemented

covr 4 writes each trace as hit counts plus the path of
`R/covr_counters.rds` in the library the test process loaded. `R CMD check
--as-cran` symlinks the installed package into `/tmp/Rtmp*/RLIBS_*`
(`tools:::setRlibs()`) and deletes that session directory before it exits.
The counters file remains in the persistent install. The path in the trace
does not. `tools/retarget-covr-traces.R` rewrites a missing path onto that
install after the check returns and before covr merges the traces.

The workflow no longer pins covr 3.6.5. That pin avoided the path; it did
not keep the counters. covr 3.6.5 traces have no `counters_file`, so the
same step leaves them alone.

## 3. Files Changed

- `tools/retarget-covr-traces.R` (new)
- `tools/run-covr-coverage.R`
- `tools/tests/test-retarget-covr-traces.R` (new)
- `tools/tests/test_codecov_workflow.py`
- `.github/workflows/test-coverage.yaml`
- `docs/dev-log/check-log.d/2026-11-18-covr-trace-retarget.md`
- this report

No example file, Rd file, NEWS entry, or vignette changed. The heavy
coverage workflow calls the same runner and needed no edit of its own.

## 3a. Decisions and Rejected Alternatives

Rejected: raising `timeout-minutes`, skipping tests, adding `nocov`, or
narrowing the shard. Rejected: leaving the 3.6.5 pin in place, because the
fast lane would never exercise the retarget and `any::covr` on the heavy
lane would keep failing. Rejected: `COVR_INSTALL_INSTRUMENT=false`, which
would re-instrument on every load and change the cost of the shard rather
than keep the counters file covr already wrote.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-18-covr-trace-retarget.md`. The toy
package reproduced the CI message without the retarget and returned 100%
coverage with it. The package test suite was not run; no package test changed.

## 5. Tests of the Tests

`tools/tests/test-retarget-covr-traces.R` fails if a dead `covr_counts` path
is left in place, if a live path or a non-count trace is rewritten, or if a
missing install counters file is ignored. The workflow test fails if the
runner drops the retarget call or if the producer pins covr 3.6.5 again.

## 6. Consistency Audit

Reader-facing surfaces were not edited. The producer still fails the shard
when testthat reports a failure, and it still uploads only on `success()`.
One OS, four shards, `GLLVMTMB_HEAVY_TESTS` unset.

## 7. Roadmap Tick

None. This is a CI measurement fix.

## 8. What Did Not Go Smoothly

Run 44109214096 looked intermittent next to run 44226202218. The first run's
workflow installed `any::covr` (4.0.0). The second had the 3.6.5 pin. All
four shards of the first run, including the rerun, failed the same way after
`FAIL 0`. A local toy package with covr 4.0.0 failed on the same
`/tmp/Rtmp*/RLIBS_*/.../covr_counters.rds` path and passed once the trace
pointed at the install.

## 9. Team Learning

Grace: the producer stays fail-closed. Curie: the retarget changes a path
string, not hit counts; the unit test checks the counts are unchanged.
Shannon: open PRs were listed before the dev-log files were added. #1745 is
a different coverage failure (runaway-warning capture) and was not edited.

## 10. Known Limitations and Next Actions

The pull request's own coverage shards are the check that this survives the
real suite. A future covr that stops using class `covr_counts` would make
the retarget a no-op and the old error would return. No validation-debt row
moves.
