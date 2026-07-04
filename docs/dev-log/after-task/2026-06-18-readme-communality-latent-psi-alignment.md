# After Task: README and Communality Latent-Psi Alignment

## Goal

Move the first-click public story and communality extractor prose one step
further away from explicit ordinary `unique()` after the ordinary `latent()`
Psi fold.

## Implemented

- Updated `README.md` so the smoke-test and Tiny examples use ordinary
  `latent()` alone for the full Gaussian decomposition.
- Updated README prose to say ordinary `latent()` carries `Psi` by default and
  `latent(..., residual = FALSE)` is the old no-residual subset.
- Updated `traits()` roxygen so the primary wide shorthand example uses
  `latent(1 | individual, d = K)` without an explicit `unique()` term, while
  still documenting `unique(1 | individual)` as compatibility syntax.
- Updated `extract_communality()`, `extract_ICC_site()`,
  `profile_ci_communality()`, and `profile_communality()` prose/errors to use
  the new no-Psi wording.
- Migrated extractor test fixtures that only needed diagonal/Psi structure:
  standalone diagonal fixtures now use `indep()`, and ordinary decomposed
  covariance fixtures use default `latent()`.

## Mathematical Contract

The ordinary decomposition remains:

```text
Sigma = Lambda Lambda^T + Psi
```

New ordinary examples use:

```r
latent(..., d = K)
```

The no-Psi subset is explicit:

```r
latent(..., residual = FALSE)
```

This slice did not change likelihood parameterisation, extractor return shape,
`part = "unique"`, source-specific `*_latent()` folds, `kernel_unique()`, or
`common =`.

## Files Changed

- `README.md`
- `R/traits-keyword.R`
- `R/extractors.R`
- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `tests/testthat/test-extractors.R`
- `tests/testthat/test-extractors-extra.R`
- `man/traits.Rd`
- `man/extract_communality.Rd`
- `man/extract_ICC_site.Rd`
- `man/extract_ordination.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks Run

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since='6 hours ago'`
  - Recent commits were the current coevolution / mission-control stack.
- `git diff --check`
  - Clean before edits.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Regenerated changed Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "extractors|extract-communality|profile-derived|profile-ci|confint-derived", reporter = "summary")'`
  - Passed after fixing two dangling formula `+` operators exposed by the first
    rerun; expected heavy skips remained.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|unique-family-deprecation|extractors|extract-communality", reporter = "summary")'`
  - Passed with expected heavy skips and informational per-row diagonal
    `sigma_eps` messages.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found.`
- `tail -5 man/extract_communality.Rd; grep -c '^\\keyword' man/extract_communality.Rd`
  - No runaway keyword block; keyword count 0.
- `tail -5 man/extract_ICC_site.Rd; grep -c '^\\keyword' man/extract_ICC_site.Rd`
  - Expected internal keyword only; keyword count 1.
- `tail -5 man/extract_ordination.Rd; grep -c '^\\keyword' man/extract_ordination.Rd`
  - No runaway keyword block; keyword count 0.
- `tail -5 man/traits.Rd; grep -c '^\\keyword' man/traits.Rd`
  - No runaway keyword block; keyword count 0.

## Tests Of The Tests

The focused extractor rerun failed before the fixture cleanup because formula
edits left dangling `+` operators in `test-extractors-extra.R` and
`test-extractors.R`. That failure verified the tests still parse and execute
the touched fixtures rather than merely scanning text.

## Consistency Audit

- `rg -n 'level has only `latent\\(\\)` and no `unique\\(\\)`|latent-only fits|refit with `\\+ unique|requires both .*latent\\(\\).*unique\\(\\)|set by `unique\\(\\)`|latent\\(0 \\+ trait \\| site, d = [12]\\) \\+\\s*unique|unique\\(0 \\+ trait \\| site\\)' README.md R/traits-keyword.R R/extractors.R tests/testthat/test-extractors.R tests/testthat/test-extractors-extra.R man/extract_communality.Rd man/extract_ICC_site.Rd man/traits.Rd`
  - No hits after the final edits.
- `rg -n 'level has only `latent\\(\\)` and no `unique\\(\\)`|latent-only fits|refit with `\\+ unique|requires both .*latent\\(\\).*unique\\(\\)|set by `unique\\(\\)`|trait-specific residual variance \\(set by `unique\\(\\)`\\)|latent\\(0 \\+ trait \\| site, d = [12]\\) \\+\\s*unique|latent\\(1 \\| individual, d = 1\\) \\+\\s*unique|unique\\(1 \\| individual\\)|unique\\(0 \\+ trait \\| individual\\)' README.md R/traits-keyword.R R/extractors.R R/profile-derived.R R/profile-derived-curves.R tests/testthat/test-extractors.R tests/testthat/test-extractors-extra.R man/extract_communality.Rd man/extract_ICC_site.Rd man/extract_ordination.Rd man/traits.Rd`
  - Remaining hits were the intentional `traits()` compatibility explanation:
    `unique(1 | individual)` still expands for old code while the parser
    remains live.

## What Did Not Go Smoothly

The first test rerun caught dangling formula continuations after deleting
explicit `unique()` lines. This is exactly the kind of small syntax regression
that makes local tests cheaper than confidence.

## Team Learning

Rose: the public story had moved in the covariance article, but README and
communality docs still taught old spelling. Pat: a new user should now see one
ordinary `latent()` term for the safe first model, not a deprecated pair on
the first screen.

## Known Limitations

- No `unique()` API removal.
- No source-specific or kernel latent-Psi fold.
- No `part = "unique"` rename.
- No `common =` replacement.
- No free-correlation reaction-norm redesign.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Actions

Continue one slice at a time through remaining public articles and exported
examples, then choose a separate design/API slice for source-specific folds,
`common =`, or extractor naming. Do not expand `kernel_unique()` for Paper 2
multi-kernel coevolution.
