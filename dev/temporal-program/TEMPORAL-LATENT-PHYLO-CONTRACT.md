# Rank-one temporal latent covariance with a fixed phylogeny: contract

## Purpose

This candidate adds one replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE)` intercept term to exactly one
fixed `phylo_indep()` intercept term supplied as a labelled `vcv` matrix or a
tree. It is an additive model with independent temporal and phylogenetic
fields before conditioning, not a phylogenetically correlated time process.

## Model and admission

For series `g`, integer occasion `t`, phylogenetic tip `h`, and trait `j`,

\[
 V_{ii'}=1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}
 +C_{h_i h_{i'}}1(j_i=j_{i'})v_{P,j_i}
 +1(i=i')\sigma_\epsilon^2.
\]

`phi = (1-10^{-6}) tanh(theta_temporal_time)`, the temporal loading is signed
and rank one, and `C` is a fixed, labelled phylogenetic covariance. The
temporal diagonal Psi is mapped off. Compare `lambda lambda'` rather than raw
loading signs.

The initial cell requires Gaussian identity-link ML/Laplace, three traits,
three integer occasions, two complete measurements per state, an odd observed
time lag in every series, one rank-one temporal term with `unique = FALSE`,
and one fixed `phylo_indep(0 + trait | series, vcv = C)` or equivalent tree
term at `rho = 1`. It rejects OU, temporal Psi, ordinary covariance terms,
additional static sources, estimated attenuation, source-by-time products,
forecasting and generic inferential routes.

## Required evidence

Before admission, an independent dense Gaussian oracle must test normalized
NLL and every active derivative at negative, zero and positive persistence;
diagonal-time and product-covariance controls must differ; tree/VCV and label
permutations must agree; long/wide syntax, score labels, unconditional
simulation and `update()` must work. A direct fixed-seed DGP must retain all
attempts and predeclare its threshold decision before the campaign. This cell
does not inherit recovery, forecast, interval, profile, bootstrap, selection,
calibration or coverage evidence from `temporal_indep() + phylo_indep()`.
