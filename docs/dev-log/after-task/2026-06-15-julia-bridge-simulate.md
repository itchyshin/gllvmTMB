# After Task: Julia Bridge Conditional Simulate Method

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Fisher / Rose`

## 1. Goal

Add the next R-visible post-fit method for `gllvmTMB_julia` objects:
`simulate()` should work where the cached bridge payload is enough to draw
honest conditional in-sample responses, and fail clearly elsewhere.

## 2. Implemented

- Added `simulate.gllvmTMB_julia()`.
- Registered `S3method(simulate, gllvmTMB_julia)`.
- Routed conditional in-sample draws for gaussian, poisson, and binomial fits.
- Used cached fitted means, `sigma_eps`, and binomial trial matrix `N`.
- Preserved original long-format row order through cached row indices.
- Rejected masked-response simulations and unsupported families explicitly.
- Documented the method on the Julia-bridge methods help page.

## 3. Files Changed

- `R/julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-simulate.md`

## 3a. Decisions And Rejected Alternatives

Decision: route only conditional in-sample simulation for gaussian, poisson, and
binomial. Rejected alternative: simulate NB2, Beta, Gamma, or Ordinal from
partial payload assumptions. Those require a tighter parameterization/cutpoint
contract before the R method should claim support.

## 4. Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::document()'`:
  completed; emitted pre-existing unresolved-link warnings outside this slice
  and generated unrelated Rd link churn that was restored before commit.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `109 pass`, `14 skip`, `0 fail`, `0 warn` in `1.8s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `301 pass`, `0 fail`, `0 warn`, `0 skip` in `52.9s`.

## 5. Tests Of The Tests

The new tests cover deterministic seeded simulation, output dimensions,
non-negative Poisson draws, cbind-binomial trial bounds, Gaussian `sigma_eps`
requirements, unsupported-family errors, and masked-response rejection. Live
tests exercise real Julia-engine Poisson and cbind-binomial objects.

## 6. Consistency Audit

NEWS now lists `simulate()` among Julia-engine post-fit methods and states that
the route is conditional, in-sample, and limited to gaussian, poisson, and
binomial. The help page documents `nsim`, `seed`, and the matrix return shape.
Wording scan used:

- `rg -n "simulate\\(\\)|simulate\\.gllvmTMB_julia|conditional|unconditional|bootstrap-grade|gaussian, poisson, and binomial|masked-response simulations|unsupported families" NEWS.md R/julia-bridge.R man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-15-julia-bridge-simulate.md`
- `rg -n "all families|all-family|complete bridge|full capability|bootstrap-ready|calibrated simulation|unconditional latent|AI-REML|non-Gaussian REML" NEWS.md R/julia-bridge.R man/gllvmTMB_julia-methods.Rd docs/dev-log/after-task/2026-06-15-julia-bridge-simulate.md`

The second scan found only historical native-R/TMB capability notes in NEWS,
not Julia-bridge simulation claims.

## 7. Roadmap Tick

This advances the R-first post-fit bridge surface. It does not add bootstrap
calibration, unconditional latent-factor redraws, or Julia engine breadth.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the post-fit bridge-method row under the R-Julia contract phase.

## 8. What Did Not Go Smoothly

`devtools::document()` again touched unrelated generated Rd files under the
local roxygen version. Those unrelated changes were restored so the commit stays
scoped to the Julia-bridge method page and S3 registration.

## 9. Team Learning

Fisher/Rose: simulation support must say whether it is conditional,
unconditional, bootstrap-grade, masked-response-aware, or merely a convenience
draw. The method now chooses the narrow honest path.

## 10. Known Limitations And Next Actions

Unsupported next rows: NB2, Beta, Gamma, Ordinal, masked-response simulation,
`newdata`, and unconditional latent-factor redraws. The next R-first bridge
slice should either improve CI-status/covariance payloads or add one unsupported
method boundary that users naturally try next.

## 11. Rose Verdict

Rose: PASS WITH NOTES — gaussian/poisson/binomial conditional simulation is
covered; no broader simulation, bootstrap, or coverage claim is made.
