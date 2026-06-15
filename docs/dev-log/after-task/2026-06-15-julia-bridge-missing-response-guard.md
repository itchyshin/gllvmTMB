# After Task: Julia Bridge Missing-Response Guard

Date: 2026-06-15

## Goal

Make the direct R wrapper reject missing responses clearly while the paired
Julia bridge still lacks a general observed-response mask.

## Implemented

- Added an `anyNA(y)` guard to `gllvm_julia_fit()` after orientation handling and
  before JuliaCall setup.
- Added a pure-R test that a direct `gllvm_julia_fit()` call with an `NA`
  response matrix fails with the missing-response mask message.
- Updated NEWS to state that direct wrapper calls with `NA` responses fail before
  JuliaCall until `GLLVM.bridge_fit` accepts masks.

## Contract

Current bridge state is complete-response only. The R wrapper may drop or reject
missing responses according to the existing `gllvmTMB()` missing-data policy, but
it must not send `NA` response matrices into `GLLVM.bridge_fit` without an
explicit observed-response mask contract.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-missing-response-guard.md`

## Tests Added

- One direct-wrapper missing-response error test in
  `tests/testthat/test-julia-bridge.R`. It exercises the failure-path clause and
  would have reached JuliaCall before the guard.

## Benchmark Numbers

N/A -- this is a pre-flight R guard, not a likelihood or optimizer path.

## R-Parity Verdict

Parity: N/A -- no fit is run and no estimator changes.

## Checks Run

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 99`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 99`, `FAIL 0`, `WARN 0`, `SKIP 0` in `42.3s`.

## Consistency Audit

- `rg -n "missing-response masks|anyNA\\(y\\)|NA responses|observed-response mask" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-15-julia-bridge-missing-response-guard.md`
  confirmed the guard, tests, and claim boundary are all visible.

## GitHub Issue Maintenance

No remote issue mutation was made. The proper successor is a dedicated
missing-response bridge issue once pushing/issue updates are approved.

## Remaining Risks

- `GLLVM.bridge_fit` still lacks the general `mask` argument needed to admit
  missing responses.
- `gllvmTMB(..., engine = "julia", missing = miss_control(response = "include"))`
  still fails deliberately.

## Rose Verdict

PASS WITH NOTES -- the guard is honest and tested, but it is not mask support.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```
