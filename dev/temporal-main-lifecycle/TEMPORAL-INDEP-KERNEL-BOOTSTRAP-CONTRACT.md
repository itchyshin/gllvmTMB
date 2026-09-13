# Replicated temporal-independent kernel bootstrap contract

## Admitted route

`bootstrap_temporal()` admits exactly the replicated Gaussian identity-link
AR1 cell

```r
temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
  kernel_indep(series, K = K, name = "fixed_kernel")
```

with one fixed labelled kernel. Each attempt redraws the exact unconditional
additive temporal-plus-kernel response and refits the saved public call. The
result keeps every draw seed, objective, convergence code, and error; failed
or non-converged refits are evidence, not discarded trials.

The existing additive simulation-moment test is the independent generative
evidence. The bootstrap test checks replay, deterministic seeds, and retained
refit rows. It does **not** establish bootstrap interval calibration or
coverage.

## Refusals

The route refuses OU, `temporal_dep()`, `temporal_latent()`, non-Gaussian
families, unqualified replicated panels, `kernel_dep()`, estimated kernel
strength, ordinary unit tiers, and every temporal combination with spatial,
phylogenetic, animal, or additional kernel sources.
