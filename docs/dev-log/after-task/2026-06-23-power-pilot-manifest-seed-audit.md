# After Task: Power Pilot Manifest And Seed Audit

**Branch**: `codex/power-pilot-manifest-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Curie / Grace / Fisher / Rose / Shannon`

## 1. Goal

Make the Phase-1 power-pilot runner auditable before any further volume:
record the planned shard/cell/seed/output-path manifest, validate duplicate
paths and seed collisions, and keep `pilot-index.rds` clearly described as a
derived resume cache rather than the durable audit trail.

## 2. Implemented

- Added manifest helpers in `dev/m3-pilot-launch.R`:
  `pilot_build_manifest()`, `pilot_write_manifest()`,
  `pilot_read_manifests()`, and `pilot_assert_manifest()`.
- Each shard records `_manifests/shard-<n>.csv` before fitting. The rows carry
  source SHA, workflow run id/number, shard, cell, result path, planned reps,
  batch seed base, and `rep_seed` min/max.
- `dev/power-pilot-run.R` now writes the shard manifest in `--mode=shard`,
  copies it in `--mode=slice`, and validates any merged manifests in
  `--mode=status`.
- `.github/workflows/power-pilot-sweep.yaml` copies shard manifests into the
  single-writer persist store and validates them before rebuilding
  `pilot-index.rds`.
- Corrected the pilot seed map so the effective `rep_seed` block is spaced
  after `m3_run_cell()` applies its family/d seed offset.
- Updated Design 66 to describe the manifest-first audit path and fixed stale
  signal-zero Type-I wording.
- Added no-fit tests for manifest round-trip, full-grid seed disjointness,
  duplicate output-path rejection, and overlapping seed-range rejection.

## 3. Mathematical Contract

No likelihood, DGP, estimator, bootstrap interval, response family, formula
grammar, or user-facing package API changed.

The only numerical contract touched is the deterministic simulation seed map.
`m3_run_cell()` computes
`rep_seed = batch_seed_base + 1000 * d + 100000 * family_index + r`. The new
pilot-grid seed map assigns raw cell seed bases after subtracting the family/d
offset, so the effective `rep_seed` blocks are spaced by
`PILOT_CELL_SEED_STRIDE`. The all-48 no-fit manifest audit verifies that the
planned 200-rep blocks do not overlap.

`CI-08` and `CI-10` remain partial.

## 3a. Decisions and Rejected Alternatives

- Decision: keep the current per-cell accumulated result files for this slice.
  The manifest makes the current store auditable without redesigning the
  storage layer midstream.
- Decision: treat `pilot-index.rds` as a local resume cache / derived cache.
  The audit trail is now the per-cell grids plus the per-shard manifest.
- Rejected alternative: launch an audit-mini or DRAC smoke. This slice was a
  prerequisite check, not a compute run.
- Rejected alternative: implement immutable `(campaign_id, cell_id, chunk_id)`
  files immediately. That belongs in the next compute-readiness slice.

## 4. Files Touched

- `.github/workflows/power-pilot-sweep.yaml`
- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `docs/design/66-capstone-power-study.md`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-manifest-seed-audit.md`

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  - PASS before shared dev-log/design edits: no open PRs.
- `git log --all --oneline --since="6 hours ago"`
  - PASS for coordination: recent work is #537-#541 plus the run-144 result
    branch.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  - PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  - PASS: 22 expectations.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  - PASS: 45 expectations across manifest/report tests.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); mf <- pilot_build_manifest(n_sim_step = 200L, n_sim_cap = 2000L, seed_base = 144L, results_dir = tempfile("pilot-manifest-all-"), n_boot = 0L, shard = 1L, n_shards = 1L, source_sha = "sha"); pilot_assert_manifest(mf); cat(sprintf("manifest ok: %d rows; seed range %d-%d\n", nrow(mf), min(mf$rep_seed_min), max(mf$rep_seed_max)))'`
  - PASS after the seed-map correction: 48 rows, seed range
    `721370001-721840200`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); rd <- tempfile("pilot-store-"); sd <- tempfile("pilot-slice-"); dir.create(rd); grid <- pilot_grid(); ord <- order(grid$cell_id); cell <- grid$cell_id[ord][1L]; mf <- pilot_build_manifest(cell_ids = cell, n_sim_step = 2L, n_sim_cap = 10L, seed_base = 147L, results_dir = rd, n_boot = 0L, shard = 1L, n_shards = 48L, source_sha = "slice-smoke"); pilot_write_manifest(mf, rd, shard = 1L); out <- system2("Rscript", c("--vanilla", "dev/power-pilot-run.R", "--mode=slice", "--shard=1", "--n-shards=48", paste0("--results-dir=", rd), paste0("--slice-dir=", sd)), stdout = TRUE, stderr = TRUE); stopifnot(file.exists(file.path(sd, "_manifests", "shard-1.csv"))); cat(paste(out, collapse = "\n"), "\n"); cat("slice manifest copied\n"); unlink(c(rd, sd), recursive = TRUE, force = TRUE)'`
  - PASS: slice mode copied `_manifests/shard-1.csv` without launching fits.
