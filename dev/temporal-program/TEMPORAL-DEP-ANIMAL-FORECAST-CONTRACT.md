# Temporal-dependent animal future-observation forecast contract

## Purpose

`forecast_temporal()` admits replicated Gaussian AR1
`temporal_dep() + animal_indep()` with one fixed labelled animal relationship.
For response rows `i,i'`, animal labels `h,h'`, series labels `g,g'`, times
`t,t'`, and traits `j,j'`, it conditions the additive fitted covariance

\[
V_{ii'} = 1(g=g')\phi^{|t-t'|}\Sigma_{T,jj'} +
A_{hh'}1(j=j')v_{A,j} + 1(i=i')\sigma_\epsilon^2.
\]

The helper uses the complete retained relationship recovered from
`Ainv_phy_rr`, maps the original animal labels through `species_aug_id`, and
uses the packed full temporal covariance.  It computes the fixed-parameter
Gaussian conditional mean and variance; `se.fit` excludes parameter
uncertainty and is not a prediction interval.

## Admission and refusals

Require exactly one replicated Gaussian AR1 `temporal_dep()` intercept block
and one fixed intercept-only `animal_indep()` block at `rho = 1`, without
ordinary covariance, another source, attenuation, slopes, temporal Psi, or a
second temporal block. Future rows must use fitted animals/series, integer
occasions strictly after each series' last fitted occasion, and complete
measurement-by-trait panels.

Refuse OU, temporal-independent or rank-one animal fits, new animals or
series, interpolation, missing or duplicate rows, incomplete panels, generic
new-data prediction, intervals, selection, and all other source-pair
forecasts. The profile/bootstrap route is separately contracted.

## Required evidence and boundary

An independently authored dense oracle must reconstruct the full covariance
from the packed temporal Cholesky factor, fixed labelled animal relationship,
animal variances, and measurement variance. It must match positive and
negative-persistence conditional means and standard deviations, distinguish
the additive covariance from an invalid animal-by-time product, preserve input
row order, and reject an unseen animal. This local fixed-parameter check does
not establish calibration, recovery, coverage, cross-platform verification,
merge, or release readiness.
