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

`temporal_dep()` is a full trait-covariance model, not a low-rank ordination.
Its labelled covariance factor and public series--occasion index are returned
by `extract_temporal()`; `getLV()` remains the score interface for the
`temporal_latent()` cell.

The initial cell is Gaussian identity-link ML/Laplace, replicated AR1, at
least three traits and occasions, complete panels with two measurements per
state, an odd observed lag per series, one temporal intercept and exactly one
intercept-only `animal_indep(0 + trait | animal, A = A)`, `pedigree =`, or
`Ainv =` source at `rho = 1`. It refuses OU, temporal Psi/latent variants,
ordinary covariance, slopes, additional sources, source-by-time products, generic
intervals, selection, and all other source-pair routes. The direct forecast and
profile/bootstrap lifecycle routes have separate contracts.

## Evidence required before an advertised claim

A separately authored dense oracle must verify normalized NLL and every active
outer derivative at negative, zero, and positive persistence; reject diagonal
and rank-one temporal substitutes and the animal-by-time product; and cover
dense A, pedigree, Ainv, labels, long/wide, update/refit, fitted labels,
conditional/unconditional simulation, and the separately contracted lifecycle
routes. A direct retained DGP and frozen
thresholds are required for recovery evidence. None transfers from a phylogeny
or rank-one-animal fixture.

## Admission probe

The initial negative result was a probe error, not an engine limitation. In an
isolated worktree on 2026-09-11, admitting this exact cell produced a diagonal
`Lambda_phy` through the existing R-level packed-loading map. An independently
assembled additive dense Gaussian likelihood differed from native TMB by
`2.93e-8`; the largest central-difference discrepancy across all outer
coordinates was `6.56e-8`. The implementation therefore reuses the established
diagonal animal map and adds no C++ covariance block.

This probe establishes only the fixed-point likelihood route. The committed
acceptance test must still cover all requested persistence values, relationship
representations, lifecycle operations, redraw simulation, refusal boundaries,
and a separately retained recovery fixture before any wider claim is made.
