# Julia bridge method-aware capability ledger

Date: 2026-06-15

## Goal

Prioritise the `gllvmTMB` R surface by making the Julia bridge capability ledger
explicit about methods, not just fit admission. The immediate gap was that
`gllvm_julia_capabilities()` could say a family was admitted while leaving CI and
post-fit support implicit.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_capabilities.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-method-capabilities.md`
- paired metadata only:
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration/src/bridge.jl`
  and
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration/test/test_bridge_capabilities.jl`

## What Changed

- Added explicit R-side bridge ledger columns:
  - `ci_no_x_wald`
  - `ci_no_x_profile`
  - `ci_no_x_bootstrap`
  - `postfit_coef`
  - `postfit_fit_stats`
  - `postfit_summary`
  - `postfit_predict`
  - `postfit_residuals`
  - `postfit_simulate`
  - `postfit_ordination`
- Updated the live drift guard to compare every admitted R-side logical
  capability against `GLLVM.bridge_capabilities()`.
- Updated the paired Julia bridge metadata surface and unit test so the live
  guard has an engine-side target.
- Kept the route conservative: ordinal rows are fit/CI/ordination rows, not
  prediction/residual/simulation rows; mixed-family remains no-X/no-mask/no-CI.

## Tests And Checks

```sh
~/.juliaup/bin/julia --project=. -e 'using GLLVM; caps=GLLVM.bridge_capabilities(); @assert :ci_no_x_wald in propertynames(caps); @assert :postfit_predict in propertynames(caps); println(length(caps.family), " capability rows")'
```

Result in `GLLVM.jl-integration`: `10 capability rows`.

```sh
~/.juliaup/bin/julia --project=. --startup-file=no test/test_bridge_capabilities.jl
```

Result in `GLLVM.jl-integration`: `19/19 pass` in `0.2s`.

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result in `gllvmTMB`: `FAIL 0 | WARN 0 | SKIP 18 | PASS 219` in `2.6s`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

Result in `gllvmTMB`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 519` in `68.9s`.

```sh
Rscript -e 'devtools::test()'
```

Result in `gllvmTMB`: `FAIL 0 | WARN 3 | SKIP 724 | PASS 2989`. Warnings were
the existing `nadiv::makeAinv()` selfing warning and the existing
`glmmTMB`/`TMB` version mismatch.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvm_julia_capabilities.Rd`. Existing unresolved-link
roxygen warnings remain; unrelated generated Rd churn was reverted.

```sh
Rscript -e 'pkgdown::check_pkgdown()'
```

Result: no problems found.

## Claim Boundary

This is a contract and drift-guard slice. It does not add a new family, new
likelihood route, new confidence-interval engine, or speedup.

The `ci_no_x_*` columns apply only to complete one-part no-covariate bridge
fits. They do not admit masked-response intervals, mixed-family intervals, or
non-Gaussian fixed-effect-X intervals.

REML remains Gaussian-only. HSquared-style AI-REML remains useful inspiration for
later exact Gaussian variance-component cells, not a non-Gaussian/Laplace claim.

## Rose Verdict

PASS WITH NOTES. The R user surface is now clearer and the live bridge guard
will catch method-level R-vs-Julia drift. Remaining gaps: public article/matrix
sync, rendered visual evidence, full suite after this slice, and follow-up
bridge parity for CIs beyond the current live smoke/parity tests.

## Next Command

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```
