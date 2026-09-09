# Temporal parametric-bootstrap contract

The temporal bootstrap will draw unconditional responses with
`simulate(fit, condition_on_RE = FALSE)`, replace only the saved response
column in a copy of the original public data, and invoke `update(fit, data =
...)`. It must not reconstruct an iid covariance formula from parsed ordinary
covstructs.

The initial target is the temporal `phi`/`kappa` estimate for unreplicated,
Gaussian, temporal-only `temporal_indep()` fits. Each row of the result retains
its seed, simulated response identity, convergence code, objective, estimate,
and error text. Failed or non-converged refits are retained and excluded only
from summaries with their denominator shown. This is parametric refit
variability, not coverage evidence.
