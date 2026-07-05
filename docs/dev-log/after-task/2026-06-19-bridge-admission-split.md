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
- Replaced bridge wording that could imply benchmarked acceleration
  (`fast GLLVM.jl engine`, `Experimental acceleration path`) with
  `experimental GLLVM.jl bridge fitting path`.
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

Continuation refresh, same date:

- Pre-edit lane check before updating this shared after-task report:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> only draft PR #489 was open, still on
  `codex/r-bridge-grouped-dispersion`, clean at pushed head `03fdda1`, with
  visible `ubuntu-latest (release)` and `recovery` checks successful.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago"`
  -> only `07181cf Split Julia bridge admission lane` was reported.
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge|plot-covariance-tables", reporter = "summary")'`
  -> exit code 0; expected 14 live-Julia rows skipped.
- Julia-only checks in
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`:
  `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  -> `Pass 121 | Total 121`;
  `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  -> `Pass 40 | Total 40`;
  `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  -> `Pass 64 | Total 64`;
  `julia --project=. --startup-file=no test/test_bridge_missing_mask.jl`
  -> `Pass 83 | Total 83`;
  `julia --project=. --startup-file=no test/test_bridge_x.jl`
  -> `Pass 169 | Total 169`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> exit code 0; JuliaCall activated the pinned integration project and
  completed with `Julia exit`.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> exited 0 and completed with `DONE`; the only reported skips were expected
  heavy/optional dependency skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-bridge-admission-split-rerun", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|ERROR|NOTE|clang|fixed-enum|R_ext/Boolean|whether package.*can be installed|Status|install" /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-rerun`
  -> confirmed the warning was the known Apple Clang / R header
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.

Current wording and validation refresh, 2026-06-19 10:34 MDT:

- Pre-edit lane check:
  `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,url`
  -> only draft PR #489 was open, still on
  `codex/r-bridge-grouped-dispersion`.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago"`
  -> recent local split commits were `d7826f0`, `d5a2295`, and `07181cf`;
  no separate active PR/agent collision was found for this split worktree.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> completed; wrote `gllvmTMB.Rd`.
- `rg -n "fast GLLVM|Experimental acceleration|acceleration path|accelerat" NEWS.md R/gllvmTMB.R R/julia-bridge.R _pkgdown.yml man/gllvmTMB.Rd man/gllvm_julia*.Rd docs/design/35-validation-debt-register.md`
  -> no matches.
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge|plot-covariance-tables", reporter = "summary")'`
  -> exit code 0; expected 14 live-Julia rows skipped.
- Current GLLVM.jl #101 status:
  `gh pr view 101 --repo itchyshin/GLLVM.jl --json number,title,state,isDraft,mergeStateStatus,headRefName,headRefOid,baseRefName,baseRefOid,statusCheckRollup,updatedAt,url`
  -> open draft, clean, head `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`;
  current CI and Documenter checks were successful.
- Julia-only checks in
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`:
  `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  -> `Pass 121 | Total 121`;
  `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  -> `Pass 40 | Total 40`;
  `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  -> `Pass 64 | Total 64`;
  `julia --project=. --startup-file=no test/test_bridge_missing_mask.jl`
  -> `Pass 83 | Total 83`;
  `julia --project=. --startup-file=no test/test_bridge_x.jl`
  -> `Pass 169 | Total 169`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> exit code 0; JuliaCall activated the pinned integration project and
  completed with `Julia exit`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> exit code 0; completed with `DONE`; reported skips were expected
  heavy/optional dependency skips.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|ERROR|NOTE|clang|fixed-enum|R_ext/Boolean|can be installed|Status" /private/tmp/gllvmtmb-rcmdcheck-bridge-admission-split-20260619-current/gllvmTMB.Rcheck/00check.log /private/tmp/gllvmtmb-rcmdcheck-bridge-admission-split-20260619-current/gllvmTMB.Rcheck/00install.out`
  -> the only warning was the known Apple Clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.
