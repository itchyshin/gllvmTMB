# After Task: Meta/Pedigree Helper Bug Fixes

## 1. Goal

Land the first preserved low-risk clean-file batch from Claude's
2026-07-04 handover: Groups A and D, covering `block_V()` positive-
definiteness and `pedigree_to_A()` selfing / missing-parent handling.

## 2. Implemented

`block_V()` now checks the compound-symmetric lower bound inside each
multi-row study block. For block size `m`, `rho_within` must satisfy
`rho > -1/(m - 1)`; values at or below that bound abort before an
indefinite known-covariance block can be returned.

`pedigree_to_A()` now treats selfing as two known identical parents, so
`F_i = A[parent,parent] / 2` rather than zero. It also warns when a sire
or dam is referenced but absent from the `id` column, because silently
treating that parent as an unrelated founder can hide incomplete or
mistyped pedigrees.

## 3a. Decisions and Rejected Alternatives

The branch keeps both fixes at the helper layer. It does not change the
`meta_V()` formula grammar, the Gaussian known-covariance likelihood,
the sparse `pedigree_to_Ainv_sparse()` helper, or animal-keyword engine
plumbing. A broader rejection of zero sampling variances in `block_V()`
was left out because issues #656/#657 are specifically about the
within-study correlation bound, and changing zero-variance handling
would alter a separate input contract.

## 4. Files Touched

- `NEWS.md`
- `R/animal-keyword.R`
- `R/two-stage.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-meta-pedigree-pd-fixes.md`
- `tests/testthat/test-block-v-pd.R`
- `tests/testthat/test-pedigree-to-A-inbreeding.R`

## 5. Checks Run

Commands were run on macOS with `NOT_CRAN=true` and
`GLLVMTMB_HEAVY_TESTS=1`.

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-block-v-pd.R", reporter = "summary"); testthat::test_file("tests/testthat/test-block-V.R", reporter = "summary"); testthat::test_file("tests/testthat/test-pedigree-to-A-inbreeding.R", reporter = "summary")'
```

Outcome: passed. `test-block-v-pd.R` ran 6 expectations, existing
`test-block-V.R` ran 19 expectations, and
`test-pedigree-to-A-inbreeding.R` ran 7 expectations.

```sh
Rscript --vanilla -e 'devtools::test(filter = "animal-keyword", reporter = "summary")'
```

Outcome: passed, with one pre-existing skip for the optional `nadiv`
comparison.

```sh
air format R/animal-keyword.R R/two-stage.R tests/testthat/test-block-v-pd.R tests/testthat/test-pedigree-to-A-inbreeding.R
git diff --check
```

Outcome: formatting completed; `git diff --check` passed with no
output.

```sh
rg -n "block_V|pedigree_to_A|meta_V|pedigree_to_Ainv_sparse|animal-keyword|positive-definite|selfing|absent" NEWS.md R/animal-keyword.R R/two-stage.R man _pkgdown.yml docs/design tests/testthat/test-block-v-pd.R tests/testthat/test-pedigree-to-A-inbreeding.R
rg -n "gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|\\bS_B\\b|\\bS_W\\b|\\\\bf S|trio" NEWS.md R/animal-keyword.R R/two-stage.R tests/testthat/test-block-v-pd.R tests/testthat/test-pedigree-to-A-inbreeding.R
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
```

Outcome: Rose-style NEWS scan found the new text scoped to helper
contracts only; broader hits were pre-existing NEWS/history or generated
documentation references. `pkgdown::check_pkgdown()` reported "No
problems found."

```sh
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Outcome: attempted but interrupted after about 14 minutes with no final
summary and no worktree artefacts. Do not count this as passed package
check evidence.

## 6. Tests of the Tests

The new `block_V()` test is a failure-before-fix guard: before the
bound check, the below-bound and boundary `expect_error()` calls would
not error, and at least one accepted block had a non-positive
eigenvalue. The new pedigree test is also failure-before-fix: the
selfed offspring diagonal was `1` instead of `1.5`, and the absent-
parent warning did not exist. The outcross test guards the neighbouring
ordinary-pedigree behaviour.

## 7a. Issue Ledger

Fixed #656 and #657 for `block_V()` positive-definiteness. Fixed #623
for selfing in `pedigree_to_A()`. Fixed #607 by warning on parent IDs
that are referenced but absent from the pedigree `id` column.

## 8. Consistency Audit

Neighbourhood scan:

```sh
rg -n "pedigree_to_A|block_V\\(" tests/testthat R
```

The scan identified existing `test-block-V.R` and
`test-animal-keyword.R` as the relevant regression surfaces, and both
were run. No roxygen block, function signature, exported symbol, formula
grammar, generated Rd file, or validation-debt row changed. NEWS wording
states the IN scope and explicitly excludes grammar, likelihood, sparse
pedigree, and animal-engine changes.

## 9. What Did Not Go Smoothly

The original Claude draft after-task report covered only `block_V()`.
This branch replaces that half-report with a combined report so the
repository does not imply that only #656/#657 were part of the batch.
The formatter also wrapped existing one-line guards inside
`block_V()`, increasing the displayed diff without changing behaviour.

## 10. Known Residuals

Full `devtools::test()` was not run for this helper batch.
`devtools::check()` was attempted but interrupted after about 14
minutes; it is not package-check evidence for this branch. The `nadiv`
comparison in `test-animal-keyword.R` remains skipped because `nadiv`
is not installed in the local environment. The open PR stack #707-#710
also touches `NEWS.md` and `docs/dev-log/check-log.md`, so this PR may
need a simple append-only rebase after those merge.

## 11. Team Learning

Preserved scratchpad fixes should be landed from clean worktrees, not
from the busy Dropbox bridge branch. When combining manifest groups,
rewrite the evidence report to match the actual batch rather than
copying a single-group report forward.
