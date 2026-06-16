# After Task: R Bridge Response/Pearson `residuals()` Admission

## Goal

Promote the next honest post-fit bridge row by exposing in-sample
response-scale and Pearson residuals for the Julia bridge rows that retain
enough score payload to reconstruct fitted values.

## Implemented

Added `residuals.gllvmTMB_julia(object, type = c("response", "pearson"))`.
Response residuals are observed response minus fitted response mean. Pearson
residuals divide by the current family variance convention: Gaussian
`sigma_eps^2`, Poisson `mu`, and Bernoulli/binomial `p * (1 - p) / N`. Binomial
responses are converted to observed proportions `y / N`, and response masks are
preserved as `NA` residual cells.

The capability ledger now advertises `postfit_predict` and `postfit_residuals`
only for `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES`: Gaussian, Poisson, and
Bernoulli binomial. Grouped-dispersion, ordinal, and mixed-family rows fail
loudly until their score/probability/residual contracts are explicit.

## Mathematical Contract

This slice does not change the fitted likelihood, optimizer, or parameter
estimates. It evaluates conditional in-sample residuals from the retained
fitted-value payload:

```text
response residual = observed response - fitted response mean
Pearson residual = response residual / sqrt(variance fitted at the mean)
```

The residuals are conditional on fitted latent scores. They are not marginal
residuals, not simulation residuals, not randomized quantile residuals, and not
new-data diagnostics.

## Files Changed

- `R/julia-bridge.R`: residual helpers, `residuals.gllvmTMB_julia()`, score
  orientation normalization, no-latent score handling, and narrower capability
  flags for score-bearing post-fit methods.
- `tests/testthat/test-julia-bridge.R`: pure residual reconstruction tests,
  binomial proportion tests, mask-to-`NA` tests, ordinal/mixed-family rejection
  tests, live residual checks for admitted no-X rows, and grouped-dispersion
  residual rejection checks.
- `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`: regenerated S3 registration
  and method docs.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/check-log.md`, and `docs/dev-log/coordination-board.md`:
  updated JUL-01 scope, evidence, and next-lane boundary.
- `pkgdown-site/index.html`, `pkgdown-site/status.json`, and
  `pkgdown-site/version.txt`: local ignored status widget refreshed after the
  source commit.

## Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R` -> completed
  quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> regenerated
  `NAMESPACE` and `man/gllvmTMB_julia-methods.Rd`.
- `tail -5 man/gllvmTMB_julia-methods.Rd; grep -c '^\\keyword' man/gllvmTMB_julia-methods.Rd || true`
  -> expected method-description tail, keyword count `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 11 expected Julia-runtime skips and 0 failures.
- `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 0 failures.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(identical(caps$family[caps$postfit_predict], gllvmTMB:::.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES)); stopifnot(identical(caps$family[caps$postfit_residuals], gllvmTMB:::.GLLVM_JULIA_RESIDUAL_FAMILIES)); stopifnot(!caps$postfit_predict[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(!caps$postfit_residuals[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("without retained score payloads", caps$notes, fixed = TRUE))); stopifnot(any(grepl("response/Pearson residuals are routed", caps$notes, fixed = TRUE))); print(caps[, c("family", "postfit_predict", "postfit_residuals", "postfit_simulate", "status")], row.names = FALSE)'`
  -> R capability ledger guard passed.
- `rg -n "S3method\\(residuals,gllvmTMB_julia\\)|residuals\\.gllvmTMB_julia|postfit_residuals|response/Pearson|without retained score payloads" NAMESPACE R/julia-bridge.R man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md`
  -> S3 registration, docs, tests, and scoped ledger wording all present.
- `git diff --check` -> clean.

## Tests Of The Tests

The pure residual tests are feature-combination tests: they combine retained
score payload reconstruction with masks and binomial trial counts. The
transposed-score test is a boundary case for payload orientation. The ordinal
and mixed-family residual tests are failure-path guards. The live tests combine
ordinary `gllvmTMB(..., engine = "julia")` dispatch with residual extraction for
Gaussian, Poisson, and Bernoulli rows, and they verify grouped-dispersion
residuals reject instead of returning unsupported values.

## Consistency Audit

Validation row: JUL-01 remains `partial`. IN: in-sample
`predict()` / `fitted()` / `residuals(type = "response" / "pearson")` for
score-bearing Gaussian, Poisson, and Bernoulli binomial bridge rows. PARTIAL:
residuals are conditional on fitted latent scores and retained training
payloads. PLANNED/GATED: grouped-dispersion residuals, ordinal residuals or
probabilities/classes, mixed-family residuals, `newdata` prediction, simulation,
extractor parity, grouped-dispersion CIs, per-trait ordinal CIs, masked CIs,
mixed-family CIs, X-row CIs, and structured terms.

Stale-wording scans used:

```sh
rg -n "residuals/simulate/extractor parity remain gated|in-sample predict\\(\\)/fitted\\(\\) are routed|all\\(!caps\\$postfit_residuals\\)|identical\\(caps\\$family\\[caps\\$postfit_predict\\], caps\\$family\\)|ordinal response probabilities/classes remain gated" NEWS.md R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvmTMB_julia-methods.Rd docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md
rg -n "postfit_predict|postfit_residuals|score payload|response/Pearson|grouped-dispersion residuals|mixed-family residuals" NEWS.md R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvmTMB_julia-methods.Rd docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md
rg -n "MultiTraits|CSR|LHS|trait-network|multilayer" docs/dev-log/coordination-board.md NEWS.md docs/design/35-validation-debt-register.md
```

Remaining hits are current scoped claims, historical check-log commands, or the
expected MultiTraits scout note in the coordination board. The `LHS` hits are
ordinary formula-LHS wording. This slice adds an S3 method but does not change a
formula keyword, argument default, or public syntax convention, so the
convention-change cascade is not triggered.

## What Did Not Go Smoothly

The first live residual probes for grouped-dispersion rows failed with
`score payload row count does not match units`. That was useful: the failure
showed the earlier `postfit_predict = TRUE` claim was too broad. The slice now
narrows both prediction and residual capability flags to rows with retained
score payloads, and it leaves grouped residuals as an explicit gate.

## Team Learning

Hopper/Karpinski: post-fit R methods need a named payload contract before a row
is advertised. Rose: prediction and residual flags must follow evidence, not
the fact that a row can fit. Curie: the masked-residual and grouped-rejection
tests caught the hidden shape problem before the capability matrix drifted.

## Known Limitations

Grouped-dispersion rows currently do not retain the score payload needed for
R-side residual reconstruction. Ordinal rows need a separate probability/class
and residual convention. Mixed-family residuals need per-trait family variance,
mask, and status rules before admission. No simulation, extractor, `newdata`, or
CI-status claim is added by this slice.

## Next Actions

Decide whether the next bridge row should add grouped-dispersion score payloads,
response-scale ordinal probability/classes, scalar-response simulation, or
extractor parity. Keep the MultiTraits scout idea in the public-learning-path
lane: borrow visual teaching patterns only after the model-estimated
uncertainty/status contract is ready.
