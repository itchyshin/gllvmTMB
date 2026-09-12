# Rank-one temporal-kernel future-observation forecast contract

`forecast_temporal()` admits replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE) + kernel_indep()` with exactly
one fixed labelled diagonal kernel. For response rows `i,i'`, it conditions the
additive covariance
\[
1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}+
K_{g_i g_{i'}}1(j_i=j_{i'})v_{K,j_i}+1(i=i')\sigma_\epsilon^2.
\]
It forecasts complete future measurement-by-trait panels for fitted series
only. `se.fit` is a fitted-parameter conditional standard deviation, not an
interval or coverage claim. OU, temporal Psi, ranks above one, new series,
interpolation, generic new-data prediction, selection, intervals, and other
source pairs remain refused.

The independent dense-conditioning test rebuilds the full covariance from the
packed temporal loadings, fixed labelled kernel, kernel trait variances and
measurement variance, then matches conditional means and standard deviations.
This local check does not establish calibration, general recovery, or release
readiness.
