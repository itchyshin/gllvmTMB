# Check-log: covr trace retarget (refs #1785)

**Goal:** Show that covr 4's "Can't read coverage trace file" failure is the
R CMD check temp-library symlink, and that retargeting the stored path onto
the surviving install restores coverage without dropping tests.

**Commands:**

    python3 tools/tests/test_codecov_workflow.py
    Rscript --vanilla tools/tests/test-retarget-covr-traces.R
    Rscript --vanilla /tmp/covr-repro.R

The third command is a local toy package (`toypkg`, one function, `tests/foo.R`)
run twice through `covr::package_coverage(type = "none")` and
`R CMD check --as-cran --install=skip`. covr 4.0.0 was installed in
`/tmp/Rlib` and copied into `.Library` so the check could load it. That
script is not in the repo.

**Results:**

- `python3 tools/tests/test_codecov_workflow.py`: 11 tests, OK.
- `Rscript --vanilla tools/tests/test-retarget-covr-traces.R`:
  `retarget_covr_traces: PASS` (R 4.3.3). One dead `covr_counts` path was
  rewritten; a live path, a plain trace, and a `covr_pending_*` marker were
  left alone; a missing stable counters file stopped the retarget.
- `/tmp/covr-repro.R` with covr 4.0.0: the run without the retarget stopped
  with `Can't read coverage trace file
  '/tmp/RtmpaQwLkX/RLIBS_d2eb2ce263b1/toypkg/R/covr_counters.rds'`. The same
  package with `retarget_missing_covr_counters()` reported `ok=TRUE` and
  `percent=100`.

Not run: the four GitHub coverage shards (they are the pull-request check),
`devtools::test()`, and `devtools::check()`. No package test, likelihood, or
Rd file changed.

**Claim boundary:** This does not change line-coverage scope, skip any test,
add `nocov`, or raise the shard timeout. It does not change a validation-debt
row or a public estimate. The toy percent is one function in a throwaway
package, not a gllvmTMB coverage number.
