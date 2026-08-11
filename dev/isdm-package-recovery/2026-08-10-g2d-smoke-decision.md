# G2d replacement local-smoke decision — do not admit Totoro

## Decision

`G2D_SMOKE_HOLD`. The replacement ordinary seed-86101 smoke retained its root,
fit, and manifest artifacts at `results/g2d-smoke-20260810-210000/`, but both
arms stopped at a harness profile error. Totoro is not admitted.

## Cause and interpretation

The profiler used partial `$` matching for `fit$tmb_map$theta_diag_B`. The
object had no exact `theta_diag_B` map (the intended free six-coordinate
state), but R partially matched the unrelated one-element
`theta_diag_B_slope` map and raised “coordinates are tied or skipped.” This is
a harness error, not an estimator, profile, or recovery conclusion. The exact
map lookup is now repaired and independently reviewed, but this smoke is not
rerun under its one-smoke authority.

## Next gate

Any future replacement smoke needs fresh explicit approval, a new frozen
commit, and a new root. G2c remains `G2C_SMOKE_ADMISSION_HOLD`; no campaign,
empirical, public, spatial, count, comparator, source-admission, or Issue #953
work is authorised by this decision.
