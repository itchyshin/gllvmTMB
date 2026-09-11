# Temporal dependent covariance with a fixed SPDE field: contract

## Purpose

This candidate admits exactly one replicated Gaussian AR1 `temporal_dep()`
intercept term and one fixed-mesh intercept-only `spatial_indep()` term. It is
an additive temporal-plus-spatial model; it is not a separable or evolving
space--time process.

## Model and admission

For observation rows `i` and `i'`, with series `g`, integer occasion `t`,
trait `j`, and mesh projection row `P_i`, the covariance is

\[
 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}[L_TL_T^\top]_{j_i j_{i'}}+
 1(j_i=j_{i'})\tau_{j_i}^{-2}[P Q(\kappa)^{-1}P^\top]_{ii'}+
 1(i=i')\sigma_\epsilon^2,
\]

where `phi = (1 - 1e-6) tanh(theta_temporal_time)` and
`Q(kappa) = kappa^4 M0 + 2 kappa^2 M1 + M2`. `L_T` is the signed packed
lower-triangular full temporal trait loading matrix; the spatial field stays
trait-diagonal. The mesh is fixed while `kappa` and each spatial scale are
estimated.

The initial cell is Gaussian identity-link ML/Laplace, replicated AR1, at
least three traits and occasions, complete panels with two measurements per
state, and one temporal plus one intercept-only spatial term at `rho = 1`.
Each `(series, time)` state must have one coordinate pair across traits and
measurements; every series must contain an odd integer time lag. It refuses
OU, temporal Psi/latent variants, ordinary covariance, slopes, extra sources,
estimated attenuation, source-by-time products, forecasts, intervals,
profiles, bootstrap, and selection.

`temporal_dep()` reports a labelled temporal covariance factor and public
series--occasion index through `extract_temporal()`; it does not turn the
full-rank factorization into a low-rank `getLV()` ordination.

## Required evidence

The independent dense oracle reconstructs `P` from public mesh coordinates
and checks normalized NLL plus every outer central derivative at negative,
zero, and positive persistence. It must reject diagonal and rank-one temporal
substitutes and an unmasked time-by-space product. Long/wide and row-permuted
fits must agree at common parameters, retain labels, and replay through
`update()`.

Unconditional simulation must redraw the full temporal state and each
trait-diagonal SPDE field. It checks same-state and lagged cross-trait
covariances, plus cross-series spatial covariance, against analytic Gaussian
Monte Carlo standard errors; conditional draws must center on the retained
linear predictor.

A direct DGP must separately simulate a stationary non-diagonal multivariate
AR1 state, independent SPDE fields, and measurement noise without calling
production temporal simulation. Freeze mesh, seeds, truth, optimiser,
thresholds, and all results before the campaign. Record temporal covariance,
spatial scales, range, persistence, fixed effects, gradients, optimizer state,
and Hessian availability. This cell cannot borrow recovery evidence from the
rank-one or temporal-independent spatial cells.

## Pre-run result

The fixed `phi = .6`, seed `2609331` smoke fit took 11.797 seconds with
optimizer code zero, accepted second pass, and maximum outer gradient
`.00094893`. The first two frozen `phi = -.4` attempts returned in 20.131 and
6.754 seconds. The third attempt (seed `2609333`) consumed a full CPU for 109
seconds without returning, and was terminated under the measured one-fit
budget; its factual receipt is retained. The campaign is paused after four
attempts, so it provides no recovery verdict and no threshold is relaxed.

## Timing diagnostic before any continuation

The retained termination does not identify whether the optimizer or the
optional post-fit Hessian call consumed the extra time. A later diagnostic must
not overwrite a frozen attempt receipt or change its fixture, seed, optimizer,
or thresholds. It uses exactly one existing planned cell and writes a separate
receipt. First run the fit-only diagnostic with
`DEP_SPATIAL_DIAGNOSTIC=1`, `DEP_SPATIAL_SKIP_HESSIAN=1`,
`DEP_SPATIAL_ONE=<planned index>`, and a new
`DEP_SPATIAL_DIAGNOSTIC_OUTPUT=<path>` under `results/diagnostics/`. Only if that retained probe reaches a
successful endpoint can a separately authorized Hessian-inclusive diagnostic
be considered. Diagnostic output records `fit_elapsed_seconds`,
`hessian_elapsed_seconds`, `gradient_elapsed_seconds`, and whether the Hessian
was requested. A phase receipt is written before each expensive stage, so an
interruption records the last reached stage. It is timing evidence only: it
neither repairs the frozen campaign nor supplies recovery evidence.

### Retained fit-only diagnostic (2026-09-11)

The authorized fit-only replay selected the existing third planned cell
(`phi = -.4`, `seed = 2609333`) and wrote separate receipts at
`results/diagnostics/dep-spatial-attempt-03-fit-only-20260911.csv` and
`results/diagnostics/dep-spatial-attempt-03-fit-only-20260911-phase.csv`.
It consumed 215.571 seconds in fitting and returned `All 1 restarts failed.`
before the Hessian or gradient stages. It confirms that this repeat's delay was
inside the optimizer path, rather than in the optional Hessian calculation. It
does not change the paused campaign, its frozen rows, its criteria, or the
absence of a recovery verdict. The condition for considering a Hessian-inclusive
diagnostic was not met.

## Spatial-scale correction

The DGP divides each SPDE draw by its precision `tau`, and the TMB parameter is
`tau = exp(log_tau_spde)`. The four retained attempted rows instead recorded
`exp(-log_tau_spde)` while comparing it to precision-scale truth. They remain
immutable timing and optimizer receipts, but cannot support any spatial-scale
recovery verdict. A future recovery contract must use the precision scale in
both the DGP and estimator extraction, freeze a new output location and all
criteria before execution, and retain every attempt. No threshold is relaxed
and no prior result is reclassified as recovery evidence.
