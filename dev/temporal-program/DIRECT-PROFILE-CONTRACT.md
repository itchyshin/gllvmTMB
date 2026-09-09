# Direct temporal profile contract

The first temporal interval route will expose one direct time-kernel parameter
per fit through `confint(..., method = "profile")`. It profiles the marginal
TMB/Laplace objective: every nuisance parameter is re-optimized at each fixed
time parameter value and the temporal innovations remain integrated random
effects. It must never profile fitted temporal states.

For AR1, the user-facing target is

\[
\phi=(1-10^{-6})\tanh(\theta_T),
\]

so profile limits are transformed from the optimized `theta_temporal_time`
scale. Negative persistence remains admissible. For OU, the user-facing target
is the positive rate \(\kappa=\exp(\theta_T)\); translating elapsed time does
not alter its profile, while rescaling time changes its reciprocal.

The initial route admits temporal-only, unreplicated Gaussian identity-link
fits and only the direct time parameter. It must prove that its profile
objective equals the fitted marginal objective at the MLE, match an independent
dense Gaussian likelihood over fixed parameter values, and expose flat or
boundary profiles without inventing endpoints. Wald intervals, derived
covariance targets, replicated panels, source combinations, bootstrap, and
coverage claims remain separate work.

## Feasibility receipt

On 2026-09-09, `tmbprofile_wrapper()` was run directly on
`theta_temporal_time` from a three-series, four-occasion,
three-trait temporal-independence fit. The wrapper evaluated the temporal TMB
objective and returned the transformed AR1 MLE (`-0.1711763`). Both bounds were
`NA` for that deliberately small, weak fixture. This is retained as a
feasibility observation only: it proves that the generic TMB profile machinery
can address the native temporal parameter, not that the profile has calibrated
interval endpoints.
