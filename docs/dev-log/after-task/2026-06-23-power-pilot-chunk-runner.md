# After Task: Power Pilot Immutable Chunk Runner

## 1. Goal

Move the Design 66 power-pilot compute path one small step beyond manifest-only
preflight: prove that an active chunk manifest row can write one immutable RDS
chunk that the existing chunk-output audit can validate.

## 2. Implemented

- Added `lambda_scale` to `pilot_build_manifest()` rows so chunk jobs carry the
  same signal-to-loading-scale value used by the accumulated-store runner.
- Added `pilot_run_chunk_manifest()`, which validates active
  `output_mode = "chunk"` manifest rows, calls `m3_run_cell()`, reindexes
  `rep` into the planned per-cell window, adds chunk provenance fields, and
  writes one chunk RDS per active row.
- Added `dev/power-pilot-run.R --mode=chunk`, which builds and writes the
  chunk manifest, runs active rows, emits simple machine-readable counters, and
  validates outputs with `pilot_assert_chunk_outputs()`.
- Updated `docs/design/66-capstone-power-study.md` to separate preflight,
  chunk writing, chunk-output audit, and later aggregation.

## 3a. Decisions and Rejected Alternatives

No likelihood, estimator, family, interval, or data-generating process changed.
The runner reuses `m3_run_cell()` with the same arguments as the accumulated
runner: `family`, `d`, `n_units`, `lambda_scale`, `targets =
"Sigma_unit_diag"`, `n_boot`, and `ci_level`. The only new transformation is
bookkeeping: each chunk's local `rep = 1..n_reps` is reindexed to the manifest
window `n_before + 1 .. n_before + n_reps_planned`, matching the existing
accumulated-store `pilot_reindex_reps()` contract.

Rejected alternatives:

- Do not retrofit the existing accumulated-store `--mode=shard` path to write
  chunks; that would mix shared per-cell stores and immutable chunk semantics.
- Do not add the aggregator in the same slice; validating "one task writes one
  immutable file" is the smaller compute-readiness proof.
- Do not launch DRAC or SLURM from this branch; the local chunk smoke is enough
  for this code path.

## 4. Files Touched

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-chunk-runner.md`

## 5. Checks Run

- `git fetch origin main --prune && gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url && git log --all --oneline --since="6 hours ago" --decorate` -> PASS; no open PRs before shared-file edits.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'` -> PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'` -> PASS; 85 expectations.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R` -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'` -> PASS; 108 expectations.
- `rm -rf /tmp/gllvmtmb-chunk-runner-smoke && Rscript --vanilla dev/power-pilot-run.R --mode=chunk --shard=1 --n-shards=48 --n-sim-step=1 --n-sim-cap=5 --seed-base=157 --results-dir=/tmp/gllvmtmb-chunk-runner-smoke --n-boot=0 --dry-run=true >/tmp/gllvmtmb-chunk-runner-smoke.out 2>&1 && Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir=/tmp/gllvmtmb-chunk-runner-smoke >>/tmp/gllvmtmb-chunk-runner-smoke.out 2>&1 && cat /tmp/gllvmtmb-chunk-runner-smoke.out && find /tmp/gllvmtmb-chunk-runner-smoke -type f | sort` -> PASS; one real chunk file plus manifest validated.
- `git diff --check` -> PASS.
- `Rscript --vanilla -e 'source("/Users/z3437171/shinichi-brain/tools/check-after-task.R"); main_check_after_task("docs/dev-log/after-task/2026-06-23-power-pilot-chunk-runner.md")'` -> PASS; after-task structure check passed.

## 6. Tests of the Tests

The new chunk-writer test uses a fake runner so the unit suite does not pay for
fits, but it verifies the important interface: `family`, `d`, `n_reps`,
`seed_base`, `n_units`, `lambda_scale`, `targets`, and `n_boot` are passed from
the manifest into the runner. It also verifies that an existing three-rep store
produces a manifest window `4:5`, that written chunk rows are reindexed to
`rep = 4:5`, and that `pilot_assert_chunk_outputs()` accepts the file. The
negative test rejects an accumulated-store manifest, so the chunk runner cannot
silently write through the shared per-cell-store path.

## 7a. Issue Ledger

- `CI-08` and `CI-10` remain partial.
- No validation-debt row moved.
- No GitHub issue was closed by this slice.
- No Totoro login, DRAC login, SLURM job, GPU check, or production run was
  launched.

## 8. Consistency Audit

- `rg -n "mode=chunk|pilot_run_chunk_manifest|lambda_scale|chunk_rows|pilot_chunk_id|pilot_assert_chunk_outputs" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md` -> intended hits only.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML|pilot-index\\.rds.*chunk.*writer|chunk.*writer.*pilot-index\\.rds" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md` -> no matches.

No validation-debt row moved. `CI-08` and `CI-10` remain partial because this
does not repair pilot metric semantics, add target-explicit coverage gates, or
run the confirmatory campaign.

## 9. What Did Not Go Smoothly

The first focused test run failed because the test expected
`pilot_assert_chunk_outputs()` to return literal `TRUE`. The helper correctly
returns an audit data frame, so the test now checks `nrow(audit)` and
`audit$exists`.

## 10. Known Residuals

- No immutable-chunk aggregator exists yet.
- `pilot-index.rds` remains the accumulated-store derived cache; chunk-mode
  files are not combined into it.
- No Totoro login, DRAC login, SLURM job, GPU check, or production run was
  launched.
- True binary probit, ordinal coverage repair, MCSE denominator expansion, and
  the audit-mini design remain separate slices.

## Next Actions

1. Add an immutable-chunk aggregator that reads validated chunk files, detects
   missing/duplicate `(cell_id, rep)` rows, combines chunks per cell, and writes
   a derived per-cell store or report artifact.
2. Add a no-fit aggregation CLI smoke, then a tiny local chunk+aggregate smoke.
3. Only after the aggregation path passes locally, map the same commands onto
   Totoro and DRAC login-node manifest checks.

## 11. Team Learning

Ada kept the lane small after the #544 merge: one runnable chunk writer, no
aggregator, no DRAC launch. Shannon's coordination check was clean: fresh
worktree from `origin/main`, no open PRs, and recent history was the expected
#538-#544 sequence. Grace's compute-readiness rule is reinforced: the local
smoke writes one chunk and validates it before any scheduler work.
