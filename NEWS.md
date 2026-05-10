# gllvmTMB 0.2.0

This release rebuilds gllvmTMB from a clean repository, modelled on
the drmTMB sister package's "regimented" team and tooling. The
package is now a focused multivariate stacked-trait GLLVM engine:
the legacy 133-export NAMESPACE is trimmed to ~50 gllvmTMB-native
exports, and the inherited single-response sdmTMB code paths are
gone.

## Major changes

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

* Authors@R cph list trimmed from 21 entries to 5: Nakagawa
  (gllvmTMB-native code), Anderson + Ward + English + Barnett
  (inherited sdmTMB SPDE/mesh code in `R/mesh.R`, `R/crs.R`,
  `R/plot.R`'s `plot_anisotropy*`), and Kristensen (TMB).

## Bug fixes

This is a fresh-repo bootstrap; there are no carry-forward bug
fixes. The legacy repo (`itchyshin/gllvmTMB-legacy`) preserves the
0.1.x history.
