# After Task: Gamma Shared-Bridge Parity

## Goal

Resolve the Gamma decision left by the NB1/Gamma bridge audit without
overclaiming native per-trait Gamma support.

## Implemented

In the paired Julia runtime, `GLLVM.bridge_fit(family = "gamma")` now routes
through `fit_gamma_gllvm_grouped()` with one shared dispersion group. This
matches current native `gllvmTMB` ordinary Gamma, where `sigma_eps` is one
shared coefficient of variation across Gamma traits.

In `gllvmTMB`, the R bridge tests and capability notes now distinguish
NB2/NB1/Beta per-trait grouped dispersion from Gamma shared grouped dispersion.

## Evidence

The small complete balanced reduced-rank fixture reports:

- Julia Gamma `logLik = 17.595906505513`.
- Native TMB Gamma `logLik = 17.595906784863`.
- Delta `-2.7935e-07`.
- `df = 5` for both engines.
- Julia `dispersion_group_id = c(1, 1)`.
- Julia public `sigma = c(0.0077397024, 0.0077397024)`, matching native
  `sigma_eps = 0.0077397018`.

## Checks Run

- `julia --project=. test/test_bridge_grouped_dispersion.jl` in
  `../GLLVM.jl-integration` -> `49/49 pass`.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- Live bridge check:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.

## Scope Boundary

`JUL-01` remains `partial`. This slice proves current-oracle Gamma point parity
on one small complete balanced reduced-rank fixture. It does not implement
native per-trait Gamma CV/shape, grouped-dispersion CIs, masks, non-Gaussian X,
mixed-family Gamma, structured terms, broad simulation recovery, or speed
claims.

## Team Learning

- Ada/Hopper: choose the current native oracle for bridge parity when the
  engine has a broader experimental row.
- Gauss/Noether: per-trait Gamma requires a native likelihood/reporting design,
  not just a bridge routing switch.
- Rose: Gamma wording must say shared grouped dispersion unless and until the
  native per-trait expansion lands.
