# Contributing to gllvmTMB

`gllvmTMB` is early-stage software. Contributions should be small,
tested, and linked to the project design documents.

## Definition of Done

A modelling feature is complete only when it includes:

- implementation in `R/` (and `src/gllvmTMB.cpp` if a likelihood
  change);
- simulation or unit tests under `tests/testthat/`, including the
  symbolic-math <-> implementation alignment table from the
  `add-simulation-test` skill;
- documentation (roxygen on every exported function);
- a runnable example in the function's roxygen `@examples`;
- a check-log entry under `docs/dev-log/check-log.md`;
- review for likelihood, parameterisation, and scope (the `reviewer`
  Codex agent or the equivalent inline review hat).

## Scope

The package is for stacked-trait, long-format multivariate GLLVMs.
Single-response models belong in `glmmTMB`; spatial single-response
models belong in `sdmTMB`.

The covariance dispatch is the 3 x 5 keyword grid:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The decomposition mode is `latent + unique` paired:
Sigma = Lambda Lambda^T + diag(s).

## Development Checks

Use these commands before review:

```r
devtools::document()
devtools::test()
devtools::check()
pkgdown::check_pkgdown()
```

For changes that touch README, vignettes, reference navigation,
exported functions, or generated Rd files, run `pkgdown::check_pkgdown()`
before pushing. For changes that touch user-formula parsing, tutorial
code, or article examples, also render the affected articles:

```r
pkgdown::build_articles(lazy = FALSE)
```

Long simulation studies should live outside CRAN-time tests, gated
by `Sys.getenv("RUN_SLOW_TESTS")` or moved to `data-raw/`.

Keep work-in-progress to one open PR, and let GitHub Actions finish
before pushing a follow-up commit. The pkgdown workflow is sequenced
after a green `R-CMD-check` on `main`; do not use pkgdown as a
parallel substitute for the full check.

## Pre-Publish Audit

Any PR touching public prose or reference navigation should run the
Rose pre-publish audit before merge. The audit is deliberately narrow:
method lists, default-value claims, exported function names, the
3 x 5 keyword grid, argument names, family lists, and stale
terminology. It is a consistency gate, not a general rewrite pass.

## Articles

Every public article is **Tier 1** by default. Tier 2 / Tier 3
require explicit justification in the article's YAML front-matter.
The `article-tier-audit` skill encodes the triage. The
`vignettes/articles/morphometrics.Rmd` is the canonical Tier-1
exemplar.
