# After-task report -- Julia bridge ordinal drift closure

## Goal

Close the final current R-vs-local-GLLVM.jl capability drift rows for the
narrowed seven-family bridge ledger.

## Summary

The R bridge now admits the same current Ordinal Wald-CI and postfit residual
capability booleans that local `GLLVM.bridge_capabilities()` advertises. It
routes no-X Wald CI payloads for `family = "ordinal"` and reconstructs
response/Pearson ordinal-score residuals from retained category probabilities.
The live capability drift probe now reports zero rows.

## Files changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-ordinal-drift-closure.md`
- `man/gllvmTMB_julia-methods.Rd`

## Implementation details

- Split no-X CI capability into Wald and profile vectors so Ordinal can be
  Wald-admitted while Ordinal profile/bootstrap stays gated.
- Kept `ordinal_probit()` bridge admission gated through `GJL-GATE-ORDINAL-CI`.
- Removed obsolete `GJL-GATE-ORDINAL-RESIDUAL` from the current gate registry.
- Added ordinal residual reconstruction using probability-weighted expected
  category scores and the corresponding ordinal-score variance.
- Emptied `.gllvm_julia_expected_capability_drifts()`; unregistered future
  drift remains a test failure.
- Refreshed the JUL-01 validation-debt row so current bridge debt no longer
  lists Ordinal Wald CI or ordinal-score residuals as unavailable.

## Tests added or updated

- Pure bridge capability tests now assert Ordinal Wald CI and Ordinal residual
  admission, Ordinal profile and simulation gates, and zero expected drift.
- Mocked ordinal postfit tests now check response/Pearson ordinal-score
  residual matrices.
- Live bridge tests now assert zero drift and route a live Ordinal no-X Wald CI
  payload through GLLVM.jl.

## Checks run

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: completed and regenerated `man/gllvmTMB_julia-methods.Rd`; roxygen
reported pre-existing unresolved-link warnings in unrelated topics.

```sh
Rscript --vanilla -e 'source("R/julia-bridge.R"); gates <- gllvm_julia_gate_registry(); caps <- gllvm_julia_capabilities(); print(gates[, c("gate_id", "validation_row")], row.names=FALSE); print(caps[, c("family", "ci_no_x_wald", "ci_no_x_profile", "postfit_residuals", "postfit_simulate")], row.names=FALSE); drift <- .gllvm_julia_capability_drift(julia_caps = caps); cat("drift_rows=", nrow(drift), "\n")'
```

Outcome: local R ledger has 20 gates; Ordinal has `ci_no_x_wald = TRUE`,
`ci_no_x_profile = FALSE`, `postfit_residuals = TRUE`,
`postfit_simulate = FALSE`; local R-vs-R drift is 0 rows.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 359 assertions, 0 failures, and 13 expected
live-GLLVM-path skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 798 assertions, 0 failures, and 0 skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME="$HOME/.juliaup/bin" Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); gllvm_julia_setup(); engine_caps <- JuliaCall::julia_eval("GLLVM.bridge_capabilities()"); drift <- gllvmTMB:::.gllvm_julia_capability_drift(julia_caps = engine_caps); print(drift[, c("family", "capability", "direction", "status", "gate_id")], row.names = FALSE); cat("n=", nrow(drift), "unregistered=", sum(drift$status == "unregistered"), "\n")'
```

Outcome: 0 drift rows, `n = 0`, `unregistered = 0`.

## Not run

- Full `devtools::check()`.
- Totoro/DRAC compute.
- Julia source-Psi parity.
- Source-specific `lv = ~ env` exposure.

## Claim boundary

This closes current capability drift for the narrowed R/Julia bridge ledger.
It is not v1.0 completion, coverage calibration, broad ordinal CI parity,
source-specific LV support, mixed-family CI support, non-Gaussian fixed-effect
`X` parity, mask parity, `unique=` parity, or active compute.

## Remaining gates

- Ordinal profile/bootstrap CIs.
- `ordinal_probit()` bridge admission.
- Ordinal simulation.
- Newdata prediction/simulation and unconditional redraws.
- Masks, mixed-family rows/CIs, non-Gaussian fixed-effect `X`.
- Source-specific `lv` and Julia parity for source-specific `unique=`.

## Rose verdict

PASS WITH NOTES - the narrowed bridge capability drift is closed, but this is
still not a full R/Julia v1.0 parity claim.
