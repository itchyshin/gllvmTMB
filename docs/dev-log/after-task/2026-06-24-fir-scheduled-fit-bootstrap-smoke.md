# After Task: fir Scheduled Fit And Bootstrap Smoke

## Goal

Run the next CPU-only fir SLURM smoke steps after the manifest-only PR:
one tiny scheduled fit job with `N_BOOT=0`, then one tiny scheduled
bootstrap job with `N_BOOT=2` only if the first job inspected cleanly.

## Implemented

No package source changed. The slice produced scheduled-compute evidence
that the existing SLURM wrapper can run the audit-mini ladder on fir as a
scheduled CPU job, write immutable chunk outputs, aggregate them, and emit
the issue summary without touching `pilot-index.rds`.

## Mathematical Contract

No public R API, likelihood, formula grammar, family implementation,
estimator, NAMESPACE, generated Rd, vignette, or pkgdown navigation change.
The jobs used the existing audit-mini grid and existing
`Sigma_unit_diag` target path. This is smoke / scheduler / artifact-schema
evidence only, not coverage, power, Type-I, or validation-row promotion
evidence.

## Files Changed

- `docs/design/66-capstone-power-study.md` -- added the fir scheduled
  `N_BOOT=0` and `N_BOOT=2` smoke evidence, with limitations.
- `docs/dev-log/check-log.md` -- appended the command/evidence ledger.
- `docs/dev-log/after-task/2026-06-24-fir-scheduled-fit-bootstrap-smoke.md`
  -- this report.

## Checks Run

- `git fetch origin --prune`
  -> PASS.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared doc edits; no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared doc edits; recent history was only the merged
  fir-library-smoke commit.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 8 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> post-merge R-CMD-check `28111548411` success, pkgdown
  `28111605400` success, scheduled Power pilot sweep `28106026686`
  still in progress.
- `bash -n dev/power-pilot-slurm-smoke.sh dev/power-pilot-drac-setup.sh dev/power-pilot-smoke.sh`
  -> PASS locally.
- `RESULTS_DIR=/tmp/gllvmtmb-local-slurm-write-check R_LIBS_USER_DIR=/tmp/gllvmtmb-local-r-lib SLURM_ACTION=write SLURM_STAGE=all SLURM_TIME=01:00:00 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0 bash dev/power-pilot-slurm-smoke.sh`
  -> PASS locally; wrote the expected sbatch file without submitting.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R"); testthat::test_file("tests/testthat/test-m3-pilot-report.R")'`
  -> PASS locally, 143 + 33 expectations.
- `ssh fir '... command -v sbatch; command -v srun; command -v sinfo; ...'`
  -> PASS; fir reachable in batch mode and SLURM commands available.
- `ssh fir '... R_LIBS_USER="$SCRATCH/gllvmtmb-r-libs/4.5.0" Rscript --vanilla -e "requireNamespace(\"gllvmTMB\")" ...'`
  -> PASS; `gllvmTMB` version `0.2.0` visible from the prepared scratch
  R library.
- Local/remote `sha256sum` comparison for
  `dev/power-pilot-smoke.sh`, `dev/power-pilot-slurm-smoke.sh`,
  `dev/power-pilot-drac-setup.sh`, `dev/power-pilot-run.R`,
  `dev/m3-pilot-launch.R`, and `dev/m3-pilot-report.R`
  -> PASS; fir source copy matched the clean local source.
- fir `SLURM_ACTION=test SLURM_STAGE=all N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0`
  -> PASS; `sbatch --test-only` accepted the job.
- fir `SLURM_ACTION=submit SLURM_STAGE=all N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0`
  -> PASS; job `45626865` completed, exit code `0:0`, elapsed
  `00:00:08`, four active chunks, four aggregate files, no
  `pilot-index.rds`.
