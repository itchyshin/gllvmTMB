# Design 86 Arc 7 — Gate-A q=2 protocol

**Status:** frozen deterministic `NON_GATE2` protocol. This is neither a V2
amendment nor authority to invoke a Design 86 runner.

## Scope and decision rule

Arc 7 tests the q=2 lower-triangular loading representation because the
historical extreme coordinates were raw `theta_rr` values. It does not alter,
rescore, or reconstruct either smoke record. A `GO` requires every A0--A4
sidecar and both independent reviews. Any missing evidence, failed derivative
check, established separation/rank defect, failed candidate comparison, or
claim-boundary breach is `PARK`.

## q=2 physical map

For `theta = (theta_1, ..., theta_5)` with `T = 3, q = 2`,

```
Lambda = [theta_1,       0
          theta_3, theta_2
          theta_4, theta_5].
```

The q=2 fixture is interior. Simultaneous orthogonal transformations preserve
the un-gauged objective, but the lower-triangular constraint leaves only the
four sign reflections. Each reflection must preserve the scalar/TMB objective,
`mu_by_obs`, `v_by_obs`, and KL within relative `1e-12`. A 45-degree
rotation must violate the declared upper-zero cell and is outside this packed
coordinate space.

For the scaling control `Lambda' = c Lambda`, `a' = a/c`, and `A' = A/c^2`,
likelihood moments are held fixed but KL is not. At `c = 2`, the fixture's
predicted total KL increase is `1.775726222239781`. A matching result rules
out that q=2 scaling path as an objective-preserving escape; it is not a
global coercivity claim.

## A0--A4 retained evidence

- **A0:** rehash both immutable manifest/result/receipt chains, retain their
  declared cross-links, field semantics, and legacy missing runtime explicitly.
- **A1:** retain one row for every flat q=2 parameter and every historical
  extreme, with source lines, transform, physical coordinate, and `parList`
  round trip. Require exact agreement between the R and C++ loading map.
- **A2:** at every declared fixed point and profile scale, retain each AD
  coordinate, `h = 1e-4, 1e-5, 1e-6` objective pair, finite-difference
  value, normalized discrepancy, and stability decision. Two adjacent steps
  must be finite and have discrepancy at most `1e-4`.
- **A3:** retain full raw/symmetrised Hessian matrices, eigenpairs, physical
  vectors, gradients, objective components, profile rays, fixed-design rank,
  separation certificate/infeasibility result, and all four optimizer stages.
  Curvature is interpreted only at a finite stationary reference with
  recomputed gradient below `1e-4`.
- **A4:** predeclare one exact-inverse block coordinate map using the absolute
  spectral decomposition of the stationary Hessian blocks and eigenvalue floor
  `1e-6`. Retain starts, map/inverse/Jacobian, physical-coordinate vectors,
  objectives, gradients, messages, health, and same-target comparison.

## Fixed controls

All arrays are deterministic and contain no Design 86 DGP or smoke seed.
They share `N = 2, T = 3, q = 2` and use nonconstant fixed-effect designs.
The balanced control has finite fixed-effect estimates; the separable control
has a recorded fixed-effect recession certificate; the rank-deficient control
has declared singular values but no separation certificate. A fixture label is
not evidence of separation.

## Gate A

`GO` requires complete A0--A4 evidence; no rank/separation finding; a finite
stationary reference; local scalar/AD/FD agreement; and an A4 transformed trace
that alone becomes healthy while reaching the same physical target within
`1e-8`. A lower coordinate gradient alone is not a pass.

`PARK` records a structural result or integrity failure and stops before V2.
`INCONCLUSIVE` records valid non-discriminating evidence and likewise stops
before V2. No outcome itself authorizes a V2, Gate B, or smoke.
