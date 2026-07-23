# gllvmTMB

<!-- badges: start -->
[![R-CMD-check](https://github.com/itchyshin/gllvmTMB/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/itchyshin/gllvmTMB/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/itchyshin/gllvmTMB/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/itchyshin/gllvmTMB/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> [!WARNING]
> **`gllvmTMB` is experimental — use at your own risk.** It is not complete, is
> not fully human-verified, and needs extensive further validation. CRAN
> availability is not a statement of scientific maturity. Point estimates are the
> supported claim; no cell's interval coverage is certified, and covariance routes
> have focused-test evidence only. Treat everything else as provisional until the
> package is declared mature.

`gllvmTMB` fits multivariate models for data where each site,
individual, species, or study has several responses: body traits,
species occurrences, behaviours, outcomes, or similar measurements.
The main question is simple:

> Which responses vary together, and how much of that variation is shared
> versus response-specific?

Unlike PCA or NMDS, `gllvmTMB` estimates latent structure **inside a
likelihood** rather than from a distance matrix or eigen-decomposition.
Loadings, correlations, and communalities can be paired with model-based
uncertainty where a target-specific route is supported; broad interval
calibration remains incomplete.

## Start Here

| If you want to... | Read this |
|---|---|
| fit your first model | [Get started with gllvmTMB](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html) |
| choose the guide matching your data and question | [Browse all articles](https://itchyshin.github.io/gllvmTMB/articles/) |
| check whether a fit is interpretable | [Can I trust this fit?](https://itchyshin.github.io/gllvmTMB/articles/fit-diagnostics.html) |
| look up formulas, covariance terms, or families | [Reference index](https://itchyshin.github.io/gllvmTMB/reference/) |

`gllvmTMB` is under active development and has lifecycle **experimental**: the
formula grammar, defaults, and extractor output may still change as the API
matures. The public path above is deliberately bounded — fit one
ordinary Gaussian model, then interpret `Sigma`, correlations, loadings, and
communality, then branch to diagnostics or keyword lookup. Bare-bar
`(1 + x | g)` slopes remain reserved.

## What the model does

Start with one ordinary Gaussian `latent()` model. It splits the
trait covariance matrix into shared axes plus trait-specific variance:

$$
\boldsymbol{\Sigma}
=
\boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\mathsf T}
+
\boldsymbol{\Psi},
\qquad
\boldsymbol{\Psi}
=
\operatorname{diag}(\psi_1,\ldots,\psi_T).
$$

In words: total trait covariance = shared multivariate structure +
response-specific variation. Read the equation from left to right:

| Model piece | R syntax | What it means |
|---|---|---|
| `Sigma` | `extract_Sigma_table(fit, level = "unit")` | The total covariance among traits, one report-ready row per entry. This is usually the first report-ready target. |
| `Lambda` | `latent(..., d = K)` | The loading matrix: one row per trait and one column per latent axis. Its raw entries are rotation-dependent, so start interpretation from `Sigma`, correlations, or communality. |
| `Lambda Lambda^T` | `extract_Sigma(fit, part = "shared")` | Shared axes: traits that rise and fall together across units. |
| `Psi` | ordinary `latent(...)` by default | Trait-specific variance left over after the shared axes. Each diagonal entry is one `psi_t`. |

Use `latent(...)` for this decomposed model, and `indep(...)` for a
standalone diagonal baseline.

Most readers will start from a wide data frame: one row per unit, one
column per trait. Use that shape directly with the `traits(...)` formula
marker. If your data are already stacked long, use the same `gllvmTMB()`
entry point with `value ~ ...`, `trait =`, and `unit =`. Internally, both
paths reach the same stacked-trait model.

## What "stacked-trait" Means

The user-facing data shape can be wide or long. The model itself is
stacked-trait: internally, every fit sees one row per `(unit, trait)`
observation. Five traits on 100 individuals become 500 model rows. The
wide `traits(...)` interface does that stacking for you; the long
interface lets you supply the stacked table yourself.

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

set.seed(1)
n_ind <- 30
n_rep <- 3
individual <- factor(rep(seq_len(n_ind), each = n_rep))

z <- rnorm(n_ind)[individual]
u <- matrix(rnorm(n_ind * 3, sd = 0.35), n_ind, 3)[individual, ]

df_wide <- data.frame(
  individual = individual,
  visit = rep(seq_len(n_rep), times = n_ind),
  bill_length = 0.8 * z + u[, 1] + rnorm(n_ind * n_rep, sd = 0.5),
  body_mass = 0.5 * z + u[, 2] + rnorm(n_ind * n_rep, sd = 0.5),
  wing_length = -0.3 * z + u[, 3] + rnorm(n_ind * n_rep, sd = 0.5)
)

fit <- gllvmTMB(
  traits(bill_length, body_mass, wing_length) ~ 1 +
    latent(1 | individual, d = 1),
  data = df_wide,
  unit = "individual"
)

fit
extract_communality(fit, level = "unit")
extract_Sigma_table(fit, level = "unit")
```

You need R 4.1.0 or newer and a working compiler toolchain because
TMB models are compiled during installation. If installation fails
while compiling C++, install the usual R build tools for your
platform: Rtools on Windows, Xcode Command Line Tools on macOS,
or the R development toolchain on Linux.

## Data shapes: wide or long, one entry point

One entry point handles both shapes. Start with wide data if that is
what you have on disk; use long data when your workflow already stores
one response per row.

- **Wide data frame** -- one row per unit, one column per trait. The
  `traits(...)` LHS marker names the response columns and the RHS uses
  compact wide shorthand (no `trait =` argument needed -- the LHS *is*
  the trait spec):
  ```r
  gllvmTMB(traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2),
           data = df_wide, unit = "unit")
  ```
- **Long data frame** -- one row per `(unit, trait)` observation, one
  `value` column for the response:
  ```r
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
           data = df_long, trait = "trait", unit = "unit")
  ```

Predictors go into the formula in either form. Both paths reach the same
stacked-trait model and produce the same fit (identical log-likelihood and
estimates). The [Get started](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html)
vignette shows the runnable wide/long equivalence.

Missing response cells are allowed. In a wide `traits(...)` data frame,
an `NA` trait value can be treated as an unobserved unit-trait cell; in
long data, an `NA` in the response column is treated the same way. The
other observed traits for that unit stay in the likelihood, and
`predict_missing()` reconstructs masked response cells when
`missing = miss_control(response = "include")` is used. Missing predictors
default to fail-loud, but one explicitly modelled `mi()` predictor is
supported through `missing = miss_control(predictor = "model")` and
`impute = list(...)` for the covered Gaussian, grouped, phylogenetic,
binary, ordered, and unordered fixed-effect routes. Ordinary missing
grouping variables, offsets, weights, or design-matrix values still error
because the model cannot build that row.

## Current support boundary

The public site is deliberately focused on workflows with usable examples and
an explicit evidence boundary. Use the table below as the current reader-facing
boundary; each linked guide states the narrower conditions under which its
examples and interpretations apply.

| Surface | Current message |
|---|---|
| Long and wide data | Both are supported through `gllvmTMB()`: long data use `value ~ ...` with `trait = "trait"`; wide data use `traits(...) ~ ...`. |
| Missing response cells | `NA` responses are treated as unobserved unit-trait cells (gated out of the likelihood) for long response rows and wide `traits(...)` cells, with `predict_missing()` for the reconstruction route. The masking is family-agnostic; the validated worked example is Gaussian, with other families covered by the same route but lighter recovery evidence so far. |
| Missing predictors | Supported for one explicitly modelled `mi()` predictor: Gaussian fixed, grouped, phylogenetic, binary, ordered, and unordered fixed-effect routes. Multiple `mi()` terms, non-Gaussian bounded/count predictors, and structured discrete predictor models are planned. |
| First worked model | Gaussian `latent()` with its default `Psi` companion is the safest public decomposition example and is shown in [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html). |
| Latent-rank choice | [How many latent dimensions should I fit?](https://itchyshin.github.io/gllvmTMB/articles/model-selection-latent-rank.html) compares Gaussian ordinary `latent()` candidate ranks with `logLik()`, AIC, BIC, and `check_gllvmTMB()` rows. These criteria help route model choice within a fixed candidate set; they do not prove the biological rank or replace diagnostics. |
| Formula keywords | The four taught covariance modes—Scalar, Independent, Dependent, and Latent—are documented across ordinary, animal, phylogenetic, and spatial sources in [Formula keyword grid](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html). |
| Response families | Families are listed in [Response families](https://itchyshin.github.io/gllvmTMB/articles/response-families.html); evidence depth and supported covariance regimes vary by family. |
| Fitted diagnostics | [Can I trust this fit?](https://itchyshin.github.io/gllvmTMB/articles/fit-diagnostics.html) shows the first post-fit triage. `check_gllvmTMB()` reports numerical fit health; `predictive_check()`, `residuals()`, and `diagnostic_table()` provide fitted-model response diagnostics for the scoped Gaussian, Poisson, and NB2 paths. These are diagnostic displays, not posterior predictive checks or interval calibration. |
| Deferred guides | Quantitative-genetic heritability, confirmatory loading constraints, applied mixed-response and ordinal workflows, broad interval calibration, and cross-package agreement do not yet have public worked guides. Their underlying functions may exist, but that alone is not a recommendation to use them for those scientific claims. |

## Current boundaries

`gllvmTMB` is for stacked-trait multivariate models. Single-response
models belong in `glmmTMB`; spatial single-response models belong
in `sdmTMB`; one- or two-response distributional regression
belongs in `drmTMB`.

**Not yet in this release** (named here so user-facing prose does not
overpromise):

- **Mixed-family latent-scale correlations for delta / hurdle families.**
  Designed but not advertised: the cross-family correlation is route-only
  and its coverage is uncalibrated.
- **Plain bare-bar random slopes `(1 + x | g)`.** Reserved. The keyworded
  Gaussian reaction-norm decomposition `latent(1 + x | unit, d = K)` (and its
  long-form equivalent) is available and extracts with
  `extract_Sigma(level = "unit_slope", ...)`.
- **Known-variance meta-analysis with `meta_V()`.** The function remains under
  development and has no public worked guide yet. Do not infer a complete
  applied workflow from the export alone.
- **SPDE barrier meshes and broader REML.** A narrow Gaussian-only `REML = TRUE`
  pilot ships; non-Gaussian, weighted, and missing-data REML remain later work.
- **Zero-inflated / hurdle / two-stage delta families with latent-scale
  correlations.** Two-sub-model families have two latent scales, so a single
  latent-scale correlation is ambiguous; deferred until a clean reporting
  convention is agreed.

## Citation and acknowledgements

If you use gllvmTMB, please cite the package and the engine /
dependency papers it builds on. Run `citation("gllvmTMB")` for
formatted entries; the curated list is:

- **gllvmTMB**: Nakagawa S (2026). *gllvmTMB: Fit Multivariate
  Models from Wide Response Data.* R package version 0.6.0.
  <https://itchyshin.github.io/gllvmTMB/>
- **TMB engine**: Kristensen K, Nielsen A, Berg CW, Skaug H,
  Bell BM (2016). *TMB: Automatic Differentiation and Laplace
  Approximation.* Journal of Statistical Software, 70(5), 1-21.
  <https://doi.org/10.18637/jss.v070.i05>
- **sdmTMB (when using `spatial_*()` keywords)**: Anderson SC,
  Ward EJ, English PA, Barnett LAK, Thorson JT (2025). *sdmTMB:
  An R Package for Fast, Flexible, and User-Friendly Generalized
  Linear Mixed Effects Models with Spatial and Spatiotemporal
  Random Fields.* Journal of Statistical Software, 115(2), 1-36.
  <https://doi.org/10.18637/jss.v115.i02>

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
  alternative with stacked-trait formula grammar and the four-mode
  covariance-keyword grid.
- `MCMCglmm` and `brms` are Bayesian alternatives for multivariate
  phylogenetic / multi-response models; `gllvmTMB` returns ML point
  estimates with profile, Wald, or bootstrap routes where supported. Method
  availability does not establish calibrated interval coverage; follow the
  boundary in the relevant guide before reporting uncertainty.

A full scope comparison and decision matrix lives in
[`docs/design/04-sister-package-scope.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/04-sister-package-scope.md)
on GitHub.

## Support boundary

Reader-facing support is defined by the current guides linked above. A formula
being accepted by the parser does not guarantee that its covariance parameters
are estimable from a particular data set; check fit health and the boundary in
the relevant guide before interpreting a model.
