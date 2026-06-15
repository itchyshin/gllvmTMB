# After Task: Julia Bridge Glance Method

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Pat / Rose`

## 1. Goal

Add the broom-style `glance()` companion for `gllvmTMB_julia` objects so R users
can inspect cached fit statistics in the same workflow as `tidy()`.

## 2. Implemented

- Added `glance.gllvmTMB_julia()`.
- Re-exported `generics::glance` alongside `generics::tidy`.
- Registered `S3method(glance, gllvmTMB_julia)`.
- Returned one row with `logLik`, `AIC`, `BIC`, `df`, `nobs`, `converged`,
  `iterations`, `engine`, `family`, and `model`.
- Documented the method on the Julia-bridge methods help page and the generated
  reexports page.

## 3. Files Changed

- `R/generics-imports.R`
- `R/julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `man/reexports.Rd`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-glance.md`

## 3a. Decisions And Rejected Alternatives

Decision: make `glance()` a cached fit-statistics table only. Rejected
alternative: include interval, covariance, residual, or simulation summaries,
because those belong to explicit methods/status rows and would blur the bridge
contract.

## 4. Checks Run

- `air format R/generics-imports.R R/julia-bridge.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::document()'`:
  completed; emitted pre-existing unresolved-link warnings outside this slice
  and generated unrelated Rd link churn that was restored before commit.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `116 pass`, `14 skip`, `0 fail`, `0 warn` in `1.9s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `311 pass`, `0 fail`, `0 warn`, `0 skip` in `52.0s`.

## 5. Tests Of The Tests

The tests lock the one-row column contract on a synthetic object and verify a
live Julia-engine Poisson fit reports the expected model and `nobs` in
`generics::glance()`.

## 6. Consistency Audit

NEWS now lists `glance()` among Julia-engine post-fit methods. The help page
describes `glance()` as one row of cached fit statistics, not an inference or
diagnostics method.

## 7. Roadmap Tick

This advances the R-first post-fit bridge surface. It does not add Julia engine
breadth or covariance/CI payloads.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the post-fit bridge-method row under the R-Julia contract phase.

## 8. What Did Not Go Smoothly

`devtools::document()` again touched unrelated generated Rd files under the
local roxygen version. Those unrelated changes were restored. The generated
`man/reexports.Rd` change was kept because `glance` is now genuinely re-exported.

## 9. Team Learning

Pat/Rose: familiar broom methods are useful, but each one should have a small
contract. `glance()` is fit statistics only.

## 10. Known Limitations And Next Actions

`glance()` does not report covariance status, CI availability, simulation
support, profile/bootstrap endpoints, or diagnostic residual summaries. Those
remain separate bridge-surface rows.

## 11. Rose Verdict

Rose: PASS — one-row cached fit statistics are covered and no broader inference
claim is made.
