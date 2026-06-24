# After Task: fir SLURM Library Manifest Smoke

**Branch**: `codex/fir-slurm-library-smoke`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Grace / Curie / Fisher / Rose / Shannon`

## 1. Goal

Make the first fir SLURM smoke reproducible enough to submit a real
manifest-only job from a prepared scratch checkout, while keeping the stop
line before fit-running jobs, GPU work, production volume, or validation-row
promotion.

## 2. Implemented

- Added `dev/power-pilot-drac-setup.sh`, a login-node setup helper that
  creates a version-pinned user R library, installs the current checkout with
  Depends/Imports/LinkingTo dependencies, and verifies that `gllvmTMB` is
  available.
- Extended `dev/power-pilot-slurm-smoke.sh` so SLURM jobs can load extra
  cluster modules, prepend a prepared R library, and check `gllvmTMB` before
  running the smoke wrapper.
- Updated Design 66 to record the fir package-library convention and the
  first real manifest-only SLURM smoke without writing private account or
  quota details into public docs.
- Submitted fir SLURM job `45601426` with `SLURM_STAGE=manifest`; it completed
  successfully and wrote only manifest/SLURM files.

## 3. Files Changed

Implementation:

- `dev/power-pilot-drac-setup.sh`
- `dev/power-pilot-slurm-smoke.sh`

Documentation and logs:

- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-fir-slurm-library-manifest-smoke.md`

## 3a. Decisions and Rejected Alternatives

Decision: use a project/scratch/home R-library fallback, with the fir smoke run
using the scratch path explicitly.

Rationale: fir login exposed system-only default R libraries after module load,
and the home filesystem produced remote I/O errors during checkout sync. Scratch
was available and appropriate for purgeable smoke setup.

Rejected alternative: persist private allocation or quota-specific values in
the repository. The helper accepts operator-provided paths instead.

Decision: keep this slice at manifest-only submission.

Rationale: the plan's stop line was a manifest-only fir PR. Tiny fit and
bootstrap smoke jobs belong to the next scheduled-compute slice after this
plumbing is reviewed.

Rejected alternative: immediately run `SLURM_STAGE=all`. That would widen this
PR from infrastructure readiness into fit execution.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared design/dev-log edits; no open PRs.
- `git log --all --oneline --since="6 hours ago"`
  -> PASS before shared design/dev-log edits; recent remote history was the
  expected `power-pilot-results` accumulator commits only.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 10 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> observed full-check run `28088698708` completed as `cancelled` because
  Windows was cancelled after macOS and Ubuntu had passed; scheduled Power
  pilot sweep run `28093240971` was still queued/running on main and was not
  used as validation evidence.
- `bash -n dev/power-pilot-drac-setup.sh && bash -n dev/power-pilot-slurm-smoke.sh && git diff --check`
  -> PASS.
- `rm -rf /tmp/gllvmtmb-slurm-lib-write && SLURM_ACTION=write RESULTS_DIR=/tmp/gllvmtmb-slurm-lib-write SLURM_STAGE=manifest SCRATCH=/tmp/gllvmtmb-scratch DRAC_EXTRA_MODULES='StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1 geos/3.12.0 proj/9.2.0' SEED_BASE=182 bash dev/power-pilot-slurm-smoke.sh && bash -n /tmp/gllvmtmb-slurm-lib-write/_slurm/power-pilot-smoke.sbatch && sed -n '1,80p' /tmp/gllvmtmb-slurm-lib-write/_slurm/power-pilot-smoke.sbatch`
  -> PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-manifest.R")'`
  -> PASS; 143 expectations.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-report.R")'`
  -> PASS; 33 expectations.
- `DRAC_EXTRA_MODULES="StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1 geos/3.12.0 proj/9.2.0" R_LIBS_USER_DIR="$SCRATCH/gllvmtmb-r-libs/4.5.0" bash dev/power-pilot-drac-setup.sh`
  -> PASS on fir; final lines included `gllvmTMB_version=0.2.0` and `ready`.
- fir package visibility check with the same module stack and
  `R_LIBS_USER=$SCRATCH/gllvmtmb-r-libs/4.5.0`
  -> PASS; `gllvmTMB_available=TRUE`, `gllvmTMB_version=0.2.0`.
- fir `SLURM_ACTION=test SLURM_STAGE=manifest`
  -> PASS; `sbatch --test-only` accepted the manifest job.
- fir `SLURM_ACTION=submit SLURM_STAGE=manifest`
  -> PASS; submitted job `45601426`, which completed in 4 seconds with
  `ExitCode 0:0`.
