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
> primary inferential output, but their evidence is route- and regime-specific.
> Broad package-wide interval coverage is not certified. Three exact native,
> pinned, unrotated ordinary-Gaussian standardized-loading Wald cells have
> target-specific certificates only in one frozen DGP, conditional on eligible fits;
> other parameter regimes and neighbouring cells do not inherit them.
> Total-variance penalty profiles are still only an approximate calculation:
> even for historically measured cells, we have not confirmed that the
> retained fix-and-refit endpoints match the exact profile-likelihood answer.

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
| decide whether your model and intended result are inside the current evidence boundary | [Current limitations and boundaries](https://itchyshin.github.io/gllvmTMB/articles/current-limits.html) |
| choose the guide matching your data and question | [Browse all articles](https://itchyshin.github.io/gllvmTMB/articles/) |
| check whether a fit is interpretable | [Can I trust this fit?](https://itchyshin.github.io/gllvmTMB/articles/fit-diagnostics.html) |
| look up formulas, covariance terms, or families | [Reference index](https://itchyshin.github.io/gllvmTMB/reference/) |

`gllvmTMB` is under active development and has lifecycle **experimental**: the
formula grammar, defaults, and extractor output may still change as the API
matures. The public path above is deliberately bounded. For Gaussian models,
point estimates have only been checked to recover known parameters under the
specific conditions tested so far, starting with `indep()` or `dep()`; inspect
the covariance point estimate. The latent model below remains the clearest way
to teach `Sigma = Lambda Lambda^T + Psi`, but for the two model shapes
recommended for real analyses, we have so far only measured how they behave —
we have not yet shown they recover known parameters — so treat this as a
teaching example, not a proven method. Bare-bar
`(1 + x | g)` slopes remain reserved.

## What the model does

The teaching example uses one ordinary Gaussian `latent()` model. It splits
the trait covariance matrix into shared axes plus trait-specific variance:

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

After the first CRAN release is accepted, install the released package with:

```r
install.packages("gllvmTMB")
```

Until then, install the development build from GitHub with `pak`:

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
`impute = list(...)` for the covered native-Laplace Gaussian, grouped,
phylogenetic, binary, ordered, and unordered fixed-effect routes. VA refuses
modelled `mi()` predictors. **Do not treat parser support as an NB2 reliability
claim:** the frozen NB2 latent missing-response cell produced catastrophic
dispersion failures that ordinary fit diagnostics often missed; that route is
not recommended for dependable inference. Ordinary missing
grouping variables, offsets, weights, or design-matrix values still error
because the model cannot build that row.

## Current support boundary

The canonical reader-facing boundary is
[Current limitations and boundaries](https://itchyshin.github.io/gllvmTMB/articles/current-limits.html).
Read it before choosing a family, covariance source, estimator, or interval
method. In brief:

- start from an ordinary native-Laplace model and inspect fit health;
- interpret rotation-invariant `Sigma`, correlations, and communality before
  raw loading columns;
- treat structured sources, slopes, alternative integration engines, and most
  non-Gaussian combinations as experimental or partial unless their guide names
  the evidence regime;
- do not infer interval calibration from the availability of Wald, bootstrap,
  or profile bounds.

`gllvmTMB` is for stacked-trait multivariate models. Use `glmmTMB` for a
single-response GLMM, `sdmTMB` for a single-response spatial model, and
`drmTMB` for one- or two-response distributional regression.

## Citation and acknowledgements

If you use gllvmTMB, please cite the package and its TMB engine.
Run `citation("gllvmTMB")` for formatted entries:

- **gllvmTMB**: Nakagawa S (2026). *gllvmTMB: Fit Multivariate
  Models from Wide Response Data.* R package version 0.7.1.
  <https://itchyshin.github.io/gllvmTMB/>
- **TMB engine**: Kristensen K, Nielsen A, Berg CW, Skaug H,
  Bell BM (2016). *TMB: Automatic Differentiation and Laplace
  Approximation.* Journal of Statistical Software, 70(5), 1-21.
  <https://doi.org/10.18637/jss.v070.i05>
The current spatial helpers were substantially rewritten in gllvmTMB against
the published SPDE/GMRF construction and public `fmesher` API after an earlier
implementation derived from the GPL-3 `sdmTMB` helpers. We retain sdmTMB
attribution in `inst/COPYRIGHTS`; the current implementation is covered by
focused tests, while the broader spatial family remains partial. TMB
itself is a runtime dependency rather than included code. Most of the
gllvmTMB C++ engine in `src/gllvmTMB.cpp` is original package code written
against the TMB API; `inst/COPYRIGHTS` separately records the same-author
GPL-3 numerical and missing-predictor code reused from `drmTMB`.
See the [spatial-model guide](https://itchyshin.github.io/gllvmTMB/articles/spatial-models.html#provenance-acknowledgement-and-licensing)
for the public provenance, acknowledgement, and GPL-3 explanation.

## Sister packages

- `drmTMB` fits univariate and bivariate distributional
  regression, including location-scale and bivariate
  residual-correlation models.
- `glmmTMB` fits single-response GLMMs.
- `sdmTMB` fits spatial single-response models; `gllvmTMB` fits
  multivariate stacked-trait spatial models through its own `spatial_*()`
  helper layer.
- `gllvm` (Niku et al. 2019; Korhonen et al. 2025 for `gllvm`
  2.0) is the established multivariate GLLVM / ordination package,
  with variational, extended-variational, and Laplace approximation
  paths plus a matrix-in API; `gllvmTMB` is the TMB-Laplace
  alternative with stacked-trait formula grammar and the three-mode
  covariance-keyword grid plus `common` and `unique` modifiers.
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
