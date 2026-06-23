# After Task: Power Pilot Chunk Output Audit

**Branch**: `codex/power-pilot-chunk-aggregate-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada, Grace, Curie, Fisher, Shannon`

## 1. Goal

Add the next safe compute-readiness guardrail for the Design 66 power pilot:
validate future immutable chunk outputs after array tasks finish and before any
aggregation step proceeds. This must not launch fits, mutate DRAC/Totoro state,
replace the current GitHub accumulated-store writer, or promote `CI-08` /
`CI-10`.

## 2. Implemented

- Extended `pilot_assert_manifest()` to reject overlapping per-cell replicate
  windows when `rep_start` / `rep_end` are present.
- Added `pilot_assert_chunk_outputs()`, which validates the manifest and
  returns an audit table for active planned chunks. With `require_all = TRUE`,
  it rejects missing and empty chunk files.
- Added `dev/power-pilot-run.R --mode=chunk-audit`, a no-fit CLI mode for
  dependent aggregation jobs. It fails if no manifest rows exist, fails if any
  planned active chunk file is missing/empty, and emits machine-readable
  `chunk_outputs_ok` / `chunk_output_rows` outputs.
- Added unit and CLI tests for overlapping replicate windows, missing chunk
  files, empty chunk files, successful chunk audit with fake chunk RDS files,
  and missing-manifest failure.
- Updated Design 66 to document the chunk-output audit boundary.

## 3a. Decisions and Rejected Alternatives

Decision: add a validator and CLI audit mode before adding a writer or
aggregator. Rationale: the next real risk is a false green after array
completion, where manifests exist but planned chunk files are missing or empty.
Rejected alternative: convert `run_accumulate_pilot_batch()` to a chunk writer
in this slice. That would mix compute semantics with a guardrail and increase
blast radius. Confidence: high.

Decision: fail `chunk-audit` when there are no manifest rows. Rationale: a
zero-active manifest can be legitimate when all cells are at cap, but a missing
manifest means the dependent job has no audit trail. Rejected alternative:
treat an empty manifest read as a clean no-op. Confidence: high.

## 4. Files Touched

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-chunk-output-audit.md`

## 5. Checks Run

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 57 expectations, 0 warnings/skips.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 80 expectations.
- `rm -rf /tmp/gllvmtmb-chunk-audit-missing && Rscript --vanilla dev/power-pilot-run.R --mode=preflight --shard=1 --n-shards=1 --n-sim-step=2 --n-sim-cap=10 --seed-base=154 --results-dir=/tmp/gllvmtmb-chunk-audit-missing --n-boot=0 --output-mode=chunk >/tmp/gllvmtmb-chunk-audit-preflight.out 2>&1 && set +e; Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir=/tmp/gllvmtmb-chunk-audit-missing >/tmp/gllvmtmb-chunk-audit-missing.out 2>&1; audit_status=$?; set -e; cat /tmp/gllvmtmb-chunk-audit-preflight.out; cat /tmp/gllvmtmb-chunk-audit-missing.out; echo "chunk_audit_exit=$audit_status"; test "$audit_status" -ne 0; rg -q "Missing pilot chunk output" /tmp/gllvmtmb-chunk-audit-missing.out`
  -> PASS; preflight wrote 48 active chunk manifest rows and chunk-audit
  failed with `Missing pilot chunk output` before any aggregation.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  -> PASS; `parse ok`.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS.
- `git diff --check`
  -> PASS.

## 6. Tests of the Tests

The tests intentionally corrupt otherwise valid manifests and outputs:

- duplicate a cell's `rep_start` / `rep_end` window under the same `cell_id`;
- delete a planned chunk file and require `Missing pilot chunk output`;
- create a zero-byte planned chunk file and require `Empty pilot chunk output`;
- run the CLI against an empty results directory and require `found no manifest
  rows`;
- run the CLI against fake non-empty chunk RDS files and require
  `chunk_outputs_ok=true`.

The manual smoke repeats the missing-file failure path after a full 48-row
preflight manifest is written.

## 7a. Issue Ledger

No GitHub issue was inspected, commented, closed, or created. This is a
continuation of the compute-readiness plan following PR #543.

## 8. Consistency Audit

- `rg -n "mode=chunk-audit|pilot_assert_chunk_outputs|Overlapping pilot replicate windows|Missing pilot chunk output|Empty pilot chunk output|found no manifest rows" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS for intended chunk-audit coverage.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS; no matches.
- `git diff --check`
  -> PASS.

## 9. What Did Not Go Smoothly

The first manual shell smoke used `status` as a variable name, which is
read-only in zsh. Rerunning with `audit_status` passed. The first
missing-manifest CLI test also emitted the expected `system2()` warning for a
nonzero exit; the test now suppresses that expected warning and asserts the
status/message directly.

## 10. Known Residuals

- No chunk writer or chunk result aggregator exists yet.
- The current GitHub pilot still accumulates per-cell stores.
- No Totoro/DRAC login, SLURM submission, fit, simulation sweep, or GPU check
  was attempted.
- True binary probit, ordinal coverage repair, MCSE denominator expansion, and
  DRAC environment checks remain separate slices.
- `CI-08` and `CI-10` remain partial.

## 11. Team Learning

Ada kept the lane to a validator and CLI guard. Grace's main concern was that a
dependent job must fail on missing evidence, not quietly accept an empty audit
surface. Curie and Fisher pushed the replicate-window check because chunk
aggregation needs non-overlapping within-cell replicate ranges as well as
non-overlapping seed ranges. Shannon kept the work in a fresh `/private/tmp`
worktree from post-#543 `origin/main`.
