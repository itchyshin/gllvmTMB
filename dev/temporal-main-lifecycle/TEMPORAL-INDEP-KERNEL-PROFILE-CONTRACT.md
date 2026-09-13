# Replicated temporal-independent kernel profile contract

## Admitted route

This bounded route admits `profile_temporal()` for exactly the Gaussian,
identity-link, replicated AR1 cell:

```r
temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
  kernel_indep(series, K = K, name = "fixed_kernel")
```

The existing unreplicated, temporal-only `temporal_indep()` route remains
admitted.  The profile targets the transformed temporal AR1 persistence,
`(1 - 1e-6) * tanh(theta_temporal_time)`, while TMB re-optimizes every other
unmapped parameter, including the fixed-kernel variance parameters.

This is a finite likelihood-profile computation.  It is not a calibrated
confidence interval, a profile of latent states, a coverage claim, or evidence
for other source combinations.

## Refusals

The route refuses OU, `temporal_dep()`, `temporal_latent()`, non-Gaussian
families, unqualified replicated panels, `kernel_dep()`, estimated kernel
strength, ordinary unit tiers, and every temporal combination with spatial,
phylogenetic, animal, or additional kernel sources.

## Verification

The independent test builds a replicated fixed-kernel fit, compares the
reported estimate and the direct `TMB::tmbprofile()` trace at its MLE, checks
that the trace rises above the MLE objective, and exercises the early refusal
for a non-qualified kernel mode.  The existing kernel likelihood test remains
the covariance and parameterization evidence.
