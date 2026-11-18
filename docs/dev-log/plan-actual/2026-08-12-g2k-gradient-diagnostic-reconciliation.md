# G2k gradient diagnostic reconciliation

**Worktree:** `/private/tmp/gllvmtmb-isdm-g2k-gradient-diagnostic`
**Branch:** `codex/isdm-g2k-gradient-diagnostic`
**Starting commit:** `9c9ca27775c14868fffc3ffa317c9eca56ac73b0`

## Planned versus actual

The task was a read-only diagnosis of the completed G2k FIR campaign, not an
estimator repair.  The transferred campaign evidence remains bound to
`6ee117774f14cdc54533e21ac22e0157ecd01305` and retains 150 requested starts,
150 completed ledgers, and zero missing attempts.  The new extractor validates
those invariants before it reads any ledger and writes only a fresh private
diagnostic root.

Actual diagnostic root:
`dev/isdm-package-recovery/results/g2k-gradient-diagnostic-20260812-007/`.
It retains `all-attempt-gradient-diagnostic.csv`, the criterion and interaction
tables, an RDS evidence bundle, and a receipt.  It contains no fitted object
created by this task.

## Findings and boundary

The 150-ledger decomposition is: 89 raw-gradient failures, 25 Psi failures,
20 map failures, 3 fixed-effect failures, and no GBIF-bias/shared-covariance
failures.  Sixty-nine attempts pass all five recovery metrics yet fail the raw
gradient.  A separate 15 attempts pass the raw gradient and all metrics but
are held by the frozen mandatory-polish rule despite being polish-ineligible.

The exact decision is `NO_REPAIR`; `G2K_CALIBRATION_HOLD` remains unchanged.
No threshold, likelihood, DGP, seed grid, source gate, parameter map, recovery
criterion, public/package surface, or external-compute state was changed.
G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## Next authority needed

Only a separately approved numerical-admission design task may consider a
complete conditional-polish decision table or a distinct same-objective
candidate for the `b_fix`/`theta_rr_B` residual geometry.  It must not
reclassify G2k or begin a fit/campaign without its own approval.
