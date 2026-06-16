# After-task report: R bridge fixed-effect-X CI admission

**Date**: 2026-06-16  
**Branch**: `codex/r-bridge-grouped-dispersion`

## Purpose

Admit complete-response fixed-effect-X Wald/profile/bootstrap CI payloads for
the Julia bridge rows whose paired `GLLVM.jl` runtime already routes native
`X` intervals: Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and Gamma.

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
- `docs/dev-log/after-task/2026-06-16-r-bridge-fixed-x-ci-admission.md`

## Implementation

- Added `.GLLVM_JULIA_X_CI_FAMILIES` and the public capability columns
  `ci_x_wald`, `ci_x_profile`, and `ci_x_bootstrap`.
- Narrowed the pre-Julia CI gate: fixed-effect-X CIs are now admitted for
  Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and Gamma complete-response
  rows; NB1-X, ordinal-X, mixed-family-X, and masks combined with fixed-effect
  X still fail loudly.
- Updated capability notes, roxygen, Rd, NEWS, coordination board, and the
  validation register so no current public surface still says all X-row CIs are
  gated.
- Added pure-R tests for the `ci_x_*` capability ledger and mocked fit-time
  fixed-effect-X CI forwarding.
- Added live JuliaCall tests for direct-wrapper X-CI payloads, post-fit
  `confint()` recomputation from retained `X`, and one fit-time Poisson-X stored
  CI payload through `gllvmTMB(..., ci_method = "wald")`.

## Checks

```sh
julia --project=. --startup-file=no test/test_bridge_capabilities.jl
julia --project=. --startup-file=no test/test_bridge_ci.jl
julia --project=. --startup-file=no test/test_bridge_x.jl
```

Results in `../GLLVM.jl-integration`: capability ledger `40/40` pass; bridge CI
routing `64/64` pass; fixed-effect-X suite `169/169` pass.

```sh
air format R/julia-bridge.R tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
```

Results: formatter quiet; roxygen regenerated the three Julia bridge Rd files;
no-Julia bridge test passed with `12` expected skips and `0` failures; live
Julia bridge test passed with `0` failures.

Capability guard:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(identical(caps$family[caps$ci_x_wald], gllvmTMB:::.GLLVM_JULIA_X_CI_FAMILIES)); stopifnot(identical(caps$family[caps$ci_x_profile], gllvmTMB:::.GLLVM_JULIA_X_CI_FAMILIES)); stopifnot(identical(caps$family[caps$ci_x_bootstrap], gllvmTMB:::.GLLVM_JULIA_X_CI_FAMILIES)); stopifnot(!caps$ci_x_wald[caps$family == "nb1"]); stopifnot(!any(caps$ci_x_wald[caps$family %in% gllvmTMB:::.GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES])); stopifnot(!caps$ci_x_wald[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("complete-response fixed-effect-X Wald/profile/bootstrap CI payloads", caps$notes, fixed = TRUE))); print(caps[, c("family", "fixed_effect_X", "ci_no_x_wald", "ci_mask_wald", "ci_x_wald", "status")], row.names = FALSE)'
```

Result: `ci_x_*` true only for Gaussian, Poisson, Binomial, NB2, Beta, and
Gamma.

Stale scan:

```sh
rg -n "X-row CIs remain gated|CIs for X rows|fixed-effect-X rows remain loud gates|fixed-effect-X bridge fits are not routed yet|non-Gaussian-X intervals|ci_x_|complete-response fixed-effect-X|NB1-X CIs|ordinal-X CIs|masks\\+X CIs|response masks combined with fixed-effect X" R tests/testthat NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/after-task man
```

Result: expected current hits for the new `ci_x_*` contract and scoped
NB1-X/ordinal-X/masks+X gates, plus historical check-log and after-task rows
from earlier same-day slices.

## Scope Boundary

IN: complete-response fixed-effect-X Wald/profile/bootstrap CI payloads for
Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and Gamma bridge rows.

PARTIAL: this is endpoint routing and small-fixture native-engine parity, not
coverage calibration, speed evidence, or full native `gllvmTMB` parity.

PLANNED/GATED: NB1-X CIs, ordinal-X CIs, mixed-family-X CIs, response masks
combined with fixed-effect X, mixed-family promotion, structured covariance
terms, and broader simulation/comparator evidence.

## Review Perspectives

- Hopper: R payload contract now forwards and retains `X` for fit-time and
  post-fit CI requests.
- Karpinski: paired runtime exposes the `ci_x_*` endpoint through native
  GLLVM.jl CI engines.
- Rose: capability columns now distinguish no-X, masked no-X, and
  fixed-effect-X CI support.
- Grace: no-Julia tests remain green with expected skips; JuliaCall tests are
  live-only and do not change the default CRAN path.
