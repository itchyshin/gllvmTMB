# OU temporal--kernel first-cell contract

## Purpose

This contract qualifies the first irregular-time temporal-source pair:

```r
temporal_indep(0 + trait | series, time = elapsed,
  replicate = measurement, structure = "ou") +
  kernel_indep(series, K = K, name = "fixed_kernel")
```

It is a narrow addition to the existing replicated Gaussian source-pair
programme.  It does not admit `temporal_dep()`, `temporal_latent()`, a second
static source, an ordinary covariance term, a source-by-time interaction, or
any lifecycle helper for an OU source pair.

## Model

For observations `i` and `i'`, temporal series `g`, elapsed time `t`, kernel
level `h`, and trait `j`, the covariance is

\[
 V_{ii'} = I(g_i=g_{i'})\exp\{-\kappa |t_i-t_{i'}|\}v_{j_i}I(j_i=j_{i'})
 + K_{h_i h_{i'}}q_{j_i}^2 I(j_i=j_{i'})
 + I(i=i')\sigma_\epsilon^2,
\]

where `kappa = exp(theta_temporal_time)`.  The temporal and kernel fields are
independent before data are observed.  Their sum is not the product
`exp(-kappa * lag) * K * Sigma`.

Time must be finite numeric elapsed time.  Shifting all times must preserve
the fit.  Re-expressing time as `c * time` must transform the rate to
`kappa / c` while preserving the observation covariance.  Unlike AR1, OU does
not admit negative persistence and does not require integer or odd time lags.

## Admission and refusals

The initial cell requires Gaussian identity-link ML/Laplace, three or more
traits, three or more distinct elapsed times in each series, complete panels,
and at least two measurements per series--time state.  `K` must be a fixed,
labelled, externally supplied positive-definite nonidentity kernel.  The
kernel labels and public temporal `(series, elapsed)` identity remain visible
in extractors, simulation, long/wide rewriting and `update()`.

The implementation continues to reject unreplicated source pairs,
`temporal_dep(..., structure = "ou")`,
`temporal_latent(..., structure = "ou")`, phylogenetic, animal and spatial OU
pairs, temporal `unique = TRUE`, ordinary covariance companions, multiple
source terms, non-Gaussian responses, forecasts, intervals, profiles,
selection and bootstrap for this new OU pair.  Each needs a separate contract
and evidence.

## Evidence before promotion

1. An independently authored full dense covariance oracle must agree with the
   normalized native Gaussian NLL and every active outer numerical derivative.
   It must include irregular gaps, row and kernel-label permutations, and a
   deliberately wrong product covariance control.
2. It must prove time-shift and time-rescaling covariance identities, and
   inspect the near-constant and near-independent rate limits separately from
   mere finite gradients.
3. An independent direct simulator must validate unconditional and conditional
   moments.  Long/wide rewriting, extraction, update/refit and training row
   order need explicit tests.
4. A frozen direct-DGP recovery fixture must retain every attempt, boundary
   diagnostic and failure.  Its rate and variance recovery thresholds require
   a measured pre-run and separate compute authority when the retained campaign
   exceeds thirty minutes.

The current AR1 source-pair evidence does not qualify this cell.  Passing the
first oracle and lifecycle checks qualifies only this named local model route;
it is neither a general OU source-pair nor a recovery/coverage claim.
