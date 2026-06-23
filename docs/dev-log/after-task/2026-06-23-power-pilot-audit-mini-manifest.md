# After Task: Power Pilot Audit-Mini Manifest

## Goal

Add a small, named audit-mini manifest gate for the power pilot so the next
local or DRAC smoke can target representative cells before any broader
simulation volume.

## Implemented

This slice adds `pilot_audit_mini_grid()`,
`pilot_audit_mini_cell_ids()`, and `pilot_build_audit_mini_manifest()` in
`dev/m3-pilot-launch.R`. It also adds
`dev/power-pilot-run.R --mode=audit-mini`, which writes and validates a
four-cell chunk manifest, emits compact GitHub-output style counters, and exits
before fitting.

The audit-mini cells are gaussian, nbinom2, the current `binomial_probit` label
carried by `binomial_logit_harness`, and ordinal-probit at `d = 1`,
`n_units = 50`, and `signal = 0.2`. Defaults are two planned reps per cell,
chunk output mode, and `n_boot = 0`.

Design 66 now records this as a smoke gate before broader local or DRAC volume.
It explicitly says the binomial row is not true binomial-probit evidence until a
separate probit-link DGP/fit swap is implemented and validated.

## Mathematical Contract

No model, likelihood, DGP, estimator, interval, or scoring equation changed.
The new code only selects existing pilot-grid rows and writes a manifest. The
binomial audit-mini row keeps the existing distinction between
`family_label = "binomial_probit"` and
`evidence_family = "binomial_logit_harness"`; it does not claim validated
binomial-probit behaviour.

## Files Changed

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-audit-mini-manifest.md`

No roxygen, Rd, NEWS, README, pkgdown navigation, family registry, or validation
register rows changed.

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url && git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared design/dev-log edits; no open PRs, recent history was
  the expected #538 through #547 sequence.
- `git status --short --branch`
  -> clean branch start in
  `/private/tmp/gllvmtmb-power-pilot-audit-mini-manifest-20260623`.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  -> PASS; `parse ok`.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 129 expectations.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 162 expectations.
- `rm -rf /tmp/gllvmtmb-audit-mini-smoke && Rscript --vanilla dev/power-pilot-run.R --mode=audit-mini --seed-base=170 --results-dir=/tmp/gllvmtmb-audit-mini-smoke > /tmp/gllvmtmb-audit-mini-smoke.out 2>&1 && cat /tmp/gllvmtmb-audit-mini-smoke.out && find /tmp/gllvmtmb-audit-mini-smoke -type f | sort && Rscript --vanilla -e 'm <- read.csv("/tmp/gllvmtmb-audit-mini-smoke/_manifests/shard-1.csv"); print(m[, c("cell_id", "family_label", "evidence_family", "output_mode", "n_reps_planned", "n_boot")])'`
  -> PASS; wrote only `_manifests/shard-1.csv` and no fit result RDS files.
- `git diff --check`
  -> PASS.

## Tests Of The Tests

The new manifest test checks the exact four representative cells, their order,
the moderate-signal coordinates, the `binomial_logit_harness` evidence label,
planned reps, boot count, and manifest validation.

The new CLI test exercises the script from the repo root, checks the emitted
audit-mini counters, reads the written manifest back from disk, and verifies no
top-level RDS fit outputs were created. This is a prophylactic manifest-contract
test: it protects the next smoke step from accidentally launching fits or
silently changing the audit-mini cell set.

Two defects were caught while adding the tests. A parse check caught an
incorrect test closing brace, and the focused manifest test caught that the
generic manifest builder reordered the selected rows. The helper now restores
the audit-mini family order after building the manifest.

## Consistency Audit

Exact stale-wording scans:

- `rg -n "audit-mini|pilot_audit_mini|audit_mini|binomial_logit_harness|binomial_probit|ordinal_probit" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS for intended audit-mini and existing family-label matches.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML|validated binomial-probit|probit support|pilot-index\\.rds.*(write|mutate|update|rebuild)" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS; no DRAC/SLURM/GPU/production/AI-REML overclaim, no validated
  binomial-probit wording, and no `pilot-index.rds` mutation wording.

No public article or roxygen capability prose was edited. The relevant
validation rows remain `CI-08` and `CI-10`, both partial. No validation row
moved.

## What Did Not Go Smoothly

The first parse pass found a small test-brace mistake. The first focused
manifest test then found that `pilot_build_manifest()` returned the selected
cells in the grid/order produced by the generic helper rather than the
human-readable audit-mini family order. Both were fixed before commit.

One command creating the worktree was run from the dirty Dropbox checkout and
printed that checkout's large dirty status after worktree creation. No files in
the dirty checkout were changed; the fresh `/private/tmp` worktree was then
verified clean before edits.

## Team Learning

Ada/Shannon: keep these compute-readiness steps as small PRs and wait for the
active `main` CI/pkgdown run before the next push.

Grace: manifest-only smoke modes are useful because they can be checked locally
and on login/submission surfaces without accidentally fitting on the wrong
machine.

Curie/Fisher: the binomial row must keep carrying the `binomial_logit_harness`
label until the true probit DGP and fit route are repaired and validated.

## Known Limitations

This slice does not launch fits, run DRAC jobs, touch GPUs, repair ordinal
coverage, add MCSE/denominator reporting, or implement true binomial-probit
support. It does not move `CI-08` or `CI-10` out of partial status.

## Next Actions

After this PR is merged and main CI is green, the next safe slice is a local
audit-mini runner smoke that executes these four cells with tiny rep counts and
`n_boot = 0`, still before any DRAC production volume.
