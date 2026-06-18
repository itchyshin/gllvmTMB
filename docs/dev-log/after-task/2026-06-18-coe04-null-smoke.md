# COE-04 symmetric absence and block-null smoke

Date: 2026-06-18 11:41 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice extends the absence/null side of the Paper 2 fixed named
multi-kernel model. It keeps the model in the near-orthogonal Gaussian
latent-only regime and does not promote `COE-04` to covered.

The new gates prove this narrow behavior:

- if the phy component has true zero loadings, the fitted phy
  `Gamma_shape` collapses while the non component recovers;
- if the non component has true zero loadings, the fitted non
  `Gamma_shape` collapses while the phy component recovers;
- if both loading blocks are zero, both extracted `Gamma_shape` norms collapse
  below `1e-3`, and the full model stays within 3 log-likelihood units of an
  intercept-only fit.

The both-null case is a smoke gate, not calibrated null inference.
Moderate/high-overlap behavior, calibrated block-null thresholds, `rho`,
intervals, mixed/non-Gaussian gates, and the post-arc `*_unique()`
lifecycle/deprecation plan remain open.

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
  -> recent commits were current mission-control/article/kernel commits.
- `git diff --check`
  -> clean before edits.
- Exploratory checkout-loaded R probes over absent-phy seeds 2201..2203
  -> all converged; the fitted phy `Gamma_shape` norm stayed near zero while
  the non component recovered.
- Exploratory checkout-loaded R probes over both-null seeds 2301..2305
  -> all converged; both fitted `Gamma_shape` norms stayed near zero. The
  full-versus-intercept likelihood gap was small and seed-dependent, so this
  was committed as a smoke gate, not calibrated null inference.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 75`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 36`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 7 | PASS 122`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 184`.

## Review perspectives

Boole: no formula grammar change was made. The tests keep the fixed
latent-only `kernel_latent(..., name = "phy") + kernel_latent(..., name =
"non")` Paper 2 shape.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
slice extends simulation fixtures and tests the existing multi-kernel
likelihood.

Fisher / Curie: two-sided selective absence is now a heavy evidence gate. The
both-null test is deliberately labelled smoke evidence; calibrated null
thresholds still need a broader simulation grid.

Rose: dashboard, register, NEWS, and check-log keep `COE-04` as `partial` and
retain the claim guard.

## Still open

- Moderate-overlap recovery and high-overlap failure language.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
