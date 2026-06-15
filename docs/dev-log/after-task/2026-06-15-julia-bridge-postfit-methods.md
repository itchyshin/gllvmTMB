# After Task: Julia Bridge Post-Fit Methods

Date: 2026-06-15

## Goal

Make already-supported Julia-engine fits inspectable through ordinary R post-fit
methods before adding more engine breadth.

## Implemented

- Added `coef.gllvmTMB_julia()` returning a named list with available bridge
  coefficients: `alpha`, `loadings`, `gamma`, `beta_cov`, `dispersion`, and
  `sigma_eps` when present.
- Added `summary.gllvmTMB_julia()` with dimensions, model/family, logLik, AIC,
  BIC, convergence, coefficient table, loadings, and bridge note.
- Added `print.summary.gllvmTMB_julia()` for compact console output.
- Added S3 registrations and a generated `gllvmTMB_julia-methods` Rd topic.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-postfit-methods.md`

## Checks Run

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 77`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 77`, `FAIL 0`, `WARN 0`, `SKIP 0` in `46.4s`.

```sh
Rscript -e 'devtools::document()'
```

Result: registered the S3 methods and wrote `man/gllvmTMB_julia-methods.Rd`;
roxygen emitted existing link warnings unrelated to this slice.

```sh
git diff --check
```

Result: clean.

## Evidence Boundary

This is R-side inspection only. It does not implement `predict()` or
`residuals()` for Julia-engine fits and does not add new Julia engine behavior.

## Rose Verdict

PASS WITH NOTES. The Julia-engine object is now easier to inspect through normal
R methods; prediction and residual contracts remain separate R-first slices.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test()'
```

