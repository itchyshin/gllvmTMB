# After Task: Power Pilot SLURM Smoke Wrapper

**Branch**: `codex/power-pilot-slurm-smoke-20260624`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Grace / Shannon / Curie / Rose`

## 1. Goal

Add the first DRAC-facing SLURM wrapper for the power-pilot audit-mini
ladder without launching production compute. The narrow target was a
manifest-first, CPU-only smoke path that a login node can validate with
`sbatch --test-only` and that can later submit tiny scheduled smoke jobs.

## 2. Implemented

- Added `dev/power-pilot-slurm-smoke.sh`.
- Default behavior is conservative: `SLURM_ACTION=test` writes an sbatch
  file and calls `sbatch --test-only`; it does not queue a job.
- Default smoke stage is `SLURM_STAGE=manifest`, which calls
  `dev/power-pilot-smoke.sh` in manifest-only mode and launches no fits.
- Actual submission requires `SLURM_ACTION=submit`.
- The generated job loads R and Julia modules explicitly, sets
  `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, and `MKL_NUM_THREADS` to
  one, and writes logs under the selected results directory.
- Updated Design 66 so the first DRAC smoke is manifest-only, with
  fit-running stages limited to scheduled compute jobs.

## 3. Files Changed

- `dev/power-pilot-slurm-smoke.sh`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-slurm-smoke.md`

## 3a. Decisions and Rejected Alternatives

Decision: make `SLURM_ACTION=test` and `SLURM_STAGE=manifest` the
defaults.

Rationale: the first DRAC step should validate submission shape and
manifest parsing before any scheduled fits. This matches the current
audit ladder and avoids accidental production volume.

Rejected alternative: default to submitting a one-rep fit job. That
would be useful soon, but it is the second smoke, not the first.

Confidence: high for the wrapper boundary; medium for cross-cluster
defaults because account and partition conventions can vary across DRAC
hosts.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt`
  -> PASS; no open PRs.
- `git log --all --oneline --since='6 hours ago' --decorate`
  -> PASS; recent history was the expected power-pilot readiness lane.
- `git fetch origin --prune`
  -> PASS; `origin/main` included the merged smoke wrapper.
- `git worktree add -b codex/power-pilot-slurm-smoke-20260624 /private/tmp/gllvmtmb-slurm-smoke-fir-20260624 origin/main`
  -> PASS.
- `ssh -G fir | rg '^(hostname|user|identityfile|port) '`
  -> PASS; `fir` resolves to the DRAC host alias.
- Read-only `fir` login/environment probe
  -> PASS; SLURM was available, `/scratch` and `/project` existed, and
  `module load r/4.5.0 julia/1.12.5` exposed `Rscript` and `julia`.
  Private quota/account details were reported to the maintainer in chat,
  not persisted in this public report.
- `bash -n dev/power-pilot-slurm-smoke.sh`
  -> PASS.
- `rm -rf /tmp/gllvmtmb-slurm-smoke-write && SLURM_ACTION=write RESULTS_DIR=/tmp/gllvmtmb-slurm-smoke-write SLURM_STAGE=manifest SEED_BASE=181 bash dev/power-pilot-slurm-smoke.sh && bash -n /tmp/gllvmtmb-slurm-smoke-write/_slurm/power-pilot-smoke.sbatch`
  -> PASS; wrote a manifest-stage sbatch file and the generated job
  script parsed cleanly.
- `ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null fir 'sbatch --test-only' < /tmp/gllvmtmb-slurm-smoke-write/_slurm/power-pilot-smoke.sbatch`
  -> PASS; `fir` SLURM accepted the script as a dry-run/test-only job.
- `ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null fir 'squeue -u "$USER" -h -o "%i|%t|%M|%D|%R|%j" | head -n 20'`
  -> PASS; no queued jobs appeared after the test-only validation.

## 5. Tests of the Tests

No R unit tests were added. This is a shell/runbook slice. The test path
checks the wrapper syntax, checks a generated sbatch file, and uses
`sbatch --test-only` on `fir` so the scheduler validates the job shape
without queueing work.

## 6. Consistency Audit

- `rg -n "SLURM|sbatch|DRAC|GPU|production campaign|n_sim = 2000|AI-REML|validated binomial-probit|probit support" dev/power-pilot-slurm-smoke.sh docs/design/66-capstone-power-study.md`
  -> PASS for intended SLURM/DRAC boundary wording and existing
  `n_sim = 2000` planning references.
- `rg -n "GPU.*(enabled|tested)|production launch|n_sim = 2000.*started|AI-REML|validated binomial-probit|probit support|pilot-index\\.rds.*(write|mutate|update|rebuild)" dev/power-pilot-slurm-smoke.sh docs/design/66-capstone-power-study.md || true`
  -> PASS; no red-flag matches.

## 7. Roadmap Tick

N/A. This is compute-readiness plumbing for Design 66, not a validation
row promotion.

## 7a. GitHub Issue Ledger

No issue was commented or closed. The relevant live board is issue #340,
but this slice does not change its evidence status.

## 8. What Did Not Go Smoothly

The first remote environment probe used a strict unset-variable shell and
stopped when `$PROJECT` was unset. The rerun treated unset variables as
evidence instead of fatal state. Also, the user said "Fia"; SSH config
showed the usable DRAC alias is `fir`, while a literal `fia` alias points
elsewhere.

## 9. Team Learning

Ada: keep the lane small. A SLURM dry-run wrapper is useful only if it
does not quietly become a production campaign.

Grace: `fir` is a plausible first CPU target. R and Julia are available
through modules, but package library paths still need an explicit
project/scratch convention before fit-running jobs are submitted.

Shannon: the dirty Dropbox checkout remained untouched; work happened in
a fresh `/private/tmp` worktree from current `origin/main`.

Curie: this is submission plumbing only. It changes no DGP, scoring
metric, interval definition, or MCSE rule.

Rose: public wording keeps the boundary explicit: manifest-only first,
scheduled tiny fits second, production scaling later, no GPU lane.

## 10. Known Limitations And Next Actions

- No DRAC fit was run.
- No SLURM job was submitted; `sbatch --test-only` validated the job shape.
- No remote package library was created or populated.
- No GPU capability was tested.
- `CI-08` and `CI-10` remain partial.

Next safe slice: establish the remote package-library convention under
project/scratch, then submit the first real `fir` manifest-only SLURM job
from a remote checkout. After that passes, submit the second tiny
scheduled smoke with `SLURM_STAGE=all`, `N_SIM_STEP=1`, `N_BOOT=0`, and
then the third with `N_BOOT=2`.
