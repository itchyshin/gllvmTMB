# Rank-one temporal-animal direct-profile contract

This route admits `profile_temporal()` only for replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE) + animal_indep()` with one fixed
intercept-only relationship source at `rho = 1`. It profiles only
`theta_temporal_time`; each point re-optimizes the signed rank-one temporal
loadings, animal trait-diagonal variances, measurement variance, and fixed
effects in the marginal TMB objective.

The focused test matches the transformed AR1 MLE and the profile objective at
that MLE against a direct `TMB::tmbprofile()` trace. It does not profile animal
variances, loadings, derived covariance targets, or conditional temporal
scores. Returned endpoints are not calibrated intervals or coverage evidence.
OU, temporal Psi, rank above one, ordinary terms, other source pairs, generic
`confint()`, and bootstrap/selection claims remain outside this contract.
