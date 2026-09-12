# Rank-one temporal-spatial bootstrap contract

This proposed route is limited to replicated Gaussian AR1
`temporal_latent(..., d = 1, unique = FALSE) + spatial_indep()` with exactly
one fixed intercept-only mesh term at `rho = 1`. A bootstrap draw must redraw
both the temporal score process and SPDE field, then refit through the saved
public call so the projection is rebuilt from the response rows, coordinates,
and retained mesh. It must never reuse a fitted row-aligned `A_proj` matrix.

Admission must require the `spde` tier, the `spatial_indep` provider marker,
rank one, no temporal Psi, replicated AR1 data, one intercept-only mesh, no
ordinary or additional source tiers, and Gaussian identity-link ML/Laplace.
The independent lifecycle test must permute the saved rows before refitting and
show the rebuilt projection has the new row order; all draw seeds and failed
refits remain output rows. This route requires its own test and documentation
update before public admission. It establishes no bootstrap interval, coverage,
recovery, cross-platform, or release claim.
