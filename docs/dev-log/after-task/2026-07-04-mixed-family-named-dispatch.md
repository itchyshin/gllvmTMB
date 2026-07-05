# After-Task Report: Mixed-Family Named-List Dispatch Repair

Date: 2026-07-04 21:18 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Issue: #610

## Goal

Prevent silent wrong-family assignment when a mixed-family `family = list(...)`
argument is named but ordered differently from the selector levels in
`family_var`.

## Files Changed

- `R/fit-multi.R`
- `R/families.R`
- `man/families.Rd`
- `tests/testthat/test-stage37-mixed-family.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-mixed-family-named-dispatch.md`

## What Changed

- Added `.align_mixed_family_list()` so named mixed-family lists are reordered
  to match the selector levels before `family_id_vec`, `link_id_vec`, and
  `family_per_row` are constructed.
- Preserved the legacy contract for unnamed lists: their order must match the
  selector levels.
- Added a loud guard for partially named family lists.
- Updated the family help text and generated Rd to document the named-list
  alignment rule.
- Strengthened Stage 37 tests to check row-wise family IDs, not only aggregate
  counts.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("R/families.R")); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R", reporter = "summary")'
```

Result: Stage 37 mixed-family tests passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-m1-2-mixed-family-fixture.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-mixed-family-extractor.R", reporter = "summary")'
```

Result: heavy/NOT_CRAN mixed-family fixture and extractor checks passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-traits-keyword.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE); cat("document-ok\n")'
```

Result: traits parser tests passed and documentation regenerated.

## Rose Verdict

OK as an existing-surface correctness repair. This does not promote mixed-family
CIs, masked mixed-family fits, fixed-effect-X mixed-family fits, or calibration
claims.

## Next

Continue the missing/mixed correctness lane. High-value adjacent candidates are
per-cell weights under `missing = "include"` (#589), duplicate long-row guards
(#642), and non-Gaussian positivity guards (#659).
