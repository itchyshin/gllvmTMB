# After Task: Power Pilot Audit-Mini Runner

## Goal

Add a tiny local execution gate for the power pilot so the representative
audit-mini cells can be run as immutable chunks before any broader local or
DRAC volume.

## Implemented

This slice adds `pilot_run_audit_mini_manifest()` in
`dev/m3-pilot-launch.R`. The helper builds the same fixed four-cell audit-mini
manifest, writes it to `_manifests/`, runs the active chunk rows through
`pilot_run_chunk_manifest()`, and audits the expected chunk files.

`dev/power-pilot-run.R --mode=audit-mini-run` exposes that helper as a CLI mode.
It emits `audit_mini_rows`, `audit_mini_active_chunks`,
`audit_mini_chunk_output_rows`, and `n_errored`.

Design 66 now records `audit-mini-run` as a tiny local execution smoke after the
manifest-only `audit-mini` gate. It explicitly says this path does not mutate
`pilot-index.rds`, submit DRAC/SLURM work, or start a production campaign.

## Mathematical Contract

No model, likelihood, DGP, estimator, interval, or scoring equation changed. The
runner reuses the existing M3 harness and immutable chunk writer. The binomial
cell still has `family_label = "binomial_probit"` and
`evidence_family = "binomial_logit_harness"`; this remains a labelled harness
limitation, not validated binomial-probit support.

## Files Changed

- `dev/m3-pilot-launch.R`
- `dev/power-pilot-run.R`
- `tests/testthat/test-m3-pilot-manifest.R`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-audit-mini-runner.md`

No roxygen, Rd, NEWS, README, pkgdown navigation, family registry, or validation
register rows changed.

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url && git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared design/dev-log edits; no open PRs, recent history was
  the expected #539 through #548 sequence.
- `git status --short --branch`
  -> clean branch start in
  `/private/tmp/gllvmtmb-power-pilot-audit-mini-runner-20260623`.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-manifest.R")); cat("parse ok\n")'`
  -> PASS; `parse ok`.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 143 expectations.
- `air format dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-manifest|m3-pilot-report")'`
  -> PASS; 176 expectations.
- `rm -rf /tmp/gllvmtmb-audit-mini-run-smoke && OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/power-pilot-run.R --mode=audit-mini-run --seed-base=171 --n-sim-step=1 --n-sim-cap=1 --n-boot=0 --results-dir=/tmp/gllvmtmb-audit-mini-run-smoke > /tmp/gllvmtmb-audit-mini-run-smoke.out 2>&1 && cat /tmp/gllvmtmb-audit-mini-run-smoke.out && find /tmp/gllvmtmb-audit-mini-run-smoke -type f | sort && Rscript --vanilla -e 'm <- read.csv("/tmp/gllvmtmb-audit-mini-run-smoke/_manifests/shard-1.csv"); print(m[, c("cell_id", "family_label", "evidence_family", "output_mode", "n_reps_planned", "n_boot")]); cat("chunk files=", length(list.files("/tmp/gllvmtmb-audit-mini-run-smoke/_chunks", pattern = "[.]rds$", recursive = TRUE)), "\n")'`
  -> PASS; four local no-bootstrap one-rep chunks written, `n_errored=0`.
- `OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir=/tmp/gllvmtmb-audit-mini-run-smoke >> /tmp/gllvmtmb-audit-mini-run-smoke.out 2>&1 && OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/power-pilot-run.R --mode=chunk-aggregate --results-dir=/tmp/gllvmtmb-audit-mini-run-smoke >> /tmp/gllvmtmb-audit-mini-run-smoke.out 2>&1 && OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/m3-pilot-report.R --emit-issues --chunk-aggregate --results-dir=/tmp/gllvmtmb-audit-mini-run-smoke >> /tmp/gllvmtmb-audit-mini-run-smoke.out 2>&1 && tail -80 /tmp/gllvmtmb-audit-mini-run-smoke.out && find /tmp/gllvmtmb-audit-mini-run-smoke/_chunk-aggregate -type f | sort`
  -> PASS; chunk audit validated four outputs, aggregate wrote four per-cell
  aggregate files and 20 rows, and the aggregate issue line flagged two one-rep
  nonPD cells.

## Tests Of The Tests

The new unit test uses a fake runner to confirm the helper calls all four
audit-mini cells, forwards the correct family, `n_reps`, `n_boot`, and target
arguments, writes four immutable chunks, writes the manifest, and adds chunk
provenance columns.

The real CLI smoke exercises the actual M3 harness at the smallest useful local
size: one no-bootstrap replicate per audit-mini cell. The follow-on audit,
aggregate, and issue-line commands prove those chunks can move through the
downstream immutable-chunk ladder.

## Consistency Audit

Exact stale-wording scans:

- `rg -n "audit-mini-run|pilot_run_audit_mini_manifest|audit_mini_chunk_output_rows|pilot-index\\.rds|DRAC|SLURM|production campaign|n_sim = 2000|AI-REML|validated binomial-probit|probit support" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS for intended new runner matches plus existing Design 66 boundary
  language around `n_sim = 2000`, DRAC, and `pilot-index.rds`.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(run|launch|submitted)|GPU|production launch|n_sim = 2000.*started|AI-REML|validated binomial-probit|probit support|pilot-index\\.rds.*(write|mutate|update|rebuild)" dev/m3-pilot-launch.R dev/power-pilot-run.R tests/testthat/test-m3-pilot-manifest.R docs/design/66-capstone-power-study.md`
  -> PASS; no DRAC/SLURM/GPU/production/AI-REML overclaim, no validated
  binomial-probit wording, and no `pilot-index.rds` mutation wording.

No public article or roxygen capability prose changed. The relevant validation
rows remain `CI-08` and `CI-10`, both partial. No validation row moved.

## What Did Not Go Smoothly

Nothing broke in this slice. The main practical signal was that the one-rep
real smoke produced nonPD flags for `binomial_probit` and `nbinom2`; with one
rep and no bootstrap this is expected diagnostic noise, so it is recorded here
only as a reminder not to interpret the smoke as power or coverage evidence.

## Team Learning

Grace: the local smoke should always set BLAS/OpenMP thread counts to 1 before
we translate it to DRAC submission scripts.

Curie/Fisher: one-rep smoke is useful for plumbing and provenance, not for
interval quality. The first evidence-bearing audit-mini run needs larger
denominators and MCSE reporting.

Shannon/Rose: keep manifest-only and execution-smoke modes separate. That makes
it obvious which command is safe for login/submission surfaces and which command
actually fits models.

## Known Limitations

No DRAC login, SLURM job, GPU check, production campaign, or `n_sim = 2000` run
was launched. The one-rep smoke is not coverage, power, or Type-I evidence.
True binary probit, ordinal coverage repair, denominator/MCSE expansion, and
DRAC environment checks remain separate slices. `CI-08` and `CI-10` remain
partial.

## Next Actions

After this PR is merged and main CI is green, the next safe slice is to prepare
the local/DRAC smoke command wrappers around the audited sequence:
`audit-mini`, `audit-mini-run`, `chunk-audit`, `chunk-aggregate`, and aggregate
reporting, still with `n_boot = 0` and no production volume.
