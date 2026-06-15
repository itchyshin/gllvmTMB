# After Task: Julia Bridge NB1 Post-Fit Methods

## Goal

Complete the post-fit R surface for the already-admitted NB1 no-X
`engine = "julia"` bridge row.

## Historical Status Note

This report predates `2026-06-15-julia-bridge-nb1-mask.md`. NB1 no-X response
masks are now admitted for point fits and in-sample post-fit rows. Remaining
NB1 bridge gaps are fixed-effect X, masked CIs/profile/bootstrap, masked
simulation, mixed-family NB1, and native TMB-vs-Julia comparator parity.

## Implemented

NB1 now uses the log-link response-scale prediction route in
`predict.gllvmTMB_julia()` / `fitted.gllvmTMB_julia()`. That unlocks the
existing `residuals()` and `augment()` methods for complete-data NB1 bridge
objects. `simulate.gllvmTMB_julia()` now routes conditional in-sample NB1 draws
when the object carries a finite positive dispersion payload.

## Mathematical Contract

NB1 uses the linear mean-variance parameterization
`Var(Y | mu) = mu * (1 + phi)`. Conditional simulation draws with
`stats::rnbinom(mu = mu, size = mu / phi)`, which gives
`Var = mu + mu^2 / (mu / phi) = mu * (1 + phi)`.

## Files Changed

- `R/julia-bridge.R` - NB1 inverse-link route, row-wise dispersion guard, and
  NB1 conditional simulation.
- `tests/testthat/test-julia-bridge.R` - pure-R synthetic NB1 post-fit tests
  plus live NB1 prediction/residual/augment/simulation checks.
- `man/gllvmTMB_julia-methods.Rd` - regenerated method documentation.
- `NEWS.md` - updated the Julia bridge post-fit boundary.
- `docs/dev-log/check-log.md` - recorded evidence.

## Tests Added

Added pure-R tests for NB1 response prediction, residuals, augmentation,
conditional simulation reproducibility, integer/non-negative simulated counts,
and bad-dispersion failure. Extended the live NB1 Julia test to cover
`predict()`, `residuals()`, `augment()`, and reproducible conditional
`simulate()` on the public `gllvmTMB(..., engine = "julia")` route.

## Benchmark Numbers

N/A - no hot-path fitting code changed.

## R-Parity Verdict

R-to-Julia bridge parity for the admitted NB1 fit row remains covered by the
previous direct-logLik equality test. This slice adds R post-fit behavior over
the existing Julia payload; native TMB-vs-Julia NB1 statistical parity remains
a separate comparator gate.

## JET / Allocs / Aqua Verdicts

- JET: N/A - R post-fit bridge code only.
- Allocs: N/A - R post-fit bridge code only.
- Aqua: N/A - R post-fit bridge code only.

## Checks Run

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 16 | PASS 163`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 394`.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvmTMB_julia-methods.Rd`; unrelated pre-existing
roxygen unresolved-link warnings remain. Unrelated Rd churn was reverted.

```sh
Rscript -e 'pkgdown::check_pkgdown()'
```

Result: `No problems found`.

```sh
git diff --check
```

Result: clean after final whitespace check.

## Consistency Audit

```sh
rg -n "NB1|nb1|simulate\\(\\)|gaussian, poisson, binomial" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md man/gllvmTMB_julia-methods.Rd
```

Result: expected hits in the NB1 inverse-link route, simulation branch, tests,
NEWS, and generated manual page.

## GitHub Issue Maintenance

No issue was opened or closed. This is a local R-first bridge completion slice
under the broader bridge-gate drift lane.

## What Did Not Go Smoothly

Roxygen regenerated unrelated manual-page formatting in four topics. Those
side effects were reverted manually; only the Julia-bridge method Rd change was
kept.

## Team Learning

Admitting a family is not just `fit()` plus `confint()`: the R surface also
needs prediction, residual, augmentation, and simulation behavior or explicit
fail-fast boundaries.

## Remaining Risks

- NB1 with fixed-effect covariates remains unsupported.
- NB1 masked CIs/profile/bootstrap and masked simulations remain unsupported.
  NB1 no-X response masks landed in a later slice.
- NB1 profile/bootstrap CIs are not separately validated here.
- Native TMB-vs-Julia NB1 parity is still a future comparator gate.
- `simulate()` is conditional on fitted in-sample means; it is not an
  unconditional bootstrap or posterior predictive route.

## Known Limitations

This completes post-fit behavior only for complete, balanced, one-part no-X NB1
reduced-rank fits routed through `engine = "julia"`.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

## Rose Verdict

Rose verdict: PASS WITH NOTES - NB1 post-fit methods are routed and live-tested
for the admitted complete-data no-X row, while NB1 X, masked CIs/simulations,
profile/bootstrap, native-TMB parity, and mixed-family rows remain open gates.
NB1 no-X response masks landed in a later slice.
