# G2i measured recovery pre-run packet

## Earned input

The single G2i admission smoke at
`results/g2i-smoke-20260811-001` completed in approximately six minutes from
root receipt to terminal stage.  Its three raw restarts took 13.629, 19.905,
and 20.100 seconds; the remaining time was the six five-offset profiles and
artifact closure.  It is therefore a runtime measurement for this fixed
fixture/estimator, not recovery evidence.

## Proposed S7 only

Run one new local known-truth recovery replicate on the exact committed G2i
estimator, retaining one seed, one attempt, fit, truth, parameter recovery
summary, profiles, decision ledger, manifest, and final provenance closure.
It must use a fresh result root and report wall time separately for fitting and
profiles.  Expected wall time is 6--10 minutes; stop and report if it exceeds
30 minutes.  Inspect non-empty output before any array is considered.

## Preconditions

- G2i commit and private fixture are frozen; no new restart policy, DGP, map,
  source gate, threshold, or profile coordinate is admitted.
- The local pre-run requires separate maintainer approval.
- A Totoro campaign remains unapproved.  If the pre-run is valid, its measured
  wall time and retained artifacts determine the replication count, core cap
  (at most 150), and a separate campaign approval request.

## Scope fence

S7 would assess only the private synthetic six-species nonspatial core.  It
would not add spatial fields, a detection extension, survey-count outcomes,
empirical data, comparators, zero inflation, a public workflow, or Paper 2
claims.
