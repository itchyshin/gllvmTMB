# After Task: Julia Bridge Response Mask

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Gauss / Fisher / Rose`

## 1. Goal

Admit the first R-side missing-response route for `engine = "julia"` without
overclaiming: keep the `gllvmTMB` user surface first, pass an explicit
observed-cell mask to the paired GLLVM.jl bridge, and preserve honest residual
and CI-status behavior.

## 2. Implemented

- Added `mask` to `gllvm_julia_fit()` (`TRUE = observed`).
- Wired `gllvmTMB(..., engine = "julia", missing =
  miss_control(response = "include"))` to keep the balanced trait-by-unit grid,
  sanitize only masked response cells, and pass the mask through JuliaCall.
- Kept Gaussian masks, `X` plus masks, masked CI refits, mixed-family masks, and
  unbalanced tables as explicit errors.
- Updated `residuals.gllvmTMB_julia()` so masked rows report `observed = NA`,
  `residual = NA`, `status = "masked"`, and a finite fitted value.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_fit.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-response-mask.md`

## 3a. Decisions and Rejected Alternatives

Decision: support no-X non-Gaussian masks first. Rationale: the paired Julia
family fitters already have exact mask semantics; Gaussian/X/masked-CI routes
need separate contracts. Rejected alternative: silently drop missing cells or
reuse `engine = "tmb"` behavior without a Julia mask payload. Confidence: high
for the Poisson live route, medium for the broader admitted family list until
each gets its own R parity row.

## 4. Checks Run

- `~/.juliaup/bin/julia --project=. test/test_bridge_missing_mask.jl`
  in `GLLVM.jl-integration`: `17/17 pass`.
- `~/.juliaup/bin/julia --project=. test/test_bridge_x.jl`
  in `GLLVM.jl-integration`: `52/52 pass`.
- `~/.juliaup/bin/julia --project=. test/test_bridge_ci.jl`
  in `GLLVM.jl-integration`: `66/66 pass`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'`:
  `150/150 pass`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `150/150 pass` in `48.5s`.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `79 pass`, `10 skip`, `0 fail` in `3.9s`.
- `Rscript -e 'devtools::document()'`: regenerated `man/gllvm_julia_fit.Rd`;
  pre-existing roxygen link warnings only.

## 5. Tests of the Tests

New tests cover direct wrapper guards, synthetic masked residual status, live
Poisson `missing = miss_control(response = "include")`, and direct wrapper
sentinel invariance (`NA` masked cells vs garbage masked cells).

## 6. Consistency Audit

`NEWS.md` now says response masks are initial/no-X/non-Gaussian and Poisson is
the live-tested route. It no longer claims all missing-response masks are
unsupported, but keeps Gaussian, X+mask, and masked-CI limits visible.

## 7. Roadmap Tick

Phase 6 missing-response bridge: first R-side slice banked.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated.

## 8. What Did Not Go Smoothly

`devtools::document()` touched unrelated generated `.Rd` files; those churn
diffs were removed, leaving only `man/gllvm_julia_fit.Rd`.

## 9. Team Learning

Hopper: R should own the user contract and pass flat masks to Julia. Gauss:
sentinel values must be ignored in both likelihood and score reconstruction.
Fisher: masked CIs stay unavailable until the refit/profile/bootstrap path
passes the same mask. Rose: the claim boundary must say Poisson live-tested, not
all families parity-proven.

## 10. Known Limitations And Next Actions

Next slices: add per-family R bridge parity rows for Binomial/NB2/Beta/Gamma/
Ordinal masks; implement masked CI-status payloads or refit support; then
consider Gaussian and X+mask routes separately.
