# Temporal future forecast contracts

`forecast_temporal(fit, newdata)` is a deliberately small forecast route for
the native temporal source. It returns response-scale Gaussian point forecasts
for future occasions in **existing** series. It conditions on the complete
observed response vector and holds fitted parameters fixed.

For observed response vector \(y_o\), future response vector \(y_n\), fitted
fixed-effect means \(m_o, m_n\), and the fitted temporal-plus-observation
covariance blocks, the route evaluates

\[
 E(y_n \mid y_o, \widehat\theta) =
 m_n + V_{no} V_{oo}^{-1}(y_o-m_o),
\]

\[
 \operatorname{Var}(y_n \mid y_o, \widehat\theta) =
 V_{nn} - V_{no}V_{oo}^{-1}V_{on}.
\]

`se.fit = TRUE` returns the square root of the second expression. It is a
fitted-parameter conditional predictive standard deviation, not an interval
and not a coverage claim.

The first admitted cell is unreplicated Gaussian identity-link ML with the
temporal provider as its only random-effect source. `newdata` must contain a
complete trait panel for each requested series--occasion pair; series must be
known to the fit and each requested time must be strictly later than the last
fitted time for that series. AR1 occasions remain integers; OU times retain
their supplied numeric scale.

A separate contract at `TEMPORAL-KERNEL-FORECAST-CONTRACT.md` admits one
replicated AR1 `temporal_indep() + kernel_indep()` future-observation route.
It uses the full additive temporal-plus-kernel covariance and requires a
complete trait panel for every future measurement. Its fixed-parameter dense
conditioning check is not interval calibration or a general source-pair
forecast claim.

This contract does not cover new series, interpolation, replicated panels
outside that named AR1-kernel cell, other ordinary or structured source tiers,
parameter uncertainty, intervals, profiles, bootstrap, or selection. Each
requires its own covariance and validation evidence before admission.
