# After Task: animal_latent() default Psi fold

## Goal

Carry Stage A of the latent migration forward after the spatial blocker:
make `animal_latent()` carry its additive-genetic diagonal Psi companion by
default, matching ordinary `latent()` and `phylo_latent()`, while keeping
`unique = FALSE` as the loadings-only escape hatch.

## Implemented

`animal_latent(id, d = K, pedigree = ped)` now rewrites to the existing
`phylo_rr(..., vcv = A)` reduced-rank path plus an automatic
`phylo_rr(..., .phylo_unique = TRUE, .auto_unique = TRUE, vcv = A)`
companion. An explicit `animal_unique()` companion is deduped against the
automatic one, so the folded default is byte-equivalent to
`animal_latent(..., unique = FALSE) + animal_unique()`.

`animal_latent(..., unique = FALSE)` preserves the older loadings-only route.
Augmented animal random-regression syntax, such as
`animal_latent(1 + x | id, d = K)`, remains on the existing loadings-only
slope engine in this slice.

## Mathematical Contract

For intercept-only animal latent terms, the fitted additive-genetic trait
covariance is now

```text
G = Lambda Lambda^T + Psi_animal
```

where both `Lambda Lambda^T` and `Psi_animal` are scaled over individuals by
the same relatedness matrix `A`. In R syntax:

```r
animal_latent(id, d = K, pedigree = ped)
```

targets the same model as:

```r
animal_latent(id, d = K, unique = FALSE, pedigree = ped) +
  animal_unique(id, pedigree = ped)
```

This PR does not change `src/gllvmTMB.cpp`, the TMB likelihood, the sparse
animal / phylo engine, or the SPDE engine. It is a formula-rewriter and
documentation/test slice over the already-existing dense/sparse relatedness
paths.

## Files Changed

- `R/brms-sugar.R`: animal rewrite emits the automatic source-specific Psi
  companion by default, validates `unique`, and keeps augmented slope routing
  loadings-only.
- `R/animal-keyword.R`: `animal_latent()` gains `unique = TRUE` and updated
  roxygen.
- `R/unique-keyword.R`: source-specific diagonal guidance now distinguishes
  folded phylo/animal terms from pending spatial/kernel terms.
- `tests/testthat/test-animal-latent-unique-fold.R`: new parser, error,
  equivalence, and dedup tests.
- `tests/testthat/test-animal-keyword.R` and
  `tests/testthat/test-matrix-animal-nongaussian.R`: existing animal-vs-phylo
  loadings-only comparisons now opt into `unique = FALSE`.
- `man/animal_latent.Rd`, `man/animal_unique.Rd`, `man/diag_re.Rd`,
  `man/phylo_unique.Rd`, `man/spatial_unique.Rd`: regenerated help touched by
  roxygen updates.
- `NEWS.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  `docs/design/00-vision.md`, `docs/design/01-formula-grammar.md`,
  `docs/design/14-known-relatedness-keywords.md`,
  `docs/design/2026-06-21-source-specific-latent-psi-fold.md`,
  `docs/design/35-validation-debt-register.md`, and
  `docs/design/43-asreml-speed-techniques.md`: convention-change cascade and
  validation ledger updates.
- `vignettes/articles/animal-model.Rmd`,
  `vignettes/articles/api-keyword-grid.Rmd`, and
  `vignettes/articles/gllvm-vocabulary.Rmd`: user-facing examples now teach the
  folded animal syntax.

`air format` was run on touched R/test files. It normalized nearby code in
`R/brms-sugar.R`, `R/animal-keyword.R`, `test-animal-keyword.R`, and
`test-matrix-animal-nongaussian.R`; the semantic diff is the `unique` fold and
test retargeting above.

## Checks Run

- RED-first:
  `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-animal-latent-unique-fold.R", reporter = "summary")'`
  failed before implementation: no automatic `.phylo_unique` /
  `.auto_unique` companion, no `unique = FALSE` loadings-only route, and no
  invalid-`unique` error.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed;
  unrelated generated Rd churn was removed before staging.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-animal-latent-unique-fold.R", reporter = "summary")'`
  passed (`.................`).
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-animal-keyword.R", reporter = "summary")'`
  passed (`...................S..S`); skips were the existing heavy ANI-09 gate
  and missing Suggests-only `nadiv`.
- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-animal-nongaussian.R", reporter = "summary")'`
  passed (`..................................................`).
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test()'` passed:
  `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3422 ]`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed:
  `No problems found`.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` rendered the
  touched `animal-model`, `api-keyword-grid`, and `gllvm-vocabulary` articles,
  then failed in existing `vignettes/articles/lambda-constraint-suggest.Rmd`
  chunk `profile-confidence-eye` because `loading_ci(fit_pr, level = "unit",
  method = "wald")` now correctly rejects an unconstrained loading fit. A
  detached `origin/main` worktree at `90a0762` reproduced the identical failure
  with `pkgdown::build_article("articles/lambda-constraint-suggest", lazy =
  FALSE)`, so this is recorded as pre-existing article render debt, not an
  animal-fold regression.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  completed with `0 errors, 1 warning, 0 notes`. The warning was local
  Apple-clang/R-header install noise:
  `R_ext/Boolean.h:62:36: warning: unknown warning group
  '-Wfixed-enum-extension', ignored [-Wunknown-warning-option]`.
- `git diff --check` passed.
- Rendered-Rd spot check:
  `tail -5 man/animal_latent.Rd man/animal_unique.Rd man/diag_re.Rd man/phylo_unique.Rd man/spatial_unique.Rd`
  and
  `grep -c '^\\keyword' man/animal_latent.Rd man/animal_unique.Rd man/diag_re.Rd man/phylo_unique.Rd man/spatial_unique.Rd`
  showed only the expected one `\keyword{internal}` in `man/diag_re.Rd`.

## Tests Of The Tests

The new test file satisfies the failure-before-fix rule: it failed before the
rewriter emitted the automatic companion and before invalid `unique` values were
rejected. It also exercises a boundary/error path (`unique = NA`) and a feature
combination path (explicit `animal_unique()` dedup against the automatic
companion). The Gaussian equivalence test is the byte-identity guard for the
fold, and the non-Gaussian animal matrix rerun keeps the loadings-only
`animal_latent(unique = FALSE)` route aligned with dense `phylo_latent(vcv = A,
unique = FALSE)`.

## Consistency Audit

Exact scans:

- `rg -n 'animal_latent\([^\n]*\)\s*\+\s*animal_unique|animal_latent\(d = K\) \+ animal_unique' R tests vignettes README.md NEWS.md docs AGENTS.md CLAUDE.md CONTRIBUTING.md`
  found only intentional compatibility prose in this branch plus historical
  after-task records; no live animal tutorial still teaches the paired spelling
  as primary.
- `rg -n 'remaining `spatial_latent` / `animal_latent`|animal_latent.*future|source-specific latent-Psi folds remain future|source-specific paired compatibility pattern' AGENTS.md CLAUDE.md CONTRIBUTING.md NEWS.md docs vignettes R`
  found one historical after-task note from 2026-06-19; no current source doc
  says the animal fold is still future.
- `rg -n '\.auto_residual|residual = TRUE|residual = FALSE|latent\([^\n]*residual' R tests vignettes README.md NEWS.md docs AGENTS.md CLAUDE.md CONTRIBUTING.md`
  found expected soft-deprecated ordinary `residual =` alias coverage and
  historical design/dev-log notes. It also surfaced existing live prose debt in
  `vignettes/articles/pitfalls.Rmd` that still describes
  `phylo_latent(species, d = K)` as loadings-only; that is outside this animal
  slice and should be handled in the Stage B docs hardening pass.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S' README.md NEWS.md docs/design vignettes R tests AGENTS.md CLAUDE.md CONTRIBUTING.md`
  found only the pattern documented in `docs/design/10-after-task-protocol.md`;
  no new user-facing `S_B` / `S_W` notation was introduced.

Status inventory: `NEWS.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
`docs/design/01-formula-grammar.md`, `docs/design/35-validation-debt-register.md`,
and affected articles were updated. `README.md`, `ROADMAP.md`, and
`_pkgdown.yml` did not require changes for this existing exported keyword.

Roadmap tick: N/A. The latent migration is tracked in the Stage-A design and
dev-log handoff rather than a public `ROADMAP.md` progress row.

GitHub issue ledger: inspected open issues matching
`animal_latent OR animal_unique OR latent unique`; relevant open tracker is
#526 for the spatial blocker, not this animal slice. Inspected issues matching
`lambda-constraint-suggest OR loading_ci OR profile-confidence-eye`; broad
article/status issues #230 and #340 are relevant to the pre-existing article
render debt. No issue was closed and no new issue was created in this scoped
animal PR.

## What Did Not Go Smoothly

`pkgdown::build_articles(lazy = FALSE)` exposed a mainline article failure in
`lambda-constraint-suggest.Rmd`. That was useful evidence but it means the
article-render gate is not fully green until the profile-retention example is
repaired or marked as an expected-error teaching chunk.

`air format` also produced more formatting churn than ideal in files already
touched by the slice. Review should use the semantic hunks and `git diff -w`
when checking the implementation.

## Team Learning

Ada kept the slice scoped after the spatial blocker: animal was safe because it
uses the already-wired relatedness companion path, while spatial remains blocked
on engine support.

Boole checked the grammar contract: `unique = TRUE` is default, `unique = FALSE`
is loadings-only, and malformed `unique` values fail loudly.

Noether checked the symbolic/R alignment: the R formula target and prose both
state `G = Lambda Lambda^T + Psi_animal` on the same relatedness matrix `A`.

Curie checked that the test suite covers parser emission, failure paths,
deduplication, Gaussian equivalence, and non-Gaussian loadings-only parity.

Grace checked the package gates: full tests passed, pkgdown index passed, full
`R CMD check` reached the known local Apple-clang warning only, and article
render debt was verified against `origin/main`.

Rose checked stale wording and validation-debt alignment. The important live
follow-up is the stale `pitfalls.Rmd` phylo wording plus the
`lambda-constraint-suggest.Rmd` render failure.

Shannon checked coordination state before shared dev-log/design edits: no open
PRs were present, and recent commits were the already-merged handoff,
diagnostic, and spatial-blocker sequence.

## Known Limitations

- Augmented `animal_latent(1 + x | id)` remains loadings-only in this slice.
- `spatial_latent()` remains blocked by #526 until the SPDE engine can estimate
  additive low-rank plus per-trait diagonal spatial fields in one fit.
- `kernel_latent()` is the next source fold candidate.
- The pre-existing `lambda-constraint-suggest.Rmd` render failure should be
  fixed before claiming a fully green article-render gate for the migration.
- `vignettes/articles/pitfalls.Rmd` still has stale phylo loadings-only wording
  from before #519.

## Next Actions

1. Open the animal fold PR and require maintainer "yes merge" because this is a
   grammar/default change.
2. Start `kernel_latent()` from a fresh worktree after this PR is in review.
3. Schedule Stage B docs hardening for the `pitfalls.Rmd` phylo line and the
   `lambda-constraint-suggest.Rmd` article-render failure.
