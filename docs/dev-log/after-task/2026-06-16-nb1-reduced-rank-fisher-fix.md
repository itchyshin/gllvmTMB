# After Task: NB1 Reduced-Rank Fisher-Boundary Fix

## Goal

Turn the reduced-rank NB1 bridge audit into a fixed, tested small-fixture parity
row after identifying the Julia boundary numerical issue.

## Implemented

In the paired Julia runtime:

- `src/families/negbin1.jl` now uses a Poisson-limit branch in
  `_nb1_fisher_mu()` for `phi <= 1e-6`.
- `test/test_nb1.jl` covers the tiny-`phi` Fisher-information boundary.

In `gllvmTMB`:

- `tests/testthat/test-julia-bridge.R` now promotes NB1 in the grouped
  reduced-rank main-dispatch parity loop.
- The NB1 row compares Julia and native TMB log-likelihood, df, per-trait
  intercepts, loadings, and `phi` on the small complete balanced fixture.

## Mathematical Contract

The NB1 parameterisation is unchanged:

```text
Var(y | mu, phi) = mu * (1 + phi)
```

The fix is numerical, not statistical: near `phi -> 0`, NB1 tends to Poisson,
so Fisher information should tend to `1 / mu`.

## Files Changed

Paired Julia runtime:

- `../GLLVM.jl-integration/src/families/negbin1.jl`
- `../GLLVM.jl-integration/test/test_nb1.jl`
- `../GLLVM.jl-integration/docs/dev-log/check-log.md`
- `../GLLVM.jl-integration/docs/dev-log/after-task/2026-06-16-nb1-fisher-boundary.md`

R bridge:

- `tests/testthat/test-julia-bridge.R`
- `docs/dev-log/2026-06-16-nb1-reduced-rank-fisher-fix.md`
- `docs/dev-log/2026-06-16-nb1-reduced-rank-parity-audit.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-nb1-reduced-rank-fisher-fix.md`

## Checks Run

- `julia --project=. test/test_nb1.jl` in `../GLLVM.jl-integration`
  -> `34/34 pass`.
- Live bridge check:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly.
- No-Julia bridge check:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed cleanly with six expected Julia-runtime skips.
- Julia bridge/grouped checks:
  `julia --project=. test/test_bridge_grouped_dispersion.jl` -> `49/49 pass`;
  `julia --project=. test/test_grouped_dispersion_tweedie_nb1.jl` -> `15/15 pass`.
- Stale-claim scans:
  `rg -n 'reduced-rank NB1 parity remains unpromoted|reduced-rank NB1 remains partial|NB1 still needs reduced-rank|objective-form investigation|0\.07678|1\.034579' docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/2026-06-16-nb1-reduced-rank-fisher-fix.md docs/dev-log/after-task/2026-06-16-nb1-reduced-rank-fisher-fix.md tests/testthat/test-julia-bridge.R README.md NEWS.md vignettes pkgdown-site/index.html`
  -> expected historical check-log entries only.
  `rg -n 'NB1.*full parity|full native parity|complete bridge|CRAN-ready bridge|Gamma.*native parity|native parity.*Gamma|Gamma.*covered.*Julia|broad NB1|speed claim' docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/2026-06-16-nb1-reduced-rank-fisher-fix.md docs/dev-log/after-task/2026-06-16-nb1-reduced-rank-fisher-fix.md tests/testthat/test-julia-bridge.R README.md NEWS.md vignettes`
  -> expected guardrail language and historical scan-command strings only.
- `git diff --check` -> clean in both `gllvmTMB` and
  `../GLLVM.jl-integration`.

## Evidence

The promoted reduced-rank NB1 fixture reports native `logLik =
-52.4618425767`, Julia `logLik = -52.4619219625`, `df = 6` for both engines,
and delta `-7.9386e-05`. At the native fitted fixed parameters, the Julia
objective is `-52.4618425607`, matching native TMB to about `1.6e-08`.

## Consistency Audit

`JUL-01` remains `partial` overall. The reduced-rank NB1 small-fixture point row
is now covered, but grouped-dispersion CIs, masks, non-Gaussian X, mixed-family
NB1, structured terms, and broad simulation/speed claims remain gated.

## Team Learning

- Gauss/Karpinski: boundary Fisher information must use the Poisson-limit
  branch before the trigamma difference loses precision.
- Hopper: the bridge fixture should compare point estimates, not only payload
  labels.
- Rose: promote only the fixture depth that is actually tested.

## Known Limitations

This does not prove broad NB1 performance, inference, or simulation recovery.
It proves a small complete balanced reduced-rank point-parity fixture.
