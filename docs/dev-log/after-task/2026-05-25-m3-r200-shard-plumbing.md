# After-task: M3 r200 shard plumbing

**Date:** 2026-05-25
**Branch:** `codex/r200-shard-plumbing-2026-05-25`
**Spawned subagents:** none. Ada coordinated with Grace, Curie, Fisher,
and Shannon perspectives.

## Task Goal

Prepare the M3 production-grid workflow for a future maintainer-authorised
r200 run by adding deterministic four-shard plumbing. This PR does not
dispatch r200, does not inspect results, and does not change any
validation-debt register status.

## Files Changed

- `.github/workflows/m3-production-grid.yaml`
  - Adds `shard: [1, 2, 3, 4]` to the workflow matrix.
  - Names shard artefacts as
    `m3-coverage-{family}-d{d}-shard{N}-{grid,summary}.rds`.
  - Adds a downstream aggregate job that downloads shard artefacts for
    each `(family, d)` cell and uploads the existing aggregate artefact
    shape: `m3-coverage-{family}-d{d}-{grid,summary}.rds`.
  - Raises default retention from 14 to 30 days.
  - Repeats the Design 50 / PR #267 / PR #270 stop conditions in workflow
    comments.
- `dev/m3-grid.R`
  - Adds `m3_shard_rep_range()` and `m3_rep_index_range()`.
  - Adds `rep_index_start` / `rep_index_end` support to `m3_run_cell()`
    and `m3_run_grid()` so shard-local jobs preserve global replicate
    numbers and global replicate seeds.
- `dev/precompute-m3-grid.R`
  - Adds `--shard` and `--n-shards` CLI flags.
  - Records shard metadata in the grid artefact.
- `dev/aggregate-m3-shards.R`
  - New combiner that reads shard grid artefacts, checks duplicate
    replicate rows, recomputes `m3_summarise()`, and writes aggregate
    grid + summary RDS files.
- `docs/dev-log/check-log.md`
  - Records commands, outcomes, and deliberate non-runs for this slice.

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> no open PRs before editing.
- `git log --all --oneline --since="6 hours ago"`
  -> recent #261, #265, #268, #270, #271, and #272 activity inspected.
- `gh run list --repo itchyshin/gllvmTMB --limit 12 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url`
  -> post-#272 `main` R-CMD-check active; local work proceeded and push
  was held.
- `air format dev/m3-grid.R dev/precompute-m3-grid.R dev/aggregate-m3-shards.R`
  -> completed.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=4 --shard=1 --n-shards=2 --targets=Sigma_unit_diag --n-boot=0 --seed-base=20260525 --out-dir=/tmp/gllvmTMB-m3-shard-smoke --out-prefix=m3-coverage-gaussian-d1-shard1`
  -> global reps 1-2 ran in `real 4.16s`.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=4 --shard=2 --n-shards=2 --targets=Sigma_unit_diag --n-boot=0 --seed-base=20260525 --out-dir=/tmp/gllvmTMB-m3-shard-smoke --out-prefix=m3-coverage-gaussian-d1-shard2`
  -> global reps 3-4 ran in `real 3.28s`.
- `Rscript --vanilla dev/aggregate-m3-shards.R --input-dir=/tmp/gllvmTMB-m3-shard-smoke --input-prefix=m3-coverage-gaussian-d1 --out-dir=/tmp/gllvmTMB-m3-shard-smoke --out-prefix=m3-coverage-gaussian-d1`
  -> read 2 shard grid artefacts and wrote aggregate grid + summary.
- `Rscript --vanilla -e 'x <- readRDS("/tmp/gllvmTMB-m3-shard-smoke/m3-coverage-gaussian-d1-grid.rds"); stopifnot(identical(sort(unique(x$grid$rep)), 1:4)); stopifnot(nrow(x$summary) == 1L); ...'`
  -> aggregate metadata preserved reps 1-4 and summary reported
  `n_completed = 4`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); stopifnot(identical(as.integer(m3_shard_rep_range(200, 1, 4)), c(1L, 50L))); stopifnot(identical(as.integer(m3_shard_rep_range(200, 4, 4)), c(151L, 200L))); cat("shard ranges ok\n")'`
  -> `shard ranges ok`.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/m3-production-grid.yaml"); puts "workflow yaml ok"'`
  -> `workflow yaml ok`.
- `git diff --check`
  -> clean.

## Definition of Done

- **Implementation:** workflow, driver, grid runner, and aggregation script
  implement deterministic shard plumbing.
- **Simulation recovery test:** not applicable; no likelihood, family,
  estimator, or formula grammar changed. The local Gaussian smoke verifies
  runner plumbing only.
- **Documentation:** dev-log and after-task report document usage,
  artefact names, and scope boundaries.
- **Runnable user-facing example:** not applicable; this is internal dev
  infrastructure. A local dev smoke command is recorded above.
- **Check-log entry:** appended in this branch.
- **Review pass:** Grace / Curie / Fisher / Shannon perspectives applied to
  workflow dispatch, replicate identity, promotion-gate wording, and lane
  coordination.

## Boundaries

- No r200 workflow was dispatched.
- No validation-debt register row was edited.
- No result memo was written.
- No `ROADMAP.md`, `_pkgdown.yml`, article, `R/*`, `src/*`,
  `NAMESPACE`, or reference documentation changed.
- The post-run register edit remains a separate slice after maintainer
  authorisation, workflow completion, and result review.
