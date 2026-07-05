# After Task: Live Bridge And Two-Kernel Checks

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Grace / Hopper / Curie / Rose / Ada`

## 1. Goal

Close the remaining focused review-package evidence gaps: the large coevolution
two-kernel test and the live R-to-GLLVM.jl bridge test.

## 2. Implemented

No code changed. This is evidence-only.

## 3. Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-live-bridge-and-two-kernel-checks.md`

## 3a. Decisions and Rejected Alternatives

Decision: rerun the live bridge test with juliaup explicitly prepended to
`PATH`.

Reason: the first live attempt found `GLLVM_JL_PATH` but failed before bridge
logic because `JuliaCall` could not find `julia`.

## 4. Checks Run

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'
```

Outcome: passed.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl" NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

First outcome: failed before bridge logic because `JuliaCall::julia_setup()`
could not find Julia. The warning probe showed `bash -l -c 'which julia'` had
status 1.

```sh
PATH="$HOME/.juliaup/bin:$PATH" bash -l -c 'which julia; julia --version'
PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'cat(Sys.which("julia"), "\n"); system("bash -l -c \"which julia; julia --version\"")'
```

Outcome: both probes found `/Users/z3437171/.juliaup/bin/julia`; Julia version
was 1.10.0.

```sh
PATH="$HOME/.juliaup/bin:$PATH" GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl" NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Outcome: passed. The run activated the local `GLLVM.jl` project and completed
the live bridge tests.

## 5. Tests of the Tests

The first live bridge failure was an environment failure, not a bridge failure.
The second run proved that setting `PATH` allowed `JuliaCall` to exercise the
live bridge against the local GLLVM.jl checkout.

## 6. Consistency Audit

Both `gllvmTMB` and `GLLVM.jl` worktrees were clean after the checks. This is
local validation evidence only; no GitHub CI or push occurred.

## 7. Roadmap Tick

The review package now has fresh local evidence for:

- route-matrix heavy checks;
- extractor/plot checks;
- formula grammar checks;
- coevolution heavy checks including two-kernel;
- live GLLVM.jl bridge tests;
- pkgdown and local R CMD check.

## 7a. GitHub Issue Ledger

No issue was closed or commented.

## 8. What Did Not Go Smoothly

`JuliaCall` did not see Julia until juliaup was added to `PATH`. The fix was
environmental and did not require code changes.

## 9. Team Learning

When running live bridge tests locally, set:

```sh
PATH="$HOME/.juliaup/bin:$PATH"
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl"
```

## 10. Known Limitations And Next Actions

- Evidence is local; CI has not run because the branch was not pushed.
- The branch remains very large and should be split or packaged for review
  before more capability work.
