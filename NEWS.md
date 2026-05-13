# gllvmTMB 0.2.0 (first CRAN release)

First public release of `gllvmTMB`, a Template Model Builder (TMB)
engine for stacked-trait generalised linear latent variable models
(GLLVMs). `gllvmTMB()` fits multivariate models in which the same
observational units carry several responses -- traits, species,
items, behaviours, outcomes -- and the scientific question concerns
their shared latent covariance, ordination, communality,
phylogenetic signal, or spatial structure.

## User-facing API

* Two entry points share one long-format engine:
  * `gllvmTMB(value ~ ..., data = df_long, unit = "...")` accepts
    long-format data (one row per `(unit, trait)` observation) and
    wide data frames marked with the formula-LHS helper
    `traits(...)`. The wide form uses compact syntax such as
    `traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2)`; the parser
    expands fixed predictors, `latent()` / `unique()` / `indep()` /
    `dep()`, bar-style `phylo_indep()` / `phylo_dep()`, and
    `spatial_*()` terms to the long trait-stacked grammar.
    Species-axis `phylo_scalar()` / `phylo_unique()` /
    `phylo_latent()` calls and ordinary `(1 | group)` random
    intercepts pass through unchanged.
  * `gllvmTMB_wide(Y, ...)` is the matrix-in entry point for
    matrix-first workflows and the only path that accepts per-cell
    weight matrices.

* The covariance grammar is a 3 x 5 keyword grid (correlation x
  mode):

  | correlation \ mode | scalar | unique | indep | dep | latent |
  |---|---|---|---|---|---|
  | none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
  | phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
  | spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

  The decomposition mode pairs `latent + unique`:
  `Sigma = Lambda Lambda^T + diag(s)`.

* Per-trait response families: gaussian, binomial (with multi-trial
  via `cbind(succ, fail)` or weights), betabinomial, poisson,
  lognormal, Gamma, nbinom2, tweedie, Beta, student, ordinal_probit,
  truncated_poisson, truncated_nbinom2, delta_lognormal, delta_gamma.
  Mixed-family fits are accepted via `family = list(...)` keyed by
  trait.

* `gllvmTMB()` requires at least one covariance-structure term. A
  call without any `latent()` / `unique()` / `indep()` / `dep()` /
  `phylo_*()` / `spatial_*()` term errors with a pointer to
  `glmmTMB::glmmTMB()` for single-response work.

## Inference

* ML or REML point estimates via TMB's Laplace approximation.
* Profile-likelihood confidence intervals for derived quantities
  (repeatability, communality, phylogenetic signal, pairwise
  correlations) through the `profile_ci_*()` family.
* `extract_correlations()` exposes Fisher-z (default), Wald, and
  bootstrap intervals via the `method` argument.

## Phylogenetic and spatial paths

* Phylogenetic covariance via the sparse `A^-1` representation of
  Hadfield & Nakagawa (2010), with `tree` (an `ape::phylo`) or
  `phylo_vcv = Cphy` (a precomputed covariance matrix) as input.
* Spatial covariance via the SPDE / GMRF approximation from
  `sdmTMB`. `gllvmTMB` includes SPDE / mesh / anisotropy helpers
  (`make_mesh()`, `R/crs.R`, parts of `R/plot.R`) inherited from
  `sdmTMB` under GPL-3; provenance is recorded in `inst/COPYRIGHTS`
  and at the top of each inherited R file.

## Inherited code and citation

* `Authors@R` names Shinichi Nakagawa as the sole author of
  `gllvmTMB`. Upstream copyright holders for inherited code
  (Anderson, Ward, English, Barnett for `sdmTMB` SPDE / mesh /
  anisotropy R helpers; Kristensen for `TMB`; Thorson for `VAST`
  transitively via `sdmTMB`) are recorded in `inst/COPYRIGHTS` and
  acknowledged in `inst/CITATION`, `README.md`, and file-top
  comments of the inherited R files. This follows the
  CRAN-recommended pattern in "Writing R Extensions" §1.1.1 of
  using a `Copyright: inst/COPYRIGHTS` field rather than `cph`
  entries in `Authors@R` for inherited-code copyright holders.

* `inst/CITATION` curates `citation("gllvmTMB")`. The primary
  entry is the (in-prep) Nakagawa methods paper; companion
  entries cite Kristensen et al. (2016) for TMB and Anderson
  et al. (2025) for `sdmTMB` when the spatial path is used.

## Source-tree notes

* The TMB engine is compiled at install time from
  `src/gllvmTMB.cpp`. The DLL is registered via
  `useDynLib(gllvmTMB, .registration = TRUE)`.
* `gllvmTMBcontrol()` returns an options object distinct from
  `sdmTMB::sdmTMBcontrol()`. Extra `...` arguments emit a
  warning.

## Relationship to the legacy 0.1.x line

This 0.2.0 release rebuilds `gllvmTMB` from a focused multivariate
GLLVM core. The pre-0.2.0 legacy line preserved at
`itchyshin/gllvmTMB-legacy` re-exported a large surface from
`sdmTMB` and exposed single-response paths; the 0.2.0 release does
neither. Users who want single-response models should install
`sdmTMB` or `glmmTMB` directly, which install side-by-side with
`gllvmTMB` without conflict.
