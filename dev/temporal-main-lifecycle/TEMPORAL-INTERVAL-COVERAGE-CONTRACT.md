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

Profile calls use `ystep = 0.1` and `ytol = 3`. The latter exceeds the
95%-profile likelihood-ratio cutoff (`qchisq(.95, 1) / 2`, about `1.92`), so
the search is allowed to reach a nominal endpoint.

The generic `confint()` temporal guard remains in place until this campaign is
complete, independently reviewed, and reconciled with the public contract.

## Configuration diagnostic retained: 2026-09-13

The initial local pre-run used `ytol = 1`, which is below the required
likelihood-ratio cutoff. Its 30 fitted profiles consequently could not be
asked to reach a nominal endpoint; all 30 converged but returned missing
endpoints. That retained output is
`results/temporal-profile-coverage-20260913.csv`. It is a configuration
diagnostic, not an interval-coverage result.

The DGP, seeds, fitted model, endpoint definition, and acceptance criterion
are unchanged. The only correction is the declared TMB likelihood range above.
On the fixed smoke seed, the corrected search returned finite endpoints
`0.5346553` and `0.9040291`, containing the true `phi = 0.6`. The corrected
30-seed receipt will be retained separately as
`results/temporal-profile-coverage-ytol3-20260913.csv`.

## Corrected retained result: 2026-09-13

All 30 fixed-seed fits converged with finite objectives and all 30 corrected
profile calls supplied finite endpoint pairs. Twenty-four of 30 intervals
contained the true `phi = 0.6`; the exact binomial 95% lower bound was
`0.6143`. This misses both predeclared acceptance criteria (`27/30` coverage
and lower bound at least `0.75`). The receipt is retained in
`results/temporal-profile-coverage-ytol3-20260913.csv`. It establishes only a
failed, small fixed-DGP profile-endpoint calibration gate; it does not support
generic temporal confidence intervals or coverage claims.
