# After Task: Julia Bridge Prediction And Residuals

Date: 2026-06-15

## Goal

Continue the R-first bridge finish by making supported Julia-engine fits usable
with ordinary in-sample prediction and residual methods.

## Implemented

- Added `predict.gllvmTMB_julia()` for in-sample link- and response-scale
  predictions.
- Added `fitted.gllvmTMB_julia()` returning a trait x unit fitted matrix.
- Added `residuals.gllvmTMB_julia()` returning simple response residuals with
  observed and fitted values.
- Stored trait/unit row indices on objects created through
  `gllvmTMB(..., engine = "julia")`, so prediction and residual tables preserve
  the original training-row order.
- Added explicit failure paths for unsupported `newdata`, ordinal prediction,
  and Gaussian covariate prediction when the current Julia bridge payload lacks
  the needed coefficient fields.

## Contract

For supported one-part Julia-engine fits, the in-sample conditional linear
predictor is reconstructed as

```text
eta[t, s] = alpha[t] + Lambda[t, ] %*% z[s, ] + sum_k X[t, s, k] * gamma[k]
```

where `beta_cov` replaces `alpha` when the non-Gaussian covariate bridge returns
the intercept vector under that name. Response-scale fitted values use the
current bridge family links: identity for gaussian, exp for poisson/nbinom2/gamma,
and logit inverse for binomial/beta.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-predict-residuals.md`

## Tests Added

- Pure-R synthetic `gllvmTMB_julia` tests for `predict()`, `fitted()`, and
  `residuals()`; these exercise the independent-formula check and failure-path
  clause because expected values are computed directly from `alpha`, `Lambda`,
  and `scores`.
- Live bridge tests for no-X and X Poisson fits; these exercise the
  neighbouring-feature clause by combining the methods with the JuliaCall
  bridge.
- Explicit error tests for `newdata`, ordinal prediction, and Gaussian-X
  prediction where the bridge payload is incomplete.

## Benchmark Numbers

N/A -- this is R-side post-fit reconstruction and S3 plumbing, not a hot
likelihood or optimizer path.

## R-Parity Verdict

Parity: N/A -- this slice does not compare R/TMB and Julia point estimates. It
checks that the R bridge object can reconstruct its own in-sample fitted values
from the payload returned by `GLLVM.bridge_fit`.

## Checks Run

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 98`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 98`, `FAIL 0`, `WARN 0`, `SKIP 0` in `41.6s`.

```sh
Rscript -e 'devtools::document()'
```

Result: registered `predict`, `fitted`, and `residuals` S3 methods and updated
`man/gllvmTMB_julia-methods.Rd`; roxygen emitted existing link warnings
unrelated to this slice.

```sh
git diff --check
```

Result: clean.

## Consistency Audit

- `rg -n "predict\\.gllvmTMB_julia|fitted\\.gllvmTMB_julia|residuals\\.gllvmTMB_julia|Gaussian covariate predictions|ordinal predictions|newdata predictions" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md man/gllvmTMB_julia-methods.Rd`
  confirmed the supported and rejected surfaces are documented and tested.

## GitHub Issue Maintenance

No remote issue mutation was made. This belongs under the existing Julia bridge
gate-drift / post-fit-method workstream; remote updates remain push/PR-gated.

## What Did Not Go Smoothly

The first test run failed because the new S3 methods were not registered in
`NAMESPACE`; roxygen fixed that. A second run exposed an `is.na()` warning on
formula `re_form`, which is now handled without warning.

## Remaining Risks

- `newdata` predictions are not supported.
- Ordinal prediction needs cutpoints/probability payloads from the Julia bridge.
- Gaussian covariate prediction needs the full mean coefficient vector from the
  Julia bridge.
- Residuals are simple response residuals only, not randomized-quantile or
  simulation-rank diagnostics.

## Rose Verdict

PASS WITH NOTES -- the R-side in-sample prediction/residual surface is covered
for current one-part bridge payloads, with unsupported cells failing loudly.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```
