# Temporal-dependent spatial lifecycle contract

## Purpose

This contract admits direct persistence profiling, unconditional bootstrap/refit,
and known-series future-observation forecasting for replicated Gaussian AR1
`temporal_dep() + spatial_indep()` with one fixed mesh. The fitted covariance
is additive,

\[
V_{ii'} = 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\Sigma_{T,j_i j_{i'}}
+ 1(j_i=j_{i'})\tau_{j_i}^{-2}[P Q(\kappa)^{-1}P^\top]_{ii'}
+ 1(i=i')\sigma_\epsilon^2.
\]

It is not a time-evolving spatial field or a separable space--time product.
The profile holds only the temporal time coordinate fixed while re-optimizing
the full temporal covariance, spatial scales/range, measurement variance, and
fixed effects. The bootstrap redraws both fields with `condition_on_RE =
FALSE` and refits the saved call. The forecast rebuilds future mesh projections
and uses the fixed-parameter Gaussian conditional mean/variance; `se.fit` is
not an interval.

## Admission and refusals

Require exactly one replicated Gaussian AR1 `temporal_dep()` intercept block
and one fixed-mesh intercept-only `spatial_indep()` block at `rho = 1`, with no
ordinary covariance, another source, attenuation, slopes, temporal Psi, or a
second temporal block. Future rows must use fitted series, strictly future
integer occasions, complete measurement-by-trait panels, finite fitted
coordinate columns, and coordinates with nonzero projection on the fitted
mesh.

Refuse OU, temporal-independent or rank-one spatial pairs, new series,
interpolation, missing/duplicate/incomplete panels, out-of-mesh coordinates,
generic new-data prediction, selection, generic intervals, and all other
source pairs. These helpers do not amend the retained failed spatial recovery
gate.

## Required evidence and boundary

The independent forecast oracle must rebuild `fm_basis()` and the finite-element
precision from the stored mesh and public coordinate names, match conditional
means and standard deviations at positive and negative persistence, distinguish
the additive model from a time-by-space product, preserve row order, and refuse
missing or out-of-domain coordinates. Lifecycle tests must close the profile at
the direct TMB trace, retain deterministic bootstrap refit attempts, and reject
OU. Existing spatial tests supply the separate dense likelihood/gradient,
simulation, and long/wide/update evidence.

This is local fixed-parameter and lifecycle evidence. It is not recovery,
forecast calibration, interval coverage, cross-platform verification, merge,
or release evidence.
