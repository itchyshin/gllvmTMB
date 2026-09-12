# Direct temporal profile contract

The first temporal profile route exposes one direct time-kernel parameter per
fit through `profile_temporal()`. It profiles the marginal TMB/Laplace
objective: every nuisance parameter is re-optimized at each fixed time
parameter value and the temporal innovations remain integrated random effects.
It must never profile fitted temporal states. Generic `confint()` remains
refused for temporal fits because its existing routes assume iid latent scores.

For AR1, the user-facing target is

\[
\phi=(1-10^{-6})\tanh(\theta_T),
\]

so profile limits are transformed from the optimized `theta_temporal_time`
scale. Negative persistence remains admissible. For OU, the user-facing target
is the positive rate \(\kappa=\exp(\theta_T)\); translating elapsed time does
not alter its profile, while rescaling time changes its reciprocal.

The initial route admits temporal-only, unreplicated Gaussian identity-link
fits and only the direct time parameter. Its composed extensions admit exactly
the replicated Gaussian AR1 or irregular-time OU
`temporal_indep() + kernel_indep()` cells
with one fixed labelled kernel. At every fixed persistence value,
`TMB::tmbprofile()` re-optimizes the full marginal objective, including the
kernel variance and all remaining nuisance parameters; it does not profile a
conditional temporal state or hold the kernel estimate fixed. It must prove
that its profile objective equals the fitted marginal objective at the MLE,
match an independent dense Gaussian likelihood over fixed parameter values,
and expose flat or boundary profiles without inventing endpoints. Its returned
lower and upper values are profile endpoints, not a coverage claim. Wald
intervals, derived covariance targets, source-pair forecasts and bootstrap,
temporal `dep`/`latent`, other sources, and coverage claims remain separate work.

One additional composed route admits replicated AR1
`temporal_dep() + phylo_indep()` with one fixed intercept-only phylogenetic
source. It profiles only `theta_temporal_time`; the full packed temporal
loading block, every phylogenetic variance, and the measurement variance are
re-optimized at every profile point. Its test establishes transformed-MLE
closure against the direct `TMB::tmbprofile()` trace and refuses an altered OU
structure. The route does not define a profile for a temporal covariance entry,
a phylogenetic variance, or a derived target; its endpoints are not calibrated
intervals or coverage evidence.

One further composed route admits replicated AR1
`temporal_dep() + animal_indep()` with one fixed intercept-only animal
relationship. It has the same direct-persistence target: the full packed
temporal covariance, every animal variance, the measurement variance, and
fixed effects are re-optimized at each fixed time coordinate. The lifecycle
test closes the transformed profile at the direct TMB trace and rejects a
changed OU structure. This is neither a profile of animal variance nor an
interval-calibration claim, and it does not change the retained failed
dependent-animal recovery gate.

## Feasibility receipt

On 2026-09-09, `tmbprofile_wrapper()` was run directly on
`theta_temporal_time` from a three-series, four-occasion,
three-trait temporal-independence fit. The wrapper evaluated the temporal TMB
objective and returned the transformed AR1 MLE (`-0.1711763`). Both bounds were
`NA` for that deliberately small, weak fixture. This is retained as a
feasibility observation only: it proves that the generic TMB profile machinery
can address the native temporal parameter, not that the profile has calibrated
interval endpoints.
