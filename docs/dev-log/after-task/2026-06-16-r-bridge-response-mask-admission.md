# After Task: R Bridge Response-Mask Admission

## Goal

Expose the paired Julia engine's existing missing-response mask contract through
the R `engine = "julia"` bridge without weakening the claim boundary around
Gaussian masks, fixed-effect covariates, mixed families, or masked intervals.

## Implemented

In `gllvmTMB`, `gllvm_julia_fit()` now accepts `mask`, validates it against the
oriented response matrix, and passes it to `GLLVM.bridge_fit`.

The main `gllvmTMB(..., engine = "julia")` dispatch now builds an observed-cell
mask when the long data are missing one or more `(trait, unit)` cells. It fills
masked response cells with family-safe placeholders before calling Julia, then
stores `missing_response` and `response_mask` on the returned
`gllvmTMB_julia` object.

The R-side capability ledger marks response masks as routed for one-part no-X
point fits in Poisson, Bernoulli binomial, NB2, NB1, Beta, Gamma, ordinal, and
ordinal-probit rows. It keeps Gaussian masks, mixed-family masks, X+mask, and
masked CIs as explicit gates.

## Evidence

- Direct R wrapper coverage:
  `gllvm_julia_fit(..., mask = mask)` is exercised for every mask-capable bridge
  family in `tests/testthat/test-julia-bridge.R`.
- Main-dispatch coverage:
  `gllvmTMB(..., engine = "julia")` is exercised with dropped `(trait, unit)`
  cells for Poisson, NB1, Gamma, and ordinal-probit fixtures.
- Engine-side anchor:
  `../GLLVM.jl-integration/test/test_bridge_missing_mask.jl` still passes and
  checks direct Julia mask parity / sentinel invariance.

## Checks Run

- Pre-edit coordination:
  `gh pr list --state open --json number,title,headRefName,baseRefName,updatedAt,url`
  -> `[]`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" -- AGENTS.md CLAUDE.md ROADMAP.md CONTRIBUTING.md docs/dev-log/decisions.md docs/dev-log/check-log.md docs/design docs/dev-log/after-task inst/COPYRIGHTS DESCRIPTION`
  -> current local Codex programme commits only.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with eight expected Julia-runtime skips.
- Live R bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- Julia engine mask test:
  `julia --project=. test/test_bridge_missing_mask.jl` in
  `../GLLVM.jl-integration` -> `37/37 pass`.
- Documentation:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/gllvm_julia_fit.Rd`.
- Capability ledger guard:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); print(caps[, c("family", "missing_response", "ci_no_x_wald", "postfit_predict", "status", "notes")], row.names = FALSE); stopifnot(identical(caps$family[caps$missing_response], gllvmTMB:::.GLLVM_JULIA_MASK_FAMILIES)); stopifnot(!caps$missing_response[caps$family == "gaussian"]); stopifnot(!caps$missing_response[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY])'`
  -> mask-capable rows are Poisson, binomial, NB2, NB1, Beta, Gamma,
  ordinal, and ordinal-probit.
- Rose pre-publish checks:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); print(names(formals(gllvm_julia_fit))); stopifnot("mask" %in% names(formals(gllvm_julia_fit))); stopifnot(any(grepl("mask", capture.output(tools::Rd2txt(tools::parse_Rd("man/gllvm_julia_fit.Rd"))))))'`
  -> `gllvm_julia_fit()` source formals and `man/gllvm_julia_fit.Rd` agree.
  `rg -n "gllvm_julia_fit" _pkgdown.yml R NAMESPACE man/gllvm_julia_fit.Rd | head -80`
  -> export remains in `NAMESPACE` and `_pkgdown.yml`.
- Stale-claim scan:
  `rg -n 'requires a complete \(balanced\)|requires a balanced trait|CI, masks|masks, X|response masks,|broader structures, masks|no-X/no-mask|no-mask/no-CI|masks remain gated|mask.*follow-up|response masks.*planned|response masks.*gated' R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-06-16-r-bridge-response-mask-admission.md README.md NEWS.md vignettes man/gllvm_julia_fit.Rd pkgdown-site/index.html`
  -> expected guardrails only after the NEWS wording was narrowed.
- Whitespace:
  `git diff --check` -> clean in `gllvmTMB` and
  `../GLLVM.jl-integration`.

## Scope Boundary

`JUL-01` remains `partial`. This slice routes observed-cell response masks for
one-part no-X point fits. It does not provide masked confidence intervals,
masked post-fit extractor parity, masked mixed-family fits, masks with
fixed-effect covariates, Gaussian response masks, structured dependence, broad
native-vs-Julia parity, simulation recovery, or speed claims.

## Team Learning

- Hopper: bridge admission should unlock existing engine rows only when the R
  payload can label the stop conditions precisely.
- Karpinski: the engine mask contract remains the source of truth for family
  admission and sentinel invariance.
- Rose/Shannon: the capability table, validation row, tests, and coordination
  board must all change together when a previously gated row becomes routed.
