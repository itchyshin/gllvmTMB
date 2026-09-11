# Temporal dependent covariance with a fixed kernel: contract

## Purpose

This is the first non-diagonal temporal source-pair model. It adds exactly one
replicated Gaussian AR1 `temporal_dep()` intercept term to exactly one fixed,
labelled `kernel_indep()` intercept term. It is an additive model. It is not a
source-by-time interaction and it does not promote any existing temporal
source-pair recovery result.

## Model

For stacked observations `i` and `i'`, series `g`, integer occasion `t`,
kernel level `h`, and trait `j`, the fitted covariance is

\[
 V_{ii'} =
 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}
 [L_T L_T^\top]_{j_i j_{i'}} +
 K_S(h_i,h_{i'})1(j_i=j_{i'})v_{S,j_i} +
 1(i=i')\sigma_\epsilon^2.
\]

The two fields are independent before conditioning. The parameterisation is
`phi = (1 - 1e-6) * tanh(theta_temporal_time)`, a packed lower-triangular
`L_T` in `theta_temporal_rr`, kernel diagonal variances `v_S`, and the
replicated measurement variance `sigma_epsilon^2`. Temporal diagonal
parameters and temporal iid state effects are mapped off. The loading packing
uses the existing signed lower-triangular convention, so validation compares
covariances rather than unaligned loading signs.

The intentionally excluded interaction is

\[
 K_S(h_i,h_{i'})\phi^{|t_i-t_{i'}|}\Sigma_{ST},
\]

which represents an evolving kernel field and requires a separate state,
simulation, prediction, and recovery contract.

## Admission

The first cell admits Gaussian identity-link ML/Laplace only, three or more
traits, three or more ordered integer occasions in each series, at least two
complete measurement replicates at every state, one temporal intercept block,
one labelled fixed kernel at `rho = 1`, and no ordinary `unit` or `unit_obs`
components. Each series must contain an odd lag so signed AR1 persistence is
identifiable. The kernel and temporal covariance bases must be nonproportional
over the observed panel.

Refuse OU, temporal latent modes, another static source, estimated source
attenuation, an outcome-trained kernel, temporal slopes, missing or incomplete
panels, new-series forecasting, profiles, bootstrap, intervals, selection,
and source-by-time interactions. Those routes retain their own contracts.

## Required evidence

1. An independently authored dense Gaussian covariance oracle compares
   normalized marginal NLL and central derivatives for every free outer
   parameter at nonzero temporal off-diagonal covariance and `phi` in
   `(-.4, 0, .6)`.
2. Controls prove that a diagonal temporal covariance and a substituted product
   kernel disagree with the native additive `dep` model.
3. Long/wide syntax, row and kernel-label permutations, score/extractor labels,
   simulation moments, and `update()`/refit preserve the public temporal and
   kernel identities.
4. A fixed-seed direct DGP recovery fixture retains every result, optimizer
   status, gradient, Hessian result and threshold decision. Its runtime is
   measured before any campaign exceeding 30 minutes.
5. Existing temporal-only and diagonal kernel-pair tests remain green.

No test of this cell establishes source-pair forecasting, calibration,
coverage, general recovery, or support for phylogenetic, animal, or spatial
`temporal_dep()` pairs.

## Frozen recovery fixture

The direct generator in `run-dep-kernel-recovery.R` never calls package
simulation. It uses 80 series, 16 integer occasions, two measurements, and
three traits. The fixed labelled kernel is a nonproportional unit-diagonal
exponential coordinate kernel. The true fixed effects are `(.2, -.3, .1)`,
the temporal covariance is `L_T L_T^T` for

\[
L_T=\begin{pmatrix}.55&0&0\\ .12&.50&0\\ -.08&.10&.48\end{pmatrix},
\]

the static diagonal kernel standard deviations are `(.35, .28, .40)`, and
the measurement standard deviation is `.30`. It retains every combination of
`phi = (-.4, 0, .6)` and seeds `2609221:2609223`.

Every attempted fit must have finite objective, optimizer convergence zero,
an accepted final second optimizer pass, and maximum outer gradient at most
`1e-3`. Within each persistence value, the three retained attempts must have
mean absolute phi error at most `.15`, median absolute phi error at most
`.20`, median relative Frobenius error for the temporal covariance at most
`.30`, median relative error for every kernel variance at most `.35`, and
mean absolute fixed-effect error at most `.25`. These are a fixed engineering
smoke criterion for this named DGP. Passing it would not establish general
recovery or interval coverage.
