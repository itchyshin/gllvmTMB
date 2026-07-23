# Design 86 Arc 7 — Gate-A q=2 audit (PARK)

## Decision

**Gate A: PARK.** No V2 amendment, Gate-B preflight, Design 86 runner, or
smoke is authorised.

## What the controlled record supports

The deterministic q=2 lower-triangular loading map has five locally independent
coordinates at the frozen fixture: its covariance-map Jacobian has rank 5 and
smallest singular value `0.6720753`. The four lower-triangular sign reflections
have identical scalar/TMB objective, `mu`, `v`, and KL hashes. These are
discrete representations, not a continuous loading ridge.

At the predeclared scale `c = 2`, q=2 scaling preserves the selected likelihood
moments but increases KL by `1.77572622223978`, matching the algebraic
prediction. It rules out that one q=2 scale ray as an objective-preserving
escape. The maximum recorded normalized AD/finite-difference discrepancy is
`5.33081e-09`, which is local derivative evidence only.

The fixed separable design has a declared recession control and reached
objective zero with gradient about `3.0e-12`; balanced and rank-deficient
controls remain unhealthy. This demonstrates how the constructed controls
differ. It does not establish separation, rank deficiency, or a cause in either
immutable historical smoke.

## Why promotion is prohibited

The separation control is a protocol stop condition, so A4 was not eligible.
No spectral coordinate map, inverse/Jacobian, transformed trace, or same-target
comparison exists. Rose also finds the receipt non-promotion-complete: A0 does
not parse declared cross-links; A1 maps only five loading coordinates rather
than the full vector/historical extremes; and A2/A3 omit specified stability,
component, and review-receipt fields. The q=2 Hessians are not interpreted as
stationary curvature because the balanced trace remains unhealthy.

## Boundary ledger

| Statement | Status |
| --- | --- |
| Immutable smoke hashes remain unchanged. | supported |
| q=2 packed loading map is locally rank-defective. | not supported |
| q=2 common scaling is an objective-preserving escape. | not supported on the tested ray |
| The constructed separable control differs from balanced/rank-deficient controls. | supported |
| Historical smoke failures arose from separation, a ridge, or conditioning. | not established |
| A coordinate remedy, V2, Gate B, or one smoke may proceed. | prohibited by PARK |

## Next state

Neutral options are to park, defer, or commission a future independently
approved diagnostic with an auditable historical-mechanism hypothesis. No
option selects a run in this arc.
