# After Task: Julia Bridge Masked-CI Status Boundary

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Fisher / Rose`

## 1. Goal

Make masked-response interval requests on `gllvmTMB_julia` objects fail with a
deliberate CI-status boundary instead of falling through to an indirect refit
error or a misleading cached interval table.

## 2. Implemented

- Added R-side helpers for the masked-response CI boundary:
  `ci_unavailable_masked_response` on point-fit objects and method-specific
  `*_unavailable_masked_response` statuses for `confint()`.
- Made `confint.gllvmTMB_julia()` reject masked-response objects before cached
  CI fields or refits can return a matrix.
- Preserved the direct `gllvm_julia_fit(..., mask = ..., ci_method != "none")`
  guard.
- Propagated `ci_status` from non-masked Julia CI refits.
- Set the `ordinal_probit` masked sentinel to the same harmless category as the
  ordinal bridge and added an explicit ordinal-probit `residuals()` failure
  assertion.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-masked-ci-status.md`

## 3a. Decisions And Rejected Alternatives

Decision: keep `confint.gllvmTMB_julia()` as a matrix-returning base-R-style
method and error on unsupported masked intervals. Rejected alternative: return a
status data frame from `confint()`, because that would quietly change the method
contract. Confidence: high for the unsupported-boundary behavior; no CI endpoint
math is added here.

## 4. Checks Run

- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `87 pass`, `12 skip`, `0 fail`, `0 warn` in `2.4s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'`:
  `259 pass`, `0 fail`, `0 warn`, `0 skip`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `259 pass`, `0 fail`, `0 warn`, `0 skip` in `53.7s`.

## 5. Tests Of The Tests

The new tests would fail if `confint()` checked cached CI fields before checking
the mask, if direct masked CI refits lost their method-specific status, or if an
ordinal-probit masked fit allowed residuals without a probability/cutpoint
payload.

## 6. Consistency Audit

`NEWS.md` now states that masked point fits carry an unavailable CI status and
that masked `confint()` calls fail with method-specific statuses. It does not
claim masked Wald/profile/bootstrap support.

## 7. Roadmap Tick

Phase 5 bridge contract and Phase 6 missing-response bridge gain a clearer
inference boundary. The actual masked interval engines remain queued.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated.

## 8. What Did Not Go Smoothly

The first implementation was almost enough, but Hopper noted a cached-CI bypass
risk and missing `ci_status` propagation on non-masked refits. Rose also caught
that ordinal residuals needed the same explicit unsupported guard as ordinal
predictions before the claim was dashboard-safe.

## 9. Team Learning

Hopper: keep `confint()` honest as a matrix method; use errors for known
unsupported preconditions. Rose: call this R-side CI-status/error handling, not a
Julia CI payload and not masked interval support.

## 10. Known Limitations And Next Actions

Next slices: actual masked CI refit support, Gaussian response masks, X+mask
contracts, `cbind()`/weighted binomial public masks, and R/TMB-vs-Julia parity
where the estimand is matched.

Rose verdict: PASS WITH NOTES — the unsupported interval boundary is explicit,
but no masked CI endpoint is computed.
