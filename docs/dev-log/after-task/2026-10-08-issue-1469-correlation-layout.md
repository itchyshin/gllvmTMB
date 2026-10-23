# After Task: Issue 1469 correlation pair layout

**Branch**: `codex/issue-1469-correlation-output`
**Date**: `2026-10-08`
**Roles (engaged)**: Ada, Pat, Rose (self-review perspectives)

## 1. Goal

Reproduce issue #1469 and make the symmetric correlation outputs easy to find.

## 2. Implemented

The extractor help and covariance article now explain the unique-pair layout,
why the endpoint items occur in only one name column, and why direct tile plots
look incomplete. Examples show the existing symmetric heatmap, full matrix,
and all-cell table. A synthetic ordinal regression test exercises those routes
with non-alphabetical factor levels.

### Mathematical contract

No likelihood, public R API, formula grammar, family, or default changed.
For p traits the unique-pair table has p(p-1)/2 rows. The full matrix is
symmetric; the all-cell table has p squared rows. Liability-scale correlations
are distinct from Pearson correlations of observed ordinal scores.

## 4. Files Touched

- `R/extract-correlations.R`: roxygen help and examples only.
- `man/extract_correlations.Rd`: corresponding generated help.
- `vignettes/articles/covariance-correlation.Rmd`: runnable matrix examples.
- `docs/design/06-extractors-contract.md`: explicit layout contract.
- `tests/testthat/test-correlation-pair-layout.R`: 15 assertions.
- `NEWS.md`: documentation correction receipt.
- `docs/dev-log/check-log.md`: verification receipt.
- This after-task report.

## 3a. Decisions and Rejected Alternatives

Preserve unique-pair output. Duplicating every pair by default would change
existing summaries, joins, interval tables, and pair counts. The full output
and symmetric plot already exist; expose them in the help rather than adding
a redundant API. No numerical defect was reproduced.

## 5. Checks Run

The public issue example was replayed with d=1 because d was undefined and
the fitted object was not assigned in the posted code. It produced 28 pairs
for 8 traits; the maximum absolute matrix asymmetry was zero. The full
extractor returned 64 cells. The rendered heatmap was inspected visually.
These results concern output layout, not fit quality or latent-rank selection.

`testthat::test_file("tests/testthat/test-correlation-pair-layout.R")`:
15 pass, zero failures. Tested current source R functions with the installed
0.7.1 native DLL; no compiled source changed. The initial installed-package
probe also passed all 15 assertions.

`roxygen2::roxygenise(roclets="rd", load_code=roxygen2::load_source)`:
completed. Unrelated generated Rd drift was restored from HEAD.

`pkgdown::check_pkgdown()`: blocked by the existing missing reference index
entry for `sigma.gllvmTMB_multi`. The tracked topic and reference configuration
are unchanged by this patch. Pandoc also reported existing mathml deprecation
warnings. This is not a clean whole-site check.

Article HTML rendering and Rd parsing: both completed successfully.
The supplied-data heatmap was visually inspected; all eight items appear on
both axes, with matching reversed cells.
Full R CMD check was not run locally for this documentation/test-only patch.

## 6. Tests of the Tests

Prophylactic test, not a red-green numerical repair: existing behavior passed
before documentation edits. The all-cell row count catches a missing triangle;
cell-to-matrix equality catches wrong item labels or ordering; pair union catches
a dropped item; the built heatmap checks that both axes include every item.
No tolerances were widened and collaborator data were not added to tests.

## 8. Consistency Audit

`rg -n 'unique pairs|symmetric|entries = "all"' R/extract-correlations.R
man/extract_correlations.Rd vignettes/articles/covariance-correlation.Rmd
docs/design/06-extractors-contract.md`: routes and wording agree.
README, ROADMAP, NAMESPACE and pkgdown navigation introduce no new API here.
No conventional argument or default changed. Rose self-review verdict: OK for
this narrow documentation claim; the whole-site index blocker remains separate.

## 7. Roadmap Tick

N/A: no capability or validation-coverage row promoted.

## 7a. Issue Ledger

Inspected https://github.com/itchyshin/gllvmTMB/issues/1469.
No issue comment posted and issue not closed by this task.

## 9. What Did Not Go Smoothly

The earlier chat explanation did not point directly to the existing package
plot. The issue title calls the pair table a matrix, which obscured the output
contract. The supplied reproduction needs an explicit d and fit assignment.
The first Git restore was blocked by filesystem sandboxing; unneeded generated
files were restored by reading their HEAD contents without touching the index.

## 11. Team Learning

Ada verified the example rather than assuming a numerical defect from the
screenshot. Pair tables and matrices need distinct, visible explanations.

Pat's self-review used the shortest supported plotting call. Users should
find it from the extractor help, without writing a manual mirroring step.

Rose's self-review checked the roxygen, generated help, article and contract
against the existing extractor. No independent agent review was performed.

## 10. Known Residuals

The original latent rank was unspecified; the replay used d=1. Symmetry does
not establish statistical adequacy, convergence, or interval coverage. The
whole-site reference-index check remains blocked as described above. No merge,
release, or public reply is implied by this local verification.

Style assessment: self-review 2/10 perceived AI-like style; scientific, factual
and reference gates pass for this narrow report. This is not authorship proof.

## 12. Cross-Product Coverage

This change does NOT cover latent-rank selection, interval calibration,
other providers, Julia parity, missing-data handling or penalty inference.
R output layout only. No Julia engine, bridge interface, native likelihood,
family, or formula changes. Existing Julia point-only documentation remains
unchanged; this test exercises the native R ordinal output.