- `git diff --check`
  -> clean after wording/docs/evidence edits.

Final local refresh, 2026-06-19 16:06 MDT:

- Pre-edit lane check:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> only draft PR #489 was open, still on
  `codex/r-bridge-grouped-dispersion`, clean at pushed head `03fdda1`, with
  visible `ubuntu-latest (release)` and `recovery` checks successful.
- Pre-edit lane check:
  `git log --all --oneline --since="6 hours ago"`
  -> recent local split commits were `9bfe15c`, `af9940d`, `709eef0`,
  `4a2449a`, and `e2dd41d`; no active PR collision was found for this local
  bridge split edit.
- `git status --short --branch`
  -> clean before evidence edits.
- `git diff --check`
  -> clean before evidence edits.
- `gh pr view 101 --repo itchyshin/GLLVM.jl --json number,title,state,isDraft,mergeStateStatus,headRefName,headRefOid,baseRefName,statusCheckRollup,updatedAt,url`
  -> GLLVM.jl #101 remains open draft, clean, at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`; visible CI/Documenter checks
  are successful.
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge|plot-covariance-tables", reporter = "summary")'`
  -> exit code 0; expected 14 live-Julia rows skipped.
- Julia-only checks in
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`:
  `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  -> `Pass 121 | Total 121`;
  `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  -> `Pass 40 | Total 40`;
  `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  -> `Pass 64 | Total 64`;
  `julia --project=. --startup-file=no test/test_bridge_missing_mask.jl`
  -> `Pass 83 | Total 83`;
  `julia --project=. --startup-file=no test/test_bridge_x.jl`
  -> `Pass 169 | Total 169`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> exit code 0; JuliaCall activated the pinned integration project and
  completed with `Julia exit`.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> exit code 0 and completed with `DONE`; reported skips were expected
  heavy/optional dependency skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|ERROR|NOTE|clang|fixed-enum|R_ext/Boolean|can be installed|Status" /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619/gllvmTMB.Rcheck/00check.log /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619/gllvmTMB.Rcheck/00install.out /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619/gllvmTMB.Rcheck/tests/testthat.Rout`
  -> the only warning was the known Apple Clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.
- `rg -n "fast GLLVM|Experimental acceleration|acceleration path|accelerat|selectable Julia|bridge complete|bridge completion|release ready|release-ready|release readiness|scientific coverage|coverage passed" NEWS.md R/gllvmTMB.R R/julia-bridge.R _pkgdown.yml man/gllvmTMB.Rd man/gllvm_julia*.Rd docs/design/35-validation-debt-register.md docs/dev-log/after-task/2026-06-19-bridge-admission-split.md docs/dev-log/check-log.md`
  -> expected guardrail/history hits only in check-log and after-task evidence;
  no source or generated-reference wording reintroduced acceleration or
  selectable-algorithm claims.

## 5. Tests of the Tests

The modified bridge tests combine pure-R payload/gate tests, live Julia-via-R
runtime checks, and Julia-side bridge tests at pinned GLLVM.jl SHA
`f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`.

## 6. Consistency Audit

`git diff --name-only` shows bridge API/docs/tests plus lane evidence only.
`git diff --check` is clean.

Grace/Bacon read-only split audit returned `WARN`, not because the local split
leaks scope, but because GitHub PR #489 still points at the broader remote
branch `codex/r-bridge-grouped-dispersion` and the split branch has no 3-OS CI
evidence. The audit found no file-level leakage of dashboard, mission-control,
article estate, coevolution engine work, CRAN comments, recovery checkpoints,
or ordinary `latent()` / `unique()` Psi migration into the local split.

Chandrasekhar / Grace follow-up audit agreed the split is clean and
bridge-only against `origin/main`, and flagged the remaining wording risk in
`fast` / `acceleration` phrases. The 2026-06-19 10:34 MDT refresh removes
those phrases from the bridge lane sources and generated `gllvmTMB.Rd`.

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
- No 3-OS matrix has run on this split branch.
- GitHub PR #489 has not yet been replaced by this split branch; current PR
  greenness still describes the broader remote draft head, not the local split.
