# COE-04 high-overlap collapse-equivalence gate

Date: 2026-06-18 12:22 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds the first high-overlap collapse/equivalence gate for the Paper
2 fixed named multi-kernel model. The new heavy fixture sets the two named
kernel tiers to the same dense `K`. In that regime the correct claim is not
that `Gamma_phy` and `Gamma_non` are separately recovered; the correct claim is
that the separated two-tier parameterisation should be treated as a collapsed
higher-rank kernel.

The test verifies:

- the two named kernels are classified as high overlap;
- the separated rank-1 + rank-1 fit warns and converges;
- the collapsed rank-2 single-tier fit converges;
- the separated two-tier fit is not materially better than the collapsed fit
  (`abs(logLik difference) < 2`);
- separated `extract_Gamma(level = "phy" / "non")` warns;
- collapsed `extract_Gamma(level = "cross")` is quiet and finite.

This is not high-overlap truth recovery and not interval or `rho` evidence.

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
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> first attempt failed on over-broad high-overlap truth-recovery assertions
  (`corr` about 0.68 and 0.63); the test was narrowed to the supported
  collapse/equivalence claim.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 111`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 6 | PASS 47`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 9 | PASS 133`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 220`.

## Review perspectives

Boole: no formula grammar change was made. The test uses existing
`kernel_latent()` syntax and the existing named-level extractor.

Gauss / Noether: no TMB likelihood or parameterisation change was made. The
test compares two parameterisations of the same high-overlap covariance
structure.

Fisher / Curie: the failed draft assertion usefully blocked an overclaim. The
accepted gate supports collapse/equivalence and warning language only, not
truth recovery under indistinguishable kernels.

Rose: NEWS, validation register, Design 65, dashboard, and check-log keep
`COE-04` partial and preserve the claim guard.

## Still open

- Broader moderate-overlap calibration.
- Broader high-overlap recovery/failure calibration beyond the collapse and
  warning gates.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
