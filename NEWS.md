# gllvmTMB 0.2.0

This release rebuilds gllvmTMB from a clean repository, modelled on
the drmTMB sister package's "regimented" team and tooling. The
package is now a focused multivariate stacked-trait GLLVM engine:
the legacy 133-export NAMESPACE is trimmed to ~50 gllvmTMB-native
exports, and the inherited single-response sdmTMB code paths are
gone.

## Major changes

* The user-facing data shape is now **two ways**: long or wide.
  `gllvmTMB(value ~ ..., data = df_long, ...)` is the long-format
  path. Wide data frames use the formula-LHS `traits(...)` marker
  with compact syntax such as
  `traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2)`.
  Fixed predictors, `latent()` / `unique()` / `indep()` / `dep()`,
  bar-style `phylo_indep()` / `phylo_dep()`, and `spatial_*()` terms
  expand to the long trait-stacked formula; species-axis
  `phylo_scalar()` / `phylo_unique()` / `phylo_latent()` calls and
  ordinary `(1 | group)` random intercepts keep their existing syntax.
  Wide matrices use `gllvmTMB_wide(Y, ...)`.

* The package is standalone in the literal sense: it no longer
  exports `sdmTMB()`, `sdmTMB_cv()`, `sdmTMB_simulate()`,
  `sdmTMBpriors()`, `dharma_residuals()`, `cv_to_waywiser()`,
  `set_delta_model()`, `visreg_delta()`, `visreg2d_delta()`,
  `cAIC()`, `sanity()`, `run_extra_optimization()`, the
  `get_index*` family, the `gather_sims` / `spread_sims` / `project`
  family, or the inherited single-response S3 methods on the
  `gllvmTMB` class. Users wanting these can install
  `pbs-assess/sdmTMB` directly; gllvmTMB and sdmTMB do not conflict
  at install time.

* The TMB engine is compiled at install time as `src/gllvmTMB.cpp`
  (renamed from the legacy runtime-compiled
  `inst/tmb/gllvmTMB_multi.cpp`). The DLL is registered via
  `useDynLib(gllvmTMB, .registration = TRUE)`.

* The 3 x 5 covariance keyword grid (correlation x mode) is the
  canonical formula API:

  | correlation \ mode | scalar | unique | indep | dep | latent |
  |---|---|---|---|---|---|
  | none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
  | phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
  | spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

  The decomposition mode is `latent + unique` paired:
  Sigma = Lambda Lambda^T + diag(s).

* `gllvmTMB()` now requires at least one covariance-structure term.
  The legacy "no-covstruct" path that dispatched to `sdmTMB()`
  internally is removed; calling `gllvmTMB(y ~ 0 + trait, data = df)`
  without a covstruct keyword now errors with a pointer to
  `glmmTMB::glmmTMB()`.

* `gllvmTMBcontrol()` no longer carries a `sdmTMBcontrol` slot.
  Extra `...` arguments to `gllvmTMBcontrol()` emit a warning.

* Articles are tiered. The pkgdown navbar shows seven Tier-1
  worked-example articles plus the Get Started vignette: morphometrics,
  joint-sdm, behavioural-syndromes, choose-your-model,
  covariance-correlation, functional-biogeography, pitfalls. The
  `article-tier-audit` skill encodes the triage.

* Authors@R lists only Shinichi Nakagawa (the sole author of
  gllvmTMB). Upstream copyright holders for inherited code
  (Anderson, Ward, English, Barnett for sdmTMB SPDE / mesh /
  anisotropy R helpers; Kristensen for TMB; Thorson for VAST
  transitively via sdmTMB) are acknowledged in `inst/COPYRIGHTS`,
  `inst/CITATION`, README, and file-top comments of the inherited
  R files. This matches the CRAN-recommended pattern in "Writing
  R Extensions" §1.1.1 (use a `Copyright: inst/COPYRIGHTS` field
  rather than `cph` entries in Authors@R for inherited-code
  copyright holders) and the drmTMB author convention.
* New `inst/CITATION` curates `citation("gllvmTMB")` -- primary
  entry is the (in-prep) Nakagawa methods paper; companion
  entries cite Kristensen et al. (2016) for TMB and Anderson
  et al. (2025) for sdmTMB when the spatial path is used.

## Bug fixes

* `gllvmTMB_wide()` now keeps wide response cells, row-broadcast weights, and site-level predictors aligned when `X` is supplied; `gllvmTMB()`, `gllvmTMB_wide()`, and `traits()` also share one weight-shape validator.

The legacy repo (`itchyshin/gllvmTMB-legacy`) preserves the 0.1.x
history.
