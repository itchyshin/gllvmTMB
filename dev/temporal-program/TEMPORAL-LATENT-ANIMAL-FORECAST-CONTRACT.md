# Rank-one temporal-animal future-observation forecast contract

## Purpose

This contract admits one composed forecast route: replicated Gaussian
identity-link AR1 `temporal_latent(..., d = 1, unique = FALSE) +
animal_indep()` with one fixed labelled animal relationship. It forecasts
future observations for animals already present in the fitted panel. It does
not forecast a latent score, a new animal, or an animal-by-time process.

## Conditional covariance

For rows `i,i'`, series/animal labels `g,g'`, occasions `t,t'`, and traits
`j,j'`, the fitted response covariance is

\[
V_{ii'} = 1(g=g')\phi^{|t-t'|}\lambda_j\lambda_{j'}
+ A_{gg'}1(j=j')v_{A,j} + 1(i=i')\sigma_\epsilon^2,
\]

where \(\phi=(1-10^{-6})\tanh(\theta_{temporal})\). The helper obtains
`A` by inverting the complete retained `Ainv_phy_rr` and selecting its stored
animal indices. This is required for equivalence across dense relationship,
pedigree, and sparse precision input paths. It is additive; multiplying the
AR1 and animal kernels is deliberately wrong.

For observed and future blocks, the fixed-parameter calculation is

\[
E(y_n\mid y_o,\widehat\theta)=m_n+V_{no}V_{oo}^{-1}(y_o-m_o),
\qquad
\operatorname{Var}(y_n\mid y_o,\widehat\theta)=
V_{nn}-V_{no}V_{oo}^{-1}V_{on}.
\]

`se.fit` is the square root of the latter diagonal. It excludes parameter
uncertainty and is neither an interval nor a calibration claim.

## Admission and refusals

Require exactly the qualified replicated rank-one AR1 temporal-animal cell:
one intercept-only `temporal_latent(unique = FALSE, d = 1)` term and one
fixed intercept-only `animal_indep()` term at `rho = 1`, with no ordinary,
phylogenetic, spatial, kernel, attenuation, slope, or additional source tier.
Future rows must use fitted series/animal labels, integer occasions strictly
after each series' last fitted occasion, and complete trait panels for every
measurement. Reused measurement labels still identify separate future
observation errors.

Refuse OU, temporal Psi, rank above one, new animals or series,
interpolation, missing or duplicate rows, incomplete panels, generic
new-data prediction, intervals, selection, and every other source-pair
forecast. The separately qualified profile and bootstrap routes have their
own contracts; this forecast contract neither widens nor validates them.

## Required evidence

The independent test oracle constructs the complete dense additive covariance
from fitted packed loadings, the retained relationship matrix, animal trait
variances, and residual measurement variance. It checks conditional means and
standard deviations and distinguishes the additive model from an invalid
animal-by-time product. This is a local fixed-parameter conditioning check;
it does not establish forecast calibration, general animal-pair recovery, or
coverage.
