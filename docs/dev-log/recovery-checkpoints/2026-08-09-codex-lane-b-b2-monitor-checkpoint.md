# Lane B B2 monitor checkpoint

## Scope

Continue the frozen LA-MSPL B2 campaign through authenticated completion and
only then perform the frozen adjudication.  This checkpoint authorizes no
remote control action.

## Local state

- Repository: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch/HEAD: `main` at `5bf18ab30d7034e1c90c383fb4621d916b3a48cd`
- Upstream relationship: seven commits behind `origin/main`.
- Working tree: clean when this checkpoint was written.

## Remote B2 state

The only monitored campaign is Fir array `53884193` named `laneB_mspl_B2`.
At the last narrow-wrapper check, tasks `521` onward were `RUNNING`, with
elapsed time about `3:27:00` of the `8:00:00` allocation.  No B2-specific
failure was reported.  Other clusters' historical failures are not B2
evidence and must not be acted on or attributed to B2 without an
authenticated receipt.

The frozen B2 provenance remains:

- campaign SHA-256: `1147ea898b37720e393b9acaf524675d4ca805bf497d1038291027705869db98`
- frozen source: `/home/snakagaw/gllvmtmb_lane_b_20260808_v1`
- frozen source HEAD: `b1341c29d174b744e45e1082379d72555b683a45`

Do not resume paused Totoro launcher PID `3384266`; do not submit, restart,
cancel, or otherwise alter the Nibi feeder PID `83639` or any remote job.

## Monitoring and next action

Use only `/Users/z3437171/.codex/tools/drac-status` for read-only status
checks, no more frequently than once per minute.  When no B2 work remains
active, first verify complete authenticated receipts (exact provenance,
manifest/attempt completeness, and accounted failures) before adjudicating.
After adjudication: preserve/review NB2 HOLD commit `6e088048`, reconcile only
accepted work onto current 0.6, then rerun exact-artifact and platform
evidence.  Do not merge, bump a version, publish, release, or submit to CRAN.
