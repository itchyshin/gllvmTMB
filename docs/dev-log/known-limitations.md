# Known limitations

Single source of truth for what gllvmTMB does and does not currently
support. The `after-task-audit` skill greps this file for terms like
"rejected", "only diagonal", "planned" to catch stale wording.

## Implemented

- The 3 x 5 covariance keyword grid (correlation x mode):
  - none: `unique`, `indep`, `dep`, `latent`;
  - phylogenetic: `phylo_scalar`, `phylo_unique`, `phylo_indep`,
    `phylo_dep`, `phylo_latent`, `phylo_slope`;
  - spatial: `spatial_scalar`, `spatial_unique`, `spatial_indep`,
    `spatial_dep`, `spatial_latent`.
- The decomposition mode `latent + unique` paired:
  Sigma = Lambda Lambda^T + diag(s).
- Per-trait response families: gaussian, binomial (with multi-trial),
  betabinomial, poisson, lognormal, Gamma, nbinom2, tweedie, Beta,
  student, truncated_poisson, truncated_nbinom2, delta_lognormal,
  delta_gamma, ordinal_probit.
- Phylogenetic representation via sparse A^-1 (Hadfield & Nakagawa
  2010) plus optional `phylo_vcv = Cphy` direct VCV input.
- Spatial representation via the SPDE/GMRF approximation inherited
  from sdmTMB; supports isotropic and anisotropic mesh choices.
- Profile-likelihood confidence intervals for derived quantities
  (repeatability, communality, phylogenetic signal, correlations).
- Wide-format input via `gllvmTMB_wide()` with `traits()` LHS marker.

## Not yet implemented

- Random slopes via the bar syntax `(1 + x | g)`. Currently only
  intercept-only random terms are supported.
- Zero-inflated families (ZINB / ZIP). Cut from the 0.2.0 family
  list; planned for a later phase.
- SPDE barrier path (`add_barrier_mesh`) for coastal data. Planned;
  the upstream sdmTMB code path is GPL-3-compatible and re-import
  is straightforward.
- Two-level phylogeny + non-phylogeny decomposition (the legacy
  audit's "two-U" path) is exposed only via the diagnostic
  cross-checks `compare_dep_vs_two_U()` and
  `compare_indep_vs_two_U()`. A first-class single-call API is
  planned.
- Bayesian sampling. Use `brms` or `MCMCglmm` for that.
