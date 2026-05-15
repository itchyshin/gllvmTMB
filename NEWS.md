# gllvmTMB (development version)

## Behaviour changes (Phase 1b)

* **`extract_correlations()` `link_residual` default change.** The
  default of the new `link_residual` parameter is `"auto"`. Previously
  the function hardcoded the equivalent of `link_residual = "none"`.
  For non-Gaussian fits this means correlations are now reported on
  the latent-liability scale (with the family-specific link residual
  -- e.g. \eqn{\pi^2/3} for binomial-logit, \eqn{1} for probit,
  trigamma terms for Gamma / NB2 / Beta / etc. -- added to the
  diagonal of the implied `Sigma`). Gaussian fits are unaffected (the
  link residual is zero). A one-shot warning fires the first time a
  non-Gaussian fit is processed without an explicit `link_residual`
  argument; pass `link_residual = "auto"` to lock the new behaviour
  and suppress the warning, or `link_residual = "none"` to restore
  the previous behaviour.
* **`extract-sigma.R` Beta / beta-binomial saturation fix.** The
  `mu_t` clamp at `[1e-6, 1 - 1e-6]` (per Gauss's correctness flag)
  now applies before forming the trigamma arguments. Previously a
  saturated Beta / beta-binomial fit (`eta -> +/-Inf`) collapsed one
  of `(a_t, b_t)` to the `1e-12` floor and `trigamma(1e-12) ~ 1e24`
  crushed any reported correlation to ~0. The new clamp keeps the
  fit's degeneracy numerically visible (a large but finite trigamma
  value) rather than silently producing meaningless correlations.

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
  `Sigma = Lambda Lambda^T + diag(psi)`. Math notation uses
  the Greek letter `\boldsymbol{\Psi}` (bold capital) for the
  unique-variance diagonal matrix and `\psi_t` (italic lowercase,
  subscripted by trait) for the per-trait derived scalar, matching
  the factor-analysis / SEM convention (Bollen 1989, Mulaik 2010,
  lavaan). The legacy "two_U" task label has been retired from
  function and file names: the PIC-based cross-check diagnostics
  (`compare_PIC_vs_joint()`, `extract_two_U_via_PIC()`) are
  removed entirely, and the joint-vs-unstructured cross-checks
  are renamed to `compare_dep_vs_two_psi()` /
  `compare_indep_vs_two_psi()` (same signatures and behaviour,
  new names matching the Psi notation). See
  `docs/dev-log/decisions.md` 2026-05-14 entries (notation reversal
  + two-U/PIC retirement) and `docs/dev-log/decisions.md`
  2026-05-15 entry (partial restoration of the joint-vs-unstructured
  cross-checks under the `two_psi` rename).

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

* New technical reference articles cover the covariance keyword grid,
  the response-family surface, and the ordinal-probit threshold scale
  and cutpoint convention.

## Inference

* Maximum-likelihood point estimates via TMB's Laplace
  approximation. REML is not yet implemented; planned for a
  post-0.2.0 release as a Gaussian-only feature (matching the
  `glmmTMB` / `lme4` convention). See
  `docs/dev-log/decisions.md` 2026-05-14 REML scope note.
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

## Relationship to a pre-0.2.0 development line

The pre-0.2.0 development line of `gllvmTMB` re-exported a large
surface from `sdmTMB` and exposed single-response paths; the
0.2.0 release does neither. Users who want single-response models
should install `sdmTMB` or `glmmTMB` directly, which install
side-by-side with `gllvmTMB` without conflict.
