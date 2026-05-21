# After-task: example object contract and morphometrics fixture

**Date:** 2026-05-20
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230
**Slices:** 7 and 8
**Active reviewers:** Ada, Pat, Boole, Curie, Fisher, Grace, Rose.
**No spawned subagents were running in this slice.**

## Goal

Build the first prepared teaching fixture so Get Started and Morphometrics can
start from data, truth, formulas, and interpretation instead of a long
data-generating block.

## Implemented

- Added `docs/design/52-example-object-contract.md`.
- Added `data-raw/examples/make-morphometrics-example.R`.
- Generated `inst/extdata/examples/morphometrics-example.rds`.
- Added `tests/testthat/test-example-morphometrics.R`.
- Updated Get Started to load the morphometrics object, show the long and wide
  formulas, fit both forms, and compare likelihoods.
- Updated `vignettes/articles/morphometrics.Rmd` to load the object, show the
  truth table, fit long and wide forms from the stored formulas, and compare
  fitted covariance to known truth.
- Removed the 20-replicate simulation loop from Morphometrics and replaced it
  with a clearer boundary: this page is a teaching example, not a coverage
  study.
- Updated `ROADMAP.md` slices 7 and 8 and the article gate matrix row for
  Morphometrics.

## Files Changed

- `docs/design/52-example-object-contract.md`
- `data-raw/examples/make-morphometrics-example.R`
- `inst/extdata/examples/morphometrics-example.rds`
- `tests/testthat/test-example-morphometrics.R`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/morphometrics.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/check-log.md`

This slice did not change exported functions, likelihoods, formula grammar, or
generated Rd files.

## Tests And Checks

- `Rscript data-raw/examples/make-morphometrics-example.R`
  - First attempt failed because base `diag()` does not support
    `dimnames =`; fixed by assigning `dimnames(Psi)` after construction.
  - Final run saved the RDS.
- `Rscript --vanilla -e 'devtools::test(filter = "example-morphometrics")'`
  - Passed: 26 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed: `No problems found.`
- Targeted render of Get Started, Morphometrics, and Roadmap
  - Passed; only pre-existing missing `../logo.png` warnings.
- `git diff --check`
  - Clean.
- `gh issue comment 230 --repo itchyshin/gllvmTMB --body-file -`
  - Posted slice update:
    <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4503754431>.

## Tests Of The Tests

The new test file is a contract test and a feature-combination test:

- It verifies the shipped object has the required schema.
- It checks long and wide data shapes agree.
- It rebuilds both long and wide `gllvmTMB()` fits from the object.
- It checks the two likelihoods match.
- It checks optimizer convergence and gradient status.
- It checks fitted covariance recovers the known off-diagonal truth and keeps
  relative Frobenius error below the documented threshold.

This would catch broken object paths, stale formulas, long/wide grammar drift,
trait-level ordering problems, and a fixture whose simulated truth no longer
matches the article claim.

## Consistency Audit

Exact scans:

```sh
rg -n 'simulate_site_trait\(|set.seed\(|rnorm\(|psi2_true|Recovery across replicates|temporary setup' vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd
```

Verdict: no hits.

```sh
rg -n 'articles/(animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart|lambda-constraint|profile-likelihood-ci|mixed-family-extractors|ordinal-probit|troubleshooting-profile|stacked-trait-gllvm|gllvm-vocabulary)' README.md vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd
```

Verdict: no hits.

```sh
rg -n 'S_true|S only|matrix `S`|diag\(S\)|\\bf S|\bS_B\b|\bS_W\b|psi_t\^2|psi2_true' README.md vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd docs/design/52-example-object-contract.md data-raw/examples/make-morphometrics-example.R tests/testthat/test-example-morphometrics.R
```

Verdict: no hits.

Rendered HTML source scan:

```sh
rg -n "morphometrics-example|prepared morphometrics|formula_long|formula_wide|value ~ 0 \+ trait|traits\(length|Frobenius|Current Status|Start Here" pkgdown-site/index.html pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/morphometrics.html
```

Verdict: the rendered HTML contains the prepared object, both formulas, and
the truth-vs-fit covariance check.

## Reviewer Notes

Ada: The object contract now gives future articles a repeatable fixture shape.

Pat: Get Started is less punishing. The first example starts from a named
object instead of making readers parse a simulation before fitting.

Boole: Long and wide formulas are stored in the object, printed in the HTML,
and tested together.

Curie: The fixture is deterministic and the test checks both shape and
recovery.

Fisher: Morphometrics now names the boundary between a teaching example and a
simulation coverage claim.

Grace: Targeted tests, pkgdown check, and targeted renders passed.

Rose: The fixture prevents future article drift: if the object, formulas, or
truth change, the test should fail before the page silently misleads readers.

## Known Limitations

- The object contract is implemented for Morphometrics only.
- The visual HTML still needs maintainer review in a browser.
- The figures are rendered but not yet Florence-reviewed to publication
  quality.
- Full `devtools::test()` and `devtools::check()` were not run for this
  docs/data-fixture slice.

## Next Safe Slice

Use the same object pattern for `covariance-edge-cases-example.rds`, then
revise Covariance/correlation and Pitfalls around that object. After that,
do the maintainer HTML review for Get Started and Morphometrics.
