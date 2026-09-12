# Replicated temporal-dependent phylogenetic future-observation forecast contract

## Purpose

This contract admits one additional composed forecast route: replicated
Gaussian identity-link AR1 `temporal_dep() + phylo_indep()` with one fixed
intercept-only phylogenetic source at `rho = 1`. It forecasts future
**observations** of existing series, including their independent measurement
noise. It does not forecast a latent temporal state, an unobserved species, or
a phylogenetically evolving temporal field.

## Conditional covariance

For rows `i` and `i'`, series/tips `g,g'`, occasions `t,t'`, and traits
`j,j'`, the fitted covariance is

\[
V_{ii'} = 1(g=g')\phi^{|t-t'|}[L_TL_T^\top]_{jj'}
+ C_{gg'}1(j=j')q_j^2 + 1(i=i')\sigma_\epsilon^2,
\]

where `phi = (1 - 1e-6) tanh(theta_temporal_time)`. `C` is obtained by
inverting the full retained `Ainv_phy_rr` precision and then selecting the
observed tip indices. This preserves marginalization over tree internal nodes;
inverting a tip-only precision submatrix would instead condition on those
nodes. The dense-VCV engine's retained `1e-8` diagonal jitter is therefore
also preserved.

For observed and future blocks, the helper returns

\[
E(y_n\mid y_o,\widehat\theta)=m_n+V_{no}V_{oo}^{-1}(y_o-m_o),
\qquad
\operatorname{Var}(y_n\mid y_o,\widehat\theta)=
V_{nn}-V_{no}V_{oo}^{-1}V_{on}.
\]

`se.fit` is the square root of the latter diagonal at fitted parameter values.
It excludes parameter uncertainty and is not an interval or coverage claim.

## Admission and refusals

Require exactly one replicated AR1 `temporal_dep()` intercept term and one
fixed intercept-only `phylo_indep()` term, with no ordinary, animal, spatial,
kernel, attenuation, slope, or additional source tier. Future rows must retain
the fitted series/tip labels, use integer occasions strictly after each
series' fitted maximum, and provide a complete trait panel for each future
measurement. Reused measurement labels still denote distinct observation
errors at distinct rows.

Refuse OU, temporal `indep`/`latent` phylogenetic combinations, new series,
interpolation, missing or duplicate future rows, incomplete panels, generic
new-data prediction, intervals, profile, bootstrap, selection, and every
other source-pair forecast.

## Required evidence

The independent test oracle constructs all dense covariance blocks directly
from the fitted packed temporal loading vector and full phylogenetic precision.
It matches conditional means and variances at positive and negative AR1
persistence, checks the dense-input jitter, and distinguishes the additive
covariance from a phylogeny-by-time product. It also checks shuffled future-row
identity and panel, new-series, and OU refusals. This is a local
fixed-parameter conditioning check only; it does not establish forecast
calibration, general source-pair recovery, or coverage.
