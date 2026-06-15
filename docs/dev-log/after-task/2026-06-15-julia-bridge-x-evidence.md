# After Task: Julia Bridge Binomial/NB2/Gamma X Evidence

Date: 2026-06-15

## Goal

Promote the already-admitted fixed-effect-X Binomial, NB2, and Gamma bridge rows
from ledger-only claims to live R-side evidence.

## Implemented

- Added a live `julia-bridge` test covering:
  - `binomial()` with `env` fixed effect.
  - `nbinom2()` with `env` fixed effect.
  - `Gamma(link = "log")` with `env` fixed effect.
- Each public `gllvmTMB(..., engine = "julia")` fit is compared with the direct
  `gllvm_julia_fit()` wrapper on the same `Y`, `X`, and family.
- The test checks exact model tags, finite covariate coefficients,
  response-scale prediction shapes/ranges, finite logLik, and positive
  dispersion for NB2/Gamma.
- Updated `NEWS.md` to name Binomial/NB2/Gamma X as live-tested public dispatch
  evidence.

## Files Changed

- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-x-evidence.md`

## Checks Run

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 17 | PASS 163` in `2.4s`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 416` in `58.0s`.

```sh
git diff --check
```

Result: clean.

## Evidence Boundary

This proves R formula dispatch and direct Julia-wrapper dispatch agree for the
admitted complete-data fixed-effect-X Binomial, NB2, and Gamma bridge rows. It
does not prove native TMB-vs-Julia statistical parity, non-Gaussian X CI
routing, X+mask fits, `newdata` prediction, or mixed-family X metadata.

## Rose Verdict

Rose verdict: PASS WITH NOTES -- the X bridge ledger now has live public
evidence for all admitted X families, but inference and broader parity for
non-Gaussian X remain follow-up gates.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```
