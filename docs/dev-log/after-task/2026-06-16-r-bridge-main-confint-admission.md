# After Task: R Bridge Main-Dispatch `confint()` Admission

## Goal

Make the admitted Julia no-X CI payload route accessible from ordinary
`gllvmTMB(..., engine = "julia")` fits without adding a fit-time Julia control
surface or weakening the existing gates for unsupported CI rows.

## Implemented

`gllvm_julia_fit()` now stores the response matrix, family key, rank, trials,
fixed-effect array, response mask, orientation flag, and Julia setup arguments
needed to reproduce the exact bridge call. `confint.gllvmTMB_julia()` now has
`method = "stored" / "wald" / "profile" / "bootstrap"`: stored payloads are
read directly, and non-stored methods recompute through
`gllvm_julia_fit(ci_method = ...)` for admitted no-X Gaussian, Poisson, and
Bernoulli binomial rows.

## Mathematical Contract

No likelihood, parameter scale, or CI engine changed in this slice. The R method
only reuses the existing `GLLVM.bridge_fit` CI options already tested against
the paired Julia `test/test_bridge_ci.jl` contract. Unsupported CI regimes keep
the existing statistical boundary: grouped-dispersion rows, per-trait ordinal
rows, response masks, mixed-family vectors, and fixed-effect-X rows still stop
before Julia setup when CI endpoints are requested.

## Files Changed

- `R/julia-bridge.R`: retained bridge input, post-fit CI refit helper, and
  updated `confint.gllvmTMB_julia()` method/docs.
- `tests/testthat/test-julia-bridge.R`: pure mocked post-fit route test and
  live main-dispatch Wald CI test for Gaussian, Poisson, and Bernoulli binomial
  rows.
- `man/gllvmTMB_julia-methods.Rd`: regenerated S3 method documentation.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/check-log.md`, and `docs/dev-log/coordination-board.md`:
  claim/evidence wording updated to separate post-fit `confint()` from any
  fit-time Julia CI control surface.
- `pkgdown-site/index.html`: local status widget refreshed.

## Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R` -> completed
  quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> regenerated
  `man/gllvmTMB_julia-methods.Rd`.
- `tail -5 man/gllvmTMB_julia-methods.Rd && grep -c '^\\keyword' man/gllvmTMB_julia-methods.Rd`
  -> expected method-description tail, keyword count `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 11 expected Julia-runtime skips.
- `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with 0 failures.
- `julia --project=. test/test_bridge_ci.jl` in `../GLLVM.jl-integration` ->
  `64/64 pass`.
- `julia --project=. test/test_bridge_capabilities.jl` in
  `../GLLVM.jl-integration` -> `34/34 pass`.
- `git diff --check` -> clean.

## Tests Of The Tests

The mocked pure-R test is a feature-combination test: it combines stored bridge
input retention with the existing `confint()` S3 path and verifies that method,
level, bootstrap count, seed, setup arguments, and bridge arrays reach
`gllvm_julia_fit()`. The live test is also a feature-combination test: it fits
through the main `gllvmTMB(..., engine = "julia")` dispatch, then calls
`confint(fit, method = "wald")` post-fit for Gaussian, Poisson, and Bernoulli
binomial rows. Existing negative tests still cover unsupported CI gates before
Julia setup.

## Consistency Audit

Validation row: JUL-01 remains `partial`, now with this after-task path added.
IN: no-X post-fit `confint()` for Gaussian, Poisson, and Bernoulli binomial
Julia bridge rows. PARTIAL: the route is scoped to retained bridge-input fits
and the existing CI payload contract. PLANNED/GATED: fit-time Julia CI controls
on `gllvmTMB()`, grouped-dispersion CIs, per-trait ordinal CIs, masked CIs,
mixed-family CIs, X-row CIs, prediction, residuals, simulation, extractor
parity, structured terms, and broad native parity.

Stale-wording scan used:

```sh
rg -n "main gllvmTMB\\(\\) CI control|stored-payload confint|computed at fit time|CI controls|direct-wrapper no-X CI/status|gllvm_julia_fit\\(\\.\\.\\., ci_method" R NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md pkgdown-site/index.html man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R
```

After updates, remaining relevant hits are historical commands/evidence or
current scoped gates. This slice did not change a public argument name, keyword,
default, or formula syntax, so the AGENTS.md convention-change cascade is not
triggered.

## What Did Not Go Smoothly

The main risk was wording drift: "main-dispatch CI controls" sounded like the
only possible user route, but the implemented surface is deliberately post-fit
`confint()`. The fix was to retain bridge input rather than add new
`gllvmTMBcontrol()` or `engine_control` API in this slice.

## Team Learning

Hopper/Ada boundary: widen the ordinary user path through existing S3 methods
when possible, and reserve a formal Julia control surface for a later deliberate
design lane. Rose boundary: say "post-fit `confint()`" rather than "CI controls"
unless a fit-time API really exists.

## Known Limitations

`confint()` recomputes intervals and returns them; it does not mutate the
original fit object to attach the new payload. Bootstrap retains the current
Julia CI payload contract and does not yet expose retention/failure diagnostics
beyond the returned status fields. Unsupported rows still require future
dedicated admission work.

## Next Actions

The next bridge lane should choose one explicit row: grouped-dispersion CI
status/endpoints, masked CI/status, prediction/residual/simulation methods, or
mixed-family point promotion. Keep the capability ledger and widget synchronized
with whichever row is chosen.
