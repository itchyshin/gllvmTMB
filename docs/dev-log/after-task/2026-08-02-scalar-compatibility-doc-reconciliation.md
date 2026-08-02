# After Task: Reconcile scalar compatibility documentation

**Branch**: `codex/reconcile-scalar-docs`  
**Date**: 2026-08-02  
**Roles (engaged)**: Ada, Boole, Pat, Rose, Grace

## 1. Goal

Reconcile the current documentation after the spatial-guide correction: teach
`spatial_indep(..., common = TRUE)` as the canonical shared-variance form,
retain `spatial_scalar()` only as soft-deprecated compatibility syntax, and
make the mesh requirement consistent wherever spatial geometry is explained.

## 2. Implemented

The exported `spatial_scalar()` reference now has a lifecycle deprecation
badge, a migration call, and a current-code example. The `spatial()` wrapper,
top-level help, SPDE reference, canonical design docs, validation register, and
wide-to-long mapping now use the 4 × 3 mode grid plus `common` / `unique`
modifiers. Current spatial grammar documentation now says that coordinates
locate observations and that `make_mesh()` creates the required, pre-built
mesh and sparse projection; `coords =` does not build a mesh.

**Mathematical contract**: no R API, parser, likelihood, family, or numerical
parameterisation changed. `spatial_indep(..., common = TRUE)` and
`spatial_scalar()` continue to route byte-identically to the tied-SPDE-scale
engine. SPA-01 remains covered, SPA-02 / FG-13 remain partial, and SPA-03
continues to cover the shared-variance route.

## 3. Files Changed

- Reference source: `R/brms-sugar.R`, `R/gllvmTMB.R`, `R/spde-keyword.R`.
- Regenerated help: `man/gllvmTMB.Rd`, `man/spatial.Rd`,
  `man/phylo.Rd`, `man/spatial_latent.Rd`, `man/spatial_scalar.Rd`,
  `man/spatial_unique.Rd`, and `man/spde.Rd`.
- Reader-facing overview: `README.md` and
  `vignettes/articles/gllvm-vocabulary.Rmd`.
- Current design and evidence surfaces: `docs/design/00-vision.md`,
  `01-formula-grammar.md`, `02-data-shape-and-weights.md`,
  `03-likelihoods.md`, `03-phylogenetic-gllvm.md`,
  `04-random-effects.md`, `05-testing-strategy.md`,
  `14-known-relatedness-keywords.md`, `35-validation-debt-register.md`, and
  `55-structural-slope-grammar.md`, and `57-mixed-family-link-residual.md`.
- Closeout: `docs/dev-log/check-log.md` and this report.

Historical NEWS entries, test names, and phase records retain the old function
name where it records what was true at the time.

## 3a. Decisions and Rejected Alternatives

- **Decision**: migrate new examples and primary prose, but retain a complete
  compatibility reference for `spatial_scalar()`. **Rationale**: the export and
  parser remain live, while new users need the canonical spelling.
- **Decision**: correct the mesh claim in the same patch. **Rationale**: the
  former statement that `coords =` builds a mesh directly contradicted runtime
  validation and the deployed article. **Rejected**: leave a known false claim
  because it was outside the initial scalar wording. **Confidence**: high.

## 4. Checks Run

```sh
git diff --check
# PASS

Rscript --vanilla -e 'devtools::document(quiet = TRUE); devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-scalar-family-collapse.R"); testthat::test_file("tests/testthat/test-spatial-deprecation.R")'
# scalar-family collapse: FAIL 0 | WARN 0 | SKIP 0 | PASS 19
# spatial-deprecation: FAIL 0 | WARN 0 | SKIP 1 (On CRAN) | PASS 0
# document(): two pre-existing missing S3 export-tag diagnostics in aghq-report.R.

Rscript --vanilla -e 'pkgdown::check_pkgdown(); pkgdown::build_articles(lazy = FALSE)'
# pkgdown::check_pkgdown(): PASS, No problems found.
# article build: PASS.
```

## 5. Tests of the Tests

No test was added because behaviour did not change. The scalar-collapse test
asserts the compatibility and canonical forms route identically; the article
build evaluates the user-facing syntax.

## 6. Consistency Audit

```sh
rg -n "engine builds the mesh internally|coords = c\(\"lon\", \"lat\"\).*mesh|mesh = mesh or coords" docs/design R man vignettes README.md NEWS.md AGENTS.md CLAUDE.md
# no matches.

rg -n "4 × 5|4×5" docs/design/00-vision.md docs/design/01-formula-grammar.md docs/design/02-data-shape-and-weights.md docs/design/03-likelihoods.md docs/design/04-random-effects.md docs/design/05-testing-strategy.md docs/design/14-known-relatedness-keywords.md docs/design/35-validation-debt-register.md docs/design/55-structural-slope-grammar.md
# no matches.

rg -n "spatial_scalar\(\).*Canonical name|all four spatial keywords|spatial_scalar\(0 \+ trait \| site, mesh = mesh\)" R man vignettes README.md NEWS.md docs/design
# no matches.

rg -n "spatial_indep\(.*common = TRUE" R man vignettes README.md NEWS.md docs/design
# intentional canonical examples and migration notices only.
```

## 7. Roadmap Tick

N/A — documentation reconciliation; no roadmap status changed.

## 7a. GitHub Issue Ledger

`gh issue list --state open --search 'spatial scalar in:title'` returned no
relevant open issue. No issue comment, closure, or new issue.

## 8. What Did Not Go Smoothly

The semantic brain CLI could not write its local configuration under the
sandbox, so the required brain query used the raw-vault fallback. Regenerating
Rd also reported two existing `aghq-report.R` S3 export-tag diagnostics; they
are unrelated to this documentation migration and were not changed.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada**: separated this follow-up from the already-merged article fix and used
a clean branch from current `main` because the main checkout contained foreign
work.

**Boole**: the public grammar is now consistently three modes plus modifiers;
the compatibility function remains documented rather than silently hidden.

**Pat**: the mesh correction explains the actionable distinction: coordinate
columns locate data, while `make_mesh()` builds the computational object that
the fitted model requires.

**Rose**: the sweep found and corrected both the deprecated scalar teaching and
the contradictory automatic-mesh claim across current documentation surfaces.

**Grace**: regenerated Rd, the focused compatibility test, pkgdown check, and
full article build passed.

## 10. Known Limitations And Next Actions

Historical change records and test-file names deliberately retain
`spatial_scalar`; the function export also remains live. No inference claim
changed: spatial-family breadth remains partial under FG-13 and SPA-02.
