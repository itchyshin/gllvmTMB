# After Task: Julia Bridge X Admission

Date: 2026-06-15

## Goal

Admit fixed-effect covariates through the R-to-Julia bridge only where the paired
GLLVM.jl `bridge_fit(...; X=...)` contract is already tested.

## Implemented

- `gllvm_julia_fit()` now accepts a numeric `p x n x q` `X` array for Gaussian,
  Poisson, Binomial, NB2, Beta, and Gamma bridge families.
- `.gllvmTMB_julia_dispatch()` now builds the correct `X` array from long-format
  fixed effects:
  - Gaussian receives the full mean design, including per-trait intercept
    planes plus extra covariate planes.
  - Supported non-Gaussian families receive only the extra covariate planes,
    with trait intercepts handled internally by GLLVM.jl.
- Ordinal covariate fits, mixed-family X, unsupported families, missing
  predictors, and non-Gaussian covariate CI requests still error deliberately.
- `gllvmTMB(..., engine = "julia", missing = miss_control(response = "include"))`
  now errors explicitly that missing-response masks are not wired yet.

## Files Changed

- `R/julia-bridge.R`
- `R/gllvmTMB.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `man/gllvm_julia_fit.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-x-admission.md`

## Checks Run

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 64`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 64`, `FAIL 0`, `WARN 0`, `SKIP 0` in `41.0s`.

```sh
~/.juliaup/bin/julia --project=. test/test_bridge_x.jl
```

Result: `50/50` passed in `18.0s` on the paired local
`GLLVM.jl-integration` checkout.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvm_julia_fit.Rd`; roxygen also emitted existing
link warnings unrelated to this bridge slice.

```sh
git diff --check
```

Result: clean.

## Evidence Boundary

This proves R long-format dispatch and direct `gllvm_julia_fit()` agree through
the Julia bridge for the admitted X cells. It does not prove R/TMB-vs-Julia
statistical parity, mixed-family X, missing-response masks, or non-Gaussian X
CI routing.

## Rose Verdict

PASS WITH NOTES. The R bridge is less stale and now admits tested X cells, but
missing masks and non-Gaussian covariate CIs remain explicit follow-up gates.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test()'
```
