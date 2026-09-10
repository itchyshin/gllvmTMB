# After Task: S4 failed-attempt diagnostic retention

## Goal

Retain an immutable diagnostic if the two sealed S4 selected tests are not
clean, before the runner refuses to publish a receipt.

## Implemented

The S4 runner now writes a distinct `-FAILED.json` artifact by hard link only.
It carries status `failed_test_attempt_not_a_receipt`, so it is neither a
passed receipt nor eligible to overwrite one. It binds the sealed build, R and
GLLVM runtime snapshots, Julia probe, runner identity, exact selected test
expressions, per-test table/counts, untouched raw output lines and hash, and
available expectation message/call/backtrace fields. The artifact states the
raw-output gap: `ListReporter` raw capture can omit expectation details.

## Mathematical Contract

N/A — runner evidence retention only; no likelihood, estimator, model, or
interval calculation changed.

## Files Changed

- `tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R` —
  write-once failed-attempt diagnostic and pre-refusal retention.
- `tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R` —
  synthetic non-clean-tab contract test.
- `docs/dev-log/check-log.md` — scope and check evidence.
- `docs/dev-log/after-task/2026-09-10-destination-b-s4-failure-diagnostics.md`
  — this closure record.

## Tests Added

One focused synthetic failed-tab test (18 expectations). It first failed
because the retention helper was absent, then passed. It checks the separate
failed path, no receipt, raw-output preservation/hash, all required identity
classes, selected expressions, per-test fields, available reporter detail, and
byte-for-byte write-once protection. This satisfies the failure-path clause.

## Benchmark Numbers

N/A — no hot path changed.

## R-Parity Verdict

N/A — no likelihood or fitting surface changed.

## JET / Allocs / Aqua Verdicts

- JET: N/A — R runner-only change.
- Allocs: N/A — no numerical inner loop changed.
- Aqua: N/A — Julia project/export/dependency surface unchanged.

## Checks Run

`Rscript -e 'testthat::test_file("tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R", reporter = "summary")'`
passed after the TDD RED run: 7 tests, 49 expectations, 0 failed, 0 skipped,
0 errors, 0 warnings. `git diff --check` passed. No S4 fit, Julia probe, or
selected-test replay was run.

## Consistency Audit

`git diff --check` was clean. The changed runner/test and this check-log entry
were read together; no README, public manual, C++, likelihood, engine-admission,
or seal text changed because the behavior is retained failure evidence only.

## GitHub Issue Maintenance

No issue action needed: this is a narrow in-lane evidence-retention repair.

## What Did Not Go Smoothly

The first GREEN run exposed that a helper hashed a runner path relative to the
test process working directory. The hash was moved into execution provenance,
where the runner path is known. A second test exposed that JSON dropped names
on the selected-expression vector; it is now serialized as a named list.

## P1 Collision Remediation

The original derived sibling name, `receipt-FAILED.json`, could already be a
differently named successful receipt. The runner now reserves the separate
deterministic namespace `receipt.json.failed-attempt/FAILED.json` before any
attempt activity. The new contract test proves that an occupied namespace fails
early while a legacy sibling receipt cannot collide with the reserved path. The
focused fit-free contract is now 8 tests / 53 expectations, all green.

## P2 Condition-Serialization Repair

The failed-attempt writer now recursively normalizes captured S3 conditions in
reporter details before JSON serialization. Each condition becomes only its
message, class, deparsed call, and rendered backtrace; no condition object
reaches `jsonlite`. The raw `capture.output` value is not normalized or
otherwise changed. The synthetic failed-pair regression first reproduced
`No method asJSON S3 class: condition`, then passed while proving the valid
diagnostic retains raw output, creates no receipt, preserves the condition's
identity fields, and remains byte-for-byte immutable after a second write
attempt. The focused fit-free contract is now 9 tests / 63 expectations, all
green.

### P2 Checks Run

`Rscript -e 'results <- testthat::test_file("tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R", reporter = "silent"); tab <- as.data.frame(results); cat(sprintf("S4_RUNNER_CONTRACT tests=%d passed=%d failed=%d skipped=%d error=%d warning=%d\\n", nrow(tab), sum(tab$passed), sum(tab$failed), sum(tab$skipped), sum(tab$error), sum(tab$warning)))'`
reported 9 tests, 63 expectations, 0 failed, 0 skipped, 0 errors, and 0
warnings. No S4 fit, Julia probe, selected-test replay, receipt,
qualification, push, merge, or release ran.

## Team Learning

Use the actual `ListReporter` result objects as a second channel beside raw
captured output: output alone may not explain a failed expectation.

## Remaining Risks

- The diagnostic is exercised only with a synthetic failed tab; no live S4
  replay was authorized or performed.
- A future failed live attempt needs a fresh approval before it may create an
  immutable diagnostic; a prior diagnostic path intentionally cannot be reused.

## Known Limitations

The diagnostic records available backtraces only when testthat supplies them;
it does not manufacture missing conditions or turn a failure into a receipt.

## Next Command

None for this slice. A future live S4 replay requires fresh maintainer approval
and a new output path.

## Rose Verdict

Rose verdict: PASS WITH NOTES — focused fit-free contract coverage is green;
the unrun live failure path remains intentionally unqualified pending fresh
approval.
