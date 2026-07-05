# After Task: Structural Latent Positional-Control Parser Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Boole / Curie / Rose / Grace / Shannon`

## 1. Goal

Close the issue #582 silent-fallback class locally: documented positional
control arguments in structural latent helpers should survive formula rewrite
rather than silently falling back to `d = 1`, `unique = FALSE`, or missing
`common = TRUE`.

## 2. Implemented

- Added a small local `.named_or_positional_arg()` helper inside
  `rewrite_canonical_aliases()`.
- Preserved positional `d` for ordinary augmented `latent()`, augmented
  `phylo_latent()`, `animal_latent()`, `spatial_latent()`, and the single
  named-`K` `kernel_latent()` route.
- Preserved positional `unique` for `spatial_latent()` and positional `common`
  for `indep()`.
- Added a parser-only regression that proves `spatial_latent(..., 2, TRUE)`,
  `animal_latent(..., 2, ...)`, `indep(..., TRUE)`, and
  `kernel_latent(..., K = K, 2, ...)` keep the intended rewritten controls.

## 3. Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-canonical-keywords.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-structural-latent-positional-controls.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep the fix inside the formula rewrite layer with a local helper.
Rationale: the bug is in parser/control argument preservation, not in TMB or
model likelihood code. Rejected alternative: add fitted-model smoke tests for
each route; that would be slower and would not isolate the silent rewrite
failure as cleanly. Confidence: high for the parser contract, bounded for any
later integration claims.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/brms-sugar.R")); invisible(parse("tests/testthat/test-canonical-keywords.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-animal-keyword.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-mode-dispatch.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-equivalence.R")'
```

Outcomes:

- Parse check: `parse-ok`.
- `test-canonical-keywords.R`: 96 pass, 0 fail, 0 warn, 3 expected INLA skips.
- `test-animal-keyword.R`: 10 pass, 0 fail, 0 warn, 7 expected CRAN skips.
- `test-spatial-mode-dispatch.R`: 0 fail, 0 warn, 6 expected CRAN skips.
- `test-kernel-equivalence.R`: 38 pass, 0 fail, 0 warn, 0 skip.

## 5. Tests of the Tests

The new parser regression is a direct failure-before-fix guard: before the
helper route, the rewritten calls fell back to defaults such as `d = 1L` and
missing `.spatial_unique_diag` / `common` markers. The test checks the rewritten
call text only, so it is fast and isolates the formula grammar bug.

## 6. Consistency Audit

Final audit command:

```sh
rg -n "issue #582|positional control|spatial_latent\\(0 \\+ trait \\| coords, 2|animal_latent\\(species, 2|indep\\(0 \\+ trait \\| site, TRUE|kernel_latent\\(site, K = K, 2|source-specific.*lv|mixed-family CI|interval calibration" R/brms-sugar.R tests/testthat/test-canonical-keywords.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-07-05-structural-latent-positional-controls.md
```

Verdict: found the intentional parser guard, issue #582 notes, and
claim-boundary language only. No new source-specific `lv`, mixed-family CI, or
interval-calibration promotion is made by this slice.

## 7. Roadmap Tick

N/A. This is a parser truth-lock and issue-debt repair, not a roadmap status
change.

## 7a. GitHub Issue Ledger

- Inspected issue #582 class from the open-issue triage. Local fix and tests
  added, but no GitHub comment or closure was made because this branch remains
  unpublished.

## 8. What Did Not Go Smoothly

- `testthat::test_file(..., filter = ...)` is unsupported by the local
  testthat version.
- A first full `test_file()` run omitted `pkgload::load_all(".")`, so it tested
  the installed namespace and reported stale failures. The corrected source
  checkout harness is green.

## 9. Team Learning

Ada kept the slice narrow: repair the parser truth before widening model claims.
Boole caught the real failure mode: the call rewrite was treating named controls
as the only source of truth. Curie kept the regression parser-only, making it
cheap enough to run often. Rose kept the validation register from overclaiming:
this is not source-specific `lv`, interval calibration, or mixed-family CI
evidence. Grace recorded the exact harness needed to avoid testing the installed
namespace. Shannon left the public issue untouched until the unpublished branch
is pushed or reviewed.

## 10. Known Limitations And Next Actions

No fitted-model integration or recovery grid was added. The next useful slice is
still to continue the live issue triage, with likely candidates including the
phylo sparse-Ainv sign/variance issues and remaining missing-data correctness
items. No Totoro/DRAC work is warranted for this parser guard.
