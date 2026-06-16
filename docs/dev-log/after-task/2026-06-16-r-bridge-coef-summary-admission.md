# After Task: R Bridge Coef/Summary Admission

## Goal

Admit the first R-side post-fit methods for `gllvmTMB_julia` objects without
claiming prediction, residual, simulation, extractor, or confidence-interval
parity.

## Implemented

The R bridge now registers:

- `coef.gllvmTMB_julia()`, returning a named list of available point-estimate
  payloads (`alpha`, `loadings`, grouped/public dispersion, cutpoints, and any
  covariate coefficient fields present in the Julia payload).
- `summary.gllvmTMB_julia()` and `print.summary.gllvmTMB_julia()`, returning and
  printing fit dimensions, fit statistics, convergence, missing-response status,
  coefficient payloads, covariance/correlation, and the partial-status note.
  Missing optional fit-statistic fields degrade to `NA` rather than breaking
  diagnostic summaries.

The normaliser now adds trait names to `alpha` and `communality` when the flat
Julia payload has one value per trait.

`gllvm_julia_capabilities()` now marks `postfit_coef` and `postfit_summary`
`TRUE` for admitted rows, while leaving `postfit_predict`,
`postfit_residuals`, `postfit_simulate`, and `postfit_ordination` as `FALSE`.

## Evidence

- Pure-R tests check `coef()` and `summary()` on fake grouped-dispersion and
  ordinal bridge payloads.
- Live bridge tests call `coef()` and `summary()` on real grouped-dispersion
  main-dispatch fits and on a real ordinal-probit direct bridge fit.
- `NAMESPACE` now registers `S3method(coef,gllvmTMB_julia)`,
  `S3method(summary,gllvmTMB_julia)`, and
  `S3method(print,summary.gllvmTMB_julia)`.
- `man/gllvmTMB_julia-methods.Rd` documents the point-estimate-only boundary.

## Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> `[]`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" -- AGENTS.md CLAUDE.md ROADMAP.md CONTRIBUTING.md NEWS.md NAMESPACE docs/dev-log/decisions.md docs/dev-log/check-log.md docs/design docs/dev-log/after-task inst/COPYRIGHTS DESCRIPTION R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvm_julia_fit.Rd`
  -> current local Codex programme commits only.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with eight expected Julia-runtime skips.
- Live R bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- Julia capability ledger anchor:
  `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- Roxygen/Rd:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`.
- Capability ledger guard:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); print(caps[, c("family", "postfit_coef", "postfit_summary", "postfit_predict", "postfit_residuals", "postfit_simulate", "status", "notes")], row.names = FALSE); stopifnot(all(caps$postfit_coef)); stopifnot(all(caps$postfit_summary)); stopifnot(all(!caps$postfit_predict)); stopifnot(all(!caps$postfit_residuals)); stopifnot(all(!caps$postfit_simulate)); stopifnot(any(grepl("coef() and summary() are routed", caps$notes, fixed = TRUE)))'`
  -> `coef()` and `summary()` are the only newly promoted post-fit rows.
- Whitespace:
  `git diff --check` -> clean.
- Generated-method check:
  `rg -n 'S3method\\((coef|summary),gllvmTMB_julia\\)|S3method\\(print,summary.gllvmTMB_julia\\)|gllvmTMB_julia-methods' NAMESPACE man/gllvmTMB_julia-methods.Rd R/julia-bridge.R`
  -> S3 methods are registered and documented.
- Stale wording scan:
  `rg -n "postfit_coef = FALSE|postfit_summary = FALSE|rich post-fit methods|broader structures, post-fit methods|post-fit methods.*planned|prediction, residuals, simulation, extractor parity|coef\\(\\) and summary\\(\\) are routed" R NEWS.md tests/testthat docs/design docs/dev-log NAMESPACE man`
  -> older after-task notes now distinguish the later point-estimate
  `coef()` / `summary()` admission from still-gated prediction, residual,
  simulation, extractor, and CI rows.

## Scope Boundary

`JUL-01` remains `partial`. This slice admits point-estimate `coef()` and
`summary()` methods only. It does not implement or claim `predict()`, `fitted()`,
`residuals()`, `simulate()`, `tidy()`, `augment()`, covariance extractor parity,
confidence intervals, broad native-vs-Julia parity, mixed-family promotion,
structured dependence, simulation recovery, or speed claims.

## Team Learning

- Hopper: post-fit admission should start with the flat payload that the bridge
  already labels, not with native-object emulation.
- Emmy: a small S3 surface is enough for inspection while the full R extractor
  architecture remains gated.
- Rose: the capability ledger must distinguish point summaries from prediction,
  residual, simulation, extractor, and CI parity.
