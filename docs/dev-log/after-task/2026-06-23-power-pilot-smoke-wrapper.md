# After Task: Power Pilot Smoke Wrapper

**Branch**: `codex/power-pilot-smoke-runbook-20260624`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Grace / Curie / Fisher / Shannon / Rose`

## 1. Goal

Add a small, repeatable wrapper for the immutable power-pilot audit-mini
ladder so local/Totoro smoke runs and DRAC login-node manifest checks use
the same commands and boundaries. The slice should improve compute
readiness without launching DRAC work, SLURM jobs, GPU checks, or a
production power campaign.

## 2. Implemented

- Added `dev/power-pilot-smoke.sh`.
- Default `SMOKE_STAGE=all` runs the local/Totoro smoke ladder:
  manifest, one-rep `audit-mini-run`, chunk audit, chunk aggregate, and
  chunk-aggregate report.
- `SMOKE_STAGE=manifest` writes and validates the fixed four-cell
  audit-mini manifest without launching fits. This is the DRAC-login-safe
  stage.
- The wrapper defaults `N_SIM_STEP = 1`, `N_SIM_CAP = N_SIM_STEP`,
  `N_BOOT = 0`, and sets `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, and
  `MKL_NUM_THREADS` to 1 unless already set.
- Design 66 now records the wrapper and separates manifest-only checks
  from fit-running local/Totoro or scheduled-compute smoke stages.

## 3. Files Changed

- `dev/power-pilot-smoke.sh`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-smoke-wrapper.md`

## 3a. Decisions and Rejected Alternatives

Decision: put the wrapper in `dev/`, not `.github/workflows/`.
Rationale: this slice is a human/local readiness gate and should not
submit or schedule compute.
Rejected alternative: add a SLURM script now. That would mix readiness
documentation with cluster execution before the login/environment smoke
checks have been done.

Decision: make `SMOKE_STAGE=manifest` the explicit login-node-safe mode.
Rationale: DRAC login nodes should parse manifests and inspect
environment state only; fit-running stages belong on local/Totoro or
scheduled compute jobs.
Rejected alternative: infer DRAC from hostnames. Hostname rules are brittle
and can create false confidence.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url`
  -> PASS before shared design/dev-log edits; no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS; recent history was the expected #542 through #549 power-pilot
  readiness sequence, with #549 merged at `51f8fe7d`.
- `git status --short --branch`
  -> clean branch start in
  `/private/tmp/gllvmtmb-power-pilot-smoke-runbook-20260624` on
  `codex/power-pilot-smoke-runbook-20260624...origin/main`.
- `bash -n dev/power-pilot-smoke.sh`
  -> PASS.
- `SMOKE_STAGE=manifest SEED_BASE=172 RESULTS_DIR=/tmp/gllvmtmb-smoke-wrapper-manifest bash dev/power-pilot-smoke.sh`
  -> PASS; wrote only `_manifests/shard-1.csv` and launched no fits.
- `rm -rf /tmp/gllvmtmb-smoke-wrapper-all && RESULTS_DIR=/tmp/gllvmtmb-smoke-wrapper-all SEED_BASE=173 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0 bash dev/power-pilot-smoke.sh`
  -> PASS; ran the four-cell local smoke, chunk audit, chunk aggregate, and
  chunk-aggregate report.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-23-power-pilot-smoke-wrapper.md`
  -> PASS.

## 5. Tests of the Tests

The wrapper is a dev script, not package API. The validation is
prophylactic:

- `bash -n` catches shell syntax failures.
- `SMOKE_STAGE=manifest` verifies the DRAC-login-safe path without fits.
- The `SMOKE_STAGE=all` smoke verifies the intended end-to-end local ladder
  on the new immutable chunk pathway.

## 6. Consistency Audit

- `rg -n "power-pilot-smoke|SMOKE_STAGE|DRAC-login-safe|login nodes|SLURM|GPU|production campaign|n_sim = 2000|pilot-index\\.rds|AI-REML" dev/power-pilot-smoke.sh docs/design/66-capstone-power-study.md`
  -> PASS for intended wrapper, boundary, and thread-cap wording.
- `rg -n "DRAC.*(run|launch|fit|submitted)|SLURM.*(submitted|sbatch)|GPU.*(enabled|tested)|production launch|n_sim = 2000.*started|AI-REML|validated binomial-probit|probit support|pilot-index\\.rds.*(write|mutate|update|rebuild)" dev/power-pilot-smoke.sh docs/design/66-capstone-power-study.md`
  -> PASS with no matches; reran with `|| echo "no red-flag matches"` and
  got `no red-flag matches`.

## 7. Roadmap Tick

N/A. This is a compute-readiness wrapper only; no capability row moved.

## 7a. GitHub Issue Ledger

No relevant open issue was updated. This slice implements the current
mid-term compute-readiness plan rather than responding to a single GitHub
issue.

## 8. What Did Not Go Smoothly

Nothing in the implementation was difficult. The preceding #549 pkgdown
deploy was slow, so this slice waited for that clean checkpoint before
opening a new worktree.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the smoke ladder narrow and linear so the next session can run it
without rediscovering the command sequence.

Grace: default thread caps are useful even for small smoke fits, because
they make the same wrapper safe to move from Totoro to scheduled compute.

Curie: one-rep smoke is plumbing evidence only. It can show the chunk path
works, but it cannot support coverage, power, or Type-I claims.

Fisher: the report may flag one-rep nonPD cells. That is fit-health signal
from a smoke, not evidence for or against a method.

Shannon: the wrapper should not touch the dirty Dropbox mission-control tree
or the scheduled result store.

Rose: public and developer prose must keep DRAC-login-safe manifest parsing
separate from fit-running stages.

## 10. Known Limitations And Next Actions

- No SSH login, DRAC login-node check, SLURM submission, GPU check,
  production campaign, or `n_sim = 2000` run was launched.
- The wrapper does not replace a future SLURM array script.
- `CI-08` and `CI-10` remain partial.
- Next safe slice: run `SMOKE_STAGE=manifest` on Totoro and, after explicit
  cluster access confirmation, on DRAC login nodes; then draft a SLURM
  manifest-array skeleton without submitting production volume.
