# Sister-Package Scope: Where `gllvmTMB` Sits

This document positions `gllvmTMB` relative to its R-package
neighbours so a new user can pick the right tool for their data
shape, model scope, and inference goal without trial-and-error
installs. It also makes the boundaries visible to maintainers and
reviewers: scope-creep proposals run into this document first.

## One-line summaries

| Package | Scope | Engine |
|---|---|---|
| **`gllvmTMB`** | **Multivariate stacked-trait GLLVMs**: one row per `(unit, trait)` observation, optionally with phylogenetic and spatial correlation; `Sigma = Lambda Lambda^T + diag(s)` decomposition is canonical. | TMB + Laplace |
| `drmTMB` (sister) | Univariate and bivariate distributional regression: mean / scale / shape / nu components, location-scale models. One or two responses; no GLLVM layer. | TMB + Laplace |
| `glmmTMB` | General single-response GLMMs: families, random effects, zero-inflation, dispersion. The reference TMB-based mixed-model package. | TMB + Laplace |
| `sdmTMB` | Single-response spatial GLMMs with SPDE Gaussian random fields. Builds on `glmmTMB` for mixed-effects structure and `fmesher`/`INLA` for SPDE meshes. | TMB + Laplace + SPDE |
| `gllvm` | Original multivariate GLLVM package (Niku et al.). Variational approximation or Laplace; wide-format matrix-in API; less syntactic surface than `gllvmTMB`. | TMB + VA / Laplace |
| `MCMCglmm` | Bayesian multi-response GLMMs with phylogenetic correlation. MCMC sampler; conjugate-style priors; supports `us(trait):unit` multi-response. | Gibbs sampler (custom C) |
| `brms` | Bayesian multilevel models on top of Stan; `mvbind()` syntax for multi-response. Slower but more flexible priors and posteriors. | Stan + HMC/NUTS |

## Decision matrix

Use the column on the left to find your data; read across for the
recommended package.

| Your data | Response shape | Recommended | Why |
|---|---|---|---|
| One continuous outcome with random effects (mixed model) | univariate | `glmmTMB` | The reference single-response TMB mixed-model engine. |
| One outcome, modelling mean and dispersion as separate linear predictors | univariate, distributional | `drmTMB` | Distributional regression with two LP components. |
| Two outcomes (e.g. mean / variance, or a bivariate distribution) | bivariate | `drmTMB` | Bivariate distributional support; not a multivariate GLLVM. |
| One outcome with spatial autocorrelation (single response) | univariate, spatial | `sdmTMB` | SPDE meshes and INLA-style spatial fields are sdmTMB's purpose. |
| Several trait responses per unit (3+ continuous traits, or mixed-family traits) | multivariate stacked | **`gllvmTMB`** | The stacked-trait surface is gllvmTMB's purpose. |
| Site x species occurrences (joint SDM) | multivariate binomial / count | **`gllvmTMB`** | Joint species distribution modelling is one of the canonical use cases. |
| Multi-trait data with phylogenetic correlation across traits | multivariate phylogenetic | **`gllvmTMB`** | Phylogenetic GLLVM (`phylo_latent + phylo_unique`) is canonical. |
| Multi-trait data with spatial correlation across units | multivariate spatial | **`gllvmTMB`** | Spatial GLLVM (`spatial_latent + spatial_unique`) is canonical. |
| Meta-analytic data with a known sampling covariance | univariate or multivariate meta | `gllvmTMB` (with `meta_known_V`) or `metafor` | `meta_known_V(V = V)` is the gllvmTMB keyword; `metafor` is the dedicated meta-analysis package. |
| Bayesian multi-response with phylogeny + posterior samples | multivariate Bayesian | `MCMCglmm` or `brms` | gllvmTMB returns ML / REML estimates with Laplace marginal likelihood; Bayesian inference is out of scope. |
| Bayesian multi-response without phylogeny | multivariate Bayesian | `brms` (with `mvbind()`) | brms's HMC sampler and prior flexibility are the Bayesian counterpart. |

## Why pick `gllvmTMB` specifically

The five things that distinguish `gllvmTMB` from sister packages:

1. **Stacked-trait long-format engine.** One row per
   `(unit, trait)` observation, mixed-family per trait allowed,
   weights vectorised over rows. This data shape generalises
   joint species distribution modelling, morphometrics,
   behavioural syndromes, meta-analysis, and psychometric IRT
   into one engine.
2. **Four-component covariance decomposition** when phylogeny or
   spatial is present:
   `Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy)` and
   `Sigma_non = Lambda_non Lambda_non^T + diag(s_non)`, summing
   to `Omega`. Most sister packages give you only one of these
   layers at a time.
3. **3 x 5 keyword grid** as the canonical formula surface:
   `latent / unique / indep / dep / scalar` cross
   `none / phylo_ / spatial_`. Memorable, parseable, and
   internally consistent.
