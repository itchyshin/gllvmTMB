# After-Task Report: Wald Sigma Total-Variance Guard

Date: 2026-07-04 23:05 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issues: #620, #621

## Goal

Stop Wald Sigma confidence intervals from reporting residual/Psi-only
`theta_diag_*` bounds on rows whose point estimate is total variance
`Lambda Lambda' + Psi`.

## Files Changed

- `R/z-confint-gllvmTMB.R`
- `tests/testthat/test-profile-ci.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-wald-sigma-total-variance-guard.md`

## What Changed

- `.confint_sigma_wald()` now fills diagonal bounds from `theta_diag_*` only
  when the requested tier is pure diagonal.
- If a reduced-rank `latent()` component is present, total Sigma point
  estimates remain available but lower/upper bounds stay `NA`.
- Added heavy regression coverage for the latent-plus-diagonal unit tier.
- Added companion coverage that pure-diagonal Sigma tiers still receive finite
  Wald bounds.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R", reporter = "summary")'
```

Result: non-heavy profile CI file skipped as expected.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R", reporter = "summary", desc = "Wald Sigma_unit does not attach Psi-only bounds to latent total variance")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R", reporter = "summary", desc = "Profile on Sigma_unit (pure-diag tier) gives finite bounds")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
```

Result: targeted heavy Sigma Wald guard passed; pure-diag Sigma profile/Wald
block passed; profile-to-bootstrap nsim/seed control regression passed.

## Rose Verdict

OK as an inference honesty repair. This does not add a Wald approximation for
reduced-rank total Sigma, mixed-family intervals, profile calibration, or
bootstrap coverage evidence.

## Next

Continue inference hardening with small bounded issues such as phylo-signal
fallback labelling (#654) or profile-cross-rho tie handling (#643), or move to
non-Gaussian semantics such as VP residual accounting (#615).
