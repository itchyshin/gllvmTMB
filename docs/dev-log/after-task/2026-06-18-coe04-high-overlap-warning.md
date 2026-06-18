# COE-04 high-overlap warning

Date: 2026-06-18 11:47 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closes the silent high-overlap failure-language gap for fixed named
multi-kernel fits. When fitted kernel tiers have high off-diagonal
Frobenius-style similarity, the fit now warns that component-specific
`Gamma_shape` separation is weak evidence.

The fit still proceeds and still stores the diagnostic table:

- `fit$kernel_diagnostics$similarity`;
- `fit$kernel_diagnostics$pairs`;
- `fit$kernel_diagnostics$thresholds`;
- `fit$kernel_diagnostics$note`.

This is not high-overlap recovery calibration. It is warning/claim-boundary
evidence only.

## Files changed

- `R/fit-multi.R`
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
  -> recent commits were current mission-control/article/kernel commits.
- `git diff --check`
  -> clean before edits.
- Exploratory checkout-loaded high-overlap fit before the edit
  -> converged with `fit$kernel_diagnostics$pairs$similarity == 1` and
  `overlap_class == "high"`, but emitted no warning.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 40`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 79`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 7 | PASS 126`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 188`.

## Review perspectives

Boole: no new formula grammar was added. The warning is attached to the
existing fixed named multi-kernel grammar.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
warning is computed from fixed input-kernel diagnostics.

Fisher / Curie: high overlap now has explicit failure language and a regression
test, but no calibrated high-overlap recovery/failure grid yet.

Rose: dashboard, register, NEWS, and check-log keep `COE-04` as `partial` and
retain the claim guard.

## Still open

- Moderate-overlap recovery.
- High-overlap recovery/failure calibration beyond warning language.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
