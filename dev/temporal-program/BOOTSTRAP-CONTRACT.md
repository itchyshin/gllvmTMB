# Temporal parametric-bootstrap contract

The temporal bootstrap will draw unconditional responses with
`simulate(fit, condition_on_RE = FALSE)`, replace only the saved response
column in a copy of the original public data, and invoke `update(fit, data =
...)`. It must not reconstruct an iid covariance formula from parsed ordinary
covstructs.

The first target is the temporal `phi`/`kappa` estimate for unreplicated,
Gaussian, temporal-only `temporal_indep()` fits. The first composed extension
is exactly the replicated Gaussian AR1 or irregular-time OU
`temporal_indep()` plus one fixed, labelled `kernel_indep()` intercept term at
`rho = 1`. It uses the same saved
public call, `simulate()` draw, and `update()` replay; the simulator redraws
both the temporal state and the independent kernel field. It never replaces
the fitted kernel with an iid effect or conditions on fitted random effects.

Each row of the result retains its seed, simulated response identity,
convergence code, objective, estimate, and error text. Failed or non-converged
refits are retained and excluded only from summaries with their denominator
shown. This is parametric refit variability, not coverage evidence. The
extension has deterministic source-label, draw-seed, response-row, and update
tests. It does not establish bootstrap calibration, confidence-interval
coverage or source-pair forecasting, nor bootstrap support for
temporal `dep`/`latent`, phylogenetic, animal, spatial, ordinary, or multiple
source terms.
