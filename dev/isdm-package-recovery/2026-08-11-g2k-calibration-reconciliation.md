# G2k calibration reconciliation — completed FIR campaign

## Identity and denominator

This is the replacement for the incomplete `g2k-totoro-20260811-001`
attempt, not an extension of it.  The earlier result started 128 fitting
attempts and excluded 22 candidate fixtures that failed the G2h DGP admission
check; it remains a `DESIGN_ADMISSION_HOLD` and is not used in any frequency
denominator.

The completed replacement is the private FIR campaign at
`results/g2s-fir-campaign-20260811-001`, bound to commit
`6ee117774f14cdc54533e21ac22e0157ecd01305`.  Its deterministic screen tested
candidates `86201L:87000L`, retained the first 150 G2h-admissible fixtures,
and retained all rejected candidates in `campaign-receipt.rds`.  The result
has 150 requested starts, 150 started attempts, 0 missing attempts, and 150
decision ledgers.  All 150 Slurm array tasks completed with exit code zero.

## Frozen model and decision rule

The fit is unchanged: six nonspatial species, one shared ecological
cell/species state, GBIF Poisson quadrature plus three conditionally
independent PA-cloglog events, rank-one \(\Lambda\), free diagonal \(\Psi\),
relative ecological intensity, and the GBIF-only bias gate.  No likelihood,
DGP, threshold, source gate, public interface, spatial field, count outcome,
or empirical data changed.

`PRE_RUN_RECOVERY_PASS` requires every numerical-admission and known-truth
criterion in `2026-08-11-g2i-recovery-prerun-decision.md`.  Every other
retained attempt is `PRE_RUN_RECOVERY_HOLD`.

## Results

| Quantity | Result |
| --- | ---: |
| All attempts | 150 / 150 |
| Valid diagnostic ledgers | 150 / 150 |
| Known-truth recovery metrics pass | 106 / 150 (0.7067; MCSE 0.0372) |
| Strict joint recovery pass | 22 / 150 (0.1467; MCSE 0.0289) |
| Strict joint recovery hold | 128 / 150 |
| Gradient \(\leq10^{-3}\) | 61 / 150 |
| Environmental-slope criterion | 147 / 150 |
| GBIF-bias criterion | 150 / 150 |
| Ecological-map criterion | 130 / 150 |
| Shared-covariance criterion | 150 / 150 |
| Diagonal-Psi criterion | 125 / 150 |

The dominant strict-admission loss is the frozen raw-gradient condition, not
an unretained fit error.  This observation is diagnostic evidence only; it
does not authorize a new threshold, post-hoc DGP change, retry, or replacement
campaign.

## Verdict

**`G2K_CALIBRATION_HOLD`.** The campaign specification deliberately defined
an all-attempt estimator, not a post-hoc promotion-frequency cutoff.  It
therefore cannot turn 22/150 strict joint passes into a recovery-validated
capability claim.  It does establish a reproducible numerical diagnosis:
substantive recovery metrics pass more often than the full
numerical-plus-recovery gate, with the raw-gradient gate the principal limiting
condition.

No Paper 2 efficacy claim, public promotion, detection implementation, or
spatial extension follows from this result.  The repeated-visit detection
specification remains a private, implementation-ready design that is gated on
a later core recovery PASS or a separately approved redesign/diagnostic arc.

## Provenance and operational record

The fresh remote pre-run `g2r-fir-prerun-20260811-001` passed its full ledger
at the same source revision before the campaign.  The scheduler array was
`54323628`, throttled to 50 one-core tasks, with BLAS/OpenMP pinned to one.
Results were copied to the private worktree without modification.  Two earlier
FIR launch roots are retained as non-scientific infrastructure records:
`g2p` failed before a seed due to coordinator working-directory routing and
`g2q` failed before fitting by reading the CSV header as a seed.  The corrected
`g2r` pre-run and `g2s` campaign supersede neither artifact; they simply make
their distinct status explicit.
