# After Task: Power-Pilot Shard Artifact Slice

## Goal

Repair the scheduled power-pilot persistence path so a green sweep with attempted
replicates can actually advance the durable `power-pilot-results` branch.

## Implemented

Each shard now packages a clean slice artifact containing only its touched
per-cell `.rds` file(s) plus `_runstats`. The workflow uploads that slice rather
than the full seeded store, and the persist job rejects unexpectedly large shard
artifacts before merging them.

## Mathematical Contract

No model equation, likelihood, estimator, formula grammar, simulation DGP, or
coverage estimand changed. This was a workflow persistence repair only. The
scientific claim boundary is unchanged: a green power-pilot run is process
health, not coverage or power proof.

## Files Changed

- `.github/workflows/power-pilot-sweep.yaml`
- `dev/power-pilot-run.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-17-power-pilot-shard-artifact-slice.md`

## Checks Run

- `gh pr list --state open`
- `git log --all --oneline --since="6 hours ago"`
- `git diff --check`
- Empty-store slice smoke with `Rscript --vanilla dev/power-pilot-run.R --mode=slice ...`
- Positive slice-copy smoke for shard 31, confirming only
  `nbinom2-d2-n150-sig0p0.rds` was copied.
- Shell merge simulation, confirming two fresh shard files survive without
  stale seed overwrite.
- Shell guard simulation, confirming an oversized shard slice with `N_SHARDS=48`
  exits before merge.
- Exact audit scan:
  `rg -n "power-pilot-store-shard-|power-pilot-store-seed|pilot-index\\.rds|no store changes|mode=slice|slice-dir" .github/workflows/power-pilot-sweep.yaml dev/power-pilot-run.R dev/m3-pilot-launch.R`

## Tests Of The Tests

The positive merge simulation reproduces the class of bug from run 105: two
shards must be able to advance disjoint cells without later artifacts restoring
seed-state files. The negative guard simulation verifies that a future full-store
artifact regression is caught before merge.

## Consistency Audit

No user-facing capability was advertised. No validation-debt row changed status.
No roxygen, generated Rd, README, NEWS, vignette, article, `_pkgdown.yml`,
formula grammar, or TMB likelihood path was touched. The check-log records the
exact audit scan pattern.

## What Did Not Go Smoothly

The first local shell reproduction pointed at the wrong temporary directory, so
it only proved the test wiring was wrong. The corrected reproduction confirmed
the intended merge behavior.

## Team Learning

Grace owns the CI/workflow lesson: shard artifacts must contain deltas, not the
entire seeded mutable store. Fisher and Curie should still treat the next green
run as accumulation evidence only after the results branch advances and the
scoring audit is refreshed.

## Known Limitations

This local patch cannot prove the GitHub-hosted workflow until it lands on
`main` and a scheduled or manually dispatched run executes. The current live
power-pilot evidence remains unpromoted: run 105 was green, but
`origin/power-pilot-results` did not advance.

## Next Actions

Open or merge this as a bounded workflow repair, then dispatch a dry run or wait
for the next scheduled sweep. The acceptance signal is a new
`power-pilot-results` commit after a run with nonzero attempted cells.
