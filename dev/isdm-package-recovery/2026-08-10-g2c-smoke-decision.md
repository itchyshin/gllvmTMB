# G2c local-smoke decision — do not launch the campaign

## Decision

`G2C_SMOKE_ADMISSION_HOLD`.  The approved three-visit G2c campaign is not
admitted to Totoro.  This is a named local admission result, not a 20-fixture
known-truth recovery verdict and not evidence against the scientific model in
general.

The immutable paired synthetic smoke is retained at
`results/g2c-smoke-20260810-retry1/`, produced by package commit
`2041684f044303c0fe26d5dde2b83f38d882f05d`.  It passed event construction and
native optimisation checks, but the frozen two-sided diagonal-profile rule did
not pass.  The plan therefore requires a HOLD before remote work.

## What the smoke actually shows

The one-visit and three-visit fits both retained exactly three restarts and
converged with small gradients.  The three-visit fit's maximum absolute
gradient was `1.972975e-04`, below the frozen `1e-3` threshold.  Its relative
map minimum correlation was `0.746`, versus `0.671` for its paired one-visit
fit.  That is a useful within-fixture change, but it is not a recovery claim.

The three native unit-tier diagonal log-SD coordinates are `theta_diag_B`.
Their fixed five-point profile ledgers contain one-sided/flat endpoints: for
example, coordinate 1 has a negative-direction endpoint delta NLL of `0.0055`
and coordinate 3 has `0.0015`; both violate the required two-sided endpoint
delta NLL of at least 2.  The three-visit fit is consequently ineligible.
The fit's maximum diagonal-variance error (`0.2424`) also exceeds the frozen
`0.20` target, but eligibility already fails on the profiles.

## Interpretation

Three linked PA visits add observation information while preserving the shared
cell ecological score.  They do not, in this fixture, make the rank-one plus
free-diagonal three-species covariance sufficiently two-sided under the
predeclared native profile criterion.  This is compatible with the known
near-saturation of a rank-one-plus-diagonal covariance at only three species;
it does not demonstrate a package-likelihood defect, a general
non-identifiability theorem, or a need to change the ecological estimand.

## Recommended next model-design step

Do **not** relax the profile threshold, add a detection multiplier, or rerun
the same G2c panel.  The next admissible design is a separately approved G2d
simulation with the *same* relative-intensity likelihood, source-gated GBIF
bias, one ecological rank-one field, and free diagonal `Psi`, but at a larger
multispecies dimension (for example six species) before considering more
observation-process complexity.  At three species, the rank-one-plus-diagonal
covariance is close to saturated; increasing the number of species tests the
community-model feature that the package is meant to supply without changing
the estimand or calling repeated visits a detection model.

G2d must freeze new truth, seed grid, profile coordinate map, recovery
thresholds, attacks, and a fresh immutable root before any fit.  It cannot
reuse the G2c smoke root or reclassify this HOLD.  Count, spatial, comparator,
source-admission, empirical, public, and Issue #953 work remain deferred.
