# gllvmTMB

<!-- badges: start -->
[![R-CMD-check](https://github.com/itchyshin/gllvmTMB/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/itchyshin/gllvmTMB/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/itchyshin/gllvmTMB/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/itchyshin/gllvmTMB/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`gllvmTMB` fits multivariate models for data where each site,
individual, species, or study has several responses: body traits,
species occurrences, behaviours, outcomes, or similar measurements.
The main question is simple:

> Which responses vary together, and how much of that variation is shared
> versus response-specific?

The first public examples start from the safest path: Gaussian
stacked-trait models that split the trait covariance matrix into
shared and trait-specific parts. Draft worked examples for behavioural
reaction norms, structured slopes, and cross-lineage kernels stay internal
until their reader paths are ready:

| Model piece | R syntax | What the reader should see |
|---|---|---|
| `Sigma` | `extract_Sigma_table(fit, level = "unit")` | The total covariance among traits, one report-ready row per entry. |
| `Lambda Lambda^T` | `latent(..., d = K)` | Shared axes: traits that rise and fall together across units. |
| `Psi` | `unique(...)` | Trait-specific variance left over after the shared axes. |

So `Sigma = Lambda Lambda^T + Psi` means: total trait covariance =
shared multivariate structure + response-specific variation.

Most readers will start from a wide data frame: one row per unit, one
column per trait. Use that shape directly with the `traits(...)` formula
marker. If your data are already stacked long, use the same `gllvmTMB()`
entry point with `value ~ ...`, `trait =`, and `unit =`. Internally, both
paths reach the same stacked-trait model.

## Start Here

| If you want to... | Read this |
|---|---|
| fit your first model | [Get started with gllvmTMB](https://itchyshin.github.io/gllvmTMB/articles/gllvmTMB.html) |
| see the full worked example | [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html) |
| choose how many latent dimensions to fit | [How many latent dimensions should I fit?](https://itchyshin.github.io/gllvmTMB/articles/model-selection-latent-rank.html) |
| interpret `Sigma`, correlations, `Lambda`, `psi`, and communality | [Covariance and correlation](https://itchyshin.github.io/gllvmTMB/articles/covariance-correlation.html) |
| choose formula keywords | [Formula keyword grid](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html) |
| check response-family status | [Response families](https://itchyshin.github.io/gllvmTMB/articles/response-families.html) |
| check whether a fit is interpretable | [Can I trust this fit?](https://itchyshin.github.io/gllvmTMB/articles/fit-diagnostics.html) |
| diagnose hard fits | [Convergence and start values](https://itchyshin.github.io/gllvmTMB/articles/convergence-start-values.html) and [Common pitfalls](https://itchyshin.github.io/gllvmTMB/articles/pitfalls.html) |

This is preview version `0.2.0` and the package is pre-CRAN. Advanced
worked examples return to the public navbar only after their example data
or exact syntax chunks, diagnostics, validation evidence, and rendered HTML
review pass. Ordinary individual-level Gaussian reaction norms, structured
random slopes, and cross-lineage coevolution remain buildable internal
workflows until their plain-language reader paths are ready.
Bare-bar `(1 + x | g)` slopes remain reserved.

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
    latent(1 | individual, d = 1) +
    unique(1 | individual),
  data = df_wide,
  unit = "individual"
)

fit
extract_communality(fit, level = "unit")
sigma_rows <- extract_Sigma_table(fit, level = "unit")
sigma_rows
corr_rows <- extract_correlations(fit, tier = "unit")
plot_correlations(corr_rows)
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

Predictors go into the formula in either form. Both paths reach
the same stacked-trait model and produce byte-identical fits.

Missing response cells are allowed. IN (MIS-21 / MIS-24): in a wide
`traits(...)` data frame, an `NA` trait value can be treated as an
unobserved unit-trait cell; in long data, an `NA` in the response column
is treated the same way. The other observed traits for that unit stay in
the likelihood, and `predict_missing()` reconstructs masked response
cells when `missing = miss_control(response = "include")` is used.
Missing predictors default to fail-loud, but one explicitly modelled
`mi()` predictor is supported through `missing =
miss_control(predictor = "model")` and `impute = list(...)` for the
covered v1 slices (MIS-25..MIS-31). Ordinary missing grouping variables,
offsets, weights, or design-matrix values still error because the model
cannot build that row.

## Tiny example

A one-level Gaussian GLLVM with shared and unique trait covariance
is:

```r
fit <- gllvmTMB(
  traits(bill_length, body_mass, wing_length) ~ 1 +
    latent(1 | individual, d = 1) +
    unique(1 | individual),
  data = df_wide,       # wide: one row per observation occasion
  unit = "individual"   # between-unit grouping
)
```

The same model in long form -- one row per `(individual, trait)`
observation -- uses explicit trait indicators:

```r
fit_long <- gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | individual, d = 1) +
    unique(0 + trait | individual),
  data  = df_long,      # long: one row per (individual, trait)
  trait = "trait",      # column holding the trait factor
  unit  = "individual"
)
```

Both calls reach the same stacked-trait model and produce
byte-identical fits. See the Get Started vignette for the
runnable long-to-wide pivot.

In the wide call, `latent(1 | individual, d = 1)` estimates one shared
latent axis across traits and its default diagonal Psi companion. In the
long call, the equivalent term is `latent(0 + trait | individual, d = 1)`.
Use `latent(..., residual = FALSE)` only when you deliberately want the
old no-residual low-rank subset. The fitted object reports ordination
scores, loadings, Sigma rows, pairwise correlations, and per-trait
communality.

In notation, the trait covariance the model fits is

```text
Sigma = Lambda Lambda^T + diag(psi)
```

where `Lambda` is the shared-axis loading matrix (set by
`latent()`) and `psi` (the Greek letter Psi, matching the
factor-analysis / SEM convention) is the trait-specific
residual variance carried by ordinary `latent()`. Explicit
`latent() + unique()` formulas remain compatibility syntax for older
examples.

## Current Status

The public site is intentionally small while `gllvmTMB` is pre-CRAN.
Use the table below as the homepage version; the detailed evidence lives in
the [validation-debt register](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/35-validation-debt-register.md)
and the [roadmap](https://itchyshin.github.io/gllvmTMB/articles/roadmap.html).

| Surface | Current message |
|---|---|
| Long and wide data | Both are supported through `gllvmTMB()`: long data use `value ~ ...` with `trait = "trait"`; wide data use `traits(...) ~ ...`. |
| Missing response cells | Covered for long response rows and wide `traits(...)` cells: `NA` responses can be treated as unobserved unit-trait cells, with `predict_missing()` for the masked-response route (MIS-21 / MIS-24). |
| Missing predictors | Covered for one explicitly modelled `mi()` predictor in the shipped v1 slices: Gaussian fixed, grouped, phylogenetic, binary, ordered, and unordered fixed-effect routes. Multiple `mi()` terms, non-Gaussian bounded/count predictors, and structured discrete predictor models remain planned (MIS-25..MIS-32). |
| First worked model | Gaussian ordinary `latent()` is the safest public decomposition example and is shown in [Morphometrics](https://itchyshin.github.io/gllvmTMB/articles/morphometrics.html). |
| Latent-rank choice | [How many latent dimensions should I fit?](https://itchyshin.github.io/gllvmTMB/articles/model-selection-latent-rank.html) compares Gaussian ordinary `latent()` candidate ranks with `logLik()`, AIC, BIC, and `check_gllvmTMB()` rows. These criteria help route model choice within a fixed candidate set; they do not prove the biological rank or replace diagnostics. |
| Formula keywords | The full 4 x 5 keyword grid is documented in [Formula keyword grid](https://itchyshin.github.io/gllvmTMB/articles/api-keyword-grid.html), with covered/partial status labels. |
| Response families | Families are listed in [Response families](https://itchyshin.github.io/gllvmTMB/articles/response-families.html); do not assume every exported constructor is fully validated for multivariate fits. |
| Fitted diagnostics | [Can I trust this fit?](https://itchyshin.github.io/gllvmTMB/articles/fit-diagnostics.html) shows the first post-fit triage. `check_gllvmTMB()` reports numerical fit health (DIA-08 / DIA-10). `predictive_check()`, `residuals()`, and `diagnostic_table()` provide fitted-model response diagnostics and report-ready diagnostic tables for the scoped Gaussian, Poisson, and NB2 paths (DIA-11 / DIA-12 / DIA-13). These are diagnostic displays, not posterior predictive checks or interval calibration. |
| Advanced examples | Ordinary individual-level Gaussian reaction norms now have a buildable internal behavioural-syndrome draft with long and wide examples, diagnostics, and recovery figures; non-Gaussian augmented `unique()` remains guarded. Structured random slopes, cross-lineage coevolution, animal, phylogenetic, spatial, mixed-family, meta-analysis, and profile-CI pages keep their own validation and diagnostic boundaries and stay out of the first-click public model guide until their reader paths are ready. |

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

**Current boundaries and deferred work** (named here so user-facing
prose does not overpromise):

- **Mixed-family latent-scale correlations with delta / hurdle
  families.** The two-stage structure of `delta_lognormal`,
  `delta_gamma`, etc. has no single latent-scale residual, so the
  cross-family Pearson correlation is undefined when one of the
  rows is a delta family. `check_auto_residual()` errors with
  class `gllvmTMB_auto_residual_delta_undefined` to prevent
  silent overpromise (MIX-10).
- **Ordinary random slopes through `(1 + x | g)` syntax.** Plain,
  non-structured bare-bar random slopes remain reserved. The keyworded
  ordinary Gaussian reaction-norm decomposition
  `latent(1 + x | unit, d = K)` / long-form equivalent is implemented under
  RE-12 and extracts with
  `extract_Sigma(level = "unit_slope", part = "shared" / "unique" / "total")`.
  Explicit augmented `unique(1 + x | unit)` remains Gaussian-only compatibility
  syntax, while the non-Gaussian ordinary latent path has smoke evidence only
  and stays low-rank-only. One structured random slope
  (`s = 1`) is covered
  across the phylogenetic and spatial grid for the core families. Gaussian
  `phylo_dep(1 + x1 + x2 | g)` is covered under RE-03. Non-Gaussian
  `phylo_dep(..., s >= 2)` remains fail-loud guarded pending the RE-03
  diagnostic gate.
- **`meta_V(type = "proportional")`** — Nakagawa (2022) unifying
  weighted-regression / meta-analysis
  mode; the current implemented mode is additive `type = "exact"`
  known-V (MET-03).
- **SPDE barrier meshes, broader REML estimation, storage controls.**
  A narrow Gaussian-only `REML = TRUE` pilot is implemented; non-Gaussian,
  weighted, and missing-data REML remain later work.
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

- **gllvmTMB**: Nakagawa S (2026). *gllvmTMB: Fit Multivariate
  Models from Wide Response Data.* R package version 0.2.0.
  <https://itchyshin.github.io/gllvmTMB/>
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
