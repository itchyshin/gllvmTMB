# Spatial Derived-Profile Gap Audit

**Date:** 2026-07-03  
**Scope:** read-only Fisher / Gauss / Rose audit of the spatial
`spatial_latent()` profile and covariance surface needed for the Ayumi
site-by-trait functional phylogeography reanalysis.

## Question

Can the current package support final claims from model-based spatial
latent correlations, commonality, and profile-likelihood intervals for a
site-by-trait functional phylogeography model?

The target model for the Ayumi analysis is:

```r
value_z ~ 0 + trait +
  (0 + trait):mean_tavg_z +
  (0 + trait):mean_prec_z +
  (0 + trait):sd_tavg_z +
  (0 + trait):sd_prec_z +
  spatial_latent(0 + trait | site, d = K, unique = TRUE,
                 coords = c("x_1000km", "y_1000km"))
```

with the intended spatial covariance

```text
Sigma_spde = Lambda_spde Lambda_spde' + diag(Psi_spde)
```

## Finding

Current `gllvmTMB` profile machinery is real, but the spatial-derived
route is not yet the total-covariance target needed for this analysis.

Evidence:

- `R/fit-multi.R` describes `spatial_latent()` as switching from the
  per-trait `omega_spde` path to the low-rank `omega_spde_lv` path. In
  the spatial-latent branch it maps off `log_tau_spde` and `omega_spde`,
  and only `omega_spde_lv` is random.
- `src/gllvmTMB.cpp` reports `Sigma_spde = Lambda_spde *
  Lambda_spde.transpose()` on the spatial-latent path. No spatial
  diagonal Psi companion is added there.
- `R/extract-sigma.R` sets `S <- NULL` for `level = "spde"` and records
  the note that the spatial latent tier has no unique component.
- `R/profile-derived.R::profile_ci_correlation()` sets
  `ix_diag <- integer(0)` and `use_diag <- FALSE` in the spatial branch,
  so profile correlations are for the low-rank spatial covariance only.
- The parser / fit setup currently detects the first `spde` term for the
  `is_spatial_latent` switch, so paired spatial syntax is not yet a
  robust two-component decomposition.
- The validation row `SPA-02` is now downgraded to `partial`: the cited
  tests mostly prove convergence plus a low-rank `rho:spatial` profile
  smoke. They do not prove that the total covariance includes a spatial
  unique diagonal.

## Consequence For Ayumi

The suspicious between-site correlation panels with values close to
`-1` and `1` are expected if the covariance is rank-1
`Lambda_spde Lambda_spde'` without `diag(Psi_spde)`. Those panels must
not be interpreted as final evidence for spatial morphology-nest
integration.

For the current 3000-species functional phylogeography analysis:

- model-based spatial maps and loadings from the accepted-sensitivity M4
  fit can remain exploratory / diagnostic;
- spatial correlation, commonality, and variance-partition figures must
  be labelled as low-rank or Wald-only unless rerun after the spatial
  unique fold lands;
- profile-likelihood completion for spatial total covariance is a
  package-capability prerequisite, not merely a compute retry.

## Required Package Work

1. Add the source-specific API contract:

   ```r
   spatial_latent(..., d = K, unique = TRUE)
   spatial_latent(..., d = K, unique = FALSE)
   ```

   where `unique = TRUE` means
   `Sigma_spde = Lambda_spde Lambda_spde' + diag(Psi_spde)`.

2. Keep `unique = FALSE` as the old low-rank-only path.

3. In the TMB/R contract, keep both random-effect blocks active when
   `spatial_latent(unique = TRUE)` is requested:

   ```text
   omega_spde_lv  # shared spatial latent fields
   omega_spde     # per-trait unique spatial fields
   ```

4. Report enough transformed quantities for extractors:

   ```text
   Lambda_spde
   Sigma_spde_shared
   sd_spde_unique or Psi_spde
   Sigma_spde_total
   ```

5. Update derived extractors so total spatial covariance is the default
   target:

   - `extract_Sigma(level = "spatial", part = "total")`
   - `extract_correlations(tier = "spatial")`
   - `profile_ci_correlation(tier = "spatial")`
   - `profile_correlation(tier = "spatial")`
   - `profile_ci_communality()` / `profile_communality()` if spatial is
     admitted as a communality tier
   - `profile_ci_proportions()` / `profile_proportions()` if spatial
     proportions are reported.

6. Add RED tests before implementation:

   - parser marker: `spatial_latent(..., unique = TRUE)` is recorded;
   - random-vector contents: both `omega_spde_lv` and `omega_spde` are
     random;
   - report contents: both `Lambda_spde` and unique spatial SD/Psi are
     present;
   - rank-1 total correlations are not forced to `+-1` when the unique
     spatial diagonal is non-zero;
   - `extract_Sigma(level = "spatial", part = "total")` equals shared
     plus unique;
   - `profile_ci_correlation(tier = "spatial")` profiles the same total
     covariance used by `extract_Sigma()`.

## Temporary Claim Boundary

Until those tests pass, the honest status is:

```text
spatial_latent() low-rank covariance: available
spatial_latent() + spatial unique total covariance: partial / not final
spatial total-covariance derived profile CIs: incomplete
Ayumi spatial correlation/commonality figures: exploratory only
```

## Reviewer Ledger

- **Gauss:** the current engine switches between per-trait SPDE fields
  and low-rank shared SPDE fields; it does not keep both on the
  intercept-only spatial-latent path.
- **Fisher:** profile likelihood exists, but current spatial derived
  profiles are not the total-covariance estimand needed for inference.
- **Noether:** the formula-to-estimand alignment is wrong if a caption
  says `spatial_latent + unique` but the extracted covariance is only
  `Lambda_spde Lambda_spde'`.
- **Rose:** validation-debt wording must be downgraded from covered to
  partial for the paired spatial decomposition until total-covariance
  tests land.