- fir result-tree inspection for job `45601426`
  -> PASS; files were `_manifests/shard-1.csv`,
  `_slurm/power-pilot-smoke.sbatch`, `_slurm/gllvmtmb-smoke-45601426.out`,
  and `_slurm/gllvmtmb-smoke-45601426.err`. The stderr file was empty and the
  non-manifest scan for `_chunks`, `*.rds`, and `*.RData` returned no files.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-24-fir-slurm-library-manifest-smoke.md`
  -> PASS.
- `after-task-audit` skill checklist
  -> PASS; code paths, Design 66 wording, test evidence, stale scans, and
  validation-row boundaries are aligned. No formula grammar, likelihood,
  roxygen, Rd, vignette, NEWS, public API, or validation-debt row changed.

## 5. Tests of the Tests

No package tests were added or changed. The validation is prophylactic and
plumbing-focused:

- `bash -n` catches shell syntax failures in both helpers.
- The generated-sbatch parse check catches quoting or heredoc mistakes in the
  job script produced by the wrapper.
- Existing manifest/report tests protect the four-cell audit-mini manifest and
  report machinery that the SLURM wrapper delegates to.
- The fir job artifact scan is the acceptance check for this slice: it would
  fail the stop-line contract if fit chunks or RDS outputs appeared.

## 6. Consistency Audit

- `rg -n "power-pilot-drac-setup|R_LIBS_USER_DIR|DRAC_EXTRA_MODULES|SLURM_CHECK_PACKAGE|SLURM_ACTION|SLURM_STAGE|fir|udunits|GDAL|GEOS|PROJ|GPU|production campaign|n_sim = 2000|CI-08|CI-10|AI-REML" dev/power-pilot-drac-setup.sh dev/power-pilot-slurm-smoke.sh docs/design/66-capstone-power-study.md`
  -> PASS for intended helper, wrapper, fir-module, and Design 66 boundary
  wording.
- `rg -n "GPU.*(enabled|tested)|production launch|n_sim = 2000.*started|AI-REML|validated binomial-probit|probit support|pilot-index\\.rds.*(write|mutate|update|rebuild)|CI-08.*covered|CI-10.*covered|Type-I error for Sigma_unit_diag" dev/power-pilot-drac-setup.sh dev/power-pilot-slurm-smoke.sh docs/design/66-capstone-power-study.md || true`
  -> PASS; no red-flag matches.

## 7. Roadmap Tick

N/A. This is a compute-readiness slice only; no validation-debt row or roadmap
status moved. `CI-08` and `CI-10` remain partial.

## 7a. GitHub Issue Ledger

No relevant open issue was updated and no new issue was created. This slice
continues the already logged power-pilot compute-readiness path following PR
#551.

## 8. What Did Not Go Smoothly

The first remote sync target on fir's home filesystem produced I/O errors, so
the working checkout moved to scratch. The first setup attempt also exposed a
missing `udunits`/`sf`/`fmesher` system-library stack; the compatible fir stack
was then identified as `StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1
geos/3.12.0 proj/9.2.0`. The submitted SLURM job waited under `Priority`
before running, which is normal scheduler behavior but means the next fit smoke
should still be planned as scheduled compute, not an interactive step.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the stop line crisp. This PR proves setup and manifest submission,
not model fitting.

Grace: fir needs an explicit user-library convention plus system-library
modules for spatial dependencies before scheduled jobs can reliably load the
package.

Curie: manifest-only SLURM evidence is plumbing evidence. It protects the
immutable chunk plan but says nothing about coverage, power, or Type-I error.

Fisher: no scheduled sweep output or manifest smoke output was used to promote
`CI-08` or `CI-10`.

Rose: the design note records the operational convention without private
account/quota details and repeats the production-volume boundary.

Shannon: the work stayed in the clean `/private/tmp` branch and did not touch
the dirty Dropbox mission-control checkout.

## 10. Known Limitations And Next Actions

- No `SLURM_STAGE=all` fit smoke, bootstrap smoke, GPU check, broad DRAC/Totoro
  setup, or production `n_sim = 2000` campaign was launched.
- The fir R library is a scratch smoke library and may be purged; rerun
  `dev/power-pilot-drac-setup.sh` before future scheduled smoke jobs if needed.
- The next slice is one tiny scheduled fir fit smoke:
  `SLURM_STAGE=all N_SIM_STEP=1 N_BOOT=0`, followed only after success by
  `N_BOOT=2`.
