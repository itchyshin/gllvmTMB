# After-task report: R bridge masked-CI admission

**Date**: 2026-06-16  
**Branch**: `codex/r-bridge-grouped-dispersion`  
**Paired Julia runtime**: `GLLVM.jl-integration`

## Purpose

Admit masked no-X Wald/profile/bootstrap CI payloads for the Julia bridge rows
whose point fits and native Julia CI engines already support observed-cell
masks: Poisson, Bernoulli binomial, NB2, NB1, Beta, and Gamma.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_capabilities.Rd`
- `man/gllvm_julia_fit.Rd`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-masked-ci-admission.md`

## Implementation

- Added `.GLLVM_JULIA_MASK_CI_FAMILIES` and `ci_mask_wald`,
  `ci_mask_profile`, and `ci_mask_bootstrap` columns to the R-side capability
  ledger.
- Removed the direct-wrapper `response-mask bridge fits are not routed yet` CI
  stop. Per-trait ordinal CI, mixed-family CI, and fixed-effect-X CI gates still
  stop before Julia setup.
- Updated capability notes and roxygen wording so mask point support and mask
  CI support are separate claims.
- Added pure-R tests for the new capability columns and a mocked
  main-dispatch fit-time mask-CI route.
- Added live JuliaCall tests for direct-wrapper masked Wald CIs and main
  dispatch masked post-fit Wald recomputation.

## Checks

```sh
julia --project=. --startup-file=no test/test_bridge_missing_mask.jl
julia --project=. --startup-file=no test/test_bridge_capabilities.jl
julia --project=. --startup-file=no test/test_bridge_ci.jl
```

Result in `../GLLVM.jl-integration`: masked bridge `83/83` pass; capability
ledger `37/37` pass; complete bridge CI routing `64/64` pass.

```sh
air format R/julia-bridge.R tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
```

Result: roxygen regenerated the Julia bridge Rd topics; no-Julia bridge test
passed with `12` expected skips; live Julia bridge test completed with `0`
failures.

Capability guard:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(identical(caps$family[caps$ci_mask_wald], gllvmTMB:::.GLLVM_JULIA_MASK_CI_FAMILIES)); stopifnot(identical(caps$family[caps$ci_mask_profile], gllvmTMB:::.GLLVM_JULIA_MASK_CI_FAMILIES)); stopifnot(identical(caps$family[caps$ci_mask_bootstrap], gllvmTMB:::.GLLVM_JULIA_MASK_CI_FAMILIES)); stopifnot(!any(caps$ci_mask_wald[caps$family %in% gllvmTMB:::.GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES])); stopifnot(!caps$ci_mask_wald[caps$family == "gaussian"]); stopifnot(!caps$ci_mask_wald[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("masked no-X Wald/profile/bootstrap CI payloads", caps$notes, fixed = TRUE))); print(caps[, c("family", "missing_response", "ci_no_x_wald", "ci_mask_wald", "status")], row.names = FALSE)'
```

Result: `ci_mask_*` is true only for Poisson, Bernoulli binomial, NB2, NB1,
Beta, and Gamma.

## Scope Boundary

IN: masked no-X CI payloads for Poisson, Bernoulli binomial, NB2, NB1, Beta,
and Gamma bridge rows.

PARTIAL: this is bridge-admission and status evidence. It does not establish
coverage calibration, broad native-vs-Julia parity, or speed claims.

PLANNED/GATED: Gaussian response masks, mixed-family masks, masks with
fixed-effect covariates, per-trait ordinal CI endpoints, X-row CIs,
mixed-family CIs, structured covariance terms, newdata prediction/simulation,
unconditional simulation, and richer extractor parity.

## Review Perspectives

- Hopper: R admission now follows the paired Julia mask-CI contract.
- Karpinski: paired engine support is in `GLLVM.jl-integration`.
- Fisher: `pdHess`/CI quality calibration remains a later inference programme;
  this slice only exposes the requested CI payload/status route.
- Rose: capability table, NEWS, validation register, tests, generated Rd, and
  coordination board agree on the admitted subset.
- Grace: targeted no-Julia and live Julia bridge tests passed; full package
  check/pkgdown remain release-gate work.
