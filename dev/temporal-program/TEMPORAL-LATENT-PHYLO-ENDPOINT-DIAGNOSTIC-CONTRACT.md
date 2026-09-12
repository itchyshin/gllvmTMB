# Temporal-latent phylogenetic endpoint diagnostic

## Purpose

This diagnostic examines the retained `phi = .6`, seed `2609243` endpoint of
the failed fixed-seed `temporal_latent(..., d = 1, unique = FALSE) +
phylo_indep()` recovery fixture.  Its purpose is to distinguish an objective
or derivative mismatch from a near-zero phylogenetic variance boundary.  It
does not rerun, replace, or revise the recovery campaign.

## Frozen inputs and boundaries

The data generator, seed, tree construction, fitted formula, two BFGS passes,
optimizer controls, and recovery thresholds are exactly those in
`run-latent-phylo-recovery.R`.  The existing CSV receipts and the failed
`phi = .6` recovery decision remain authoritative.  This diagnostic does not
add a recovery pass, change an initialization, replace a seed, relax a
threshold, or admit forecast, interval, profile, bootstrap, or selection
routes.

## Required checks

At the retained endpoint, a fresh `TMB::MakeADFun()` object must reproduce the
stored native objective and outer gradient.  An independently calculated dense
Gaussian likelihood must agree with the native objective and central numerical
gradients at the fitted endpoint and at declared one-sided perturbations of
the second phylogenetic loading.  Results must retain the Hessian error text,
if any, rather than reduce it to a status label.

The diagnostic may report that a loading-scale gradient is small at zero.  It
must not infer that the corresponding variance-scale derivative is zero,
because `v = a^2` is singular at `a = 0`.  A boundary observation is not
evidence of recovery, general identifiability, calibrated inference, or model
admission.
