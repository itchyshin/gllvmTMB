# G2i deterministic iSDM-polish contract

## Purpose and immutable predecessor

G2i is a fresh private continuation from G2h commit
`88e329554c3688a93b696f0ead43a4aaeea4104d`.  G2h remains
`G2H_SMOKE_HOLD`: its raw maximum AD gradient was `0.001290534`, which exceeds
the frozen smoke gate `0.001`.  G2i does not reinterpret that result.

G2i defines one new *private estimator*: the ordinary native-Laplace fit plus,
only when the predicate below is true, one deterministic same-objective
`nlminb` polish from the raw outer parameter vector.  The raw and candidate
records are both retained.  No likelihood, data-generating process, parameter
map, profile coordinate, source gate, or public interface changes.

## Eligibility

The polish can run only when all conditions hold:

1. the internal two-source iSDM marker is present; the optimizer is `nlminb`;
   AGHQ and the Laplace ridge are absent;
2. the raw fit has convergence code zero, finite objective and AD gradient,
   and a positive-definite fixed-effect Hessian;
3. `1e-3 < max(abs(raw_gradient)) < 1e-2`;
4. the sole boundary class is `near_zero_sd_B`, exactly one corresponding
   diagonal SD coordinate is flagged, and the maximum-gradient outer parameter
   is not a `theta_diag_B` coordinate.

The G2h expected case is a maximum in `theta_rr_B[2]` and a boundary in
`theta_diag_B[1]`.  The latter remains a warning; it is not removed or treated
as ecological recovery.

## One-call and acceptance contract

The candidate call receives the raw `opt$par` unchanged and uses the same
`obj$fn`, `obj$gr`, bounds, scale, controls, data, map, random effects, and
Laplace objective as the raw fit.  There is exactly one candidate call.  No
alternative start, rebuilt objective, tolerance change, or retry is allowed.

It is selected only if it has convergence code zero, finite objective and AD
gradient, positive-definite Hessian, exactly the same named boundary class and
coordinate, a non-worse objective within
`64 * .Machine$double.eps * max(1, abs(raw_objective))`, and
`max(abs(candidate_gradient)) <= 1e-3`.  Otherwise the raw fitted state is
restored and the candidate is retained only in the diagnostic ledger.

The record must retain raw/candidate parameter vectors, objectives, gradients,
Hessian flags, boundary classes, boundary coordinate/value, maximum-gradient
parameter block/index, and acceptance decision.  It also records that the
fixed parameter map is identical before and after; profiles retain the frozen
six `theta_diag_B` coordinates.

## Smoke rule

A new G2i smoke may evaluate this estimator only after compiled-unit validation
and independent review pass.  It uses a new SHA-bound result root and one fit
attempt.  It is complete only with three retained restarts, six valid frozen
profiles, a valid GBIF-only gate, the frozen geometry classification, and the
final selected-estimator gradient at or below `1e-3`.  G2h remains held even if
G2i completes.  A local recovery pre-run and any Totoro campaign remain
separately unapproved.
