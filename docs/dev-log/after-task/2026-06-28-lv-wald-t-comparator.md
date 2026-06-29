# After Task: LV Gaussian Wald t Comparator

## Goal

Add the small-N t-based comparator requested by the maintainer to the
Design 73 ordinary Gaussian `B_lv` coverage harness, without changing the
public claim that interval calibration is still pending.

## Implemented

`dev/lv-wald-coverage.R` now emits interval rows by method. The existing
normal-critical Wald path is labelled `wald_z`, and the new unit-df
t-critical comparator is labelled `wald_t_unit`. Both methods use the same
native TMB `ADREPORT(B_lv_unit)` standard errors and the same trait-scale
truth target, `B_lv = Lambda alpha^T`; only the critical value differs.

The summariser now groups by `cell_id`, `target_id`, and `interval_method`,
keeps `critical_df` and `critical_df_source`, and retains the historical
`passes_wald_coverage_band` alias while making the method-neutral
`passes_coverage_band` column primary. The CLI accepts
`--interval-methods=wald_z,wald_t_unit`; old result files without
`interval_method` are treated as `wald_z` for backward compatibility.

## Mathematical Contract

The target is unchanged:

```text
z_i = M_i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

`wald_z` uses `qnorm((1 + level) / 2)`. `wald_t_unit` uses
`qt((1 + level) / 2, df = n_units - d - 1)` with a lower bound of one
degree of freedom. The t row is a comparator for the upcoming production
coverage grid, not a derivation that the small-sample reference distribution
is exact.

## Files Changed

- `dev/lv-wald-coverage.R`
- `tests/testthat/test-lv-wald-coverage-harness.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-28-lv-wald-t-comparator.md`

## Checks Run

- `air format dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R`
  -> PASS.
- `Rscript --vanilla -e 'invisible(parse("dev/lv-wald-coverage.R")); cat("parse-ok\n")'`
  -> PASS.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS with the opt-in live smoke skipped.
- `GLLVMTMB_LV_WALD_SMOKE=true NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary")'`
  -> PASS, including the one-fit smoke.
- `rm -rf /tmp/gllvmtmb-lv-t-coverage-smoke-seed2 && GLLVMTMB_LV_WALD_COVERAGE_CLI=true NOT_CRAN=true Rscript --vanilla dev/lv-wald-coverage.R --mode=cell --cell=gaussian-d1-n72-t3 --n-reps=1 --seed-base=2 --rep-start=1 --rep-end=1 --results-dir=/tmp/gllvmtmb-lv-t-coverage-smoke-seed2`
  -> PASS after adding source-checkout loading; wrote six summary rows
  (three `B_lv` trait targets by two interval methods).
- `git diff --check` -> PASS.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m34.4s with 0 errors, 0 warnings, and
  0 notes. As in the prior slices, `devtools::check()` did not re-document
  because local roxygen2 8.0.0 differs from declared 7.3.2; no roxygen files
  changed in this slice.

## Tests Of The Tests

The new interval-method test checks the method registry, the unit-df formula,
the normal and t critical values, that the t critical is larger than the
normal critical in the small-N fixture, and the invalid-method error path.

The denominator test now duplicates the same failed-fit rows across both
interval methods. It would fail if the summariser pooled methods, dropped
failed fits, or computed MCSE from the wrong eligible denominator.

## Consistency Audit

- `rg -n 'wald_t_unit|interval_method|critical_df|passes_coverage_band|passes_wald_coverage_band' dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R`
  -> REVIEWED; expected implementation and test hits only.
- `rg -n 'coverage (passed|validated|calibrated)|calibrated intervals|complete.*coverage|t-based.*(validated|covered|calibrated)|t-critical.*(validated|covered|calibrated)' dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R docs/design/35-validation-debt-register.md docs/dev-log/after-task/2026-06-28-lv-wald-coverage-harness.md`
  -> REVIEWED; no new t-based coverage claim. Existing design rows still say
  interval calibration is pending.
- `rg -n '500-rep|500 reps|500L|production_n_reps|LV_WALD_DEFAULT_N_REPS|MCSE|failed-fit|denominator' dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R docs/dev-log/after-task/2026-06-28-lv-wald-coverage-harness.md`
  -> REVIEWED; production remains 500 reps/cell and the denominator fields
  are retained.
- `rg -n 'B_lv|alpha|Lambda|rotation|raw axis|ADREPORT|sdreport' dev/lv-wald-coverage.R tests/testthat/test-lv-wald-coverage-harness.R docs/design/35-validation-debt-register.md`
  -> REVIEWED; the interval target remains `B_lv`, not raw `alpha` or raw
  `Lambda`.

## What Did Not Go Smoothly

The first CLI smoke failed when raw `Rscript dev/lv-wald-coverage.R` could not
find an installed `gllvmTMB` package. The runner now calls
`pkgload::load_all(".")` when it is launched from a source checkout and the
package namespace is not installed.

## Team Learning

Fisher: the t-critical comparator may improve small-N coverage, but it should
be admitted by the same 500-rep grid and MCSE rule as the normal-critical Wald
row.

Curie: long-format result rows over `interval_method` make the future DRAC or
Totoro table easier to compare without rerunning fits.

Rose: status docs must say "comparator wired" rather than "t coverage works".

## Known Limitations

No production coverage grid has run in this slice. No profile/bootstrap rescue
was added. No binomial, non-Gaussian, mixed-family, mask, `X + X_lv`, or
source-specific `lv` interval claim changed.

## Next Actions

Run the Gaussian `B_lv` coverage campaign at >=500 reps/cell for both
`wald_z` and `wald_t_unit`, then decide whether the t comparator is enough for
small-N cells or whether profile/bootstrap intervals need to become the next
inference slice.
