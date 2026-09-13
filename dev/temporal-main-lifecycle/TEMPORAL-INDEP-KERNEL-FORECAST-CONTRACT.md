# Replicated temporal-independent plus kernel forecast contract

## Scope

This contract admits one fitted-parameter forecast route for the existing
Gaussian replicated AR1 cell

```r
temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
  kernel_indep(series, K = K, name = "fixed_kernel")
```

It is a forecast of future response observations for already observed series.
It is not a forecast of a latent state mean, a new-series prediction, or a
source-by-time interaction.

## Conditional Gaussian calculation

For traits `j` and `k`, source labels `h` and `h'`, series `g` and `g'`, and
occasions `t` and `t'`, the fitted covariance is

\[
V_{ij,i'k} =
1(g=g')\phi^{|t-t'|}1(j=k)v_{T,j}
+ K_{hh'}1(j=k)v_{K,j}
+ 1(i=i')\sigma_\epsilon^2.
\]

Here \(\phi=(1-10^{-6})\tanh(\theta)\).  The kernel component is static
across occasions and measurements.  It is additive: the deliberately wrong
product \(K_{hh'}\phi^{|t-t'|}v_{T,j}\) is outside this model.

Let `o` index every observed response and `n` every requested future response.
At fitted parameters, with fixed-effect means \(\eta_o,\eta_n\), return

\[
E[Y_n\mid Y_o] = \eta_n + V_{no}V_{oo}^{-1}(Y_o-\eta_o),
\qquad
\operatorname{Var}(Y_n\mid Y_o) = V_{nn}-V_{no}V_{oo}^{-1}V_{on}.
\]

`se.fit` is the square root of the displayed conditional variance.  It omits
parameter uncertainty and is not an interval or calibration claim.

## Admission

The route requires exactly the named fitted cell: Gaussian identity-link,
replicated AR1 `temporal_indep()`, one fixed labelled `kernel_indep()` source,
three or more traits, complete fitted panels, and one source label per series.
Future data must retain the fitted `series`, `occasion`, `measurement`, and
`trait` columns; include a complete trait panel at every
series--occasion--measurement; use existing series and source labels; and use
occasions strictly after each series' observed maximum.

Refuse OU, unreplicated panels, temporal `dep` or `latent`, `kernel_dep`,
estimated source strength, ordinary `unit` / `unit_obs` components, additional
structured sources, missing/incomplete future panels, unknown series or kernel
labels, and all new-series forecasts.

## Evidence required before public admission

1. An independently authored dense covariance oracle must reproduce fitted
   conditional means and variances, including the measurement residual and
   additive static kernel term, for positive and negative AR1 persistence.
2. A wrong product covariance must disagree with the native forecast.
3. Tests must preserve input-row order and reject every admission refusal.
4. Existing source-pair likelihood, simulation, long/wide, update, and fixed
   recovery evidence must remain green.  This route creates no new recovery,
   coverage, interval, profile, bootstrap, or selection claim.
