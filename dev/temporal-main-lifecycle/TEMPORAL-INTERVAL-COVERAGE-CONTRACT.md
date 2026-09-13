# Temporal profile-endpoint coverage contract

## Question

The direct helper `profile_temporal()` returns likelihood-profile endpoints for
the AR1 persistence parameter. This contract asks a narrower question than a
generic confidence-interval claim: for the native, unreplicated Gaussian
`temporal_indep()` AR1 model, how often does the retained direct-profile
endpoint interval contain the known AR1 persistence on one fixed DGP?

The answer can support only this exact route. It cannot certify `confint()`,
Wald intervals, replicated panels, `temporal_dep()`, `temporal_latent()`, OU,
source combinations, derived quantities, forecasts, or general coverage.

## Frozen pre-run fixture

Each replicate has 12 independent series, 8 consecutive occasions, and three
traits. The independently authored DGP draws a stationary AR1 process for each
series--trait pair with `phi = 0.6`, temporal variances `c(0.7, 0.45, 0.3)`,
and independent Gaussian observation variances `c(0.25, 0.35, 0.2)`. It does
not call a gllvmTMB temporal simulator.

The fitted model is:

```r
value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion)
```

The target is `phi`; each fit records optimizer convergence, maximum outer
gradient, finite objective, profile endpoint availability, interval width, and
whether a finite endpoint interval covers `0.6`. A failed fit, missing
endpoint, or non-finite value remains a retained failure and counts as not
covered. No seed is replaced.

## Stages and gate

1. Run one fixed pre-run (`seed = 2609131`) locally with
   `Rscript --vanilla dev/temporal-main-lifecycle/run-temporal-profile-coverage.R --smoke`.
   It records fit and profile elapsed time plus one retained row.
2. Use that elapsed time to estimate the 30-replicate campaign. If the estimate
   exceeds 30 minutes, present the measured receipt and obtain a separate
   compute approval before submitting the unchanged campaign to Totoro or DRAC.
   The campaign must pin BLAS to one thread and retain all rows.
3. For fixed seeds `2609131:2609160`, report empirical coverage with a binomial
   Wilson interval, endpoint availability, failures, and interval widths. The
   declared acceptance criterion is at least 27 of 30 finite intervals covering
   truth and a 95% Wilson lower bound of at least 0.75. This is a bounded
   engineering check, not a general calibration claim.

The generic `confint()` temporal guard remains in place until this campaign is
complete, independently reviewed, and reconciled with the public contract.

## Retained result: 2026-09-13

The fixed local pre-run took 2.620 seconds. The unchanged 30-seed campaign
completed in under two minutes with 30 converged, finite-objective fits. None
of the 30 profile calls supplied both finite endpoints, so finite endpoint
availability and coverage were both `0/30` (95% binomial lower bound `0`).
This fails the declared gate. The result is retained in
`results/temporal-profile-coverage-20260913.csv`; it does not support a
generic temporal interval claim and no post-result fixture, threshold, or
profile-search adjustment was made.
