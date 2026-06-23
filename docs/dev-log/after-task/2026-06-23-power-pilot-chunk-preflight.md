# After Task: Power Pilot Chunk Preflight

**Branch**: `codex/power-pilot-chunks-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada, Grace, Curie, Fisher, Shannon`

## 1. Goal

Prepare the Design 66 pilot for the next compute-readiness step by adding a
manifest-only chunk preflight path. The slice should let Totoro/DRAC validate
the planned `(campaign_id, cell_id, chunk_id)` destinations without launching
fits, changing the current GitHub accumulated-store behavior, or promoting
`CI-08` / `CI-10`.

## 2. Implemented

- Added `PILOT_CHUNK_DIR`, `pilot_chunk_dir()`, and `pilot_chunk_path()` to
  describe future immutable chunk destinations.
- Extended `pilot_build_manifest()` with `output_mode = "accumulate"` or
  `"chunk"`. The default preserves the existing current-store path; chunk mode
  points `result_path` at the immutable chunk path while still recording
  `store_path`.
- Extended `pilot_assert_manifest()` so it can validate chunk paths and, when
  needed, allow duplicate current-store paths for future chunk aggregation.
- Added `dev/power-pilot-run.R --mode=preflight --output-mode=chunk`, which
  writes and validates a manifest and exits before fitting.
- Added tests for chunk paths, duplicate chunk-path rejection, and CLI preflight
  producing only a manifest file.
- Updated Design 66 to document the no-fit preflight boundary.

## 3a. Decisions and Rejected Alternatives

Decision: keep the GitHub sweep on the existing accumulated per-cell writer.
Rationale: PR #542 just made that lane auditable and green; converting the
writer and aggregator in the same slice would mix compute semantics with a
preflight safety feature. Rejected alternative: immediately write chunk `.rds`
files from `run_accumulate_pilot_batch()`. Confidence: high for this slice.

Decision: make `output_mode = "chunk"` a manifest option, not a global behavior
change. Rationale: DRAC smoke tests need to validate immutable destinations now,
while the current GitHub path still needs duplicate current-store-path checks.
Rejected alternative: remove duplicate `result_path` checks entirely. Confidence:
high.

## 4. Files Touched

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-chunk-preflight.md`

## 5. Checks Run

- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  -> PASS; `parse ok`.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 42 expectations, 0 skips after the CLI smoke was rooted at the
  resolved repo root. GitHub R-CMD-check run `28050578137` later failed because
  this test used bare `Rscript`; the test now uses
  `file.path(R.home("bin"), "Rscript")`.
- `rm -rf /tmp/gllvmtmb-preflight-all48 && Rscript --vanilla dev/power-pilot-run.R --mode=preflight --shard=1 --n-shards=1 --n-sim-step=200 --n-sim-cap=2000 --seed-base=150 --results-dir=/tmp/gllvmtmb-preflight-all48 --n-boot=0 --output-mode=chunk && find /tmp/gllvmtmb-preflight-all48 -maxdepth 3 -type f -print | sort`
  -> PASS; wrote 48 manifest rows and 48 active chunks; only
  `_manifests/shard-1.csv` existed.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 65 expectations.
- `git diff --check`
  -> PASS.

## 6. Tests of the Tests

The CLI preflight test first skipped because the test context did not have
`dev/power-pilot-run.R` under `.`. I changed the helper to record the resolved
repo root and reran the test file; the preflight test then executed and verified
that no result `.rds` file was produced. The duplicate-chunk-path test mutates a
valid manifest into an invalid one and confirms the validator rejects it.

## 7a. Issue Ledger

No GitHub issue was inspected, commented, closed, or created. This slice is a
follow-up to the mid-term compute-readiness plan rather than an issue-specific
fix.

## 8. Consistency Audit

- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I|0 level \\*is\\* the Type-I|signal-zero Type-I" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  -> PASS; no matches.
- `rg -n "pilot-index\\.rds.*source of truth|source of truth.*pilot-index|index.*source of truth|shared index.*audit trail|derived cache|local resume cache" dev/m3-pilot-launch.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  -> PASS; remaining hits describe `pilot-index.rds` as a local resume cache
  or derived cache.
- `rg -n "mode=preflight|output-mode=chunk|chunk_path|chunk destinations|without launching fits|before fitting|m3_run_cell\\(" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS for intended coverage.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS; no matches.

## 9. What Did Not Go Smoothly

The first version of the preflight test skipped because `testthat::test_file()`
did not run with the repository root as `.`. The fix was small: the helper now
records `power_pilot_root`, and the CLI smoke temporarily sets that working
directory before calling `dev/power-pilot-run.R`. GitHub then caught a second
test-only portability issue: R CMD check rejects bare `Rscript` in tests. The
test now calls `file.path(R.home("bin"), "Rscript")`.

## 10. Known Residuals

- The current GitHub workflow still writes accumulated per-cell result files.
- The chunk manifest is not yet consumed by a chunk-result aggregator.
- No Totoro/DRAC login or SLURM submission was attempted.
- True binary probit and ordinal-probit coverage remain separate repair lanes.
- `CI-08` and `CI-10` remain partial.

## 11. Team Learning

Ada kept this as a preflight slice rather than a writer rewrite. Grace's main
constraint was that the first compute smoke must not fit on login nodes or
write shared files. Curie and Fisher kept the manifest tied to seed ranges,
replicate windows, and future MCSE-denominator work. Shannon's coordination
gate kept the branch clean and separated from the dirty mission-control tree.
