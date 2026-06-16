# After-task report: R bridge mixed-family postfit admission

**Date**: 2026-06-16  
**Branch**: `codex/r-bridge-grouped-dispersion`

## Purpose

Admit the complete balanced no-X/no-mask/no-CI mixed-family Julia bridge row
for retained-payload postfit methods: in-sample `predict()` / `fitted()`,
response/Pearson `residuals()`, conditional in-sample `simulate()`, and raw
unit-tier covariance / ordination accessors.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-mixed-postfit-admission.md`

## Implementation

- Updated the mixed-family capability row so `postfit_predict`,
  `postfit_residuals`, `postfit_simulate`, and `postfit_ordination` now match
  the paired `GLLVM.jl` bridge capability ledger.
- Removed the R-only mixed-family stops from `residuals()`, `simulate()`, and
  raw unit-tier extractor family checks.
- Kept the support narrow: complete balanced mixed-family rows can use retained
  fitted values and retained covariance / ordination payloads; mixed-family
  CIs, masks, fixed-effect X, `newdata`, unconditional redraws, and richer
  native extractor parity remain gated.
- Added Gaussian mixed-family dispersion fallback for Pearson residuals and
  conditional simulation, using the per-trait mixed-family dispersion payload
  when scalar `sigma_eps` is absent.
- Added pure-R retained-payload tests and a live JuliaCall main-dispatch test
  for Gaussian + Poisson + Bernoulli mixed-family postfit behavior.
- Updated NEWS, Rd, coordination board, and the validation register to remove
  older statements that treated mixed-family residual/simulation or raw
  accessors as R-gated.

## Checks

```sh
julia --project=. --startup-file=no test/test_bridge_mixed.jl
julia --project=. --startup-file=no test/test_bridge_capabilities.jl
```

Results in `../GLLVM.jl-integration`: mixed-family payload metadata `18/18`
pass; bridge capability ledger `40/40` pass.

```sh
air format R/julia-bridge.R tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
```

Results: formatter quiet; roxygen regenerated `man/gllvmTMB_julia-methods.Rd`;
no-Julia bridge test passed with `13` expected Julia-runtime skips and `0`
failures; live Julia bridge test passed with `0` failures.

Capability guard:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); fam <- gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY; stopifnot(caps$postfit_predict[caps$family == fam]); stopifnot(caps$postfit_residuals[caps$family == fam]); stopifnot(caps$postfit_simulate[caps$family == fam]); stopifnot(caps$postfit_ordination[caps$family == fam]); stopifnot(!caps$ci_no_x_wald[caps$family == fam]); cat("mixed-family postfit capability guard OK\\n")'
```

Result: mixed-family postfit booleans are true while mixed-family no-X CIs
remain false.

Stale scan:

```sh
rg -n "mixed-family residuals remain gated|mixed-family residuals are not routed|mixed-family simulation is not routed|mixed-family residuals/simulation|mixed-family extractors remain gated|mixed-family extractors|predict/fitted/residuals/simulate/extractor parity remain gated|scalar-response rows only|scalar-response families only" R tests/testthat NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md man
```

Result: only the generic validation-register status example row remains on the
current public/code surfaces. Historical after-task and check-log entries from
earlier slices still preserve their then-current boundaries.

## Scope Boundary

IN: complete balanced no-X/no-mask/no-CI mixed-family vector rows for retained
in-sample prediction, fitted values, response/Pearson residuals, conditional
simulation, and raw unit-tier covariance / ordination accessors.

PARTIAL: this is retained-payload postfit admission, not native `gllvmTMB`
parity, uncertainty calibration, or a broad mixed-family inference claim.

PLANNED/GATED: mixed-family CIs, mixed-family masks, mixed-family fixed-effect
X, mixed-family `newdata`, unconditional simulation, structured covariance
terms, and richer extractor parity.

## Review Perspectives

- Hopper: the R bridge now follows the paired Julia mixed-family postfit
  capability row instead of blocking it at the R gate.
- Karpinski: paired `GLLVM.jl-integration` tests still pass for mixed-family
  payload metadata and bridge capabilities.
- Emmy: S3 methods use retained payloads only and keep unsupported methods
  explicit.
- Rose: NEWS, validation register, coordination board, and Rd wording separate
  admitted postfit support from mixed-family CI/mask/X/newdata follow-up.
- Grace: the no-Julia route remains clean with expected skips; live JuliaCall
  evidence is recorded separately from CRAN-main health.
