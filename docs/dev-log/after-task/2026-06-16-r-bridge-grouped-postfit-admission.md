# After Task: R Bridge Grouped Post-Fit Admission

## Goal

Use the new paired Julia grouped score payloads to admit in-sample
`predict()` / `fitted()` / response-Pearson `residuals()` for grouped NB2, NB1,
Beta, and Gamma bridge rows.

## Implemented

Expanded `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` and
`.GLLVM_JULIA_RESIDUAL_FAMILIES` to include `negbinomial`, `nb1`, `beta`, and
`gamma` alongside Gaussian, Poisson, and Bernoulli binomial. Updated the
capability ledger and live R bridge tests so grouped rows must carry finite
scores and finite fitted values, response residuals, and Pearson residuals.

The paired Julia runtime change is
`docs/dev-log/after-task/2026-06-16-grouped-getlv-bridge-scores.md` in
`../GLLVM.jl-integration`.

## Mathematical Contract

No likelihood, fitted parameter, or dispersion scale changes in R. The R bridge
uses the same retained-payload reconstruction as the previous residual slice:

```text
eta = alpha + Lambda * z_hat
mu = linkinv(eta)
response residual = observed response - mu
Pearson residual = response residual / sqrt(V(mu, dispersion_t))
```

The grouped rows use the existing per-family variance rules: NB2
`mu + mu^2 / r_t`, NB1 `mu * (1 + phi_t)`, Beta
`mu * (1 - mu) / (phi_t + 1)`, and Gamma `mu^2 / alpha_t`. Gamma remains
shared-group in the bridge to match the current native R/TMB oracle.

## Files Changed

- `R/julia-bridge.R`: expanded the score-bearing post-fit family set and updated
  the capability note wording.
- `tests/testthat/test-julia-bridge.R`: grouped direct-wrapper and
  main-dispatch tests now require finite scores, fitted values, response
  residuals, and Pearson residuals.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/check-log.md`, and `docs/dev-log/coordination-board.md`:
  updated JUL-01 scope and evidence.
- `pkgdown-site/index.html`, `pkgdown-site/status.json`, and
  `pkgdown-site/version.txt`: local ignored status widget refreshed after
  commit.

## Checks Run

- `julia --project=. test/test_bridge_grouped_dispersion.jl` in
  `../GLLVM.jl-integration` -> `81/81 pass`.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- Direct paired Julia NB1 bridge probe -> score size `(10, 1)`, all finite.
- `julia --project=. test/test_bridge_missing_mask.jl` in
  `../GLLVM.jl-integration` -> `37/37 pass`.
- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R` -> completed
  quietly.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 11 expected Julia-runtime skips and 0 failures.
- `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 0 failures.
- R capability guard for `postfit_predict` / `postfit_residuals` -> passed.
- `git diff --check` in both worktrees -> clean.

## Tests Of The Tests

This is failure-before-fix coverage through the paired Julia test: before the
runtime patch, grouped `bridge_fit()` returned `0 x 0` scores and direct grouped
`getLV()` threw `MethodError`. The R live grouped loop now fails under that old
state because `fitted()` / `residuals()` need an `n x K` score payload.

## Consistency Audit

Validation row: JUL-01 remains `partial`. IN: in-sample
`predict()` / `fitted()` / `residuals(type = "response" / "pearson")` for
score-bearing Gaussian, Poisson, Bernoulli binomial, NB2, NB1, Beta, and Gamma
bridge rows. PARTIAL: all are conditional retained-payload reconstructions on
training data. PLANNED/GATED: grouped-dispersion CI endpoints, ordinal
probabilities/classes and residuals, mixed-family residuals, `newdata`
prediction, simulation, extractor parity, masked CI/status, X-row CI/status,
structured terms, and broad parity/speed claims.

Stale-wording scan used:

```sh
rg -n "without retained score payloads|grouped-dispersion residuals|score-bearing gaussian, poisson, and Bernoulli|no-X gaussian, poisson, and Bernoulli|postfit_predict|postfit_residuals|response/Pearson" NEWS.md R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task
```

Remaining grouped-residual hits are historical after-task/check-log evidence, not
current NEWS/register/coordination claims. This slice changes capability scope
but not a formula keyword, argument default, or public syntax convention, so the
convention-change cascade is not triggered.

## What Did Not Go Smoothly

The previous R residual slice correctly gated grouped rows, but it also revealed
that the missing evidence was a Julia method gap rather than an R residual
formula problem. The bridge's defensive `0 x 0` score fallback made the gap look
like a shape mismatch until direct grouped `getLV()` probes exposed the
`MethodError`.

## Team Learning

Karpinski: grouped fit types need post-fit score methods parallel to the shared
dispersion families. Hopper: R capability flags should follow score payload
evidence, not just point-fit success. Rose: grouped post-fit admission is not
grouped CI admission.

## Known Limitations

Grouped-dispersion CIs, simulation, extractor parity, `newdata` prediction,
structured terms, and broad native parity remain unpromoted. Ordinal and
mixed-family residuals remain gated.

## Next Actions

Choose between response-scale ordinal probabilities/classes, simulation,
extractor parity, grouped CI/status design, masked CI/status, or mixed-family
post-fit admission as the next bridge row.
