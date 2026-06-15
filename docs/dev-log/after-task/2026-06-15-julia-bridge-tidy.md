# After Task: Julia Bridge Tidy Method

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Pat / Rose`

## 1. Goal

Add the next small R-visible post-fit method for `gllvmTMB_julia` objects:
`generics::tidy()` should return the fixed-effect coefficient rows that the
bridge already caches, while unsupported interval and random-parameter tidy
requests fail clearly.

## 2. Implemented

- Added `tidy.gllvmTMB_julia()`.
- Registered `S3method(tidy, gllvmTMB_julia)`.
- Documented the method on the existing Julia-bridge methods help page.
- Added tests for the returned `term`, `estimate`, and `component` columns.
- Added tests that `effects = "ran_pars"` and `conf.int = TRUE` are explicit
  unsupported boundaries.
- Added a test that loadings are not included in `tidy(..., effects = "fixed")`.

## 3. Files Changed

- `R/julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-tidy.md`

## 3a. Decisions And Rejected Alternatives

Decision: route only `effects = "fixed"` in this slice. Rejected alternative:
include loadings or confidence intervals in `tidy()`, because that would mix
ordination parameters into a fixed-effect table or imply covariance/SE support
that the bridge does not yet carry. Confidence: high for cached fixed rows; no
claim is made for random-parameter or interval tidiers.

## 4. Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::document()'`:
  completed; emitted pre-existing unresolved-link warnings outside this slice.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `97 pass`, `14 skip`, `0 fail`, `0 warn` in `1.9s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `283 pass`, `0 fail`, `0 warn`, `0 skip` in `53.0s`.

## 5. Tests Of The Tests

The first version of the test incorrectly expected loadings in the fixed-effect
tidy table. The corrected test now locks the safer boundary: loadings are
excluded from `effects = "fixed"` and remain available through `coef()` and
ordination extractors.

## 6. Consistency Audit

NEWS now lists `tidy()` among Julia-engine post-fit methods. The help page says
only fixed tidy rows are wired and interval tidy output is unsupported.

## 7. Roadmap Tick

This advances the R-first post-fit bridge surface. It does not add Julia engine
breadth.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the post-fit bridge-method row under the R-Julia contract phase.

## 8. What Did Not Go Smoothly

`devtools::document()` touched unrelated Rd files under the local roxygen
version. Those unrelated changes were manually removed so the commit remains
scoped to the Julia-bridge method page and S3 registration.

## 9. Team Learning

Ada: small R methods keep the bridge usable while the larger parity matrix
continues.

Hopper: cached bridge fields are enough for fixed tidy rows; richer output waits
for covariance and parameter-class payloads.

Pat: `tidy()` is a natural first thing R users try after `summary()`, so a
limited, explicit method is better than falling through to no method.

Rose: PASS WITH NOTES — fixed rows are covered; no SE, CI, random-parameter, or
loading-table tidy claim is made.

## 10. Known Limitations And Next Actions

Next post-fit slices: decide whether `simulate.gllvmTMB_julia()` should be a
fail-loud method or a real cached-parameter simulation route; then extend tidy
only after covariance/CI payloads are routed.
