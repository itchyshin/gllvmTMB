# Design 98 factorial VA/JJ — plan versus actual

## Planned arc

Design 98 was planned as one private, failure-resilient q=2 Bernoulli-logit
mechanism discriminator:

\[
\{\text{direct Gaussian ELBO},\text{JJ bound}\}
\times
\{\text{diagonal }S_i,\text{full }S_i\},
\]

with low/high deterministic tensor-GH comparators, fixed-global local-factor
contrasts, and a supervised 52-task DAG. It was not a package feature,
Design-86 repair, EVA parity exercise, campaign, or public capability claim.

## Gate reconciliation

| Gate | Planned | Actual |
|---|---|---|
| G0 | Fresh isolated design, contract, provenance and math review | PASS after two contract-review rounds; committed at `5f4c3036` |
| G1 | R/C++ equality, gradients, GH and invariant mechanics | PASS; objective error at most `1.78e-15`, relative gradient error at most `2.66e-9` |
| G2 | Supervisor and fault containment | PASS; crash, timeout, malformed, partial, duplicate, interruption, orphan-resume, all-terminal and duplicate-lock cases passed |
| G3 | Retained non-evidential N=16/T=3 invocation smoke | PASS; 52/52 terminal, zero infrastructure failures, 13 healthy phase-1 and 11 healthy phase-2 nodes |
| G4 | Comparable low/high GH references | FAILED scientifically; low endpoints failed the node ladder, high endpoints failed the phase-2 gradient gate |
| G5 | Fixed-global factorial contrasts | BLOCKED by the unavailable low-GH reference; all eight phase nodes retained as dependency-blocked |
| G6 | Joint low factorial | PARTIAL; QD, QF and JD comparable, JF unavailable because all phase-2 gradients exceeded `1e-4` |
| G7 | Dependency-valid labels and closeout | `TECHNICAL_INCOMPLETE`; no mechanism flag authorized |

## Retained result

The only real UUID is
`20260724T161436-30841-62d0004f`. All 52 task inputs and terminal records
remain under `dev/design98-factorial-va-jj/results/`.

QD, QF and JD produced stable multi-start endpoints. QF improved the retained
61-node common-scale log marginal over QD by `0.0052997403`, but both failed
the covariance-error accuracy threshold. JD met the three pointwise accuracy
thresholds. These are single-fixture descriptions only. Invalid GH anchors,
blocked fixed-global contrasts and non-comparable JF prevent attribution to
finite information, mean-field geometry, JJ displacement, or Gaussian/global
error.

## Deviations from plan

- The initial contract was not executable as written. Pre-compilation review
  added exact packing, deterministic start selection, endpoint-summed
  quadrature uncertainty, directed labels, a one-shot lock and fuller
  provenance.
- The first supervisor integration incorrectly made all evaluation
  dependencies require health. It was changed before the real lock so failed
  siblings could be retained and adjudicated.
- The predeclared high-GH benchmark decision was not executed before the high
  workers. The high tasks therefore remained local. Their phase-1 runtimes
  later exceeded ten minutes, but already-started immutable attempts were not
  migrated or replayed. This is a compute-routing process miss, not evidence
  for or against an estimator.
- No retry, threshold change, quadrature-order change, alternate start,
  rescore, or second real UUID followed any failure.

## Closure

Design 98 is terminal as `TECHNICAL_INCOMPLETE`. A future attempt to replace
H31 optimization, alter optimizer health, or recover JF is a separately
approved new research design, not a Design-98 continuation.
