# After-task report: Paper 2 coevolutionary module extractor

Date: 2026-06-18 20:54 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Close the next narrow Paper 2 coevolution model gap by adding a point-estimate
module extractor for standardized cross-lineage covariance blocks, matching the
paper note's estimand:

`R = Sigma_H^{-1/2} Gamma Sigma_P^{-1/2}` followed by an SVD of `R`.

## Files touched

- `R/extract-sigma.R`
- `tests/testthat/test-coevolution-recovery.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `NAMESPACE`
- `man/extract_coevolution_modules.Rd`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- Added exported `extract_coevolution_modules()`.
- The helper standardizes a named component's cross-lineage `Gamma` block using
  the within-lineage shared covariance blocks, then returns:
  - standardized `R`;
  - singular values and squared shares;
  - row-lineage trait-axis loadings;
  - column-lineage trait-axis loadings.
- Added fake-fit tests for exact SVD math, fixed-`rho` effect scaling,
  one-module truncation, and trait validation.
- Added real-fit COE-04 coverage inside the near-orthogonal two-kernel recovery
  gate for finite ordered module singular values in both named components.
- Updated the capability ledger and Design 65 to mark module extraction as
  point-estimate evidence only.

## Definition-of-done accounting

1. Implementation: local branch implementation only; not merged to `main`.
2. Simulation recovery: no new DGP; the real-fit module gate rides the existing
   near-orthogonal COE-04 recovery fixture, and fake-fit tests check the exact
   standardized-SVD contract.
3. Documentation: roxygen/Rd generated; `_pkgdown.yml`, NEWS, Design 65, and
   Design 35 updated.
4. Runnable example: no new article example in this narrow slice. The helper is
   documented with a `\dontrun{}` example and will need article integration
   before public Paper 2 promotion.
5. Check-log: `docs/dev-log/check-log.md` has the 20:54 MDT entry with exact
   commands and outcomes.
6. Review pass: no TMB likelihood or parser grammar changed. This was an R
   extractor/test/docs slice; the remaining scientific scope is explicitly
   partial in Design 35 and the dashboard.

## Validation

- `Rscript --vanilla -e 'parse("R/extract-sigma.R"); invisible(NULL)'`
  passed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  `NAMESPACE` and `man/extract_coevolution_modules.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-recovery", reporter = "summary")'`
  passed with 2 expected heavy skips.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-recovery|coevolution-two-kernel", reporter = "summary")'`
  passed with expected heavy skips.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  passed after formatting and documentation regeneration.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` reported `No problems found.`

## Still open

- Module uncertainty and biological rank calibration.
- Formal null-threshold calibration and interval coverage.
- In-engine `rho` estimation and profile intervals.
- Broader non-Gaussian and mixed-family recovery beyond the current narrow
  Poisson cells.
- Mechanistic simulation, empirical trait/data audit, and Paper 2 figure path.
- Post-arc `unique()` / `*_unique()` deprecation and compatibility cleanup.
