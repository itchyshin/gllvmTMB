# After-task report: R bridge scalar conditional simulate admission

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

## Scope

Admitted `simulate.gllvmTMB_julia()` for scalar-response Julia bridge rows:
Gaussian, Poisson, Bernoulli binomial, NB2, NB1, Beta, and Gamma. The method is
conditional and in-sample only: it draws around retained fitted values and
retained nuisance parameters, returns an `n_obs x nsim` matrix in the same
trait-major cell order used by `predict()`, and sets masked response cells to
`NA`.

Still gated: `newdata` simulation, unconditional random-effect redraws, ordinal
simulation, mixed-family simulation, extractor parity, grouped-dispersion CIs,
per-trait ordinal CIs, X-row CIs, masked CIs, and broad native parity promotion.

## Files touched

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-simulate-admission.md`

## Definition-of-done review

1. Implementation: added `.GLLVM_JULIA_SIMULATE_FAMILIES`, updated
   `gllvm_julia_capabilities()`, registered `simulate.gllvmTMB_julia()`, and
   added scalar family draw plumbing.
2. Simulation recovery test: not a new likelihood/family/estimator. Covered by
   bridge method contract tests and live JuliaCall route tests; no new DGP
   recovery claim is made.
3. Documentation: roxygen and generated Rd updated for `simulate()`, `nsim`,
   `seed`, `newdata`, and `condition_on_RE`.
4. Runnable example: not added in this slice because the bridge remains a draft
   / next-release route and no public article was touched.
5. Check-log entry: added `2026-06-16 -- R bridge scalar conditional simulate
   admission` with exact commands and skipped checks.
6. Review pass: Ada kept the lane narrow; Rose boundary is enforced through
   `JUL-01` wording and capability flags; Shannon pre-edit census found no open
   `gllvmTMB` PR collision.

## Checks

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,updatedAt`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- R/julia-bridge.R tests/testthat/test-julia-bridge.R NAMESPACE man/gllvmTMB_julia-methods.Rd NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task`
  -> current local Codex programme commits only.
- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures with `11` expected Julia-runtime skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); expected <- c("gaussian", "poisson", "binomial", "negbinomial", "nb1", "beta", "gamma"); stopifnot(identical(gllvmTMB:::.GLLVM_JULIA_SIMULATE_FAMILIES, expected)); stopifnot(identical(caps$family[caps$postfit_simulate], expected)); stopifnot(!caps$postfit_simulate[caps$family == "ordinal"]); stopifnot(!caps$postfit_simulate[caps$family == "ordinal_probit"]); stopifnot(!caps$postfit_simulate[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("conditional simulate()", caps$notes, fixed = TRUE))); print(caps[, c("family", "postfit_predict", "postfit_residuals", "postfit_simulate", "status")], row.names = FALSE)'`
  -> scalar rows true, ordinal and mixed rows false.
- `tail -5 man/gllvmTMB_julia-methods.Rd; grep -c '^\\keyword' man/gllvmTMB_julia-methods.Rd || true`
  -> expected methods-description tail; keyword count `0`.
- `rg -n 'S3method\\(simulate,gllvmTMB_julia\\)|simulate\\.gllvmTMB_julia|postfit_simulate|conditional simulate|unconditional random-effect|newdata simulation|ordinal simulation|mixed-family simulation|simulation remains gated|simulate/extractor parity remain gated|residuals/simulate/extractor parity remain gated' NAMESPACE R/julia-bridge.R man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md`
  -> expected S3/method/test/docs hits and intentional gate notes only.
- `git diff --check`
  -> clean.

## Skipped

Full `devtools::test()`, `devtools::check()`, `pkgdown::check_pkgdown()`, CRAN
checks, and article renders were not run for this slice. No formula grammar,
compiled TMB code, public articles, or pkgdown navigation were changed.
