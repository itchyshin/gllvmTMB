# COE-04 selective-absence gate

Date: 2026-06-18 11:30 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds the first selective-absence evidence gate for the Paper 2
fixed named multi-kernel model. The committed heavy test uses a near-orthogonal
Gaussian latent-only fixture where the phy component is present and the non
component has true zero loadings.

The gate proves this narrow behavior:

- the two-kernel fit converges;
- the present phy component recovers its `Gamma_shape` truth;
- the absent non component's `extract_Gamma(level = "non")` collapses below
  `1e-3`;
- the present-only model beats the absent-only model;
- the full model does not materially improve over the present-only model.

This is not a public Paper 2 promotion and not full scientific coverage.
Moderate/high-overlap behavior, block-null calibration, `rho`, intervals,
mixed/non-Gaussian gates, and the post-arc `*_unique()` lifecycle/deprecation
plan remain open.

Supersession note: the follow-up
`2026-06-18-coe04-null-smoke.md` added the symmetric selective-absence gate
and a block-null smoke gate. This report remains the record for the first
one-direction absence slice.

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
- Exploratory checkout-loaded R probes over absent-non seeds 2101..2103
  -> all converged; the fitted non `Gamma_shape` norm stayed near zero while
  the phy component recovered.
- Exploratory checkout-loaded R probes over absent-phy seeds 2201..2203
  -> all converged; the fitted phy `Gamma_shape` norm stayed near zero while
  the non component recovered. This symmetric case is not yet promoted to a
  committed gate.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 61`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 3 | PASS 36`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 6 | PASS 122`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 170`.

## Review perspectives

Boole: no new formula grammar was added. The fixture still uses the fixed
latent-only `kernel_latent(..., name = "phy") + kernel_latent(..., name =
"non")` Paper 2 shape.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
slice extends a simulation fixture and tests the existing multi-kernel
likelihood.

Fisher / Curie: selective absence now has one heavy near-orthogonal Gaussian
gate. This is meaningful recovery evidence, but not null calibration or
interval evidence.

Rose: the dashboard, register, NEWS, and check-log all keep `COE-04` as
`partial` and retain the claim guard.

## Still open

- Moderate-overlap recovery and high-overlap failure language.
- Block-null calibration.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
