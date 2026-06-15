# After Task: Julia Bridge NB2/Beta/Gamma Simulate

Date: 2026-06-15

## Goal

Complete the narrow conditional in-sample `simulate()` route for bridge families
whose fitted mean and dispersion payloads are already available on
`gllvmTMB_julia` objects.

## Implemented

- Added `simulate.gllvmTMB_julia()` support for:
  - NB2 / `negbinomial`: `stats::rnbinom(mu = mu, size = r)`.
  - Beta: `stats::rbeta(shape1 = mu * phi, shape2 = (1 - mu) * phi)`.
  - Gamma: `stats::rgamma(shape = alpha, scale = mu / alpha)`.
- Reused the existing row-aligned dispersion helper so scalar, per-trait, and
  original-row payloads fail or expand consistently.
- Added pure-R synthetic bridge tests for NB2, Beta, Gamma, reproducible seeds,
  ranges/support, and bad dispersion errors.
- Added live bridge tests exercising Beta X, NB2 X, and Gamma X objects through
  `simulate()`.
- Regenerated `man/gllvmTMB_julia-methods.Rd` for the new supported family list.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-dispersion-simulate.md`

## Checks Run

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 17 | PASS 175` in `2.2s`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 439` in `58.3s`.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvmTMB_julia-methods.Rd`; unrelated pre-existing
roxygen unresolved-link warnings remain. Unrelated Rd churn was reverted.

## Evidence Boundary

This is conditional in-sample simulation from cached fitted means and dispersion
payloads. It is not a bootstrap, posterior predictive draw, latent-factor redraw,
`newdata` route, mixed-family simulation route, or simulation calibration claim.

## Rose Verdict

Rose verdict: PASS WITH NOTES -- the post-fit R surface is broader and still
honestly bounded; masked simulations and calibration remain explicit future
gates.

## Next Command

```sh
Rscript -e 'pkgdown::check_pkgdown()'
```
