# Replicated temporal--kernel future-observation forecast contract

## Purpose

This contract adds one narrow composed forecast route:

```r
forecast_temporal(
  gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = K, name = "fixed_kernel"),
    data = data, family = gaussian()
  ),
  future_measurements
)
```

It forecasts **new observations** at future occasions of already observed
series.  `future_measurements` therefore supplies the measurement column and
contains a complete trait panel for every `(series, time, measurement)` key.
The measurement labels may be reused at later occasions: measurement noise is
independent between distinct rows.

## Conditional covariance

For observed rows `o` and future-observation rows `n`, with fitted means
`m_o`, `m_n`, the forecast is

\[
E(y_n\mid y_o,\widehat\theta)=m_n+V_{no}V_{oo}^{-1}(y_o-m_o),
\qquad
\operatorname{Var}(y_n\mid y_o,\widehat\theta)=
V_{nn}-V_{no}V_{oo}^{-1}V_{on}.
\]

For traits `j,j'`, series `g,g'`, occasions `t,t'`, and fixed kernel levels
`h,h'`, the qualified AR1 cell uses

\[
V_{ii'}=1(g=g')\phi^{|t-t'|}v_j1(j=j')+
K_{hh'}q_j^2 1(j=j')+1(i=i')\sigma_\epsilon^2,
\]

where `phi = (1 - 1e-6) tanh(theta_temporal_time)`.  The diagonal
measurement variance belongs in `V_oo` and `V_nn`, but never in `V_no` for a
strictly future observation.  This is the additive temporal-plus-static
kernel covariance, not a source-by-time product.

## Admission and refusals

The route requires the already qualified replicated Gaussian identity-link
AR1 `temporal_indep() + kernel_indep()` model: one fixed labelled diagonal
kernel at `rho = 1`, no ordinary `unit`/`unit_obs` tier, existing series only,
integer future occasions, and a complete future measurement--trait panel.
It preserves input row order and returns fitted-parameter conditional
standard deviations when `se.fit = TRUE`.

It refuses interpolation, past or fitted occasions, new series, missing or
unknown kernel labels, incomplete panels, temporal `dep`/`latent`, OU,
phylogenetic/animal/spatial source pairs, multiple source terms, intervals,
and parameter uncertainty.  State-mean prediction without measurement noise
is a separate estimand and is not implied by this route.

## Required evidence

1. An independently written dense covariance oracle must match conditional
   means and variances for the fitted public model, including the static
   kernel term and measurement variance.
2. A deliberately substituted temporal-by-kernel product covariance must
   differ from the additive oracle.
3. Tests must check future measurement-panel validation, unknown kernel-level
   refusal, negative AR1 persistence, and shuffled input-row identity.
4. The existing temporal-only forecast tests and the source-pair likelihood,
   simulation, update, and recovery tests remain required.  This route is a
   local fixed-parameter conditioning check, not interval calibration,
   coverage, or general source-pair forecast evidence.
