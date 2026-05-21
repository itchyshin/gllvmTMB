# gllvmTMB

`gllvmTMB` fits multivariate models for data where each site,
individual, species, or study has several responses: body traits,
species occurrences, behaviours, outcomes, or similar measurements.
The main question is simple:

> Which responses vary together, and how much of that variation is shared
> versus response-specific?

The first public examples focus on the safest path: Gaussian
stacked-trait models that split the trait covariance matrix into
shared and trait-specific parts:

| Model piece | R syntax | What the reader should see |
|---|---|---|
| `Sigma` | `extract_Sigma(fit, level = "unit")` | The total covariance among traits. |
| `Lambda Lambda^T` | `latent(..., d = K)` | Shared axes: traits that rise and fall together across units. |
| `Psi` | `unique(...)` | Trait-specific variance left over after the shared axes. |

So `Sigma = Lambda Lambda^T + Psi` means: total trait covariance =
shared multivariate structure + response-specific variation.

You can fit the same model from long data or wide data. Long data are
canonical; wide data use the `traits(...)` formula marker and are pivoted
internally.

## Start Here

| If you want to... | Read this |
|---|---|
| fit your first model | [Get started with gllvmTMB](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html) |
| see the full worked example | [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html) |
| interpret `Sigma`, correlations, `Lambda`, `psi`, and communality | [Covariance and correlation](https://itchyshin.github.io/gllvmTMB/articles/covariance-correlation.html) |
| choose formula keywords | [Formula keyword grid](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html) |
| check response-family status | [Response families](https://itchyshin.github.io/gllvmTMB/articles/response-families.html) |
| diagnose hard fits | [Convergence and start values](https://itchyshin.github.io/gllvmTMB/articles/convergence-start-values.html) and [Common pitfalls](https://itchyshin.github.io/gllvmTMB/articles/pitfalls.html) |

This is preview version `0.2.0` and the package is pre-CRAN. Advanced
worked examples -- joint SDMs, profile-likelihood intervals, animal
models, phylogenetic GLLVMs, spatial models, mixed-family examples, and
meta-analysis -- are under audit. They will return to the public navbar
only after their example data, diagnostics, validation evidence, and
rendered HTML review pass.

## What "stacked-trait" Means

Internally, every fit sees one row per `(unit, trait)` observation.
Five traits on 100 individuals become 500 rows, with the trait identity
in a `trait` column and the response in a `value` column. The same entry
point also accepts a wide data frame through `traits(...)`.

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
  trait = "trait",
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
           data = df_long, trait = "trait", unit = "...")
  ```
- **Wide data frame** -- one row per unit, one column per trait;
  the `traits(...)` LHS marker names the response columns and the
  RHS uses compact wide shorthand (no `trait =` argument needed --
  the LHS *is* the trait spec):
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
  data  = sim$data,    # long: one row per (site, trait)
  trait = "trait",     # column holding the trait factor
  unit  = "site"       # column holding the between-unit grouping
)
```

The same model in wide form -- one row per site, columns `t1`,
`t2`, `t3` for the three traits -- uses the `traits(...)` LHS
marker (no `trait =` needed; the LHS *is* the trait spec):

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

## Current Status

The public site is intentionally small while `gllvmTMB` is pre-CRAN.
Use the table below as the homepage version; the detailed evidence lives in
the [validation-debt register](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/35-validation-debt-register.md)
and the [roadmap](https://itchyshin.github.io/gllvmTMB/articles/roadmap.html).

| Surface | Current message |
|---|---|
| Long and wide data | Both are supported through `gllvmTMB()`: long data use `value ~ ...` with `trait = "trait"`; wide data use `traits(...) ~ ...`. |
| First worked model | Gaussian `latent() + unique()` is the safest public example and is shown in [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html). |
| Formula keywords | The full 4 x 5 keyword grid is documented in [Formula keyword grid](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html), with covered/partial status labels. |
| Response families | Families are listed in [Response families](https://itchyshin.github.io/gllvmTMB/articles/response-families.html); do not assume every exported constructor is fully validated for multivariate fits. |
| Advanced examples | Joint SDM, animal, phylogenetic, spatial, mixed-family, meta-analysis, and profile-CI articles are under audit until their example objects, diagnostics, and validation gates pass. |

## Current boundaries

`gllvmTMB` is for stacked-trait multivariate models. Single-response
models belong in `glmmTMB`; spatial single-response models belong
in `sdmTMB`; one- or two-response distributional regression
belongs in `drmTMB`.

**Soft-deprecated in 0.2.0:**

- The legacy matrix wrapper `gllvmTMB_wide(Y, ...)` remains
  exported but is superseded by the formula-API `traits(...)` LHS
  through the single `gllvmTMB()` entry point. New examples and
  articles should use `traits(...)`; removal is a later API-change
  decision while the export remains live.

**Deferred to post-CRAN** (advertised in the roadmap, currently
not validated; named here so user-facing prose does not
overpromise):

- **Mixed-family latent-scale correlations with delta / hurdle
  families.** The two-stage structure of `delta_lognormal`,
  `delta_gamma`, etc. has no single latent-scale residual, so the
  cross-family Pearson correlation is undefined when one of the
  rows is a delta family. `check_auto_residual()` errors with
  class `gllvmTMB_auto_residual_delta_undefined` to prevent
  silent overpromise (MIX-10).
- **Random slopes through `(1 + x | g)` syntax**, capped at one
  slope for M1, with 2- and 3-slope support conditional on
  validation evidence (RE-02..RE-03).
- **`meta_V(type = "proportional")`** — Nakagawa (2022) unifying
  weighted-regression / meta-analysis
  mode; the current implemented mode is additive `type = "exact"`
  known-V (MET-03).
- **SPDE barrier meshes, REML estimation, storage controls.**
- **Zero-inflated / hurdle / two-stage delta families with
  latent-scale correlations.** Two-sub-model families have two
  latent scales (the zero-inflation logit + the count log; or
  the hurdle binary + the conditional-positive scale); the
  latent-scale correlation matrix is therefore ambiguous and
  requires reporting two correlations rather than one.
  Deferred indefinitely until a clean reporting convention is
  agreed.

For the complete row-by-row scope ledger including diagnostic
status and interval status, see the
[validation-debt register](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/35-validation-debt-register.md).

## Citation and acknowledgements

If you use gllvmTMB, please cite the package and the engine /
dependency papers it builds on. Run `citation("gllvmTMB")` for
formatted entries; the curated list is:

- **gllvmTMB**: Nakagawa S (2026). *gllvmTMB: stacked-trait,
  long-format multivariate generalised linear latent variable
  models with TMB.* R package version 0.2.0. <https://itchyshin.github.io/gllvmTMB/>
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
- `gllvm` (Niku et al. 2019; Korhonen et al. 2025 for `gllvm`
  2.0) is the established multivariate GLLVM / ordination package,
  with variational, extended-variational, and Laplace approximation
  paths plus a matrix-in API; `gllvmTMB` is the TMB-Laplace
  alternative with stacked-trait formula grammar, the 4 x 5 keyword
  grid, and issue-tracked validation for its phylogenetic / spatial
  covariance paths.
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