- `Rscript --vanilla dev/power-pilot-run.R --mode=status --results-dir=/tmp/gllvmtmb-empty-manifest-store --n-sim-cap=10 --status-out=/tmp/gllvmtmb-empty-manifest-status.md`
  - PASS: `manifest_ok=true`. The warning about no existing results directory
    is expected for this artificial empty-store smoke.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  - PASS.
- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I|0 level \\*is\\* the Type-I|signal-zero Type-I" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  - PASS: no matches.
- `rg -n "pilot_build_manifest|pilot_assert_manifest|duplicate output paths|overlapping seed ranges|pilot-index.rds.*source of truth|manifest" dev/m3-pilot-launch.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml tests/testthat/test-m3-pilot-manifest.R`
  - PASS for intended manifest coverage; the old `pilot-index.rds`
    source-of-truth wording was found and repaired.
- `rg -n "source of truth|pilot-index|index.*truth|derived cache" dev/m3-pilot-launch.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  - PASS after header repair; remaining hits describe `pilot-index.rds` as a
    local resume cache / derived cache.
- `git diff --check`
  - PASS.

## 6. Tests of the Tests

The full-grid manifest test is a failure-before-fix regression test. It failed
before the seed-map correction because same-run cells could share effective
`rep_seed` ranges after the harness family/d offset was added.

The duplicate-path and overlapping-seed tests are boundary/negative tests. They
would fail if the validator stopped rejecting two shards writing the same
per-cell file or if it stopped detecting seed-block collisions.

No model fit is required for these tests; they exercise the planning and audit
layer before compute is spent.

## 7a. Issue Ledger

- Issue #340 was not manually edited in this slice.
- No new issue was opened.
- The next workflow status update can surface `manifest_ok` via
  `dev/power-pilot-run.R --mode=status`.

## 8. Consistency Audit

Exact scans run:

- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I|0 level \\*is\\* the Type-I|signal-zero Type-I" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
- `rg -n "pilot_build_manifest|pilot_assert_manifest|duplicate output paths|overlapping seed ranges|pilot-index.rds.*source of truth|manifest" dev/m3-pilot-launch.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml tests/testthat/test-m3-pilot-manifest.R`
- `rg -n "source of truth|pilot-index|index.*truth|derived cache" dev/m3-pilot-launch.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`

Result: stale signal-zero Type-I wording was removed from the touched design
path. The old `pilot-index.rds` source-of-truth wording was replaced with
local-resume-cache / derived-cache wording. Manifest claims are backed by code
and tests.

## 9. What Did Not Go Smoothly

The first all-48 no-fit manifest audit failed with an overlapping seed-range
error. That was useful, not noise: it showed that spacing raw `cell_seed_base`
values was not sufficient because `m3_run_cell()` adds family/d offsets before
the replicate index. The fix spaces the effective `rep_seed` blocks after those
offsets.

`air format` reformatted nearby existing `rbind()` blocks in
`dev/m3-pilot-launch.R` and the status-table loop in `dev/power-pilot-run.R`.
Focused tests were rerun after formatting.

## 10. Known Residuals

- This slice does not launch simulations.
- This slice does not log into Totoro or DRAC, submit SLURM, or test GPUs.
- The current store still accumulates one per-cell result file. Immutable
  per-task chunk files are the next compute-readiness slice.
- True binary probit and ordinal-probit coverage repair remain separate.
- `CI-08` and `CI-10` remain partial.

## 11. Team Learning

Ada: keep this as a source-truth lane; do not mix it with dashboard refresh or
compute.

Curie: manifest validation is a cheap pre-compute simulation test. It found a
real seed collision without fitting anything.

Grace: single-writer persist remains the right workflow shape; manifests make
the handoff into DRAC-style immutable chunks easier.

Fisher: signal-zero rows stay diagnostic until the rejection rule exists.

Rose: status wording has to follow the storage reality. Calling an index the
source of truth was stale once sharded manifests became the audit trail.
