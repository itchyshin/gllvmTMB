# Design 86 Arc 6 — Gate-A geometry audit (PARK)

## Decision

**Gate A: PARK.** Arc 6 does not establish a single mechanism that supports
an objective-preserving coordinate change. No V2 amendment, Gate-B preflight,
Design-86 runner invocation, or smoke is authorised.

## Evidence retained

The raw controlled ledger is
`docs/dev-log/forensic/2026-07-23-design86-arc6-non-gate2-geometry/ledger.json`
with its A0, A2, and A3 sidecars. It is deterministic, uses the temporary
q=1 EVA objective only, and is labelled `NON_GATE2` throughout. The historical
and V1 smoke roots were only re-hashed; they were not changed.

The rechecked manifest/result SHA-256 pairs are:

| Record | Manifest | Result |
| --- | --- | --- |
| historical `86200001` | `dc01e37b02634f5b0de02f6c1b83e2941aafeb53ca5e4969f06a4ec62d585f63` | `ec286f75a688b815d908fd23ea958827f7245fc666b896b1a812e90052bc9398` |
| V1 `86200002` | `c5a3fbb93f04aa58ea725c73a19ec3d1d7a8d77797941d7c63b608ee896c9fb8` | `afda2d76a4e687c99ead0cd7e07e9c29dfa93f751ae22a6025c4e33fb4fb191a` |

## What the controlled result supports

For the predeclared q=1 ray, `Lambda' = c Lambda`, `a' = a/c`, and
`d' = d/c`, the selected mean/covariance combinations are held fixed, but the
variational KL terms are not. The controlled objective rises strongly at both
ends of the `c = 10^-3, ..., 10^3` grid: the balanced fixture ranges from
`6.546525` near its minimum to `674992.1`; the separable-labelled fixture from
`6.441525` to `674992.0`; and the anti-separable fixture from `6.201525` to
`674991.7`. This rules out an unbounded q=1 scale escape on this controlled
path. It does not identify the historic q=2 loading mechanism.

The scalar oracle and TMB AD agreed locally (largest recorded objective
difference `1.16e-10`; normalized central-difference discrepancy about
`4.78e-9`). This validates those local derivative computations only.

The response controls cannot establish ordinary fixed-effect logistic
separation: all use an intercept-only fixed-effect design. The labels
`separable` and `anti_separable` are retained as fixture labels, not as a
separation finding. The raw BFGS outcomes also differ across those labelled
patterns, so the response-geometry condition requires PARK rather than a
coordinate promotion.

The Hessians were evaluated at the reference point rather than a stationary
solution and include negative eigenvalues. They are local curvature evidence,
not an identifiability or optimum claim.

## Why the candidate coordinate change is rejected

The full-block diagonal preconditioner did not meet the protocol's two
conditions: the mapped traces did not reach the same physical target, and they
did not turn an unhealthy raw trace into a healthy trace. For example, the
balanced raw trace ended at objective `5.8e-7` with gradient `4e-9`, whereas
the preconditioned trace ended at `1.52e-4` with gradient `0.141`. The
anti-labelled pair also differs in objective by about `5.38e-7`, above the
predeclared `1e-8` same-target tolerance. It is not a justified remedy.

## Receipt limitation

Rose's audit also withholds a pass because the retained raw ledger is not
complete enough for promotion: A0 lacks receipt paths/hashes/cross-links and
hardcodes `rehash_match`; A1 is absent; A2 records only the reference point
rather than every grid point; and A3 does not retain all mapped physical
coordinates, per-grid Hessians, or full gradient outputs. These omissions are
recording limitations, not grounds to rerun or reinterpret the immutable
smokes.

## Boundary ledger

| Statement | Status |
| --- | --- |
| The two smoke chains remain intact and hash-consistent. | supported |
| The q=1 controlled scale ray is an unbounded structural escape. | not supported |
| The labelled fixtures establish logistic separation. | not supported |
| The preconditioner is an objective-preserving health improvement. | not supported |
| A causal explanation for either historical failure is known. | not established |
| V2 or a new smoke may proceed. | prohibited by Gate-A PARK |

## Next state

Neutral options are to park this lane, defer pending a genuinely different
falsifiable diagnostic, or commission a new separately approved arc. None
selects a V2 amendment or a live run here.
