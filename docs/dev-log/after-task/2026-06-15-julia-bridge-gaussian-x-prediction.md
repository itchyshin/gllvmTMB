# After Task: Julia Bridge Gaussian-X Prediction

Date: 2026-06-15

## Goal

Use the paired GLLVM.jl Gaussian-X `mean_coef` payload so R-side Julia-engine
fits can produce in-sample predictions for Gaussian covariate models.

## Implemented

- `coef.gllvmTMB_julia()` and `summary.gllvmTMB_julia()` now expose
  `mean_coef` when the bridge payload carries it.
- `predict.gllvmTMB_julia()` and `fitted.gllvmTMB_julia()` use
  `X * mean_coef + Lambda * z` for `gaussian_x_rr` fits.
- The old-payload failure path remains tested: Gaussian-X prediction still
  errors if the object has `X` but no `mean_coef`.
- Live Gaussian-X bridge tests now assert `mean_coef` is present and in-sample
  prediction is finite.

## Contract

For Gaussian covariate fits, `alpha` is only a per-trait fitted-mean summary.
The fitted mean must be reconstructed from the full design coefficient vector:

```text
eta[t, s] = sum_k X[t, s, k] * mean_coef[k] + Lambda[t, ] %*% z[s, ]
```

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-gaussian-x-prediction.md`

## Tests Added

- Pure-R old-payload/new-payload checks for Gaussian-X prediction.
- Live Gaussian-X bridge check that `mean_coef` length matches `dim(X)[3]` and
  in-sample link predictions are finite.

## Benchmark Numbers

N/A -- post-fit R reconstruction and payload consumption only.

## R-Parity Verdict

Parity: N/A -- this checks R reconstruction from the Julia bridge payload, not
TMB-vs-Julia estimator parity.

## Checks Run

```sh
~/.juliaup/bin/julia --project=. test/test_bridge_x.jl
```

Result in `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`:
`PASS 52`, `FAIL 0`, `ERROR 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 102`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 102`, `FAIL 0`, `WARN 0`, `SKIP 0` in `42.6s`.

## Consistency Audit

- `rg -n "mean_coef|Gaussian covariate|gaussian_x_rr|newdata|ordinal probabilities" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-15-julia-bridge-gaussian-x-prediction.md`
  confirmed covered and unsupported prediction surfaces are visible.

## GitHub Issue Maintenance

No remote issue mutation was made. This should be linked from the bridge
post-fit/prediction issue when remote updates are approved.

## Remaining Risks

- `newdata` prediction remains unsupported.
- Ordinal probabilities remain unsupported.
- Missing-response masks remain unsupported.

## Rose Verdict

PASS WITH NOTES -- Gaussian-X in-sample prediction is covered with the paired
payload; broader prediction surfaces remain open.
