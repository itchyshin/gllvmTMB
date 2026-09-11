# Rank-one temporal latent covariance with a fixed animal relationship: contract

## Purpose

This candidate adds one replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE)` intercept term to exactly one
fixed `animal_indep()` intercept term supplied as a labelled relationship
matrix, pedigree, or sparse precision. It is an additive model with
independent temporal and animal fields before conditioning, not a
time-correlated animal process.

## Model and admission

For series `g`, integer occasion `t`, animal `h`, and trait `j`,

\[
 V_{ii'}=1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}
 +A_{h_i h_{i'}}1(j_i=j_{i'})v_{A,j_i}
 +1(i=i')\sigma_\epsilon^2.
\]

`phi = (1-10^{-6}) tanh(theta_temporal_time)`, the temporal loading is signed
and rank one, and `A` is a fixed, labelled animal covariance. The
temporal diagonal Psi is mapped off. Compare `lambda lambda'` rather than raw
loading signs.

The initial cell requires Gaussian identity-link ML/Laplace, three traits,
three integer occasions, two complete measurements per state, an odd observed
time lag in every series, one rank-one temporal term with `unique = FALSE`,
and one fixed `animal_indep(0 + trait | series, A = A)`, `pedigree =`, or
`Ainv =` term at `rho = 1`. It rejects OU, temporal Psi, ordinary covariance terms,
additional static sources, estimated attenuation, source-by-time products,
forecasting and generic inferential routes.

## Required evidence

Before admission, an independent dense Gaussian oracle must test normalized
NLL and every active derivative at negative, zero and positive persistence;
diagonal-time and product-covariance controls must differ; dense-A, pedigree,
sparse-Ainv, and label permutations must agree; long/wide syntax, score labels, unconditional
simulation and `update()` must work. A direct fixed-seed DGP must retain all
attempts and predeclare its threshold decision before the campaign. This cell
does not inherit recovery, forecast, interval, profile, bootstrap, selection,
calibration or coverage evidence from `temporal_indep() + animal_indep()`.
