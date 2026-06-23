# After Task: Power Pilot Aggregate Report Reader

## Goal

Add the next narrow Design 66 compute-readiness slice: after immutable chunks
are audited and aggregated into per-cell files, let the existing report layer
read those aggregate files explicitly and compute the same MCSE, denominator,
fit-health, and evidence-label summary it already computes for accumulated
stores.

## Implemented

- Added `pilot_chunk_aggregate_results_dirs()` to resolve `_chunk-aggregate/`
  directories from parent pilot result directories.
- Added `pilot_collect_chunk_aggregates()` as the explicit report reader for
  per-cell aggregate files produced by `pilot_aggregate_chunk_outputs()`.
- Added `dev/m3-pilot-report.R --emit-issues --chunk-aggregate` so issue-summary
  jobs can read aggregate stores after chunk validation and aggregation.
- Added `--chunk-aggregate` support to the scoring-audit CLI route by resolving
  aggregate directories before calling `pilot_scoring_audit()`.
- Added report tests for direct aggregate collection and CLI issue-line
  emission from `_chunk-aggregate/`.
- Updated `docs/design/66-capstone-power-study.md` to describe this as an
  explicit source, not an automatic scan, and to state that it does not mutate
  `pilot-index.rds`.

## Mathematical Contract

No likelihood, DGP, estimator, interval, formula grammar, or model-fitting
semantics changed. The report reader only changes where already-validated
per-replicate rows are read from. The rows then pass through the existing
`pilot_collect()` reducer, preserving current coverage, MCSE, denominator,
fit-health, and evidence-label semantics.

## Files Changed

- `dev/m3-pilot-report.R`
- `tests/testthat/test-m3-pilot-report.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-aggregate-report-reader.md`

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url && git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before editing shared design/dev-log files.
- `git status --short --branch`
  -> clean branch start on
  `codex/power-pilot-aggregate-report-20260623...origin/main`.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-report.R")); invisible(parse("tests/testthat/test-m3-pilot-report.R")); cat("parse ok\n")'`
  -> PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-report.R")'`
  -> first run FAIL on CLI working directory, then PASS after the test ran the
  CLI from the repo root.
- `air format dev/m3-pilot-report.R tests/testthat/test-m3-pilot-report.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 140 expectations.
- `rm -rf /tmp/gllvmtmb-aggregate-report-smoke && Rscript --vanilla dev/power-pilot-run.R --mode=chunk --shard=1 --n-shards=48 --n-sim-step=1 --n-sim-cap=5 --seed-base=162 --results-dir=/tmp/gllvmtmb-aggregate-report-smoke --n-boot=0 --dry-run=true >/tmp/gllvmtmb-aggregate-report-smoke.out 2>&1 && Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir=/tmp/gllvmtmb-aggregate-report-smoke >>/tmp/gllvmtmb-aggregate-report-smoke.out 2>&1 && Rscript --vanilla dev/power-pilot-run.R --mode=chunk-aggregate --results-dir=/tmp/gllvmtmb-aggregate-report-smoke >>/tmp/gllvmtmb-aggregate-report-smoke.out 2>&1 && Rscript --vanilla dev/m3-pilot-report.R --emit-issues --chunk-aggregate --results-dir=/tmp/gllvmtmb-aggregate-report-smoke >>/tmp/gllvmtmb-aggregate-report-smoke.out 2>&1 && cat /tmp/gllvmtmb-aggregate-report-smoke.out && find /tmp/gllvmtmb-aggregate-report-smoke -type f | sort`
  -> PASS.
- `git diff --check`
  -> PASS.
- `rg -n "pilot_collect_chunk_aggregates|pilot_chunk_aggregate_results_dirs|--chunk-aggregate|_chunk-aggregate|PILOT_CHUNK_AGGREGATE_DIR" dev/m3-pilot-report.R tests/testthat/test-m3-pilot-report.R docs/design/66-capstone-power-study.md`
  -> PASS for intended references.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML|pilot-index\\.rds.*(write|mutate|update|rebuild)|automatic.*chunk.*scan|double-count" dev/m3-pilot-report.R tests/testthat/test-m3-pilot-report.R docs/design/66-capstone-power-study.md`
  -> PASS for no DRAC/SLURM/GPU/production/AI-REML overclaim, no
  `pilot-index.rds` mutation wording, and no automatic chunk-scan wording.
  Expected `double-counted` guardrail matches appeared in the new aggregate
  report helper/design note and in an older row-deduplication helper comment.

## Tests Of The Tests

The new tests exercise:

- direct collection from a fake `_chunk-aggregate/<cell>.rds` store;
- preservation of denominator, MCSE, fit-health, and evidence-label columns;
- CLI issue-line emission with `--emit-issues --chunk-aggregate`.

## Consistency Audit

The design note now describes the preflight -> chunk -> chunk-audit ->
chunk-aggregate -> aggregate-report ladder. No user-facing package capability
was advertised, no validation row status moved, and `CI-08`/`CI-10` remain
partial.

## What Did Not Go Smoothly

The first focused test run failed because the CLI smoke inherited testthat's
working directory. In that context, the script could not find `dev/m3-grid.R`,
hit the fail-soft summary path, and printed `none`. The test now runs the CLI
from the detected repo root, matching the intended GitHub-summary use.

## Team Learning

Grace's reporting guardrail is to keep aggregate stores explicit. A caller must
ask for `_chunk-aggregate/` with `--chunk-aggregate` or
`pilot_collect_chunk_aggregates()`, so derived chunk aggregates cannot be
silently combined with legacy accumulated stores.

## Known Limitations

- No Totoro login, DRAC login, SLURM job, GPU check, production campaign, or
  `n_sim = 2000` run was launched.
- `pilot-index.rds` is not rebuilt from immutable chunks in this slice.
- True binary probit, ordinal coverage repair, denominator expansion beyond the
  current report table, and final power/Type-I metric semantics remain separate
  work.

## Next Actions

The next safe slice is to add an audit-mini manifest for representative
Gaussian, nbinom2, binomial-logit/probit, and ordinal-probit cells, still at
tiny smoke scale and still without DRAC/SLURM submission.
