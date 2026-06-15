# After Task: Julia Bridge Cbind Binomial Trial Transport

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Fisher / Rose`

## 1. Goal

Close the R-surface gap where `gllvmTMB(..., engine = "julia")` rejected
binomial `cbind(successes, failures)` responses even though the paired Julia
bridge already accepts a binomial trial matrix `N`.

## 2. Implemented

- Parsed two-column `cbind(successes, failures)` model responses only for
  `family = binomial()`.
- Transported successes as the Julia response matrix `Y` and
  successes + failures as the binomial trial matrix `N`.
- Added observed-cell validation for finite, non-negative cbind components and
  positive observed trial counts.
- Preserved missing-response include semantics: if either cbind component is
  missing, the whole response row is masked; masked cells use harmless transport
  sentinels (`Y = 0`, `N = 1`) and the observed-cell mask carries the likelihood
  boundary.
- Kept non-binomial `cbind()` responses as a pre-JuliaCall error.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-cbind-binomial.md`

## 3a. Decisions And Rejected Alternatives

Decision: implement this as R-side marshalling to the existing Julia `N` matrix
contract. Rejected alternative: encode cbind binomial as a new bridge family or
special Julia object, because no new likelihood is needed. Confidence: high for
the transport claim; R/TMB statistical parity remains a separate validation
gate.

## 4. Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `91 pass`, `14 skip`, `0 fail`, `0 warn` in `2.1s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'`:
  `277 pass`, `0 fail`, `0 warn`, `0 skip`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `277 pass`, `0 fail`, `0 warn`, `0 skip` in `56.3s`.

## 5. Tests Of The Tests

The new tests would fail if cbind responses were still rejected, if `N` were not
pivoted into the trait x unit trial matrix, if missing cbind components were not
masked, if malformed negative/non-finite/zero-trial rows passed validation, or
if a non-binomial cbind response reached JuliaCall.

## 6. Consistency Audit

`NEWS.md` now removes `cbind()` binomial from the unsupported list and replaces
it with a narrower boundary: binomial cbind transport is supported for the
validated no-X reduced-rank bridge rows, while non-binomial cbind responses and
masked CI endpoints remain unsupported.

## 7. Roadmap Tick

This is an R-first bridge-surface repair. It advances the R user workflow and
uses the paired `GLLVM.jl` checkout as a validator, rather than adding Julia
engine breadth.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This slice
belongs under the Julia bridge gate-drift and missing-response transport
roadmap rows.

## 8. What Did Not Go Smoothly

The first live assertion compared `fit$N` to an unnamed matrix, while the bridge
correctly preserved dimnames. The expectation was tightened with `unname()` so
the test checks trial values without rejecting useful labels.

## 9. Team Learning

Ada: R-first sequencing is the right default now; close visible user-surface gaps
before widening Julia-only engine breadth.

Hopper: `cbind(successes, failures)` is just binomial `Y` plus `N` transport
when the estimand is otherwise unchanged.

Fisher: interval claims do not move here; masked CI endpoints are still
unavailable and should keep explicit CI-status failures.

Rose: PASS WITH NOTES — support is covered for R-side cbind transport and direct
Julia-bridge equivalence only. Do not claim R/TMB statistical parity, mixed
family cbind, covariate-masked cbind, or masked interval support from this
slice.

## 10. Known Limitations And Next Actions

Next R-first slices: freeze the bridge/capability status ledger, continue
missing-response bridge coverage where the R surface already admits it, and then
work through post-fit methods and CI-status rows before adding new Julia engine
families.
