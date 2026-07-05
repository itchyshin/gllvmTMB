# After Task: Sparse Ainv extra-node direct engine

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: Ada / Noether / Fisher / Curie / Grace / Rose / Shannon

## 1. Goal

Fix issue #612 locally: the direct sparse `Ainv` engine must not subset a
precomputed precision matrix to the observed species / animal levels when the
matrix contains extra pedigree ancestors or internal nodes.

## 2. Implemented

- Added `.resolve_sparse_phylo_precision()` in `R/fit-multi.R`.
- Preserved the exact tip-only sparse route and level reordering.
- For extra-node sparse `Ainv`, kept the full precision matrix, computed the
  full covariance-scale log determinant, set `n_aug_phy` to the full sparse
  dimension, and mapped observed levels into the augmented rows via
  `species_aug_id`.
- Added an animal-model regression where the pedigree contains unphenotyped
  ancestors absent from the fitted data.

## 3. Files Changed

- `R/fit-multi.R`
- `tests/testthat/test-pedigree-sparse-ainv-engine.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-sparse-ainv-extra-node-engine.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep the full augmented sparse precision and pass an observed-tip map,
matching the `phylo_tree` / Hadfield route. Rejected alternative: fail loud on
extra sparse rows, as suggested by the issue. Rationale: the TMB engine already
supports `n_aug_phy >= n_species` and `species_aug_id`; using that machinery is
more useful and mathematically correct. Confidence: high for Gaussian sparse
Ainv equivalence; broader non-Gaussian behaviour inherits the same prior path
and remains covered by existing family-specific route tests, not by this slice.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("tests/testthat/test-pedigree-sparse-ainv-engine.R")); cat("parse-ok\n")'
```
Outcome: `parse-ok`.

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-pedigree-sparse-ainv-engine.R", reporter = "summary")'
```
Outcome: passed, including the new unphenotyped-ancestor sparse full-`Ainv`
versus dense marginal-`A` regression.

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-phylo-hadfield.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage3-propto-equalto.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load-all-ok\n")'
git diff --check
```
Outcome: Hadfield sparse-tree path passed; `propto()` sibling test passed with
one pre-existing glmmTMB non-PD-Hessian skip in the combined smoke cell;
`load_all()` passed; whitespace check passed.

## 5. Tests of the Tests

The new regression uses a pedigree with founders/ancestors `i1`-`i8` absent
from the fitted data. It asserts that the sparse route keeps more augmented rows
than observed species, retains the full `Ainv` rownames, maps observed rows with
`species_aug_id`, and matches the dense covariance path's log-likelihood.

## 6. Consistency Audit

```sh
rg -n "Ainv_phy_rr|log_det_A_phy_rr|species_aug_id|n_aug_phy|GMRF|phylo" src/gllvmTMB.cpp R/fit-multi.R tests/testthat/test-pedigree-sparse-ainv-engine.R tests/testthat/test-phylo-hadfield.R
```
Verdict: confirmed the TMB sparse prior already admits `n_aug_phy >= n_species`
and observed-row indexing through `species_aug_id`.

```sh
rg -n "Ainv\\[levs, levs|phylo_vcv\\[levs, levs|Ainv_phy_rr\\s*<-\\s*phylo_vcv\\[levs" R/fit-multi.R tests/testthat
```
Verdict: broad hits are intentional exact tip-only helper subsetting and dense
covariance / `propto()` covariance subsetting, not the old direct sparse-engine
assignment.

```sh
rg -n "Ainv_phy_rr\\s*<-\\s*phylo_vcv\\[levs|Ainv_phy_rr\\s*<-\\s*Ainv\\[levs" R/fit-multi.R tests/testthat
```
Verdict: no remaining old direct sparse-engine precision-subset assignment.

## 7. Roadmap Tick

N/A. This is a correctness repair inside the existing sparse `Ainv` route, not
a public roadmap status promotion.

## 7a. GitHub Issue Ledger

- Inspected issue #612:
  https://github.com/itchyshin/gllvmTMB/issues/612
- Issue #612 remains open upstream because this local fix has not been pushed or
  included in a PR.

## 8. What Did Not Go Smoothly

The tempting small fix was to reject extra sparse rows. The better fix required
checking that the existing TMB prior already had the right augmented-node
machinery from the `phylo_tree` path.

## 9. Team Learning

Ada kept this paired with #636 but separate: direct sparse engine first, dense
`propto()` adapter second.

Noether checked the prior identity: keeping the full precision and integrating
unobserved nodes gives the marginal prior for observed tips; subsetting the
precision conditions on dropped nodes.

Fisher kept the evidence claim to log-likelihood equivalence under a Gaussian
animal fixture with unphenotyped ancestors.

Curie added the regression on the actual failure scenario rather than another
tip-only byte-equivalence case.

Grace verified parser, package load, focused sparse engine tests, Hadfield
tests, propto sibling tests, and whitespace.

Rose kept the public claim unchanged: no new source-specific `lv`, interval, or
compute claim follows from this fix.

Shannon ran the open-PR and recent-log lane check before shared ledger edits.

## 10. Known Limitations And Next Actions

This does not make all sparse precision inputs semantically safe; users still
need rownames/colnames that identify the same unique levels. Next cleanup slices
should continue closing issue-queue correctness tickets and then refresh the
completion matrix for the remaining missing/mixed/structural surfaces.
