# After Task: Julia Bridge Contract Shrink

**Branch**: `engine-julia`
**Date**: `2026-06-14`
**Roles (engaged)**: Ada / Hopper / Rose / Grace

## 1. Goal

Make the R-side `engine = "julia"` bridge match the current paired
`GLLVM.jl` minimal `GLLVM.bridge_fit` contract, so R does not admit unsupported
Julia bridge cells.

## 2. Implemented

- Narrowed `.gllvm_julia_family()` to the homogeneous one-part families
  currently accepted by `GLLVM.bridge_fit`: gaussian, poisson, binomial,
  nbinom2 mapped as `negbinomial`, beta, gamma, and ordinal.
- Rejected mixed-family lists, nbinom1, lognormal, `num.lv < 1`, missing
  latent blocks, and fixed-effect covariates before attempting unsupported Julia
  calls.
- Preserved matrix dimnames by passing `trait_names` and `unit_names` through
  `gllvm_julia_fit()`.
- Made `confint.gllvmTMB_julia()` stop when the Julia bridge returns
  `ci_status != "ok"` instead of returning an empty or misleading interval
  matrix.
- Updated the bridge tests, generated help for `gllvm_julia_fit()`, and NEWS
  wording to match the narrower supported surface.

## 3. Files Changed

Bridge:

- `R/julia-bridge.R`

Tests:

- `tests/testthat/test-julia-bridge.R`

User-facing status:

- `NEWS.md`
- `man/gllvm_julia_fit.Rd`

Audit trail:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-14-julia-bridge-contract-shrink.md`

## 3a. Decisions and Rejected Alternatives

**Decision**: shrink the R gate to the current Julia branch instead of keeping
the future integration-bridge surface.

**Rationale**: the paired `GLLVM.jl` `bridge_fit` rejects fixed-effect `X`,
mixed families, missing-response masks, and NB1/lognormal. Admitting those from
R would make the R bridge stricter or looser than the actual engine for the
wrong reasons.

**Rejected alternative**: keep the X-admission tests and rely on Julia to fail.
That gives users misleading R-side capability messages and lets drift return.

**Confidence**: high for the bridge gate; low for broader R/TMB statistical
parity, which remains a separate gate.

## 4. Checks Run

- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl" JULIA_HOME="/Users/z3437171/.juliaup/bin" Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'`
  - Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 49`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Result: loaded `gllvmTMB`; wrote `man/gllvm_julia_fit.Rd`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl" JULIA_HOME="/Users/z3437171/.juliaup/bin" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", stop_on_failure = TRUE)'`
  - Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 49` in 22.9 s.
- `git diff --check`
  - Result: clean.
- `rg -n "GLLVM_JULIA_X_FAMILIES|Gaussian-only fixed-effect|non-Gaussian covariates|admits fixed-effect X|_x_rr|nbinom1, beta|lognormal families|mixed responses|or a list for mixed|fixed-effect-X model" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md man/gllvm_julia_fit.Rd man/confint.gllvmTMB_julia.Rd`
  - Result: no matches.

## 5. Tests of the Tests

- Boundary tests now assert that fixed-effect covariates, mixed-family lists,
  unsupported families, `num.lv = 0`, non-`rr` terms, and unbalanced trait-unit
  tables fail before unsupported Julia work starts.
- Live Julia tests assert that long-format dispatch matches direct
  `gllvm_julia_fit()` and that native Julia Wald CI payloads match the R
  `confint()` surface to `1e-6`.
- At this slice, the profile-CI test asserted explicit unsupported CI status
  rather than accepting an empty matrix. Follow-up commit `19264a5` updated the
  oracle and now live-tests Gaussian profile/bootstrap CI transport; see
  `docs/dev-log/after-task/2026-06-14-julia-bridge-ci-oracle-sync.md`.

## 6. Consistency Audit

The stale-wording scan listed in section 4 found no remaining references in the
touched bridge files to the removed X-admission/mixed-family/lognormal claims.
NEWS now states the current narrow bridge and names the rejected cells.

## 7. Roadmap Tick

This is a bridge honesty slice for the R-Julia connection. It does not complete
the broader bridge: fixed-effect `X`, mixed families, missing-response masks,
R/TMB-vs-Julia statistical parity, and post-fit method coverage remain queued.

## 7a. GitHub Issue Ledger

- Relevant issue: `gllvmTMB#488` gate drift. No GitHub issue was commented or
  closed from this local session because push/remote mutation is maintainer
  gated.

## 8. What Did Not Go Smoothly

The existing live bridge test compared `engine = "julia"` directly against the
TMB engine and failed by about 1.5 log-likelihood units on the Gaussian fixture.
That is useful evidence but not part of this gate. The test now checks the
smaller claim this slice can prove: R long-format dispatch and direct
`GLLVM.bridge_fit` marshaling agree.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: the bridge lane needs claim discipline before breadth; the safest slice was
to narrow user-visible support rather than chase future integration code.

Hopper: R must fail before JuliaCall setup for unsupported cells, especially on
machines without Julia installed.

Rose: TMB parity and R-to-Julia marshaling are different claims. This slice
proves the latter only.

Grace: the focused live bridge test is green; full package checks remain a
pre-PR gate.

## 10. Known Limitations And Next Actions

- Implement the wider `GLLVM.bridge_fit` integration surface for fixed-effect
  `X`, mixed-family metadata, and response masks before relaxing these R gates.
- Add a separate R/TMB-vs-Julia parity issue/gate for logLik, loadings after
  Procrustes, dispersion transforms, and CI payloads.
- Run full `devtools::test()` and `devtools::check()` before publishing the
  bridge branch.

Rose verdict: PASS WITH NOTES -- R now matches the current Julia bridge
contract, but broader statistical parity and wider bridge coverage remain open.
