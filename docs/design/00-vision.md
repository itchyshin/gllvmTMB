# Vision

`gllvmTMB` provides fast multivariate generalised linear latent
variable models (GLLVMs) using TMB, focused on stacked-trait long-
format data with phylogenetic and spatial extensions. The package
should remain broadly useful for applied ecology, evolution, and
environmental science -- the first tutorials and examples are
motivated by morphometrics, joint species distribution modelling,
behavioural syndromes, and functional biogeography.

The package identity is:

> memorable multivariate-formula syntax via the 3 x 5 covariance
> keyword grid; glmmTMB-like speed via TMB's Laplace approximation;
> sparse phylogenetic and SPDE spatial paths in one engine.

`gllvm` is an important conceptual reference, but `gllvmTMB` should
not copy its grammar wholesale. The public grammar should be easy to
remember for applied biologists and strict enough to keep the TMB
implementation identifiable.

Every implemented model class should have two parallel
representations:

1. symbolic equations that define the likelihood and parameter
   meanings;
2. matching R syntax that maps each equation term to a formula
   component.

This is both a development discipline and a teaching principle.
Equations should prevent API drift; syntax should make those
equations usable. The 5-row alignment table (see
`.agents/skills/add-simulation-test/SKILL.md`) is the canonical
form.

## Core Idea

A model is defined by:

1. one long-format response column (`value`);
2. trait-level fixed effects on the LHS (e.g.
   `value ~ 0 + trait + (0 + trait):env`);
3. one or more covariance-structure keywords drawn from the 3 x 5
   grid:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

4. a per-trait response family from `R/families.R`;
5. optional `meta_known_V(V = V)` for known-sampling-covariance
   meta-analysis.

The decomposition mode is `latent + unique` paired:
Sigma = Lambda Lambda^T + diag(psi) (the Greek letter Psi;
see `docs/dev-log/decisions.md` 2026-05-14 notation reversal).

## Signature Feature

The signature syntax should read like the model's biological story:

```r
gllvmTMB(
  value ~ 0 + trait
        + latent(0 + trait | site, d = 2)         # B-tier
        + unique(0 + trait | site)                # B-tier residual
        + latent(0 + trait | site_species, d = 1) # W-tier
        + unique(0 + trait | site_species)        # W-tier residual
        + phylo_latent(species, d = 1)            # phylogenetic LV
        + phylo_unique(species),                  # phylogenetic residual
  data = df,
  trait = "trait", unit = "site", cluster = "species",
  family = gaussian()
)
```

This is the package's strongest distinct contribution. Other
multivariate packages either lack the phylogenetic + spatial
extensions or lack the formula-grammar polish.

## Audience And Examples

Examples, vignettes, and pkgdown pages should often use ecological
and evolutionary questions, while package-level headings should stay
general:

- morphometric trait covariance;
- joint species distribution modelling;
- behavioural syndromes;
- functional biogeography (the Nakagawa et al. in-prep manuscript);
- phylogenetic comparative methods;
- meta-analysis with within-study sampling correlation.

## Sibling Boundary

`drmTMB` is the univariate / bivariate distributional-regression
sister package. `sdmTMB` is the spatial-single-response sister.
`gllvmTMB` is the multivariate stacked-trait package. All three
share TMB and a common discipline (canonical keywords, simulation
recovery on every likelihood change, after-task reports), but they
do not interbreed except via narrow code-provenance lines recorded
in `inst/COPYRIGHTS`.
