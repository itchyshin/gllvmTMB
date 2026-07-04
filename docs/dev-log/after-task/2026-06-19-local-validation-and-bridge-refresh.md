# After Task: Local Validation And Bridge Refresh

## Goal

Close the local validation-warning tail after the ordinary `latent()` default-Psi
cleanup, then refresh the R, Julia, and Julia-via-R bridge evidence without
mutating GLLVM.jl #101.

## Implemented

- Updated the Stage 3 combined `propto()` smoke test to use ordinary
  `latent()` for the default shared-plus-diagonal covariance path instead of
  spelling the same current behaviour as `latent() + unique()`.
- Updated the Stage 33 binomial and Poisson current-behaviour tests to use
  ordinary `latent()` instead of `latent() + unique()`.
- Refreshed local R validation, pkgdown validation, preserved R CMD check
  evidence, Julia-only bridge tests at the pinned GLLVM.jl #101 SHA, and the
  live Julia-via-R bridge suite.

## Mathematical Contract

Ordinary `latent(0 + trait | site, d = K)` now carries its diagonal Psi
companion by default. These edits do not change the likelihood target; they
make current-behaviour tests exercise the canonical syntax for the same
shared-plus-diagonal covariance model.

The Stage 3 glmmTMB comparison still compares gllvmTMB ordinary `latent()` to
glmmTMB's `rr() + diag()` spelling for the same fitted covariance structure.

## Files Changed

- `tests/testthat/test-stage3-propto-equalto.R`
- `tests/testthat/test-stage33-non-gaussian.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-local-validation-and-bridge-refresh.md`

No roxygen, Rd, article, likelihood, parser, or user-facing example source was
changed in this slice.

## Checks Run

- `git status --short --branch`
  - branch `codex/r-bridge-grouped-dispersion`, ahead 56, inherited dirty tree.
- `git diff --check`
  - clean before and after edits.
- `Rscript --vanilla -e 'devtools::test(filter = "stage3-propto-equalto|stage33-non-gaussian")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 20`.
- `Rscript --vanilla -e 'devtools::test()'`
  - `FAIL 0 | WARN 0 | SKIP 730 | PASS 3261`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`
  - `0 errors | 1 warning | 1 note`; the note was `unable to verify current time`.
- `Rscript --vanilla -e 'rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-20260619-suggestsfalse", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))'`
  - `0 errors | 1 warning | 0 notes`.
  - Preserved warning: Apple clang ignores R's
    `R_ext/Boolean.h` pragma for `-Wfixed-enum-extension`.
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  - expected 14 live-Julia skips; no failures or warnings.
- `git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" worktree add --detach /tmp/gllvmjl-pr101-refresh-20260619 f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`
  - created a detached verification worktree at pinned GLLVM.jl #101 SHA.
- `julia --project=. --startup-file=no -e 'import Pkg; Pkg.instantiate()'`
  - completed dependency setup and precompiled `GLLVM`.
- `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  - `Pass 121 | Total 121`.
- `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  - `Pass 40 | Total 40`.
- `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  - `Pass 64 | Total 64`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 1188`.

## Tests Of The Tests

- The touched tests are acceptance tests for current syntax after the
  ordinary-latent Psi fold.
- The Stage 3 test remains a feature-combination check: ordinary latent
  covariance plus `propto()` plus an independent glmmTMB likelihood comparison.
- The Stage 33 tests remain non-Gaussian acceptance checks for binomial and
  Poisson families with default latent covariance and per-row family ids.
- Failure-before-fix evidence for this slice is the prior full-suite warning
  tail: three lifecycle warnings from these same files.

## Consistency Audit

Pre-edit lane check before shared-file edits:

- `gh pr list --state open`
  - only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits were reported.

Stale wording scans:

- `rg -n "latent\\(0 \\+ trait \\| site, d = 2\\) \\+ unique\\(0 \\+ trait \\| site\\)|rr \\+ diag|latent\\(\\)/unique\\(\\)|latent\\(\\)/unique" tests/testthat/test-stage3-propto-equalto.R tests/testthat/test-stage33-non-gaussian.R`
  - no matches.
- `rg -n "unique\\(0 \\+ trait \\| site\\)|converges with rr \\+ diag|Stage 3: rr \\+ diag" tests/testthat/test-stage3-propto-equalto.R tests/testthat/test-stage33-non-gaussian.R`
  - no matches.

Maxwell / Grace read-only audit agreed the patch scope is appropriate and
warned not to log this as a Big 4 completion, release readiness, CRAN
readiness, or scientific coverage.

## What Did Not Go Smoothly

- The first preserved `devtools::check(cleanup = FALSE)` attempt failed because
  the `cleanup` argument is defunct in this devtools version.
- Two `rcmdcheck::rcmdcheck()` attempts failed early because `_R_CHECK_FORCE_SUGGESTS_`
  was not passed with the correct named-env syntax. The successful preserved
  check uses `env = c("_R_CHECK_FORCE_SUGGESTS_" = "false")`.

## Team Learning

- Grace's useful distinction held: clean local tests and bridge suites are
  strong local evidence, but not a 3-OS branch matrix or release gate.
- The exact warning source matters. The retained R CMD check log shows the
  remaining warning is from Apple's handling of R's `R_ext/Boolean.h` pragma,
  not from gllvmTMB package logic.

## Known Limitations

- Current local gllvmTMB remains ahead/dirty and is not identical to pushed PR
  #489 head.
- The GLLVM.jl working checkout is not PR #101; Julia-only checks used a
  detached temp worktree pinned to `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`.
- This slice does not prove source-specific or kernel latent-Psi folding.
- This slice does not close bridge completion, release readiness, CRAN
  readiness, article public placement, or scientific coverage.

## Next Actions

1. Use the refreshed local validation and bridge evidence for the bridge
   landing/split decision.
2. If release readiness is considered, require a fresh 3-OS PR matrix for the
   current local tree after it is pushed by the maintainer-approved process.
3. Continue the Big 4 plan one gate at a time: bridge landing/split, article
   placement, and scientific evidence gates.
