# After Task: Julia Bridge NB1 Missing-Response Mask

**Branch**: `engine-julia`  
**Date**: `2026-06-15`  
**Roles (engaged)**: `Ada / Hopper / Gauss / Fisher / Rose`

## 1. Goal

Admit NB1 missing-response masks through the R `engine = "julia"` surface only
after the paired Julia bridge could prove mask parity and sentinel invariance.

## 2. Implemented

- Added `nb1` to the R-side mask-admitted bridge family ledger.
- Added live `gllvmTMB(..., family = nbinom1(), engine = "julia", missing =
  miss_control(response = "include"))` coverage to the existing admitted
  missing-response family loop.
- Added NB1 to the direct-wrapper sentinel-invariance test so `NA` and garbage
  values in masked cells yield the same fit.
- Updated `NEWS.md` and the coordination board so NB1 masks are no longer
  described as unsupported.
- Reworded the Gaussian-only `check_identifiability()` non-Gaussian message so
  it describes that diagnostic boundary without implying package-level
  non-Gaussian/mixed-family support is absent.

## 3. Files Changed

- `R/julia-bridge.R`
- `R/check-identifiability.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-nb1-mask.md`

## 4. Statistical Contract

For NB1 bridge fits with an observed-cell mask `M`, only cells with `M = TRUE`
enter the reduced-rank point-fit likelihood. The R bridge may sanitize masked
responses before JuliaCall, but the paired Julia fit must produce identical
log-likelihoods, parameters, loadings, and scores when masked cells contain
missing values or arbitrary sentinels.

This is point-fit and in-sample post-fit support. Masked CI/profile/bootstrap
refits and masked simulations remain unsupported.

## 5. Checks Run

- `~/.juliaup/bin/julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  in `GLLVM.jl-integration`: `20/20 pass`.
- `~/.juliaup/bin/julia --project=. --startup-file=no test/test_bridge_missing_mask.jl`
  in `GLLVM.jl-integration`: `34/34 pass`.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `FAIL 0 | WARN 0 | SKIP 18 | PASS 227` in `2.9s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 571` in `70.7s`.
- `Rscript -e 'devtools::test()'`:
  `FAIL 0 | WARN 3 | SKIP 724 | PASS 2997`. The warnings are pre-existing
  environment/deprecation diagnostics, including the local `glmmTMB`/`TMB`
  version mismatch.
- `Rscript -e 'devtools::test(filter="check-identifiability")'`:
  `FAIL 0 | WARN 0 | SKIP 13 | PASS 0`.
- `git diff --check`: clean.

## 6. Tests Of The Tests

The new coverage would have failed before this slice because the R capability
ledger expected `nb1$missing_response = FALSE`, the public missing-response
family loop did not include `nbinom1()`, and the direct-wrapper sentinel test did
not exercise NB1.

## 7. Consistency Audit

Stale-wording scan:

```sh
rg -n "No engine = \"julia\" mixed-family admission|do not admit family lists|mixed-family.*planned|mixed-family.*queued|NB1 covariate\s*or missing-response|Non-Gaussian / mixed-family support is queued|nbinom2, beta, gamma, and ordinal-probit|17b2154|6056071|f1894bc" README.md NEWS.md R tests docs/dev-log/coordination-board.md -S
```

Result: no matches.

## 8. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting remains maintainer-gated.

## 9. What Did Not Go Smoothly

The first no-Julia bridge test failed because the expected NB1 capability row was
still set to `missing_response = FALSE`. That was the intended stale-ledger
guard doing its job, and the assertion was updated before the live JuliaCall
gate was rerun.

## 10. Known Limitations And Next Actions

- NB1 fixed-effect-X bridge fits remain rejected.
- Masked CI/profile/bootstrap refits remain rejected with method-specific
  CI-status messages.
- Masked simulations remain rejected.
- Gaussian response masks and mixed-family masks remain separate slices.
- Next R-first slice: harden unsupported-cell CI-status contracts for
  non-Gaussian-X and mixed-family bridge requests.

## 11. Rose Verdict

Rose verdict: PASS WITH NOTES — NB1 missing-response point fits and in-sample
post-fit rows are covered, but masked CIs/simulations and NB1-X remain deliberate
unsupported cells.
