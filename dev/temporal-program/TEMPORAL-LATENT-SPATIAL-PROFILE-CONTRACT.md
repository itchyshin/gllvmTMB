# Rank-one temporal-spatial direct-profile contract

This route admits `profile_temporal()` only for replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE) + spatial_indep()` with one fixed,
intercept-only mesh source at `rho = 1`. It profiles only
`theta_temporal_time`; each point re-optimizes the signed rank-one temporal
loadings, spatial trait-diagonal variances and range, measurement variance, and
fixed effects in the marginal TMB objective. The mesh remains fixed.

The focused test matches the transformed AR1 MLE and the profile objective at
that MLE against a direct `TMB::tmbprofile()` trace. It does not profile spatial
range or scale, loadings, derived covariance targets, or conditional temporal
scores. Returned endpoints are not calibrated intervals or coverage evidence.
OU, temporal Psi, rank above one, ordinary terms, other source pairs, generic
`confint()`, and selection claims remain outside this contract.
