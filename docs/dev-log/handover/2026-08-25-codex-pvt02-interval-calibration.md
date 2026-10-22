# Session Handoff: PVT-02 interval-calibration packet

Meta: 2026-08-25 · Codex · lane `codex/pvt02-interval-calibration`

## Critical Context

The PVT-02 packet is ready, but the `n_sim = 5000` calibration campaign has
**not** run. The only local data are two smoke replicates; do not call them
coverage evidence or alter CI-08/public status. The public `n >= 150` predicate
and the stale truth-matrix wording are documented discrepancies, deliberately
not edits in this leased lane.

## What Was Accomplished

Created `dev/pvt02/` pure contract, focused tests, bounded smoke/receipt
verifiers, and PVT-02 artifacts. The smoke ran indices 50001–50002 (seeds
152002–152003), took 21.3 s, retained both attempts, and produced finite
ordered profiles. Rose PASSed the scope review. Grace found a missing
realised-seed check; it was repaired and Grace PASSed the re-review. Unlazy
`--reverify` is 4/4 green.

## Current Working State

- Working: all bounded packet work is complete and ready for a narrow local
  commit on this branch.
- In progress: none.
- Not working / blocked: the frozen campaign requires explicit Totoro approval.

## Key Decisions & Rationale

- Exact candidate: Gaussian, unit tier, `latent(..., unique = TRUE)`, `d=2`,
  `n_units=400`, trait-1 `log(V_t)` profile.
- Exact future window: 50001:55000, with realised seeds checked against the
  d=2 mapping; no historical pooling.
- Failed profile endpoints count as misses among converged fits; failed outer
  fits remain in all-attempt reporting.
- Future promotion requires 5,000 attempts, disjoint seeds, coverage >= 0.94,
  and coverage minus twice replicate-clustered MCSE >= 0.94.

## Landing State

`handoff_gate.sh` was run before this handoff and reported the three untracked
PVT-02 path groups, plus 463 unrelated unpushed commits on other branches.
Those foreign branches are not this lane's state. The PVT-02 files are committed
in the same narrow local commit that contains this handoff; no push/PR/merge is
authorised.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/pvt02-interval-calibration` packet | yes, local commit | no | none | CARRIED-OVER: awaiting campaign approval |

## Next Immediate Steps

1. Obtain explicit approval for a Totoro 5,000-replicate campaign.
2. Before launch, choose capped cores (at most 150), output/retention location,
   and checksum/manifest procedure; preserve every failed attempt.
3. Run a target-specific pre-launch seed and output check, then the frozen
   campaign only. A future claim-reconciliation task, not this one, handles
   any predicate or truth-matrix change.

## Blockers / Open Questions

Approval is required for the >30-minute campaign. No other decision is open.

## Gotchas & Failed Approaches

The old certificate's seed formula can alias across rank cells. PVT-02 checks
both indices and realised seeds. An Unlazy `CHECK:` runs from its ledger
directory, so use the relative verifier paths already recorded in the local
ledger. The earlier testthat wrapper printed a success token after an error;
the corrected wrapper now fails on captured expectations.

## How to Resume

```sh
git switch codex/pvt02-interval-calibration
Rscript --vanilla dev/pvt02/verify-contract.R
Rscript --vanilla dev/pvt02/verify-tests.R
Rscript --vanilla dev/pvt02/verify-smoke-receipt.R docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-smoke-receipt.csv
```

Read the plan, reconciliation, and pre-run receipt in
`docs/dev-log/artifacts/pvt02/` before proposing any campaign command.
