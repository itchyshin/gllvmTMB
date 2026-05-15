# gllvmTMB

`gllvmTMB` fits **multivariate models** for data where the same
rows carry several measurements at once -- five body traits per
bird, twenty species occurrences per site, three behaviours per
session, several outcomes per study. The scientific target is
the **trait covariance**: which measurements co-vary, what drives
that covariance (a shared latent axis? a phylogenetic signal? a
spatial pattern?), and how much variance is trait-specific.

Three things distinguish `gllvmTMB`:

- **Stacked-trait long format.** Internally the engine works on
  `(unit, trait)` observations stacked into a long data frame, so
  one fit can handle several traits with different response
  distributions, missing cells, and per-row predictors. Wide data
  frames are accepted; the package pivots for you.
- **One formula grammar** for trait covariance. `latent()` adds a
  low-rank shared axis; `unique()` adds a trait-specific diagonal;
  the phylogenetic and spatial variants (`phylo_latent`,
  `spatial_unique`, etc.) extend the same grammar to species
  relatedness and spatial fields.
- **TMB engine, maximum-likelihood (ML) estimates.** Fits take
  seconds to minutes; profile-likelihood and bootstrap intervals
  are first-class. (REML is on the post-0.2.0 roadmap as a
  Gaussian-only feature -- see `NEWS.md`.)

## What "stacked-trait" means

Internally, every fit sees one row per `(unit, trait)`
observation. Five traits on 100 individuals become 500 rows, each
with the trait identity in a `trait` column and the response in a
`value` column. Different traits can use different response
distributions; missing cells drop out automatically. You can hand
the engine a long data frame directly, or a wide data frame via
the `traits(...)` formula-LHS marker -- the package pivots wide
to long for you.

The data shape is general: site x species, individual x trait,
species x trait, paper x outcome, or any similar `unit x response`
layout.

## Start here

- New to the package? Read
  [Get started with gllvmTMB](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html).
