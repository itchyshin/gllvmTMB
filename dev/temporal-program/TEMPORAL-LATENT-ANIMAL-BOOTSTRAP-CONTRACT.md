# Rank-one temporal-animal bootstrap contract

This contract admits `bootstrap_temporal()` for replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE) + animal_indep()` with exactly one
fixed intercept-only animal relationship at `rho = 1`. Each attempt redraws the
full unconditional joint response and replays the saved public call through
`update()`. It retains the draw seed, fitted persistence, objective,
convergence code, and every error; it does not condition on a sampled temporal
score or animal effect.

The focused fixture verifies deterministic retained draw seeds, finite
objectives or retained errors, and the known rank-one animal model. The
source-cell suite separately verifies the dense additive likelihood, simulation
moments, relationship labels, update replay, and a retained fixed-seed recovery
gate. This is a local refit-workflow check only: it does not establish
bootstrap standard errors, intervals, bias, coverage, cross-platform evidence,
or release readiness. OU, temporal Psi, rank above one, generic bootstrap APIs,
and every other source pair remain refused.
