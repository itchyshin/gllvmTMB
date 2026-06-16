# After-task report: R bridge grouped-dispersion CI admission

**Date**: 2026-06-16  
**Branch**: `codex/r-bridge-grouped-dispersion`  
**Paired Julia runtime**: `GLLVM.jl-integration@b2ab8a5`

## Purpose

Admit no-X Wald/profile/bootstrap CI payloads for the grouped-dispersion Julia
bridge rows: NB2, NB1, Beta, and shared-Gamma. This closes the bridge-side
status gap after the Julia engine added grouped CI adapters, while keeping
per-trait ordinal, masked, mixed-family, and X-row CIs gated.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_fit.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-grouped-ci-admission.md`

## Implementation

- `.GLLVM_JULIA_CI_NO_X_FAMILIES` now excludes only per-trait ordinal rows, so
  NB2, NB1, Beta, and Gamma are admitted for no-X CI payloads.
- `gllvm_julia_fit()` no longer errors before Julia setup for grouped
  `ci_method != "none"` requests.
- Capability notes now distinguish no-X CI support from still-planned X-row CI
  and native parity promotion.
- Live tests now check grouped direct-wrapper Wald CIs and grouped
  main-dispatch post-fit/stored Wald CIs with nuisance labels `r[...]`,
  `phi[...]`, and `alpha[...]`.

## Checks

```sh
julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl
julia --project=. --startup-file=no test/test_bridge_capabilities.jl
julia --project=. --startup-file=no test/test_bridge_ci.jl
```

Result in `../GLLVM.jl-integration`: grouped bridge `121/121` pass;
capabilities rerun `34/34` pass after expected-ledger update; bridge CI `64/64`
pass.

```sh
air format R/julia-bridge.R tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
```

Result: roxygen regenerated `man/gllvm_julia_fit.Rd`; no-Julia bridge test
passed with `12` expected skips; live Julia bridge test passed with `0`
failures.

## Scope Boundary

IN: no-X grouped-dispersion NB2, NB1, Beta, and shared-Gamma bridge CIs for
Wald/profile/bootstrap payload requests, with R tests covering the Wald
normalisation path and Julia tests covering grouped Wald/profile/bootstrap
routing.

PARTIAL: broad native-vs-Julia parity still rests on selected fixtures, not a
full simulation grid.

PLANNED/GATED: per-trait ordinal CIs, masked CIs, mixed-family CIs, X-row CIs,
NB1-X, ordinal-X, mixed-family-X, newdata prediction/simulation, unconditional
simulation, and richer extractor parity.

## Review Perspectives

- Hopper: R bridge admission now matches the paired Julia capability row.
- Karpinski: paired engine commit `b2ab8a5` supplies the grouped CI adapters.
- Rose: NEWS, capability table, validation register, coordination board, tests,
  and generated Rd now agree on the grouped-CI scope.
- Grace: targeted no-Julia and live Julia bridge tests passed; full package
  check/pkgdown remain release-gate work.
