# After Task: Bridge Admission Split

**Branch**: `codex/bridge-admission-split-20260619`
**Date**: `2026-06-19`
**Roles (engaged)**: `Ada / Rose / Shannon / Grace`

## 1. Goal

Create a clean bridge-admission lane for the R-side `engine = "julia"`
bridge, separated from the mixed local Big 4 tree and from the
process-heavy material that had accumulated on draft PR #489.

This is a lane split and local validation gate. It does not claim bridge
completion, release readiness, CRAN readiness, or scientific coverage.

## 2. Implemented

- Created `/tmp/gllvmtmb-bridge-admission-split` on branch
  `codex/bridge-admission-split-20260619` from main SHA
  `0567cd747b9e81fa694e846a6d155bf60e35e0b8`.
- Restored only bridge-admission files from PR #489 head
  `03fdda1cedd325188448ffe58b42f09acbf69e61`.
- Excluded dashboard, mission-control, recovery-checkpoint, CRAN-comment,
  power-pilot, broad process, article, coevolution/TMB, and ordinary
  `latent()`/`unique()` Psi-migration material from this split lane.
- Regenerated roxygen output with `devtools::document(quiet = TRUE)`.
- Validated the split lane in pure R, Julia-only, live Julia-via-R, full
  testthat, pkgdown, and R CMD check contexts.

## 3. Files Changed

Bridge API / extractor surface:

- `NAMESPACE`
- `R/extract-correlations.R`
- `R/extract-sigma-table.R`
- `R/extract-sigma.R`
- `R/extractors.R`
- `R/gllvmTMB.R`
- `R/julia-bridge.R`
- `R/output-methods.R`
- `R/plot-covariance-tables.R`

Bridge docs and reference index:

- `NEWS.md`
- `_pkgdown.yml`
- `docs/design/35-validation-debt-register.md`
- `man/compare_Sigma_table.Rd`
- `man/extract_Sigma.Rd`
- `man/extract_Sigma_table.Rd`
- `man/extract_correlations.Rd`
- `man/extract_ordination.Rd`
- `man/getLV.Rd`
- `man/getLoadings.Rd`
- `man/getResidualCov.Rd`
- `man/gllvmTMB.Rd`
- `man/gllvmTMB_julia-methods.Rd`
- `man/gllvm_julia_capabilities.Rd`
- `man/gllvm_julia_fit.Rd`
- `man/gllvm_julia_gate_registry.Rd`
- `man/plot_Sigma_comparison.Rd`
- `man/plot_Sigma_heatmap.Rd`
- `man/plot_Sigma_table.Rd`
- `man/plot_correlations.Rd`

Bridge tests:

- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-plot-covariance-tables.R`

Lane evidence:

- `docs/dev-log/after-task/2026-06-19-bridge-admission-split.md`
- `docs/dev-log/check-log.md`

## 3a. Decisions and Rejected Alternatives

Decision: split from `main` and restore explicit bridge pathspecs from
`03fdda1`, rather than pushing the current local
`codex/r-bridge-grouped-dispersion` tree.

Rejected alternative: keep PR #489 as the active bridge lane with all
mission-control and process evidence included. Rose/Shannon classified this as
too broad for bridge admission.

## 4. Checks Run

Pre-edit lane check before shared dev-log edits:

```sh
gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url
git log --all --oneline --since="6 hours ago"
```

Outcome: only draft PR #489 was open; no recent commits reported.

Split branch setup:

```sh
git worktree add -b codex/bridge-admission-split-20260619 \
  /tmp/gllvmtmb-bridge-admission-split \
  0567cd747b9e81fa694e846a6d155bf60e35e0b8
```

Outcome: created branch/worktree at main SHA `0567cd7`.

```sh
git restore --source=03fdda1cedd325188448ffe58b42f09acbf69e61 -- \
  NAMESPACE NEWS.md \
  R/extract-correlations.R R/extract-sigma-table.R R/extract-sigma.R \
  R/extractors.R R/gllvmTMB.R R/julia-bridge.R R/output-methods.R \
  R/plot-covariance-tables.R _pkgdown.yml \
  docs/design/35-validation-debt-register.md \
  man/compare_Sigma_table.Rd man/extract_Sigma.Rd \
  man/extract_Sigma_table.Rd man/extract_correlations.Rd \
  man/extract_ordination.Rd man/getLV.Rd man/getLoadings.Rd \
  man/getResidualCov.Rd man/gllvmTMB.Rd \
  man/gllvmTMB_julia-methods.Rd man/gllvm_julia_capabilities.Rd \
  man/gllvm_julia_fit.Rd man/gllvm_julia_gate_registry.Rd \
  man/plot_Sigma_comparison.Rd man/plot_Sigma_heatmap.Rd \
  man/plot_Sigma_table.Rd man/plot_correlations.Rd \
  tests/testthat/test-julia-bridge.R \
  tests/testthat/test-plot-covariance-tables.R
```

Outcome: bridge-only restore completed; no staging.

Validation:

- `git diff --check` -> clean.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> completed.
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge|plot-covariance-tables", reporter = "summary")'`
  -> exit code 0; 14 live-Julia rows skipped because `GLLVM_JL_PATH` was unset.
- `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  in `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`
  -> `Pass 121 | Total 121`.
- `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  -> `Pass 40 | Total 40`.
- `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  -> `Pass 64 | Total 64`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> exit code 0; JuliaCall activated the pinned integration project and
  completed with `Julia exit`.
- `Rscript --vanilla -e 'devtools::test()'`
  -> `FAIL 0 | WARN 0 | SKIP 718 | PASS 3098`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-bridge-admission-split", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))'`
  -> `0 errors | 1 warning | 0 notes`.
- Warning scan showed the only R CMD check warning was the known Apple Clang /
  R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.

## 5. Tests of the Tests

The modified bridge tests combine pure-R payload/gate tests, live Julia-via-R
runtime checks, and Julia-side bridge tests at pinned GLLVM.jl SHA
`f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`.

## 6. Consistency Audit

`git diff --name-only` shows bridge API/docs/tests plus lane evidence only.
`git diff --check` is clean.

## 7. Roadmap Tick

N/A. This split makes the bridge lane reviewable; it does not move a roadmap
feature row.

## 7a. GitHub Issue Ledger

No issue was opened or closed. Draft PR #489 remains the remote reference for
the earlier broad bridge draft; this local split branch has not been pushed.

## 8. What Did Not Go Smoothly

PR #489 had accumulated process-heavy evidence and unrelated lane material.
The current main worktree remains large and dirty; this split does not clean
or replace that preserved state.

## 9. Team Learning

Ada: lane shape matters as much as test status. A green PR can still be too
broad to review safely.

Rose/Shannon: process evidence should be lane-specific.

Grace: R, Julia, and Julia-via-R each need separate evidence.

## 10. Known Limitations And Next Actions

- No push was made.
- No staging was done.
- No 3-OS matrix has run on this split branch.
- This does not mutate or update GLLVM.jl #101.
- This does not complete the Julia bridge, release readiness, CRAN readiness,
  or scientific coverage.
- Next action: review/commit/push the bridge-admission split only after the
  maintainer accepts this lane shape, then continue Big 2 (`unique()` /
  ordinary `latent()` Psi migration), Big 3 (fixed multi-kernel / COE-04), and
  Big 4 (public article placement) as separate lanes.
