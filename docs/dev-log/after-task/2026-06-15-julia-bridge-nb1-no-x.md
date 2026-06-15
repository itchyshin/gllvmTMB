# After Task: Julia Bridge NB1 No-X Admission

## Goal

Admit the narrow NB1 (`nbinom1`) no-X reduced-rank route through the R
`engine = "julia"` bridge.

## Historical Status Note

This report predates `2026-06-15-julia-bridge-nb1-mask.md`. NB1 no-X response
masks are now admitted for point fits and in-sample post-fit rows. Remaining
NB1 bridge gaps are fixed-effect X, masked CIs/profile/bootstrap, masked
simulation, mixed-family NB1, and native TMB-vs-Julia comparator parity.

## Implemented

The R bridge now maps `nbinom1()` / `"nbinom1"` / `"nb1"` to the paired
`GLLVM.bridge_fit` `nb1` route. `gllvm_julia_capabilities()` now lists NB1 as
an admitted no-X row instead of planned debt. The tests keep NB1 fixed-effect-X
and, at this slice, missing-response-mask cells rejected before JuliaCall and add a live NB1
fit plus Wald CI smoke.

## Mathematical Contract

NB1 uses the linear mean-variance parameterization
`Var(Y | mu) = mu * (1 + phi)`. The R and Julia sides both carry `phi` on the
natural scale for the public payload, so no NB2-style inversion is used.

## Files Changed

- `R/julia-bridge.R` - NB1 family mapping, capability ledger, and integer
  response coercion.
- `tests/testthat/test-julia-bridge.R` - NB1 mapping, rejection gates, live fit,
  direct-logLik parity, and Wald CI smoke.
- `man/gllvm_julia_capabilities.Rd` - regenerated capability documentation.
- `NEWS.md` - updated the bridge scope boundary.
- `docs/dev-log/check-log.md` - recorded evidence.

## Tests Added

Added pure-R tests for NB1 mapping, NB1 X rejection, and NB1 mask rejection.
Added one live Julia-gated NB1 no-X test that checks formula route, direct
`gllvm_julia_fit()` logLik equality, finite positive dispersion payload, and
well-formed Wald CIs with a `phi` row.

## Benchmark Numbers

N/A - no hot-path code changed.

## R-Parity Verdict

R-to-Julia structural and direct-bridge parity passed for the admitted NB1 row:
the formula fit and direct `gllvm_julia_fit()` logLik matched to `1e-8` in the
live test. Native TMB-vs-Julia statistical parity remains a separate comparator
gate.

## JET / Allocs / Aqua Verdicts

- JET: N/A - R bridge routing only.
- Allocs: N/A - R bridge routing only.
- Aqua: N/A - R bridge routing only.

## Checks Run

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 16 | PASS 151`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

First result: `FAIL 3 | WARN 0 | SKIP 0 | PASS 362`; the failure was a test
assumption that NB1 dispersion was scalar in R.

Corrected result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 370`.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvm_julia_capabilities.Rd`; unrelated pre-existing
roxygen unresolved-link warnings remain.

```sh
Rscript -e 'pkgdown::check_pkgdown()'
```

Result: `No problems found`.

```sh
git diff --check
```

Result: clean.

## Consistency Audit

```sh
rg -n "nbinom1|\\bnb1\\b|mixed-family vector|bridge_capabilities|gllvm_julia_capabilities" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md man/gllvm_julia_capabilities.Rd
```

Result: expected hits in the bridge family mapping, capability ledger, NB1
tests, NEWS, and generated manual page.

## GitHub Issue Maintenance

No issue was opened or closed. This is a local R-first bridge admission slice
under the broader bridge-gate drift lane.

## What Did Not Go Smoothly

The first live test assumed a scalar `fit$dispersion`; the R bridge object
returns a finite positive dispersion vector. The test was corrected to assert
the supported contract rather than the wrong shape.

## Team Learning

For family admission, test the public R object shape as returned before naming
that shape in docs or downstream code.

## Remaining Risks

- Native TMB-vs-Julia NB1 parity is not yet tested in this slice.
- NB1 profile/bootstrap CIs are not separately validated.
- NB1 fixed-effect covariates, masked CIs/profile/bootstrap, masked
  simulations, mixed-family rows, and broader structures remain unsupported in
  the R bridge. NB1 no-X response masks landed in a later slice.

## Known Limitations

This admits only complete, balanced, one-part no-X reduced-rank NB1 fits through
`engine = "julia"`. Unsupported NB1 cells still fail before JuliaCall.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

## Rose Verdict

Rose verdict: PASS WITH NOTES - NB1 no-X is admitted and live-tested, while
native TMB parity, profile/bootstrap CIs, X, mixed-family, and broader
structures remain open gates. NB1 no-X response masks landed in a later slice.
