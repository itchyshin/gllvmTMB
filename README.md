# gllvmTMB

`gllvmTMB` fits stacked-trait multivariate generalised linear latent
variable models (GLLVMs) with Template Model Builder. Use it when the
same units have several responses, traits, species, behaviours, or
items, and the scientific question is about their shared covariance,
ordination, communality, phylogenetic signal, or spatial structure.

The package accepts data in either **long** or **wide** shape; the
two paths reach the same engine, and you pick whichever shape
matches your data on disk:

- **Long** -- one row per `(unit, trait)` observation:
  ```r
  gllvmTMB(value ~ ..., data = df_long, unit = "...", ...)
  ```
- **Wide** -- one row per unit, one column per trait. `Y` is either
  a numeric matrix or a wide data frame; `gllvmTMB_wide()` detects
  the container and pivots internally:
  ```r
  gllvmTMB_wide(Y, ...)
  ```

The first examples are motivated by ecology, evolution, and
environmental science, but the data shape is general: site x
species, individual x trait, species x trait, paper x outcome, or
any similar unit x response layout.

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

## Preview status

This site is built from preview version `0.2.0`. The package is
pre-CRAN and intentionally bounded: use it for the implemented
stacked-trait workflows listed below, and treat unsupported model
classes as roadmap work rather than hidden features.

The legacy repository at
[`itchyshin/gllvmTMB-legacy`](https://github.com/itchyshin/gllvmTMB-legacy)
preserves the 0.1.x history. The current package is a fresh,
focused rebuild.

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
  S_B = c(0.2, 0.3, 0.2),
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
platform: Rtools on Windows, Xcode Command Line Tools on macOS, or
the R development toolchain on Linux.

## Tiny example

A one-level Gaussian GLLVM with shared and unique trait covariance is:

```text
y_it = alpha_t + z_i lambda_t + epsilon_it
z_i ~ Normal(0, 1)
epsilon_it ~ Normal(0, s_t)
Sigma = Lambda Lambda^T + diag(s)
```

```r
fit <- gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | site, d = 1) +
    unique(0 + trait | site),
  data = sim$data,
  unit = "site"
)
```

Here `latent(0 + trait | site, d = 1)` estimates one shared latent
axis across traits, and `unique(0 + trait | site)` estimates the
trait-specific residual variance left over after that shared axis.
The fitted object can then report ordination scores, loadings,
Sigma, pairwise correlations, and per-trait communality.

## What can I model now?

- **Continuous stacked traits.** Use Gaussian GLLVMs with `latent()`,
  `unique()`, `indep()`, or `dep()` for individual x trait, site x
  trait, or species x trait data. Read
  [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html).
- **Binary or count multivariate responses.** Use binomial, Poisson,
  negative-binomial, Tweedie, beta, beta-binomial, Student-t,
  truncated, delta, or ordinal-probit families when each trait has
  its own response distribution. Read
  [Joint species distribution modelling](https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html)
  and the
  [reference index](https://itchyshin.github.io/gllvmTMB/reference/index.html).
- **Reduced-rank ordination.** Use `latent(0 + trait | unit, d = K)`
  when a few latent dimensions should explain many cross-trait
  associations.
- **Trait-specific residual variance.** Pair `latent()` with
  `unique()` when you need
  `Sigma = Lambda Lambda^T + diag(s)` rather than a latent-only
  covariance.
- **Phylogenetic trait covariance.** Use `phylo_latent()` and
  `phylo_unique()` when species relatedness should contribute to
  cross-trait covariance.
- **Spatial multivariate structure.** Use `spatial_latent()` and
  related `spatial_*()` keywords with meshes created by `make_mesh()`
  when sites share spatially structured multivariate residuals.
- **Known sampling covariance.** Use `meta_known_V(V = V)` for
  multivariate meta-analytic sampling covariance.

## Covariance keyword grid

The formula grammar is a 3 x 5 grid: correlation source crossed with
covariance mode.

|                | scalar             | unique             | indep             | dep             | latent             |
|---             |---                 |---                 |---                |---              |---                 |
| **none**       | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| **phylo**      | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| **spatial**    | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The decomposition mode is `latent + unique` paired:

```text
Sigma = Lambda Lambda^T + diag(s)
```

Standalone `latent()` is the no-residual reduced-rank subset.
Standalone `unique()` is the marginal independent mode and is
equivalent to `indep()`. `dep()` estimates a full unstructured Sigma.

## Current boundaries

`gllvmTMB` is for stacked-trait multivariate models. Single-response
models belong in `glmmTMB`; spatial single-response models belong in
`sdmTMB`; one- or two-response distributional regression belongs in
`drmTMB`.

The package accepts data in either **long** or **wide** shape.
`gllvmTMB(value ~ ..., data = df_long)` is the long-format path;
`gllvmTMB_wide(Y, ...)` is the wide path (`Y` is a numeric matrix or
a wide data frame). Both reach the same long-format engine.

Random slopes through `(1 + x | g)` syntax are not yet implemented.
The current structured-effect paths are strongest for intercept-only
latent, unique, phylogenetic, and spatial covariance terms.

Zero-inflated count families, SPDE barrier meshes, and a first-class
two-level phylogeny plus non-phylogeny API are planned work.

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

- `drmTMB` fits univariate and bivariate distributional regression,
  including location-scale and bivariate residual-correlation models.
- `glmmTMB` fits single-response GLMMs.
- `sdmTMB` fits spatial single-response models. `gllvmTMB` inherits
  sdmTMB's SPDE and mesh code for its `spatial_*()` keywords.
