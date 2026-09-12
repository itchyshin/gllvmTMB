# Replicated temporal-dependent phylogenetic bootstrap contract

## Purpose

This contract admits one composed parametric-bootstrap route:
replicated Gaussian identity-link AR1 `temporal_dep() + phylo_indep()` with one
fixed intercept-only phylogenetic source at `rho = 1`.

For each retained attempt, `bootstrap_temporal()` redraws the complete fitted
joint response with `simulate(..., condition_on_RE = FALSE)`, replaces only the
public response column in the saved training data, and calls `update()` on the
saved public fit. It retains the draw seed, objective, estimated persistence,
convergence code, and an error string for every failed refit.

The helper therefore re-estimates the temporal loading block, all phylogenetic
trait-diagonal variances, measurement variance, and fixed effects. It does not
hold a sampled temporal state, a phylogenetic effect, or a fitted covariance
parameter fixed while refitting.

## Admission and refusals

Require exactly one replicated Gaussian AR1 `temporal_dep()` intercept term and
one fixed intercept-only `phylo_indep()` source, without ordinary, animal,
spatial, kernel, attenuation, slope, or additional source tiers. The saved
long or wide public call and its phylogenetic input must be recoverable by
`update()`.

Refuse OU, temporal `indep`/`latent` phylogenetic combinations, a changed
source tier, generic non-Gaussian fits, generic bootstrap APIs, and every other
temporal source pair. This contract does not admit a new public simulation
grammar.

## Required evidence and boundary

The focused lifecycle test fits the qualified source pair, obtains two
unconditional redraw/refit attempts, verifies retained row identity and
deterministic draw seeds under a supplied seed, and confirms finite objectives
or retained error text. The existing source-pair tests separately check its
unconditional simulated covariance, update replay, phylogenetic labels, and
tree/VCV equivalence.

This is local lifecycle evidence only. It is not a bootstrap standard-error,
confidence-interval, bias, coverage, recovery, cross-platform, or release
claim; every failed or non-converged refit remains an output row rather than
being replaced.