- fir artifact inspection for
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot0-20260624T164759Z`
  -> PASS; manifest source SHA was
  `7c675dd33d58f4dfd633cacfbf05e62c0e168d61`, `n_boot = 0`,
  evidence families were `gaussian`, `nbinom2`,
  `binomial_logit_harness`, and `ordinal_probit`.
- fir `SLURM_ACTION=test SLURM_STAGE=all N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=2`
  -> PASS; `sbatch --test-only` accepted the job.
- fir `SLURM_ACTION=submit SLURM_STAGE=all N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=2`
  -> PASS; job `45627388` completed, exit code `0:0`, elapsed
  `00:00:08`, four active chunks, four aggregate files, no
  `pilot-index.rds`.
- fir artifact inspection for
  `$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot2-20260624T165402Z`
  -> PASS for artifact shape and source SHA; report emitted
  `binomial_probit-d1-n50-sig0p2 nonPD 100%; nbinom2-d1-n50-sig0p2 nonPD 100%`
  and ordinal-probit had `ci_available = FALSE`.

## Tests Of The Tests

No tests were added. The targeted manifest/report tests still exercise the
manifest shape, evidence-family labelling, chunk runner, aggregate path, and
MCSE/denominator semantics. The remote smoke jobs then exercised the same
script path through real scheduled SLURM jobs.

## Consistency Audit

- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I|signal-zero Type-I|Type-I error for Sigma_unit_diag" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  -> PASS before this report; signal-zero wording remains diagnostic.
- `rg -n "binomial_probit|binomial_logit_harness|zero-exclusion|coverage_mcse|coverage_eligible" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml tests/testthat/test-m3-pilot-report.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS before this report; binomial-probit cell IDs still carry
  explicit `binomial_logit_harness` evidence.
- `rg -n "GPU.*(enabled|tested)|production launch|n_sim = 2000.*started|validated binomial-probit|probit support|CI-08.*covered|CI-10.*covered" docs/design/66-capstone-power-study.md`
  -> PASS after edits; no new overclaim in the updated Design 66 prose.

## What Did Not Go Smoothly

The fir smoke source directory is a source copy rather than a Git checkout.
The source-copy checksums matched the clean local source, and the submitted
jobs carried `GITHUB_SHA` through the SLURM environment into the manifest, so
the scheduled smoke evidence is still traceable. Future wrapper polish could
write the source SHA explicitly into the sbatch script body to reduce reliance
on SLURM's default environment export.

The `N_BOOT=2` smoke completed but correctly surfaced tiny-run diagnostics:
non-PD Hessian flags for the binomial logit harness and nbinom2 cells, and no
primary interval for ordinal-probit. These are not promoted.

## Team Learning

Ada kept the slice bounded to the DRAC smoke ladder and stopped at the first
real evidence boundary.

Grace verified the scheduler, module stack, scratch R library, source-copy
checksums, SLURM status, and artifact schema before widening from `N_BOOT=0`
to `N_BOOT=2`.

Curie/Fisher keep the interpretation narrow: these jobs prove scheduling and
artifact plumbing, not Monte Carlo operating characteristics.

Rose keeps the public-story guardrail: `CI-08` and `CI-10` remain partial,
the binomial row remains logit-harness evidence, and ordinal coverage remains
unresolved.

## Roadmap Tick

N/A. No roadmap row or progress bar changed.

## GitHub Issue Ledger

Issue #340 remains the Power pilot board. No issue was commented, closed, or
created in this slice because the evidence is smoke/plumbing only and should
not be presented as validation promotion.

## Known Limitations

- CPU-only fir evidence only; no GPU lane.
- No production `n_sim = 2000` campaign launched.
- No broad DRAC/Totoro sweep launched.
- No validation rows moved; `CI-08` and `CI-10` remain partial.
- `binomial_probit` cell IDs still use `binomial_logit_harness` evidence.
- Ordinal-probit primary interval coverage remains unresolved.
- The `N_BOOT=2` tiny smoke surfaced non-PD diagnostics and is not a
  capability claim.

## Next Actions

1. Patch the true binomial-probit DGP/fit harness before any probit evidence
   is used for validation.
2. Decide whether ordinal-probit can produce a primary interval row or should
   be explicitly excluded from confirmatory coverage promotion.
3. Add an explicit source-SHA export line to the SLURM wrapper if the next
   reproducibility polish PR touches the wrapper.
4. Only after the probit and ordinal gates are addressed, freeze the CPU-only
   core-grid launch plan.
