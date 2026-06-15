# After Task: Julia Bridge Mask Family Matrix

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Gauss / Fisher / Rose`

## 1. Goal

Turn the first missing-response bridge route from a Poisson-only live claim into
a tested no-X one-part family matrix on the R user surface.

## 2. Implemented

- `ordinal_probit()` now maps to the paired Julia `ordinal_probit` bridge key,
  not to the cumulative-logit `ordinal` key.
- Added direct `gllvm_julia_fit(..., mask = M)` sentinel-invariance tests for
  Binomial, NB2, Beta, Gamma, and Ordinal-probit.
- Added public `gllvmTMB(..., engine = "julia", missing =
  miss_control(response = "include"))` live tests for Bernoulli Binomial, NB2,
  Beta, Gamma, and Ordinal-probit, complementing the existing Poisson row.
- Kept Gaussian masks, X+mask, masked CI/profile/bootstrap, mixed-family masks,
  and `cbind()` binomial outside the admitted surface.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-mask-family-matrix.md`

## 3a. Decisions and Rejected Alternatives

Decision: add a paired `ordinal_probit` bridge key rather than aliasing
`ordinal_probit()` to `ordinal`. Rationale: GLLVM.jl's bare `ordinal` default is
cumulative-logit, while gllvmTMB's public ordinal family is cumulative-probit.
Rejected alternative: keep ordinal masked support direct-wrapper only. Confidence:
high for fit/nobs/mask/link transport; prediction/residual support still needs
cutpoint/probability payloads.

## 4. Checks Run

- `~/.juliaup/bin/julia --project=. test/test_bridge_missing_mask.jl`
  in `GLLVM.jl-integration`: `23/23 pass` in `16.8s`.
- `~/.juliaup/bin/julia --project=. test/test_bridge_ci.jl`
  in `GLLVM.jl-integration`: `66/66 pass` in `46.2s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'`:
  `232/232 pass`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `232/232 pass` in `50.9s`.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `80 pass`, `12 skip`, `0 fail` in `2.0s`.

## 5. Tests of the Tests

The new tests would fail without the Julia `ordinal_probit` bridge key and the
R `ordinal_probit()` mapper. They also compare masked-cell `NA` vs garbage input
for direct wrapper fits, so sentinel values cannot leak into the likelihood or
loadings.

## 6. Consistency Audit

`NEWS.md` now says the masked no-X one-part bridge is live-tested for Poisson,
Bernoulli Binomial, NB2, Beta, Gamma, and Ordinal-probit. It explicitly preserves
the masked CI, Gaussian mask, X+mask, mixed-family, and ordinal post-fit limits.

## 7. Roadmap Tick

Phase 6 missing-response bridge: per-family R-live fit matrix banked for the
currently admitted no-X one-part non-Gaussian surface.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated.

## 8. What Did Not Go Smoothly

The first audit exposed an ordinal naming trap: `ordinal_probit()` is public R
syntax, while GLLVM.jl's `ordinal` key is cumulative-logit by default. The fix
required a paired Julia bridge key, not just an R alias.

## 9. Team Learning

Hopper: every admitted family needs one public R-user row and one direct
sentinel-invariance row. Rose: do not upgrade this to general missing-data or CI
support until masked refits and parity gates exist.

## 10. Known Limitations And Next Actions

Next slices: masked CI-status/refit support, Gaussian response masks, X+mask
contracts, `cbind()`/weighted binomial public masks, and R/TMB-vs-Julia parity
where same-estimand comparison is meaningful.

Rose verdict: PASS WITH NOTES — admitted no-X masked family routes now have live
R evidence, but broad missing-data and masked-inference support remain partial.