- Not sure which covariance structure to use? Read
  [Choose your model](https://itchyshin.github.io/gllvmTMB/articles/choose-your-model.html).
- Fitting continuous traits for individuals? Start with
  [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html).
- Fitting binary species occurrences across sites? See
  [Joint species distribution modelling](https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html).
- Interpreting Sigma, correlations, and communality? Read
  [Covariance and correlation](https://itchyshin.github.io/gllvmTMB/articles/covariance-correlation.html).
- Avoiding common syntax and identifiability traps? Read
  [Common pitfalls](https://itchyshin.github.io/gllvmTMB/articles/pitfalls.html).

## What can I model now?

- **Continuous stacked traits.** Use Gaussian GLLVMs with
  `latent()`, `unique()`, `indep()`, or `dep()` for individual x
  trait, site x trait, or species x trait data. Read
  [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html).
- **Binary or count multivariate responses.** Use binomial,
  Poisson, negative-binomial, Tweedie, beta, beta-binomial,
  Student-t, truncated, delta, or ordinal-probit families when
  each trait has its own response distribution. Read
  [Joint species distribution modelling](https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html)
  and the
  [reference index](https://itchyshin.github.io/gllvmTMB/reference/index.html).
- **Reduced-rank ordination.** Use `latent(0 + trait | unit, d = K)`
  when a few latent dimensions should explain many cross-trait
  associations.
- **Trait-specific residual variance.** Pair `latent()` with
  `unique()` when you need
  `Sigma = Lambda Lambda^T + diag(psi)` rather than a latent-only
  covariance.
- **Phylogenetic trait covariance.** Use `phylo_latent()` and
  `phylo_unique()` when species relatedness should contribute to
  cross-trait covariance.
- **Spatial multivariate structure.** Use `spatial_latent()` and
  related `spatial_*()` keywords with meshes created by
  `make_mesh()` when sites share spatially structured multivariate
  residuals.
- **Known sampling covariance.** Use `meta_known_V(V = V)` for
  multivariate meta-analytic sampling covariance.

This is preview version `0.2.0`. The package is pre-CRAN and
intentionally bounded: use it for the implemented stacked-trait
workflows above, and treat unsupported model classes as roadmap
work rather than hidden features.

## Status of supported features

The matrix below sorts each feature into three buckets so you
can tell at a glance whether a path is ready for publication-
quality use (**stable**), works but has known caveats or is
under active validation (**experimental**), or is on the
roadmap but not yet implemented (**planned**). See
[`Current boundaries`](#current-boundaries) further down for the
discussion of what is intentionally out of scope.

| Feature | Status | Notes |
|---|---|---|
| **Gaussian `latent()` + `unique()`** | stable | Worked example: [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html). |
| **Binomial / Poisson / NB2 / Tweedie / Gamma / lognormal `latent()`** | stable | 15 families supported; see [Mixed responses](https://itchyshin.github.io/gllvmTMB/articles/mixed-response.html) for the full table. |
| **Beta / beta-binomial / Student-t** | stable | `mu_t` clamp guards against trigamma blow-up on saturated fits. |
| **Truncated / delta / hurdle families** | stable | `truncated_poisson`, `truncated_nbinom2`, `delta_lognormal`, `delta_gamma`. |
| **Ordinal-probit** | stable | Per-trait cutpoints. See [Ordinal-probit](https://itchyshin.github.io/gllvmTMB/articles/ordinal-probit.html). |
| **Mixed-family per-row dispatch** | stable | `family = list(...)` with a `family_var` column. |
| **`extract_Sigma()`, `extract_correlations()`, `extract_communality()`** | stable | `link_residual = "auto"` adds family-specific residuals to the diagonal. |
| **`extract_repeatability()`, `extract_phylo_signal()`** | stable | Profile CI default; falls back to Wald on full-Sigma fits with a one-shot inform message. |
| **Profile-likelihood CIs (direct parameters)** | stable | `tmbprofile_wrapper()` for direct profile + transform. |
| **Profile-likelihood CIs (derived ratio quantities)** | experimental | Lagrange fix-and-refit pattern; empirical coverage study is the Phase 1b validation milestone. |
| **`extract_correlations(method = "profile")` for correlations** | experimental | Falls back to Wald on full-Sigma fits. |
| **`check_identifiability()` Procrustes diagnostic** | stable | Simulate-refit + Procrustes alignment; catches spurious extra factors. |
| **`check_auto_residual()` safeguard** | stable | Guards `link_residual = "auto"` against mixed-family / ordinal-probit edge cases. |
| **Phylogenetic covariance (`phylo_*()`)** | stable | Paired two-Psi form is the canonical recipe; three-piece fallback documented for small trees. |
| **Spatial covariance (`spatial_*()`, SPDE / mesh)** | stable | Inherited from `sdmTMB`; see [Joint species distribution modelling](https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html). |
| **`meta_known_V()` for known sampling covariance** | stable | Diagonal V scales well; dense V is small-to-moderate `n` only. |
| **Long-format engine + wide `traits(...)` LHS** | stable | Equivalent fits; long is canonical, wide is the convenience entry point. |
| **`lambda_constraint` (confirmatory loadings)** | stable | GALAMM-style entry pinning. See [Lambda constraints](https://itchyshin.github.io/gllvmTMB/articles/lambda-constraint.html). |
| **Multi-start optimisation (`n_init >= 2`)** | stable | Reduced-rank fits recommended to use `n_init >= 5`. |
| **`simulate.gllvmTMB_multi()`** | experimental | Gaussian-noise + selected RE tiers; non-Gaussian fits fall back to conditional simulation. Family-aware redraws are roadmap (Phase 5.5). |
| **`predict.gllvmTMB_multi()`** | experimental | `type = c("link", "response")`. Typed outputs for ordinal-probit category probabilities, delta presence / positive-mean, and mixed-family per-trait `linkinv` are roadmap. |
| **REML estimation** | planned | Roadmap for a post-0.2.0 release as a Gaussian-only feature. |
| **Random slopes `(1 + x | g)`** | planned | Phase 1c-slope; depends on the Phase 1b validation milestone closing first. |
| **`confint(method = c("wald", "profile", "bootstrap"))` for fixed effects** | planned | API surface to be aligned with the existing `profile_ci_*()` family (drmTMB-style `profile_targets()` inventory). |
| **Storage controls (`keep_tmb_object = FALSE`)** | planned | Mirror `drmTMB`'s pattern for serialised-fit footprint. |
| **Zero-inflated count families** | planned | Post-CRAN extension. |
| **SPDE barrier mesh** | planned | Post-CRAN extension. |

The **stable** rows are the core surface you can use in
publication-quality work today; the **experimental** rows are
under active validation (Phase 1b validation milestone in
progress); the **planned** rows are explicit gaps that future
releases will close. Items not in either of these three buckets
are out of scope -- see [`Current boundaries`](#current-boundaries).

## Install

`gllvmTMB` is not on CRAN yet. Install the development build from
GitHub with `pak`:

```r
install.packages("pak")
pak::pak("itchyshin/gllvmTMB")
```

Then load the package and run a small smoke test:

```r
library(gllvmTMB)

sim <- simulate_site_trait(
  n_sites = 12,
  n_species = 5,
  n_traits = 3,
  mean_species_per_site = 3,
  Lambda_B = matrix(c(0.8, 0.4, -0.3), ncol = 1),
  psi_B = c(0.2, 0.3, 0.2),
  seed = 1
)

fit <- gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | site, d = 1) +
    unique(0 + trait | site),
  data = sim$data,
  unit = "site"
)

fit
extract_communality(fit, level = "unit")
extract_correlations(fit, tier = "unit")
```

You need R 4.1.0 or newer and a working compiler toolchain because
TMB models are compiled during installation. If installation fails
while compiling C++, install the usual R build tools for your
platform: Rtools on Windows, Xcode Command Line Tools on macOS,
or the R development toolchain on Linux.

## Data shapes: long or wide, one entry point

One entry point handles both shapes. Use whichever matches your
data on disk; the engine pivots as needed.

- **Long data frame** -- one row per `(unit, trait)` observation,
  one `value` column for the response:
  ```r
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
           data = df_long, unit = "...")
  ```
- **Wide data frame** -- one row per unit, one column per trait;
  the `traits(...)` LHS marker names the response columns and the
  RHS uses compact wide shorthand:
  ```r
  gllvmTMB(traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2),
           data = df_wide, unit = "unit")
  ```

Predictors go into the formula in either form. Both paths reach
the same long-format engine and produce byte-identical fits.

## Tiny example

A one-level Gaussian GLLVM with shared and unique trait covariance
is:

```r
fit <- gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | site, d = 1) +
    unique(0 + trait | site),
  data = sim$data,    # long: one row per (site, trait)
  unit = "site"
)
```

The same model in wide form -- one row per site, columns `t1`,
`t2`, `t3` for the three traits -- uses the `traits(...)` LHS
marker:

```r
fit_wide <- gllvmTMB(
  traits(t1, t2, t3) ~ 1 +
    latent(1 | site, d = 1) +
    unique(1 | site),
  data = df_wide,     # wide: one row per site
  unit = "site"
)
```

Both calls reach the same long-format engine and produce
byte-identical fits. See the Get Started vignette for the
runnable long-to-wide pivot.

Here `latent(0 + trait | site, d = 1)` estimates one shared latent
axis across traits, and `unique(0 + trait | site)` estimates the
trait-specific residual variance left over after that shared axis.
The fitted object reports ordination scores, loadings, Sigma,
pairwise correlations, and per-trait communality.

In notation, the trait covariance the model fits is

```text
Sigma = Lambda Lambda^T + diag(psi)
```

where `Lambda` is the shared-axis loading matrix (set by
`latent()`) and `psi` (the Greek letter Psi, matching the
factor-analysis / SEM convention) is the trait-specific
residual variance (set by `unique()`).

## Covariance keyword grid

The formula grammar is a 3 x 5 grid: correlation source crossed
with covariance mode.

|                | scalar             | unique             | indep             | dep             | latent             |
|---             |---                 |---                 |---                |---              |---                 |
| **none**       | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| **phylo**      | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| **spatial**    | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The decomposition mode is `latent + unique` paired:

```text
Sigma = Lambda Lambda^T + diag(psi)
```

Standalone `latent()` is the no-residual reduced-rank subset.
Standalone `unique()` is the marginal independent mode and is
equivalent to `indep()`. `dep()` estimates a full unstructured
Sigma.

## Current boundaries

`gllvmTMB` is for stacked-trait multivariate models. Single-response
models belong in `glmmTMB`; spatial single-response models belong
in `sdmTMB`; one- or two-response distributional regression
belongs in `drmTMB`.

Random slopes through `(1 + x | g)` syntax are not yet implemented.
The current structured-effect paths are strongest for
intercept-only latent, unique, phylogenetic, and spatial
covariance terms.

Zero-inflated count families, SPDE barrier meshes, and a
first-class two-level phylogeny plus non-phylogeny API are planned
work.

## Citation and acknowledgements

If you use gllvmTMB, please cite the package and the engine /
dependency papers it builds on. Run `citation("gllvmTMB")` for
formatted entries; the curated list is:

- **gllvmTMB**: Nakagawa S (in prep). *gllvmTMB: stacked-trait,
  long-format multivariate generalised linear latent variable
  models with TMB.* R package version 0.2.0.
- **TMB engine**: Kristensen K, Nielsen A, Berg CW, Skaug H,
  Bell BM (2016). *TMB: Automatic Differentiation and Laplace
  Approximation.* Journal of Statistical Software, 70(5), 1-21.
  <doi:10.18637/jss.v070.i05>
- **sdmTMB (when using `spatial_*()` keywords)**: Anderson SC,
  Ward EJ, English PA, Barnett LAK, Thorson JT (2025). *sdmTMB:
  An R Package for Fast, Flexible, and User-Friendly Generalized
  Linear Mixed Effects Models with Spatial and Spatiotemporal
  Random Fields.* Journal of Statistical Software, 115(2), 1-36.
  <doi:10.18637/jss.v115.i02>

gllvmTMB inherits SPDE / mesh / anisotropy R helpers (`R/mesh.R`,
`R/crs.R`, parts of `R/plot.R`) from `sdmTMB` (Sean C. Anderson,
Eric J. Ward, Philina A. English, Lewis A. K. Barnett) under
GPL-3. Provenance is recorded in `inst/COPYRIGHTS`, and the
inherited R files carry file-top comments pointing at that file.
TMB itself is a runtime dependency rather than included code; the
gllvmTMB C++ engine in `src/gllvmTMB.cpp` is original work by the
package author, written against the TMB API.

## Sister packages

- `drmTMB` fits univariate and bivariate distributional
  regression, including location-scale and bivariate
  residual-correlation models.
- `glmmTMB` fits single-response GLMMs.
- `sdmTMB` fits spatial single-response models. `gllvmTMB`
  inherits sdmTMB's SPDE and mesh code for its `spatial_*()`
  keywords.
- `gllvm` (Niku et al.) is the original multivariate GLLVM package
  with a variational-approximation engine and a matrix-in API;
  `gllvmTMB` is the TMB-Laplace alternative with formula grammar,
  the 3 x 5 keyword grid, and integrated phylogenetic / spatial
  paths in one engine.
- `MCMCglmm` and `brms` are Bayesian alternatives for multivariate
  phylogenetic / multi-response models; `gllvmTMB` returns ML
  point estimates with profile / Wald / bootstrap CIs and runs
  in seconds-to-minutes rather than minutes-to-hours.

A full scope comparison and decision matrix lives in
[`docs/design/04-sister-package-scope.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/04-sister-package-scope.md)
on GitHub.

## Roadmap

The package is pre-CRAN. The
[roadmap](https://itchyshin.github.io/gllvmTMB/articles/roadmap.html)
shows what is stable today, what is in flight, and what is
planned next; it is refreshed as work progresses, and it is the
canonical place to check the current status of every phase
before adopting `gllvmTMB` for a project.
