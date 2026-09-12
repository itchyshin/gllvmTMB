# Rank-one temporal latent covariance with a fixed spatial field: contract

## Candidate

This candidate is the replicated Gaussian AR1 intercept model
`temporal_latent(..., d = 1, unique = FALSE) + spatial_indep(...)`. It has two
independent additive fields before conditioning: a rank-one temporal score
indexed by `(series, occasion)`, and one static per-trait SPDE field indexed by
mesh nodes. It is not a space-time interaction.

\[
V_{ii'} = 1(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\lambda_{j_i}\lambda_{j_{i'}}
+ 1(j_i=j_{i'})\tau_{j_i}^{-2}[P Q(\kappa)^{-1}P^\top]_{ii'}
+ 1(i=i')\sigma_\epsilon^2,
\]
where \(Q(\kappa)=\kappa^4M_0+2\kappa^2M_1+M_2\) and
\(\phi=(1-10^{-6})\tanh(\theta)\). Mesh is fixed, while range and
trait-specific SPDE scales remain estimated.

## Narrow admission

Gaussian identity-link ML/Laplace only; three traits; replicated complete
panels with two measurements per temporal state; integer AR1 occasions with an
odd lag per series; one temporal rank-one term with `unique = FALSE`; and one
intercept-only `spatial_indep(..., mesh = mesh)` term at `rho = 1`.
Coordinates must be constant across traits and measurements within a temporal
state. The spatial projection is rebuilt from the prepared likelihood rows, so
long/wide conversion, update, and row permutations cannot reuse a stale
row-aligned `A_st` projection. Refuse OU, temporal Psi, ordinary terms, spatial
slopes, extra sources, estimated attenuation, and source-by-time products. The
separate bounded future-observation route is specified in
`TEMPORAL-LATENT-SPATIAL-FORECAST-CONTRACT.md`; generic prediction and every
other inferential route remain refused. The current proportional trajectory refusal is conservative,
not a claim that proportional distances prove non-identifiability.

## Evidence owed before admission

A directly assembled dense covariance must cover normalized NLL and every
active outer gradient at negative, zero and positive persistence; it must use
an independently reconstructed projection rather than copying `A_proj`.
Diagonal-temporal and genuine time-by-space-product controls must differ.
Tests must cover temporal cross-trait and spatial cross-series covariance,
labels, coordinate/projection permutations, unconditional redraw means and both
fields, long/wide replay with the rebuilt projection, and each refusal. A direct DGP must not call package
simulation, retain all fixed-seed attempts, and use a separately timed frozen
recovery gate. Existing diagonal temporal-spatial recovery evidence does not
transfer to this rank-one cell.
