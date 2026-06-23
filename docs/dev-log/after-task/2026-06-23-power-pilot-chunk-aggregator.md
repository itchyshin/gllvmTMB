# After Task: Power Pilot Immutable Chunk Aggregator

## Goal

Add the next narrow Design 66 compute-readiness slice: after chunk files are
written and audited, provide a single-writer step that binds validated chunks
into per-cell aggregate files without launching DRAC, SLURM, GPU, or production
simulation work.

## Implemented

- Added `PILOT_CHUNK_AGGREGATE_DIR` and `pilot_chunk_aggregate_dir()` for
  derived per-cell aggregate files under `_chunk-aggregate/`.
- Added `pilot_read_chunk_outputs()` to read active chunk manifest rows,
  require chunk files to be readable non-empty data frames, require `rep` and
  `trait_id`, verify campaign/chunk/cell metadata, and require observed
  replicate windows to match `rep_start`/`rep_end`.
- Added `pilot_assert_unique_chunk_rows()` and `pilot_aggregate_chunk_outputs()`
  to reject duplicate aggregate keys and optionally write one aggregate RDS per
  `pilot_cell_id`.
- Added `dev/power-pilot-run.R --mode=chunk-aggregate` and GitHub-output fields
  `chunk_aggregate_ok`, `chunk_aggregate_cells`, `chunk_aggregate_rows`,
  `chunk_aggregate_dir`, and `chunk_aggregate_error`.
- Updated `docs/design/66-capstone-power-study.md` to place
  `chunk-aggregate` after `chunk-audit` as a derived single-writer step.

## Mathematical Contract

No likelihood, DGP, estimator, interval, formula grammar, or model-fitting
semantics changed. The only contract added here is file-level provenance:
validated chunk rows must bind one-to-one into aggregate rows keyed by
`pilot_cell_id`, `rep`, `trait_id`, and `target` when `target` is present.

## Files Changed

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-chunk-aggregator.md`

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url && git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before editing shared design/dev-log files.
- `git status --short --branch`
  -> clean branch start on
  `codex/power-pilot-chunk-aggregator-20260623...origin/main`.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  -> PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> first run FAIL on test-helper scoping, then PASS after the helper fix.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 130 expectations.
- `rm -rf /tmp/gllvmtmb-chunk-aggregate-smoke && Rscript --vanilla dev/power-pilot-run.R --mode=chunk --shard=1 --n-shards=48 --n-sim-step=1 --n-sim-cap=5 --seed-base=162 --results-dir=/tmp/gllvmtmb-chunk-aggregate-smoke --n-boot=0 --dry-run=true >/tmp/gllvmtmb-chunk-aggregate-smoke.out 2>&1 && Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir=/tmp/gllvmtmb-chunk-aggregate-smoke >>/tmp/gllvmtmb-chunk-aggregate-smoke.out 2>&1 && Rscript --vanilla dev/power-pilot-run.R --mode=chunk-aggregate --results-dir=/tmp/gllvmtmb-chunk-aggregate-smoke >>/tmp/gllvmtmb-chunk-aggregate-smoke.out 2>&1 && cat /tmp/gllvmtmb-chunk-aggregate-smoke.out && find /tmp/gllvmtmb-chunk-aggregate-smoke -type f | sort`
  -> PASS.
- `rg -n "mode=chunk-aggregate|pilot_aggregate_chunk_outputs|pilot_read_chunk_outputs|pilot_assert_unique_chunk_rows|PILOT_CHUNK_AGGREGATE_DIR|_chunk-aggregate|chunk_aggregate" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS for intended references.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML|pilot-index\\.rds.*chunk.*aggregate|chunk.*aggregate.*pilot-index\\.rds|concurrent.*aggregate" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS; no matches.

## Tests Of The Tests

The new tests exercise boundary and failure paths:

- valid two-chunk aggregation writes one per-cell file and preserves both chunk
  IDs;
- a chunk whose observed `rep` values do not match the manifest window errors;
- duplicate `pilot_cell_id`/`rep`/`trait_id`/`target` rows error;
- the CLI `--mode=chunk-aggregate` writes the expected aggregate artifact.

## Consistency Audit

The design note now describes the preflight -> chunk -> chunk-audit ->
chunk-aggregate ladder. No user-facing package capability was advertised, no
validation row status moved, and `CI-08`/`CI-10` remain partial.

## What Did Not Go Smoothly

The first focused test run failed because the new `two_chunk_manifest()` test
helper was defined outside testthat's per-test sourcing environment. The helper
now resolves the sourced dev functions from `parent.frame()`, matching how the
existing tests call `source_power_pilot_manifest()`.

## Team Learning

Ada/Shannon kept this as a compute-readiness slice rather than a simulation
launch. Grace's guardrail for the next slice is to treat aggregate files as
derived artifacts until a separate report/index rebuild step validates the
derived store.

## Known Limitations

- No Totoro login, DRAC login, SLURM job, GPU check, production campaign, or
  `n_sim = 2000` run was launched.
- `pilot-index.rds` is not rebuilt from immutable chunks in this slice.
- MCSE, denominator expansion, true binary probit, ordinal coverage repair, and
  final power/Type-I metric semantics remain separate work.

## Next Actions

The next safe slice is to consume `_chunk-aggregate/` files in a read-only report
step that computes per-cell fit-health denominators and MCSE-ready summaries
without mutating the legacy accumulated store.
