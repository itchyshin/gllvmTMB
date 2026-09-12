# Rank-one temporal-spatial future-observation forecast contract

## Purpose

This contract admits replicated Gaussian identity-link AR1
`temporal_latent(..., d = 1, unique = FALSE) + spatial_indep()` with one fixed
mesh. It forecasts future observations of fitted series at supplied future
coordinates that project onto that mesh. It does not forecast a temporal SPDE
field or change the mesh.

## Conditional covariance

For response rows `i,i'`, series `g,g'`, occasions `t,t'`, traits `j,j'`,
and coordinate projections `P_i,P_{i'}`, the response covariance is

\[
V_{ii'}=1(g=g')\phi^{|t-t'|}\lambda_j\lambda_{j'}+
[P_iQ(\kappa)^{-1}P_{i'}^\top]1(j=j')\tau_j^{-2}+
1(i=i')\sigma_\epsilon^2,
\]

where \(\phi=(1-10^{-6})\tanh(\theta_{temporal})\) and
\(Q(\kappa)=\kappa^4M_0+2\kappa^2M_1+M_2\). The helper rebuilds each
projection with `fmesher::fm_basis()` from the fitted mesh and supplied
coordinate columns, then applies ordinary Gaussian block conditioning. The
temporal AR1 and static spatial field are added. Their product is explicitly
wrong.

`se.fit` is the fitted-parameter conditional response standard deviation. It
does not include parameter uncertainty and is not an interval or coverage
claim.

## Admission and refusals

Require exactly the qualified replicated rank-one AR1 temporal-spatial cell:
one intercept-only `temporal_latent(unique = FALSE, d = 1)` term and one
fixed-mesh intercept-only `spatial_indep()` term at `rho = 1`, with no
ordinary, phylogenetic, animal, kernel, attenuation, slope, or additional
source tier. Future rows must retain fitted series labels, have integer
occasions strictly later than each series' fitted maximum, complete
measurement-by-trait panels, both original mesh coordinate columns, and
finite projections inside the fitted mesh domain.

Refuse OU, temporal Psi, rank above one, new series, interpolation, missing
or duplicate rows, incomplete panels, coordinates outside the fitted mesh,
generic new-data prediction, intervals, selection, and every other
source-pair forecast. The separately qualified profile and bootstrap routes
have their own contracts; this forecast contract does not extend them.

## Required evidence

An independently authored oracle rebuilds `fm_basis()` projections and the
finite-element precision from retained TMB data, constructs complete dense
additive covariance blocks, and matches conditional means and standard
deviations at positive and negative AR1 persistence. It rejects an invalid
time-by-space product, checks shuffled row identity, and checks missing
coordinate refusal. This is local fixed-parameter conditioning evidence only:
it does not establish spatial forecast calibration, general recovery, or
coverage.
