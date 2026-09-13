# Replicated temporal-independent kernel selection contract

## Admitted route

`compare_temporal()` admits named temporal-only candidates and the qualified
replicated Gaussian identity-link AR1 cell

```r
temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
  kernel_indep(series, K = K, name = "fixed_kernel")
```

with one fixed labelled kernel. Candidates must retain exactly the same stacked
observed response vector and ordering. The returned table is only the stored
ML log likelihood, parameter count, AIC, and optimizer convergence code. It
does not attach a likelihood-ratio test, choose a latent rank, or establish
predictive performance.

## Refusals

The route refuses OU, `temporal_dep()`, `temporal_latent()`, non-Gaussian
fits, unqualified replicated panels, `kernel_dep()`, estimated kernel strength,
ordinary unit tiers, and every temporal combination with spatial,
phylogenetic, animal, or additional kernel sources.

## Verification

The independent test fits two eligible fixed-kernel candidates on the same
panel and verifies every reported log likelihood, parameter count, AIC, row
label, and convergence value against the corresponding fitted object. Existing
selection tests retain the temporal-only contract.
