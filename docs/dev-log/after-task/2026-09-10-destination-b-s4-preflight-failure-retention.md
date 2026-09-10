# After Task: Destination B S4 clean-Julia-probe diagnostic retention

## Goal

Retain an immutable failed diagnostic when the sealed S4 Julia qualification
probe stops before either selected test can run.

## Implemented

The isolated S4 runner now represents an unclean Julia probe as a structured
condition with captured output, process status, and command. After reserving
the deterministic failed-attempt namespace, its main path retains a link-only
`FAILED.json` with status `failed_environment_preflight_not_a_receipt`, stage
`julia_clean_probe`, zero selected tests, and a raw-output SHA-256, then stops
before loading `gllvmTMB` or dispatching the selected tests.

## Files Changed

- `tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R`
- `tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R`
- `docs/dev-log/check-log.md`
- this report

## Tests Added

One synthetic nonzero-probe flow test. Its RED run had one intended failing
assertion because the reserved namespace contained no `FAILED.json`; the
subsequent JSON-read error was a direct consequence of that missing file. The
GREEN test proves that the actual main-flow handler writes the diagnostic,
preserves raw output and its hash, records probe status/command and zero test
count, and leaves no receipt. This is a failure-path test of the test runner;
it launches no Julia process.

## Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R", reporter = "summary")'
Rscript --vanilla -e 'parse(file = "tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R"); parse(file = "tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R"); results <- testthat::test_file("tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R", reporter = "silent"); tab <- as.data.frame(results); cat(sprintf("S4_PREFLIGHT_RETENTION tests=%d passed=%d failed=%d skipped=%d error=%d warning=%d\\n", nrow(tab), sum(tab$passed), sum(tab$failed), sum(tab$skipped), sum(tab$error), sum(tab$warning)))'
git diff --check
```

The focused GREEN tally was 11 tests / 83 expectations, with 0 failed, 0
skipped, 0 errors, and 0 warnings. Parsing and `git diff --check` passed.

## Scope and Limitations

This is runner evidence retention only. It changes no model, likelihood, C++,
generic engine admission, public formula surface, or Julia package code. No
live Julia probe, S4 replay, model fit, receipt, qualification, push, merge,
or release ran. The previously reserved empty namespace is intentionally
untouched; a future replay needs a new output path and fresh approval.

## Benchmark, Parity, and Julia Quality

- Benchmarks: N/A — no numerical hot path changed.
- R parity: N/A — no estimator or interval calculation changed.
- JET, Allocs, Aqua: N/A — no Julia source, export, dependency, or hot loop changed.

## Independent Review

Independent review: PASS — the handler is reached after namespace reservation
and before package loading/test dispatch, preserves raw probe evidence, and
does not turn a preflight failure into a receipt.

## Next Command

None for this repair. A future S4 replay requires a new output path and fresh
maintainer approval.

## Rose Verdict

Rose verdict: PASS WITH NOTES — the local preflight-retention gap is closed;
the underlying Julia environment failure remains unclassified until separately
authorized diagnostic work captures it.
