# After Task: Julia Bridge Ordination Extractors

Date: 2026-06-15

## Goal

Make Julia-engine fits usable through the normal R ordination and observation
count surface before adding more engine breadth.

## Implemented

- Added `nobs.gllvmTMB_julia()` and registered it with `stats::nobs`.
- Added `vcov.gllvmTMB_julia()` as an explicit status error. The bridge does not
  yet carry a covariance matrix, so this slice refuses to invent one.
- Routed `extract_ordination()` through cached Julia bridge `scores` and
  `loadings` for `level = "unit"`.
- Made `getLoadings()`, `getLV()`, and `rotate_loadings()` work for
  `gllvmTMB_julia` objects via the existing ordination matrix workflow.
- Documented the current boundary: `level = "unit_obs"` returns `NULL` for
  Julia bridge fits because the payload has no within-unit latent tier.

## Files Changed

- `R/julia-bridge.R`
- `R/extractors.R`
- `R/rotate-loadings.R`
- `tests/testthat/test-julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `man/extract_ordination.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-ordination-extractors.md`

## Tests Added

- Added pure-R tests on a synthetic `gllvmTMB_julia` object for `nobs()`,
  `vcov()` status, `extract_ordination()`, `getLoadings()`, `getLV()`, and
  `rotate_loadings()`. These satisfy the failure-path clause (`vcov()`) and the
  bridge-contract clause (cached payload matrices are exercised without
  JuliaCall).

## Benchmark Numbers

N/A -- no hot path changed. This is R-side extraction/dispatch over cached
bridge payloads.

## R-Parity Verdict

Parity: N/A -- this slice does not change likelihoods, estimates, CIs, or Julia
engine math.

## Checks Run

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Initial result before roxygen registration: `PASS 109`, `FAIL 1`, `WARN 0`,
`SKIP 0`; the failure was expected `stats::vcov()` S3 dispatch before
`NAMESPACE` contained the method registration.

```sh
Rscript -e 'devtools::document()'
```

Result: registered `stats::nobs` and `stats::vcov` for `gllvmTMB_julia` and
wrote `man/gllvmTMB_julia-methods.Rd`. Roxygen emitted existing unresolved-link
warnings outside this slice.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Final focused result: `PASS 115`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 115`, `FAIL 0`, `WARN 0`, `SKIP 0` in `37.7s`.
Final rerun after the documentation pass: `PASS 115`, `FAIL 0`, `WARN 0`,
`SKIP 0` in `45.0s`.

```sh
git diff --check
```

Result: clean.

## Consistency Audit

- `rg -n "Julia bridge|engine = \"julia\"|post-fit|ordination|nobs|vcov" README.md docs R NEWS.md tests/testthat/test-julia-bridge.R`
  reviewed the relevant bridge and ordination wording. NEWS and the generated
  method page now describe the new surface; README does not claim a narrower
  bridge post-fit surface.

## GitHub Issue Maintenance

No issue action taken in this local slice. This is part of the R-first bridge
completion lane and should be folded into the existing Julia bridge tracking
issue/PR rather than opening a duplicate.

## What Did Not Go Smoothly

`stats::vcov()` did not dispatch until `devtools::document()` regenerated
`NAMESPACE`, which is the expected S3 registration path for this method.

## Team Learning

Hopper/Rose lens: bridge completeness includes ordinary R extractors and honest
failure status, not only the initial fit call.

## Remaining Risks

- `vcov()` remains unavailable until the Julia bridge returns a covariance
  matrix or a named Hessian/SE payload.
- Julia bridge ordination is between-unit only; within-unit ordination returns
  `NULL`.

## Known Limitations

This slice does not add new Julia engine behavior, `newdata` prediction, ordinal
probability prediction, missing-response masks, or within-unit latent tiers.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

## Rose Verdict

Rose verdict: PASS WITH NOTES -- the R extractor surface is now consistent for
cached Julia bridge scores/loadings, with covariance and within-unit ordination
still explicitly bounded.
