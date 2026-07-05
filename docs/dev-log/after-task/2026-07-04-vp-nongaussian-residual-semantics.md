# After-Task Report: VP Non-Gaussian Residual Semantics

Date: 2026-07-04 23:45 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #615

## Goal

Prevent `VP()` from adding a Gaussian residual variance share to traits whose
family does not use `sigma_eps` as an observation-scale residual.

## Files Changed

- `R/output-methods.R`
- `man/VP.Rd`
- `tests/testthat/test-ordiplot-VP.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-vp-nongaussian-residual-semantics.md`

## What Changed

- Added `.vp_residual_per_trait()` for the legacy `VP()` residual column.
- `VP()` now adds residual variance only for Gaussian and lognormal traits,
  where `sigma_eps` is an observation-scale residual.
- Pure Poisson/non-Gaussian VP rows no longer get a fake residual column from
  mapped-off `sigma_eps`.
- Mixed Gaussian/Poisson VP output keeps a `residual` column only because one
  trait needs it; the Poisson trait gets residual share zero.
- The roxygen text points users to `extract_proportions()` for family-aware
  latent-scale link residual shares.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/output-methods.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordiplot-VP.R", reporter = "summary")'
```

Result: VP/ordiplot tests passed, including pure Poisson, mixed
Gaussian/Poisson, and lognormal residual-semantics regressions.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE); cat("document-ok\n")'
```

Result: documentation regenerated and `man/VP.Rd` updated.

## Rose Verdict

OK as a legacy variance-share semantics repair. This does not promote
family-aware non-Gaussian variance partitioning beyond the existing
`extract_proportions()` contract, and it does not add interval or calibration
claims.

## Next

Continue the non-Gaussian semantics lane. Candidate adjacent issues include
lognormal response-mean prediction (#614), family/link modal selection in
prediction (#678), and Gamma dispersion wording/parameterisation (#622).