- This does not mutate or update GLLVM.jl #101.
- This does not complete the Julia bridge, release readiness, CRAN readiness,
  or scientific coverage.
- Next action: review/commit/push the bridge-admission split only after the
  maintainer accepts this lane shape, then continue Big 2 (`unique()` /
  ordinary `latent()` Psi migration), Big 3 (fixed multi-kernel / COE-04), and
  Big 4 (public article placement) as separate lanes.

## 11. Fresh Validation Refresh, 2026-06-19 17:19 MDT

The split branch was rechecked after the `unique()` / ordinary `latent()` Psi
split was closed locally in its own worktree as commit `e2866f7`. This refresh
does not push or mutate PR #489; it only proves the local bridge-admission
branch remains sound from R, Julia, and Julia-via-R.

Pre-edit lane check before updating this shared after-task report:

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> only draft PR #489 was open. It still points at
  `codex/r-bridge-grouped-dispersion`, is clean at pushed head `03fdda1`, and
  has visible `ubuntu-latest (release)` and `recovery` checks successful.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were local split / power-pilot commits, including
  `e2866f7`, `2da7505`, `9bfe15c`, `af9940d`, `709eef0`, `4a2449a`,
  `22316dd`, and `895cbf9`; no active PR collision was found for this local
  bridge split evidence edit.

Fresh checks from `/private/tmp/gllvmtmb-bridge-admission-split`:

- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge|plot-covariance-tables", reporter = "summary")'`
  -> exit code 0; expected 14 live-Julia rows skipped.
- `gh pr view 101 --repo itchyshin/GLLVM.jl --json number,title,state,isDraft,mergeStateStatus,headRefName,headRefOid,baseRefName,statusCheckRollup,updatedAt,url`
  -> GLLVM.jl #101 remains open draft, clean, at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`; visible CI and Documenter checks
  are successful.
- In `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` at
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`:
  `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  -> `Pass 121 | Total 121`;
  `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  -> `Pass 40 | Total 40`;
  `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  -> `Pass 64 | Total 64`;
  `julia --project=. --startup-file=no test/test_bridge_missing_mask.jl`
  -> `Pass 83 | Total 83`;
  `julia --project=. --startup-file=no test/test_bridge_x.jl`
  -> `Pass 169 | Total 169`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> exit code 0; JuliaCall activated the pinned integration project and
  completed with `Julia exit`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> exit code 0 and completed with `DONE`; reported skips were expected
  heavy/optional dependency skips.
- `Rscript --vanilla -e 'res <- rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619-turn", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false")); print(res); quit(status = if (length(res$errors)) 1 else 0)'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|ERROR|NOTE|clang|fixed-enum|R_ext/Boolean|can be installed|Status" /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619-turn/gllvmTMB.Rcheck/00check.log /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619-turn/gllvmTMB.Rcheck/00install.out /tmp/gllvmtmb-rcmdcheck-bridge-admission-split-current-20260619-turn/gllvmTMB.Rcheck/tests/testthat.Rout`
  -> the only warning was the known Apple Clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.

Ohm / Grace-Shannon returned `FAIL` for pushing the current dirty mission tree
or treating PR #489 as current evidence, but the file-scope recommendation
matches this split branch: bridge code, bridge extractor/plot gates,
bridge-generated Rd, bridge tests, minimal `_pkgdown.yml`, `NEWS.md`, JUL-01 /
JUL-01A register rows, check-log, and one bridge after-task report. The audit
explicitly excludes coevolution/TMB files, the `unique()` / ordinary
`latent()` Psi migration, article estate files, dashboard/process bulk, and
unrelated recovery checkpoints.

Updated next action: this bridge split is locally validated but still not
pushed and still has no split-branch 3-OS CI. Continue the Big 4 sequence by
preparing the fixed multi-kernel / COE-04 split next, unless the maintainer
asks to replace PR #489 with this bridge split first.
