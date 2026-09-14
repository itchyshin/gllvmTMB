# Rank-one temporal latent covariance with a fixed kernel: contract

## Purpose

This candidate adds one replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE)` intercept term to exactly one
fixed, labelled `kernel_indep()` intercept term.  It is the rank-one temporal
restriction of the temporal-dependence model.  It is an additive model and
does not turn the fixed kernel into a time-evolving field.

## Model

For stacked observations `i` and `i'`, series `g`, integer occasion `t`,
kernel level `h`, and trait `j`, the covariance is

\[
 V_{ii'} =
 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}
 + K_S(h_i,h_{i'})1(j_i=j_{i'})v_{S,j_i}
 + 1(i=i')\sigma_\epsilon^2.
\]

Here `phi = (1 - 1e-6) * tanh(theta_temporal_time)`, `lambda` is the
existing signed rank-one temporal loading vector, `v_S` is the existing
kernel trait-diagonal variance, and `sigma_epsilon^2` is the replicated
measurement variance.  The temporal diagonal Psi and its random block are
mapped off.  Loading/score sign reversal is observationally equivalent, so
validation compares `lambda lambda'`, not raw loading signs.

The excluded product covariance is

\[
 K_S(h_i,h_{i'})\phi^{|t_i-t_{i'}|}\Sigma_{ST};
\]

it is a source-by-time interaction and needs a separate state, simulation,
prediction and recovery contract.

## Narrow admission

Admit Gaussian identity-link ML/Laplace only; one temporal intercept block;
`d = 1`, `unique = FALSE`; one labelled, fixed `kernel_indep()` term with
`rho = 1`; at least three traits, three integer occasions in each series,
and two complete measurement panels per series--occasion.  Require an odd
observed time lag, no ordinary `unit`/`unit_obs` covariance term, and
nonproportional observed temporal and kernel covariance bases.

Refuse temporal `unique = TRUE`, temporal `dep`, OU, another static source,
estimated source attenuation, outcome-trained kernels, temporal slopes,
future forecasts, intervals, profiles, bootstrap, selection and every
source-by-time interaction.  Each needs its own evidence.

## Required evidence before admission

1. A direct dense Gaussian NLL and central derivative oracle must exercise
   every active fixed-effect, persistence, loading, kernel-variance and
   residual parameter, at negative, zero and positive persistence.
2. A diagonal temporal covariance and a product-kernel covariance must both
   disagree with the native rank-one additive covariance.
3. Long/wide conversion, row and kernel-label permutations, temporal score
   labels, unconditional simulation and `update()`/refit must preserve the
   public temporal and kernel identities.
4. A direct, fixed-seed DGP must retain all fits, objectives, optimizer
   status, gradients, Hessian diagnostics and threshold verdicts.  It must
   not call production simulation.  A measured pre-run and separate compute
   authorization are required before a campaign projected above 30 minutes.

No result from this candidate supports source-pair forecasting, calibration,
coverage, broad recovery, temporal `unique = TRUE`, or a phylogenetic,
animal or spatial latent pair.

## Frozen recovery fixture

The direct generator in `run-latent-kernel-recovery.R` uses 80 series, 16
integer occasions, two measurements and three traits.  The fixed labelled
kernel is the same nonproportional coordinate kernel used by the dependent
kernel fixture.  The true fixed effects are `(.2, -.3, .1)`, the rank-one
temporal loading is `(.55, .40, -.35)`, the static kernel standard deviations
are `(.35, .28, .40)`, and the measurement standard deviation is `.30`.
The retained plan is persistence `(-.4, 0, .6)` with seeds
`2609231:2609233`.

Every fit must have a finite objective, convergence zero, an accepted second
optimizer pass and outer gradient at most `1e-3`.  Within each persistence
stratum, all three retained fits must pass; mean and median absolute
persistence errors must be at most `.15` and `.20`; median relative Frobenius
error for `lambda lambda'` must be at most `.30`; median relative error for
each kernel variance must be at most `.35`; and mean absolute fixed-effect
error must be at most `.25`.  These are fixed engineering smoke criteria for
this named DGP, not general recovery or coverage evidence.

## Current-source replay

The original frozen runner and its nine retained rows were introduced on
2026-09-11. Historical output is retained under the `20260911` names. The
same independently authored DGP and threshold calculation write the
current-source replay to `latent-kernel-recovery-current-20260914*.csv`, so a
later qualification cannot overwrite historical evidence.

At source commit `5ff59b746`, a one-cell smoke completed in 12.41 seconds.
The subsequent nine-cell replay retained all terminal successes and all three
frozen strata passed. Its scientific fit fields reproduce the historical
receipt; only elapsed-time fields differ. Hessian diagnostics are retained as
`error` for all nine fits and are not an acceptance criterion in this frozen
fixture. The replay remains fixture-specific evidence and supports no general
recovery, coverage, forecast, profile, bootstrap, selection, or release
claim.
