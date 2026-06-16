# After Task: R Bridge Ordinal Prediction Admission

## Goal

Admit response-scale category probabilities and modal-class prediction for
per-trait ordinal and ordinal-probit Julia bridge rows without claiming ordinal
residuals, ordinal CIs, ordinal-X, or `newdata` prediction.

## Implemented

- Added `.GLLVM_JULIA_PREDICT_FAMILIES` so `gllvm_julia_capabilities()`
  can mark ordinal and ordinal-probit prediction admitted while keeping
  `.GLLVM_JULIA_RESIDUAL_FAMILIES` scalar-only.
- Added ordinal probability helpers in `R/julia-bridge.R` that convert
  retained link-scale predictors and per-trait cutpoints into category
  probabilities under `LogitLink` or `ProbitLink`.
- Extended `predict.gllvmTMB_julia()`:
  - `type = "response"` / `"prob"` returns long category probabilities with
    `trait`, `unit`, `category`, and `prob`;
  - `type = "class"` returns modal categories with `trait`, `unit`, and `est`;
  - scalar-response rows keep the existing `trait`, `unit`, `est` contract.
- Extended `fitted.gllvmTMB_julia()` so ordinal `type = "response"` / `"prob"`
  returns a `trait x unit x category` probability array and `type = "class"`
  returns a `trait x unit` modal-category matrix.
- Updated `NEWS.md`, `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/coordination-board.md`, and generated
  `man/gllvmTMB_julia-methods.Rd`.

## Mathematical Contract

For each ordinal trait `t`, unit `i`, category `c`, fitted latent predictor
`eta[t, i]`, ordered cutpoints `tau[t, 1:(C_t - 1)]`, and cumulative-link CDF
`F`:

`Pr(Y[t, i] = c) = F(tau[t, c] - eta[t, i]) - F(tau[t, c - 1] - eta[t, i])`,
with `F(tau[t, 0] - eta) = 0` and `F(tau[t, C_t] - eta) = 1`.

The bridge uses `LogitLink` for `ordinal` and `ProbitLink` for
`ordinal_probit`. Probabilities are normalised per `(trait, unit)` to remove
small floating-point drift. The modal class is the first maximum-probability
category. This is prediction only; no ordinal residual definition is admitted.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-ordinal-prediction-admission.md`

## Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url --limit 20`
  -> `[]`.
- Pre-edit hot-file overlap:
  `git log --all --oneline --since="6 hours ago" -- R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task`
  -> current local Codex programme commits only.
- Paired Julia PR census:
  `gh pr list --repo itchyshin/GLLVM.jl --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url --limit 20`
  -> known older draft PRs `#95` and `#94`.
- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R` -> quiet.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> regenerated
  `man/gllvmTMB_julia-methods.Rd`.
- `tail -5 man/gllvmTMB_julia-methods.Rd; grep -c '^\\keyword' man/gllvmTMB_julia-methods.Rd || true`
  -> keyword count `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> passed with `11` expected Julia-runtime skips and `0` failures; rerun after
  the fallback-message tweak also passed.
- `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> live R-to-Julia bridge tests passed with `0` failures.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); expected_predict <- c("gaussian", "poisson", "binomial", "negbinomial", "nb1", "beta", "gamma", "ordinal", "ordinal_probit"); expected_resid <- c("gaussian", "poisson", "binomial", "negbinomial", "nb1", "beta", "gamma"); stopifnot(identical(gllvmTMB:::.GLLVM_JULIA_PREDICT_FAMILIES, expected_predict)); stopifnot(identical(caps$family[caps$postfit_predict], expected_predict)); stopifnot(identical(caps$family[caps$postfit_residuals], expected_resid)); stopifnot(caps$postfit_predict[caps$family == "ordinal"]); stopifnot(caps$postfit_predict[caps$family == "ordinal_probit"]); stopifnot(!caps$postfit_residuals[caps$family == "ordinal"]); stopifnot(!caps$postfit_residuals[caps$family == "ordinal_probit"]); stopifnot(any(grepl("ordinal link, probability", caps$notes, fixed = TRUE))); print(caps[, c("family", "postfit_predict", "postfit_residuals", "postfit_simulate", "status")], row.names = FALSE)'`
  -> passed.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- `rg -n 'response-scale ordinal probabilities/classes|ordinal score/probability payloads|ordinal predictions are not routed|prediction remains gated until ordinal|ordinal probability/class|modal-class|postfit_predict|postfit_residuals' NEWS.md R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvmTMB_julia-methods.Rd docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task`
  -> expected current hits and historical append-only notes only.
- `git diff --check` -> clean.

## Tests Of The Tests

- Failure-before-fix / drift: before this slice, R marked ordinal
  `postfit_predict = FALSE` and `fitted(fit)` errored for ordinal bridge fits
  despite the Julia payload carrying scores and cutpoints.
- Boundary: the fake ordinal fixture has two traits with different category
  counts (`3` and `4`), so the probability array must pad inactive categories
  as `NA` and active probabilities must sum to one per `(trait, unit)`.
- Feature combination: the live JuliaCall test exercises the real
  `ordinal_probit` bridge fit, per-trait cutpoints, `coef()` / `summary()`,
  probability prediction, and modal-class prediction in one route.
- Negative path: `residuals(fit)` for ordinal still errors; the slice does not
  smuggle in an unvalidated ordinal residual definition.

## Consistency Audit

- `NEWS.md` now says ordinal probability/class prediction is admitted and keeps
  `newdata`, ordinal residuals, ordinal CIs, simulation, extractor parity, and
  structured terms planned/gated.
- `docs/design/35-validation-debt-register.md` row `JUL-01` now lists this
  after-task report, notes pure-R and live ordinal probability/class evidence,
  and removes ordinal probabilities/classes from the current gated list.
- `docs/dev-log/coordination-board.md` now records the ordinal probability/class
  lane and removes it from the next-lane list.
- Historical check-log and older after-task notes still contain previous
  statements that were true when written; they are append-only and are not
  mechanically rewritten.

## What Did Not Go Smoothly

The validation register row is a single very long Markdown table line, so the
small JUL-01 wording changes had to be made as exact mechanical string
replacements rather than a comfortable `apply_patch` hunk. This is a maintainability
smell for the register, but reformatting the register was outside this narrow
bridge admission slice.

## Team Learning

Hopper/Karpinski: this was a true gate-vs-engine drift closure. Julia already
advertised ordinal prediction capability and returned the payload. The R bridge
needed a small, explicit probability contract rather than a broad flip of
`postfit_predict`.

Rose: keeping residuals false while prediction becomes true matters. Ordinal
probabilities are a fitted-value surface; ordinal residuals are a separate
diagnostic/statistical contract.

## Known Limitations

- `newdata` prediction is not routed.
- Ordinal residuals are not routed.
- Per-trait ordinal CIs remain gated.
- Ordinal fixed-effect-X remains gated.
- Mixed-family ordinal rows remain gated.
- Probability prediction is conditional on the retained fitted scores; it is not
  a marginal predictive distribution or uncertainty interval.

## Next Actions

- Choose between grouped-dispersion CI endpoints/status, masked CI/status,
  simulation/extractor parity, mixed-family admission, NB1/ordinal fixed-effect-X,
  X-row CI/status, fit-time Julia CI control design, or native per-trait Gamma
  expansion spec.
