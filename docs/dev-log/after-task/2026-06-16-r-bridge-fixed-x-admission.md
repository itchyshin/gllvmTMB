# After Task: R Bridge Fixed-Effect X Admission

## Goal

Admit the next `engine = "julia"` bridge row for complete-response
fixed-effect covariates without claiming masks+X, CI, NB1-X, ordinal-X,
mixed-family-X, prediction, residual, simulation, or extractor parity.

## Implemented

The R main dispatch now routes complete-response fixed-effect-X point fits for:

- Gaussian;
- Poisson;
- Bernoulli binomial;
- NB2 / `nbinom2()`;
- Beta;
- Gamma.

For non-Gaussian rows the bridge requires the canonical `0 + trait + ...`
fixed-effect design. It sends only the extra fixed-effect columns to
`GLLVM.bridge_fit(X = ...)`, because the paired Julia `fit_gllvm_cov` contract
already estimates per-trait intercepts (`beta_cov`) internally.

The R bridge keeps loud gates for NB1-X, ordinal-X, mixed-family-X, masks+X,
X-row CIs, and non-canonical fixed-effect designs.

## Evidence

- Pure-R tests update `gllvm_julia_capabilities()` so `fixed_effect_X` is true
  only for the admitted R rows.
- Pure-R guard tests verify NB1-X, ordinal-X, and non-canonical
  non-Gaussian-X formulas fail before Julia setup.
- Live R bridge tests compare `gllvmTMB(..., engine = "julia")` with direct
  `gllvm_julia_fit(..., X = ...)` for Poisson, Bernoulli binomial, NB2, Beta,
  and Gamma.
- Direct Julia runtime test `test_bridge_x.jl` verifies `GLLVM.bridge_fit(X=...)`
  against the Julia `fit_gllvm_cov` oracle for the same one-part non-Gaussian
  family set.

## Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> `[]`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" -- NEWS.md NAMESPACE R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task man/gllvmTMB_julia-methods.Rd man/gllvm_julia_fit.Rd`
  -> current local Codex programme commits only.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with nine expected Julia-runtime skips.
- Live R bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- Julia X-contract anchor:
  `julia --project=. test/test_bridge_x.jl` in `../GLLVM.jl-integration`
  -> `52/52 pass`.
- Julia capability ledger anchor:
  `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- Roxygen/Rd:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/gllvm_julia_fit.Rd`.
- Capability ledger guard:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); print(caps[, c("family", "fixed_effect_X", "missing_response", "postfit_coef", "postfit_summary", "postfit_predict", "ci_no_x_wald", "status", "notes")], row.names = FALSE); stopifnot(identical(caps$family[caps$fixed_effect_X], gllvmTMB:::.GLLVM_JULIA_X_FAMILIES)); stopifnot(!caps$fixed_effect_X[caps$family == "nb1"]); stopifnot(!caps$fixed_effect_X[caps$family == "ordinal"]); stopifnot(!caps$fixed_effect_X[caps$family == "ordinal_probit"]); stopifnot(!caps$fixed_effect_X[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("fixed-effect X point fits are routed", caps$notes, fixed = TRUE)))'`
  -> only the named complete-response rows have `fixed_effect_X = TRUE`.
- Stale wording scan:
  `rg -n "Gaussian-only fixed-effect|Gaussian fixed-effect covariates only|non-Gaussian X through the main dispatch|non-Gaussian fixed-effect covariates|fixed-effect covariates for the gaussian family|fixed_effect_X\\], \\"gaussian\\"|fixed-effect X point fits|NB1-X|ordinal-X|masks\\+X|mixed-family-X" R NEWS.md tests/testthat docs/design docs/dev-log man/gllvm_julia_fit.Rd`
  -> older notes were tightened; remaining hits are current scoped claims.
- Whitespace:
  `git diff --check` -> clean.

## Scope Boundary

`JUL-01` remains `partial`. This slice admits complete-response fixed-effect-X
point fits only for the named rows. It does not implement or claim NB1-X,
ordinal-X, mixed-family-X, masks+X, X-row CIs, non-canonical fixed-effect
designs, prediction, residuals, simulation, extractor parity, broad
native-vs-Julia parity, structured dependence, simulation recovery, or speed
claims.

## Team Learning

- Hopper: R main dispatch should mirror the paired Julia `fit_gllvm_cov`
  parameterization, not pass duplicate trait intercept dummy columns.
- Boole: the first R admission should require `0 + trait + ...` so syntax and
  parameter mapping stay unambiguous.
- Rose: capability wording must separate fixed-effect-X point fits from masks+X,
  X-row CIs, and species-specific structural-zero coefficient work.
