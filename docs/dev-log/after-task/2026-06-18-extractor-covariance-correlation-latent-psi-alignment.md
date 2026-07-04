# After Task: Extractor and Covariance-Correlation Latent-Psi Alignment

**Date:** 2026-06-18 17:39 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Goal

Align extractor docs/tests and the covariance-correlation article with the new
ordinary `latent()` default: no-Psi fits must now be requested with
`latent(..., residual = FALSE)`.

## Implemented

- Updated `extract_Sigma()` prose and advisory notes so no-Psi means
  `residual = FALSE`, not "missing unique()".
- Updated extractor tests to use `residual = FALSE` for no-Psi fixtures.
- Updated `extract_phylo_signal()` advisory text for the ordinary
  non-phylogenetic Psi tier.
- Rewrote the covariance-correlation article's worked comparison:
  `Model A` is now the no-Psi control, and `Model B` is default ordinary
  `latent()`.

## Mathematical Contract

The ordinary decomposition is:

```text
Sigma = Lambda Lambda^T + Psi
```

The no-Psi subset is:

```r
latent(..., residual = FALSE)
```

This slice changes R documentation, tests, and tutorial formulas only. No TMB
likelihood, covariance parameterization, extractor return shape, or
`part = "unique"` value changed.

## Files Changed

- `R/extract-sigma.R`
- `R/extract-omega.R`
- `tests/testthat/test-extract-sigma.R`
- `tests/testthat/test-mixed-family-extractor.R`
- `tests/testthat/test-m1-3-extract-sigma-mixed-family.R`
- `man/extract_Sigma.Rd`
- `vignettes/articles/covariance-correlation.Rmd`
- `pkgdown-site/articles/covariance-correlation.html`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|mixed-family-extractor", reporter = "summary")'`
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|extract-sigma|mixed-family-extractor", reporter = "summary")'`
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|mixed-family-extractor|m1-7-extract-omega|phylo-signal", reporter = "summary")'`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- `tail -5 man/extract_Sigma.Rd && grep -c '^\\keyword' man/extract_Sigma.Rd`
- `git diff --check`

All tests/checks above passed. Heavy extractor / phylo-signal tests skipped as
expected behind their existing heavy gates.

## Tests Of The Tests

The extractor test failed before this fix: `test-extract-sigma.R` expected a
"missing unique" advisory from a plain `latent()` fit, but the new parser
correctly auto-emitted Psi. The repaired test now explicitly requests
`residual = FALSE` and asserts the no-Psi advisory and total/shared equality.

## Consistency Audit

- `rg -n 'without unique|without `unique\\(\\)`|no-unique|no unique|missing-unique|missing unique|fit has only latent\\(\\)|no `unique\\(\\)` term|add `\\+ unique|Refit with `\\+ unique|reminding the user to add `\\+ unique|latent\\(0 \\+ trait \\| unit, d = K\\).*no' R tests/testthat man NEWS.md README.md docs/design docs/dev-log/dashboard vignettes`
  found only intentional remaining contexts: augmented non-Gaussian
  reaction-norm prose, OLRE/standalone explicit-unique examples, ordinal
  no-unique unit test comments, and source-specific spatial latent wording.
- `rg -n 'residual = FALSE|default latent|no-Psi|ordinary latent|latent\\(\\).*Psi' vignettes/articles/covariance-correlation.Rmd pkgdown-site/articles/covariance-correlation.html R/extract-sigma.R man/extract_Sigma.Rd R/extract-omega.R tests/testthat/test-extract-sigma.R tests/testthat/test-mixed-family-extractor.R`
  confirmed the updated source, rendered HTML, Rd, extractor prose, and tests.

## Team Learning

Rose caught the status-story failure: passing parser tests were not enough while
extractor tests and the main covariance tutorial still taught the old no-Psi
meaning of ordinary `latent()`. Pat's reader path is now simpler: write
ordinary `latent()` for the full decomposition; write `residual = FALSE` only
for the control fit that intentionally removes Psi.

## Status Inventory

The slice updates public tutorial and extractor surfaces only. Validation row
anchors remain FG-04 / FG-06 for ordinary latent/decomposition grammar, FG-05 /
FG-07 for compatibility diagonal syntax, and EXT extractor rows for the existing
return-shape contract. No validation row was promoted.

## Roadmap Tick

N/A. This is cleanup required by the ordinary latent-Psi fold, not a roadmap
promotion.

## GitHub Issue Ledger

No issue or PR was mutated.

## Known Limitations

- No `unique()` API removal.
- No source-specific or kernel latent-Psi fold.
- No `part = "unique"` rename.
- No `common =` replacement.
- No free-correlation reaction-norm redesign.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Actions

Continue the `unique()` deprecation/removal plan with source-specific fold
decisions, kernel compatibility strategy, extractor naming, `common =`
migration, and eventual parser/export removal.
