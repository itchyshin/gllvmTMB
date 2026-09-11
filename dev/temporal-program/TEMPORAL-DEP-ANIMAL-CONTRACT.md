# Temporal dependent covariance with a fixed animal relationship: contract

## Purpose

This candidate admits exactly one replicated Gaussian AR1 `temporal_dep()`
intercept term and one fixed intercept-only `animal_indep()` term. It is an
additive temporal-plus-animal model, never a time-correlated animal field.

## Model and admission

For observations in series `g`, occasion `t`, related animal `h`, and trait
`j`, the covariance is

\[
 1(g=g')\phi^{|t-t'|}[L_TL_T^\top]_{jj'}+
 A_{hh'}1(j=j')v_{A,j}+1(i=i')\sigma_\epsilon^2,
\]

where `phi = (1 - 1e-6) tanh(theta_temporal_time)`. `L_T` is the signed packed
lower-triangular full temporal trait loading matrix; inference targets its
covariance. The animal term is an independent trait-diagonal static field.

The initial cell is Gaussian identity-link ML/Laplace, replicated AR1, at
least three traits and occasions, complete panels with two measurements per
state, an odd observed lag per series, one temporal intercept and exactly one
intercept-only `animal_indep(0 + trait | series, A = A)`, `pedigree =`, or
`Ainv =` source at `rho = 1`. It refuses OU, temporal Psi/latent variants,
ordinary covariance, slopes, additional sources, source-by-time products, and
forecast/interval/profile/bootstrap/selection routes.

## Evidence required before an advertised claim

A separately authored dense oracle must verify normalized NLL and every active
outer derivative at negative, zero, and positive persistence; reject diagonal
and rank-one temporal substitutes and the animal-by-time product; and cover
dense A, pedigree, Ainv, labels, long/wide, update/refit, fitted labels and
conditional/unconditional simulation. A direct retained DGP and frozen
thresholds are required for recovery evidence. None transfers from a phylogeny
or rank-one-animal fixture.

## Probe result

On 2026-09-11 a temporary parser admission was tested against an independently assembled dense additive likelihood and every outer central derivative. It failed at the first fixed parameter point, so the parser remains closed. The animal representation must be traced through its engine parameter map before this contract can proceed; it cannot inherit the phylogenetic implementation merely because both calls are labelled relationship matrices.
