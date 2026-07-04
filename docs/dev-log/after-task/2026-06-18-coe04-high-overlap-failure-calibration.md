# COE-04 non-identical high-overlap failure calibration

Date: 2026-06-18 16:25 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds one high-overlap, non-identical kernel gate for the Paper 2
fixed named multi-kernel model. The point is deliberately narrow: the model
can detect signal in a high-overlap setting, but the component-specific
`Gamma_shape` blocks are not promoted as recovered.

The heavy fixture uses seed `2551`, mixes `K_non` 85% toward `K_phy`, and keeps
the kernels non-identical while landing at `similarity = 0.999876`. The full
two-kernel model converges and beats either one-component comparator by about
`601` log-likelihood units. Component separation fails the promoted recovery
bar: own-shape correlations are `0.64` and `0.87`, and one cross-component
match is `0.52`.

This is failure-calibration evidence, not high-overlap truth recovery, interval
evidence, `rho` inference, mixed-family evidence, bridge completion, release
readiness, or scientific coverage.

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
- `curl -I --max-time 2 http://127.0.0.1:8770/`
  -> `HTTP/1.0 200 OK`.
- `lsof -nP -iTCP:8770 -sTCP:LISTEN || true`
  -> Python PID `95119` listening on `127.0.0.1:8770`.
- Exploratory checkout-loaded probe with `non_association_blend` values
  `0.55`, `0.65`, `0.75`, and `0.85`
  -> all stayed moderate-overlap, so the committed gate uses the
  `non_kernel_phy_mix` fixture axis instead.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> first attempt failed because the wrapper expected a fit warning that had
  been suppressed; the test was corrected to assert the `extract_Gamma()`
  warning directly.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 270`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 67`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 14 | PASS 171`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 399`.

## Review perspectives

Boole: no formula grammar change was made. The test uses the existing
latent-only `kernel_latent(..., name = "phy" / "non")` Paper 2 first-wave
syntax and leaves `kernel_unique()` / `*_unique()` as compatibility syntax.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
alignment table in the test ties the two fixed kernels, latent fields,
component `Gamma_shape` extractors, and truth matrices row-by-row.

Fisher / Curie: the gate is a claim-boundary test. It proves that a
non-identical high-overlap fit can detect two-component signal while failing
component separation; it does not support high-overlap truth recovery.

Rose: NEWS, Design 65, the validation register, dashboard JSON, and check-log
keep `COE-04` partial and preserve the guard sentence.

## Still open

- Broader/harder moderate-overlap calibration.
- Broader high-overlap truth-recovery/failure calibration beyond the current
  collapse-equivalence, non-identical failure-calibration, and warning gates.
- Formal null-threshold calibration beyond the diagnostic grid.
- In-engine `rho` estimation and `rho` profile intervals.
- Interval coverage.
- Broader non-Gaussian or mixed-family recovery gates beyond the narrow
  Poisson cell pair.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
