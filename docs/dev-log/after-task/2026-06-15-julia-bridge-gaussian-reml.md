# After Task: Julia Bridge Gaussian REML Route

## Goal

Make `engine = "julia"` honor Gaussian no-X `REML = TRUE` explicitly, while
rejecting unsupported REML cells instead of silently falling back to ML.

## Implemented

The R bridge now accepts a lower-level `gllvm_julia_fit(..., reml = TRUE)`
option and passes `options["reml"] = true` to the paired `GLLVM.jl` bridge for
complete Gaussian no-X fits. Public `gllvmTMB(..., engine = "julia", REML =
TRUE)` now preserves that route, stores `fit$reml = TRUE`, and returns the
`gaussian_reml_rr` model row from Julia.

The bridge rejects REML for non-Gaussian families, mixed-family vectors,
fixed-effect-X fits, and masked-response fits before JuliaCall setup. Gaussian
REML interval requests now fail with method-specific CI-status strings such as
`wald_unavailable_reml`; no REML CI endpoints are claimed.

## Mathematical Contract

REML is Gaussian-only. This slice changes R-side routing and status semantics
only: the REML criterion and point estimates are computed by the paired
`GLLVM.jl` checkout, and the R wrapper proves public formula dispatch equals the
direct bridge wrapper on the same response matrix.

## Files Changed

- `R/julia-bridge.R` - REML option routing, unsupported-cell guards, REML
  CI-status helpers, and `confint()` REML preflight.
- `tests/testthat/test-julia-bridge.R` - pure-R unsupported-cell checks and live
  Gaussian REML formula-vs-direct equality.
- `man/gllvm_julia_fit.Rd`, `man/confint.gllvmTMB_julia.Rd` - regenerated
  bridge docs for the new argument and REML CI-status boundary.
- `NEWS.md` - user-facing development note.
- `docs/dev-log/check-log.md` - command evidence.
- `docs/dev-log/coordination-board.md` - current REML status row.

## Tests Added

Added pure-R tests proving unsupported REML cells fail before JuliaCall setup:
non-Gaussian, mixed-family, fixed-effect-X, and direct REML CI requests.

Added a live R-Julia test proving public
`gllvmTMB(..., engine = "julia", REML = TRUE)` returns `gaussian_reml_rr`,
stores `fit$reml = TRUE`, has finite REML logLik, matches direct
`gllvm_julia_fit(..., reml = TRUE)` logLik to `1e-8`, and rejects Wald REML CIs
with `wald_unavailable_reml`.

## Benchmark Numbers

N/A - no hot-path or Julia engine code changed.

## R-Parity Verdict

Bridge parity passed against the paired
`/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` checkout at
`5fabcb1`. The public R formula route and direct bridge wrapper matched REML
logLik to `1e-8` on the live test fixture.

## Validation

- `Rscript -e 'devtools::document(roclets = "rd")'`
  - Passed with pre-existing unresolved-link roxygen warnings; unrelated
    generated Rd churn was reverted.
- `Rscript -e 'devtools::test(filter = "julia-bridge")'`
  - Final result: `FAIL 0 | WARN 0 | SKIP 19 | PASS 254`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'`
  - First exposed that REML `confint()` returned a matrix instead of failing.
    After the REML CI preflight, final result: `FAIL 0 | WARN 0 | SKIP 0 | PASS
    612`.
- `Rscript -e 'devtools::test()'`
  - Final result: `FAIL 0 | WARN 3 | SKIP 725 | PASS 3023`.
- `git diff --check`
  - Clean.

## Rose Verdict

Rose verdict: PASS WITH NOTES - Gaussian Julia-bridge REML is now explicit and
tested for point-fit routing; REML intervals and REML with X/masks remain
unsupported with named statuses.

## Remaining Risks

- Gaussian REML CIs are still unavailable on the Julia bridge.
- Gaussian REML with fixed-effect covariates or response masks is not routed.
- Non-Gaussian REML remains deliberately unsupported.
- This is not a speed claim and does not change `GLLVM.jl` likelihood code.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```
