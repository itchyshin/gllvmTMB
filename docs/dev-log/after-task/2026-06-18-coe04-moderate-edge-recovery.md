# COE-04 moderate-edge recovery gate

Date: 2026-06-18 11:58 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds the first moderate-overlap recovery evidence for the Paper 2
fixed named multi-kernel model. It modifies the existing near-orthogonal DGP
by blending the non association pattern 30% toward the phy association pattern,
placing the kernel pair just inside the `moderate` overlap class.

The committed gate proves this narrow behavior:

- the full two-component model converges;
- the one-component comparators converge;
- the full model beats either one-component comparator by >50 log-likelihood
  units;
- both component `Gamma_shape` correlations exceed 0.95;
- cross-component `Gamma_shape` matches stay below 0.25.

This is not broad moderate-overlap calibration and not high-overlap recovery
evidence.

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
- Exploratory checkout-loaded alpha grid over `non_association_blend` values
  0.0..1.0
  -> the pair moves from near-orthogonal into moderate at alpha 0.3.
- Exploratory checkout-loaded recovery probes over alpha 0.3, 0.5, 0.7, and
  1.0 across seeds 2401..2403
  -> all converged; the conservative alpha 0.3 case kept both component
  `Gamma_shape` correlations above 0.95 and cross-component matches below
  0.25 across the probed seeds.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 92`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 5 | PASS 40`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 126`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 201`.

## Review perspectives

Boole: no formula grammar change was made. The gate reuses fixed named
`kernel_latent()` tiers.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
slice modifies only the simulation fixture and tests the existing multi-kernel
likelihood.

Fisher / Curie: moderate-overlap recovery now has one conservative heavy gate.
It is useful evidence, but not a calibrated overlap-response curve.

Rose: dashboard, register, NEWS, and check-log keep `COE-04` as `partial` and
retain the claim guard.

## Still open

- Broader moderate-overlap calibration.
- High-overlap recovery/failure calibration beyond warning language.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
