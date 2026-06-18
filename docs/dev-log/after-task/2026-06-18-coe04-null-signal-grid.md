# COE-04 small null/signal grid

Date: 2026-06-18 13:24 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds a small heavy null/signal grid for the Paper 2 fixed named
multi-kernel model. It strengthens the existing block-null smoke gate without
claiming broad null-threshold calibration.

The test verifies:

- three near-orthogonal block-null seeds keep both component `Gamma_shape`
  norms below `1e-3`;
- those null fits keep the full two-kernel likelihood gain over an
  intercept-only model below `3`;
- two medium-signal fixtures recover both component-specific `Gamma_shape`
  matrices with correlation above `0.90`;
- those medium-signal fits beat either one-component fit by more than `100`
  log-likelihood units.

This is small-grid evidence for the near-orthogonal Gaussian latent-only
regime. It is not broad null calibration, high-overlap truth recovery,
interval evidence, `rho` inference, mixed-family evidence, or release
readiness.

## Files changed

- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Commands run

- `/opt/homebrew/bin/gh pr list --state open`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current mission-control/co-evolution arc.
- `git diff --check`
  -> clean before edits.
- Exploratory checkout-loaded probe over null seeds `2301:2304` and signal
  settings `(2601, 0.35, 0.35)`, `(2602, 0.50, 0.50)`,
  `(2603, 0.70, 0.70)`, `(2604, 0.50, 0.30)`
  -> null `Gamma_shape` norms stayed tiny but likelihood gain over intercept
  varied up to about `2.6`; weak-signal phy recovery was not robust enough for
  a committed gate, so the test uses medium-signal settings only.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 134`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 7 | PASS 47`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 10 | PASS 133`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 243`.

## Review perspectives

Boole: no formula grammar change was made. The gate uses existing
`kernel_latent(..., name = "phy" / "non")` syntax and keeps
`kernel_unique()` out of the Paper 2 first-wave model.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
new test repeats the same symbolic components across null and medium-signal
DGPs and checks extractor targets against the declared truths.

Fisher / Curie: the grid is deliberately small. It adds multi-seed null
evidence and two medium-signal contrast cells, but it does not support
calibrated Type I error, interval coverage, or `rho` inference claims.

Rose: NEWS, Design 65, the validation register, dashboard JSON, and check-log
keep `COE-04` partial and preserve the guard sentence.

## Still open

- Broader moderate-overlap calibration.
- Broader high-overlap recovery/failure calibration beyond the collapse and
  warning gates.
- Broader null-threshold calibration.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
