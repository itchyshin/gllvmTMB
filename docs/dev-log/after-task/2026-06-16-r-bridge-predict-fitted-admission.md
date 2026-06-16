# After Task: R Bridge In-Sample `predict()` / `fitted()` Admission

## Goal

Promote the next honest post-fit bridge row by exposing in-sample fitted values
for `gllvmTMB_julia` objects while keeping `newdata`, residual, simulation, and
ordinal probability claims gated.

## Implemented

Added `predict.gllvmTMB_julia()` and `fitted.gllvmTMB_julia()`. The methods
reconstruct the fitted linear predictor from retained bridge payloads:
`alpha + Lambda %*% t(scores)` for no-X rows, `X * mean_coef + Lambda z` for
Gaussian-X rows, and `beta_cov + X * gamma + Lambda z` for non-Gaussian-X rows.
`predict()` returns an in-sample data frame with `trait`, `unit`, and `est`.
`fitted()` returns the fitted trait x unit matrix. Response-scale predictions
apply identity, log, logit, or probit inverse links where the response mean is a
scalar. Per-trait ordinal response probabilities/classes still stop loudly and
require `type = "link"`.

## Mathematical Contract

This slice does not alter any likelihood or fitted parameter. It only evaluates
the conditional fitted predictor using the same payload definitions documented
by the paired Julia `src/bridge.jl` contract. The bridge scores are the fitted
conditional latent scores returned by `GLLVM.bridge_fit`; predictions are
therefore in-sample conditional fitted values, not marginal predictions and not
new-data predictions.

## Files Changed

- `R/julia-bridge.R`: prediction helpers plus `predict.gllvmTMB_julia()` and
  `fitted.gllvmTMB_julia()`.
- `tests/testthat/test-julia-bridge.R`: pure no-X, X, and ordinal-gate tests;
  live main-dispatch prediction checks piggyback on the Julia CI row.
- `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`: regenerated S3 registration
  and method docs.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/check-log.md`, and `docs/dev-log/coordination-board.md`:
  updated JUL-01 claim boundaries.
- `pkgdown-site/index.html`: local status widget refreshed.

## Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R` -> completed
  quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> regenerated
  `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`.
- `tail -5 man/gllvmTMB_julia-methods.Rd; grep -c '^\\keyword' man/gllvmTMB_julia-methods.Rd || true`
  -> expected method-description tail, keyword count `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 11 expected Julia-runtime skips.
- `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 0 failures.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(identical(caps$family[caps$postfit_predict], caps$family)); stopifnot(all(!caps$postfit_residuals)); stopifnot(any(grepl("in-sample predict()/fitted()", caps$notes, fixed = TRUE))); stopifnot(any(grepl("ordinal response probabilities/classes remain gated", caps$notes, fixed = TRUE))); print(caps[, c("family", "postfit_predict", "postfit_residuals", "postfit_simulate", "status")], row.names = FALSE)'`
  -> R capability ledger guard passed.
- `git diff --check` -> clean.

## Tests Of The Tests

The pure tests are feature-combination tests: they combine the new S3 method
with retained no-X payloads, retained fixed-effect-X payloads, and ordinal
cutpoint payloads. The ordinal test is the failure-path guard: link-scale
prediction works, while response-scale ordinal probabilities remain rejected.
The live test combines the main `gllvmTMB(..., engine = "julia")` dispatch with
the new post-fit prediction methods for Gaussian, Poisson, and Bernoulli
binomial rows.

## Consistency Audit

Validation row: JUL-01 remains `partial`, now with this after-task path added.
IN: in-sample `predict()` / `fitted()` for current Julia bridge rows, including
fixed-effect-X payload reconstruction and ordinal link-scale prediction.
PARTIAL: predictions are conditional on fitted latent scores and retained
training payloads. PLANNED/GATED: `newdata` prediction, response-scale ordinal
probabilities/classes, residuals, simulation, extractor parity,
grouped-dispersion CIs, per-trait ordinal CIs, masked CIs, mixed-family CIs,
X-row CIs, and structured terms.

Stale-wording scan used:

```sh
rg -n "postfit_predict|predict\\(\\)/fitted|prediction remains gated|Prediction, residuals|newdata prediction|ordinal response probabilities/classes|S3method\\((predict|fitted),gllvmTMB_julia\\)" R NEWS.md NAMESPACE docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R pkgdown-site/index.html
```

After updates, remaining hits are current scoped claims or historical check-log
commands. This slice adds S3 methods but does not change a formula keyword,
argument default, or public syntax convention, so the convention-change cascade
is not triggered.

## What Did Not Go Smoothly

The first pure test exposed that old/fake bridge payloads can lack a `link`
field. The method now derives a default inverse link from the family when the
payload lacks an explicit `link`, which keeps old payload-shaped tests and
future minimal payloads from failing with an unhelpful `NA` link error.

## Team Learning

Hopper/Karpinski: a bridge method can be admitted from retained flat payloads
when the reconstruction equation is explicit and tested. Rose: the public claim
must say "in-sample conditional fitted values", not broad prediction.

## Known Limitations

`predict.gllvmTMB_julia()` does not support `newdata`. `fitted()` and
`predict(type = "response")` do not yet return ordinal probabilities or
classes. Residuals and simulations remain separate rows because they need their
own response-scale conventions, mask behavior, and failure-status contracts.

## Next Actions

Choose one of the adjacent rows: response-scale ordinal prediction
probabilities/classes, residuals for scalar-response rows, simulation for
scalar-response rows, or extractor parity for covariance/ordination summaries.