4. **Two data shapes, one engine.** Long format
   (`gllvmTMB(value ~ ..., data = df_long)`) and wide format
   (`gllvmTMB_wide(Y, ...)` accepting matrix or wide data frame)
   are surface-level views of the same fit.
5. **TMB / Laplace speed.** Sparse phylogenetic A-inverse and
   SPDE GMRF meshes both run inside one compiled TMB template.

## Where the packages overlap (and what to pick)

### `gllvmTMB` vs `glmmTMB`

Overlap: both fit GLMMs with random effects. `gllvmTMB` extends
`glmmTMB` by adding the multi-trait stacking, the latent factor
covariance keywords, and the phylogenetic / spatial correlation
extensions.

Rule: **single-response models live in `glmmTMB`.** Even if you
plan to add more responses later, the gllvmTMB path requires a
real (`unit`, `trait`) row layout from the start.

### `gllvmTMB` vs `sdmTMB`

Overlap: spatial random fields via SPDE. `gllvmTMB` inherits the
SPDE / mesh code from `sdmTMB` (per `inst/COPYRIGHTS`) but uses
it for the multivariate spatial layer (`spatial_latent +
spatial_unique`) rather than for univariate species distribution
modelling.

Rule: **single-response spatial models live in `sdmTMB`.**
Multivariate spatial models -- multiple traits at the same set
of locations, with cross-trait spatial covariance -- live in
`gllvmTMB`.

### `gllvmTMB` vs `gllvm`

Overlap: both fit multivariate GLLVMs. `gllvm` (Niku et al.) is
the older and more cited package; it uses variational
approximation by default and has its own matrix-in API.
`gllvmTMB` is the TMB-Laplace alternative with explicit formula
grammar, the 3 x 5 keyword grid, and integrated phylogenetic /
spatial paths.

Rule: **use `gllvm` for pure VA-GLLVM with a numeric response
matrix.** Use `gllvmTMB` when you want formula-grammar control,
phylogeny / spatial keywords in the same model, mixed-family
per-trait, or fast Laplace inference on larger datasets.

### `gllvmTMB` vs `drmTMB`

Overlap: both are Nakagawa-maintained TMB-based packages. They
do different things: `drmTMB` is distributional regression for
one or two responses (modelling location, scale, and shape
separately); `gllvmTMB` is multivariate stacked-trait GLLVMs.
There is no overlap in scope.

Rule: **use `drmTMB` for distributional regression (location ~
predictors, scale ~ predictors, etc.).** Use `gllvmTMB` for
multivariate stacked-trait fits.

### `gllvmTMB` vs `MCMCglmm` / `brms`

Overlap: multivariate phylogenetic GLMMs. `MCMCglmm` and `brms`
both fit Bayesian multi-response phylogenetic models. They have
different sampling engines (Gibbs and HMC respectively) and
different prior structures.

Rule: **use the Bayesian packages when you need posterior
samples** (full uncertainty propagation, hierarchical
shrinkage with informative priors, complex post-fit
calculations). Use `gllvmTMB` when you need maximum-likelihood
point estimates plus profile / Wald / bootstrap CIs and want
the run to take seconds-to-minutes rather than minutes-to-hours.

## What `gllvmTMB` does NOT do

To keep the scope bounded, `gllvmTMB` deliberately does not
cover:

- **Single-response GLMMs without a trait dimension** -- use
  `glmmTMB`.
- **Single-response spatial models** -- use `sdmTMB`.
- **Distributional regression on one or two responses** -- use
  `drmTMB`.
- **Bayesian inference with posterior samples** -- use
  `MCMCglmm` (multivariate phylogenetic) or `brms` (general
  Bayesian).
- **Variational approximation as the primary inference engine**
  -- `gllvmTMB` uses Laplace; `gllvm` is the VA alternative.
- **Direct estimation of fixed-effects regression on
  individual-trait formulas without the stacked-trait
  representation.** If your model is "trait_A on env, trait_B on
  env" with no joint covariance interest, fit two separate
  `glmmTMB` calls.

## Code provenance and citation

When a `gllvmTMB` fit uses spatial keywords (`spatial_*()`),
cite the sdmTMB paper for the SPDE / mesh approach
(Anderson et al. 2025, JSS). When it uses TMB (every fit), cite
the TMB paper (Kristensen et al. 2016, JSS). The sister-package
relationship is explicit in `inst/COPYRIGHTS` and `inst/CITATION`
and the Authors@R / Copyright fields of `DESCRIPTION`.

## See also

- `README.md` "Current boundaries" section: a short user-facing
  summary of the same scope decisions.
- `docs/dev-log/decisions.md` "Legacy `gllvmTMB-legacy` archive
  scope" entry (2026-05-12): records that single-response sdmTMB
  inheritance code, single-response tests, and PIC-MOM public
  paths are explicitly archived.
- `docs/design/02-data-shape-and-weights.md`: the data shape +
  weights contract for the two user-facing shapes.
- `CLAUDE.md` "Project Identity" section: the `gllvmTMB` vs
  `drmTMB` framing.
