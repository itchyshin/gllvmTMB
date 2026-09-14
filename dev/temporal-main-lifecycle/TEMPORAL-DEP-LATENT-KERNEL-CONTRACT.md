# Dependent and rank-one temporal latent covariance with a fixed kernel: contract

## Purpose

This candidate adds two replicated Gaussian AR1 intercept terms to exactly one
fixed, labelled `kernel_indep()` intercept term:

```r
temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
  kernel_indep(series, K = K)

temporal_latent(0 + trait | series, time = occasion,
                replicate = measurement, d = 1, unique = FALSE) +
  kernel_indep(series, K = K)
```

The rank-one cell is the restricted form of the dependent cell. Both are
additive models: neither turns the fixed kernel into a time-evolving field.

## Model

For stacked observations `i` and `i'`, series `g`, integer occasion `t`,
kernel level `h`, and trait `j`, the covariance is

\[
 V_{ii'} =
 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}
 + K_S(h_i,h_{i'})1(j_i=j_{i'})v_{S,j_i}
 + 1(i=i')\sigma_\epsilon^2.
\]

Here `phi = (1 - 1e-6) * tanh(theta_temporal_time)`, `v_S` is the existing
kernel trait-diagonal variance, and `sigma_epsilon^2` is the replicated
measurement variance. For `temporal_dep()`, replace
`lambda_j lambda_j'` with the unrestricted positive-semidefinite temporal
trait covariance `Sigma_T`. For the rank-one latent cell, `lambda` is the
existing signed loading vector; its temporal diagonal Psi and random block
are mapped off. Loading/score sign reversal is observationally equivalent, so
latent validation compares `lambda lambda'`, not raw loading signs.

The excluded product covariance is

\[
 K_S(h_i,h_{i'})\phi^{|t_i-t_{i'}|}\Sigma_{ST};
\]

it is a source-by-time interaction and needs a separate state, simulation,
prediction and recovery contract.

## Narrow admission

Admit Gaussian identity-link ML/Laplace only; one temporal intercept block;
one labelled, fixed `kernel_indep()` term with `rho = 1`; at least three
traits, three integer occasions in each series, and two complete measurement
panels per series--occasion. Both cells require an odd observed time lag in
every series, no ordinary `unit`/`unit_obs` covariance term, and
nonproportional observed temporal and kernel covariance bases. The rank-one
cell additionally requires `d = 1` and `unique = FALSE`.

Refuse latent `unique = TRUE`, OU, another static source, estimated source
attenuation, outcome-trained kernels, temporal slopes, future forecasts,
intervals, profiles, bootstrap, selection and every source-by-time
interaction. Each needs its own evidence.

## Required evidence before admission

1. A direct dense Gaussian NLL and central derivative oracle must exercise
   every active fixed-effect, persistence, loading, kernel-variance and
   residual parameter, at negative, zero and positive persistence.
2. A diagonal temporal covariance and a product-kernel covariance must both
   disagree with the native rank-one additive covariance.
3. Long/wide conversion, row and kernel-label permutations, unconditional
   simulation and `update()`/refit must preserve the public temporal and
   kernel identities. Temporal score labels are required only for the
   rank-one latent cell; the dependent cell has no latent-score extractor.
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

## Recovery provenance and replay

The original frozen runner and its nine retained rows were introduced in
commit `0a81c0675`; this lifecycle ledger keeps byte-for-byte copies of that
runner's 2026-09-11 result and summary under `results/`.  Those rows document
the historical source state only.  They do not prove recovery for this branch.

`run-latent-kernel-recovery.R` is the same independently authored DGP and
threshold calculation, but writes a later replay to files named
`latent-kernel-recovery-current-20260914*.csv`.  This separation prevents a
later current-source qualification from replacing historical evidence.  A
current-source smoke run must precede the nine-cell replay; the latter remains
fixture-specific evidence and cannot support a general recovery, interval,
coverage, forecast, profile, bootstrap, selection, or release claim.

At commit `5ff59b746`, the current-source smoke completed in 12.41 seconds.
The subsequent nine-cell replay retained all nine terminal successes and all
three frozen strata passed.  Its scientific fit fields reproduce the historical
receipt; only elapsed-time fields differ.  The replay retains the reported
Hessian diagnostics (`error` for all nine fits), which are not an acceptance
criterion in this frozen fixture.  This closes the named local rank-one
fixed-kernel recovery fixture only; TEMP-06-07 remains `partial`.
