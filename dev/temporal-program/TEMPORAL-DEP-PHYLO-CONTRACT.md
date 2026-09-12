# Temporal dependent covariance with a fixed phylogeny: contract

## Purpose

This candidate adds exactly one replicated Gaussian AR1 `temporal_dep()`
intercept term to one fixed `phylo_indep()` intercept term supplied as a
labelled dense VCV matrix or a tree. It is an additive temporal-plus-lineage
model, not a phylogenetically correlated time process.

## Model

For observations `i` and `i'`, series `g`, occasion `t`, phylogenetic tip `h`,
and trait `j`, the covariance is

\[
V_{ii'} = 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}[L_TL_T^\top]_{j_i j_{i'}}
 + C_{h_i h_{i'}}1(j_i=j_{i'})v_{P,j_i}
 + 1(i=i')\sigma_\epsilon^2,
\]

where `phi = (1 - 1e-6) * tanh(theta_temporal_time)`. `L_T` is the signed,
packed lower-triangular temporal loading matrix in `theta_temporal_rr`; its
covariance, rather than unaligned loading signs, is the estimand. Fixed
phylogenetic variances are the squares of the existing source loading
parameters. The temporal diagonal Psi and iid temporal state effects are mapped
off.

The excluded interaction is

\[
C_{h_i h_{i'}}\phi^{|t_i-t_{i'}|}\Sigma_{TP,j_i j_{i'}}.
\]

It defines an evolving phylogenetic field and needs its own state, simulation,
prediction, and recovery contract.

## Narrow admission

Gaussian identity-link ML/Laplace; three or more traits; three or more integer
occasions per series; complete panels with at least two measurements per state;
an odd lag in every series; one temporal intercept; and exactly one
intercept-only `phylo_indep(0 + trait | series, vcv = C)` or tree equivalent at
`rho = 1`. Series labels map directly to labelled phylogenetic tips and remain
separate from the private temporal state index.

Refuse OU, temporal latent/Psi alternatives, ordinary `unit` or `unit_obs`
terms, phylogenetic slopes, duplicate sources, estimated attenuation,
incomplete panels, source-by-time interactions, intervals, profiles,
bootstrap, selection, and generic inference routes. The separately bounded
future-observation forecast route is defined in
`TEMPORAL-DEP-PHYLO-FORECAST-CONTRACT.md`; all other forecast routes remain
refused.

## Required evidence

An independent dense Gaussian oracle must check the normalized NLL and **every
free outer derivative** at persistence `-.4`, `0`, and `.6`, with nonzero
temporal off-diagonal covariance. It must distinguish diagonal and rank-one
temporal substitutes, plus the genuine cross-series phylogeny-by-time product
without a series mask. Tree/VCV and tip-label permutations, long/wide common
parameter likelihoods, score labels, unconditional and conditional simulation,
training predictions, and `update()`/refit must preserve identity.

A direct DGP may not call package simulation. It must redraw stationary
multivariate AR1 states, independent trait-specific phylogenetic fields, and
measurement noise; retain every fixed seed; record finite objective, two-pass
optimizer history, gradient, Hessian diagnostic or explicit absence, and frozen
threshold decisions. A passing named fixture is only local engineering evidence,
not a recovery, coverage, forecast, or interval claim.
