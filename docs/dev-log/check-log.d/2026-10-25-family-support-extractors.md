# Check-log: family support and extractor help (#1356, #1579)

**Goal:** Confirm the new support checks abort before fitting, the extractor Rd pages match behaviour, and the full suite plus R CMD check stay green.

**Commands:**

    Rscript --vanilla -e 'devtools::document(quiet = TRUE)'

    NOT_CRAN=true Rscript --vanilla -e '
      Sys.setenv(NOT_CRAN = "true")
      testthat::test_file("tests/testthat/test-family-support-checks.R")
      testthat::test_file("tests/testthat/test-issue-1579-extractor-help-text.R")
    '

    rg -n "because this helper is point-estimate only|C0 coevolution prototype|C2 recovery" R man tests NEWS.md
    rg -n "non-negative integer|proportion plus" R/fit-multi.R R/gllvmTMB.R NEWS.md tests/testthat/test-family-support-checks.R
    rg -n "—" R/fit-multi.R R/extract-sigma-table.R R/kernel-helpers.R tests/testthat/test-family-support-checks.R tests/testthat/test-issue-1579-extractor-help-text.R

    NOT_CRAN=true Rscript --vanilla -e 'devtools::test()'
    Rscript --vanilla -e 'devtools::check(document = FALSE, args = "--no-manual")'

**Results:**

- `devtools::document()`: wrote `man/extract_Sigma_table.Rd`, `man/gllvmTMB.Rd`, `man/make_cross_kernel.Rd`. Unrelated `NAMESPACE` / `DESCRIPTION` / `tidy.gllvmTMB_multi.Rd` churn from roxygen2 8.1.1 was reverted.
- Focused support checks: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 20 ]`
- Focused #1579 Rd checks: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 23 ]`
- Stale-wording scans: forbidden help phrases remain only as negative tests and the NEWS line that records their removal. No em dash in the new prose.
- Full `devtools::test()` from the source tree (NOT_CRAN=true): the package files that this PR owns were green (`family-support-checks` 20/20, `issue-1579-extractor-help-text` 23/23). Three other source-tree files that read `dev/` also ran: `test-m3-pilot-manifest.R` failed until `R CMD INSTALL` put `gllvmTMB` on the library path, then `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 147 ]`; `test-interval-calibration-ci09.R` needs historical SHA `822024b1` which is not on this checkout; `test-interval-calibration-claims.R` fails on this SHA because `vignettes/articles/current-limits.Rmd` lacks a required claim sentence. Those three files are outside this slice (`dev/` is in `.Rbuildignore`).
- `R CMD check --no-manual --as-cran` on `gllvmTMB_0.8.0.9000.tar.gz`: **Status: 4 NOTEs, 0 WARNINGs, 0 ERRORs**. Tests: `[ FAIL 0 | WARN 54 | SKIP 2068 | PASS 22640 ]`. Examples and `\donttest` examples OK. The four notes are incoming-feasibility (0.8.0.9000), two already-tracked snapshot path lengths, `TMB:::EvalADFunObject`, and `-mno-omit-leaf-frame-pointer`.

**Not run:** article rebuilds (`pkgdown::build_articles`). No formula-parser change.

**Claim boundary:** these checks show the named families abort on unsupported `y` and that the listed help pages no longer contradict behaviour. They do not promote a validation-debt row or claim coverage for every family.

## Follow-up (R review on PR #1689)

**Goal:** tolerance on binomial/betabinomial integrality, classed `gllvmTMB_response_support` errors, and a NEWS breaking-change line for proportion plus `weights = n`.

**Commands (follow-up):**

    NOT_CRAN=true Rscript --vanilla -e '
      Sys.setenv(NOT_CRAN = "true")
      testthat::test_file("tests/testthat/test-family-support-checks.R")
    '
    R CMD check --no-manual --as-cran gllvmTMB_0.8.0.9000.tar.gz

**Results (follow-up):**

- Focused `test-family-support-checks.R` after `devtools::load_all()`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 19 ]`. The new near-integer cell (`3 - 4e-10`) is accepted; invalid rows stay classed `gllvmTMB_response_support`.
- `R CMD check --no-manual --as-cran` on `gllvmTMB_0.8.0.9000.tar.gz`: **Status: 4 NOTEs, 0 WARNINGs, 0 ERRORs**. Tests: `[ FAIL 0 | WARN 54 | SKIP 2069 | PASS 22638 ]`. Examples and `\donttest` examples OK. The four notes are unchanged (incoming-feasibility 0.8.0.9000, two snapshot path lengths, `TMB:::EvalADFunObject`, `-mno-omit-leaf-frame-pointer`). The extra SKIP is the new `skip_on_cran()` near-integer cell.
