# Paper 2 S = 6 local pre-run adjudication

**Status:** `PRIVATE_NUMERICAL_AND_RECOVERY_HOLD`.

## What ran

One and only one approved seed-pinned S = 6 attempt was launched from commit
`57613984ddf844194326c3829ae97aab28ba3a35`, using the immutable receipt
`2026-08-12-paper2-local-prerun-receipt.md`, seed `86122`, and root:

```text
dev/isdm-package-recovery/results/paper2-s6-local-prerun-57613984
```

The command completed in 448.155 seconds, below its 20-minute stop threshold.
The retained stage sequence is `fixture_validated`, `fit_entered`,
`fit_returned`, `fit_retained`, and `artifacts_written`.

## Retained evidence

Both delegated and outer roots contain their fit, profiles, recovery summary,
decision ledger, runner log, manifest, and final provenance closure. The outer
closure hashes 16 artefacts and verified exactly.

All three ordinary starts had convergence code 0 and selected the same finite
objective (5231.672). The fixed Hessian was PD and all six profiles were finite
and converged. Nevertheless the raw maximum gradient was 0.002726537 in
`b_fix`, with no named boundary. Its immutable classification is Case C /
`NO_CANDIDATE`, so numerical admission is false.

The single-replicate five known-truth metrics were beta error 0.1597133,
GBIF-bias error 0.1043863, minimum map correlation 0.7324197, shared-covariance
relative Frobenius error 0.2403427, and diagonal-Psi variance error 0.2156398.
The first four meet their frozen thresholds; diagonal Psi exceeds its 0.20
threshold. Lower profile endpoint deltas for sp2, sp5, and sp6 were 0.57087,
0.42295, and 0.16194, respectively, below the required 2. No causal mechanism
is inferred from their co-occurrence.

This is one all-attempt private numerical and recovery HOLD, not a recovery
rate, a scale result, or a reader-facing capability claim.

## Consequence

Do not rerun, replace the seed, create a new root, recover a partial fit, or
alter the likelihood/DGP/map/thresholds in response to this outcome. The
protected `G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD` remain unchanged.

Any continuation needs a separate approval for the next evidence decision; it
must not reclassify Case C or relax the Psi/profile thresholds. No reader packet
or capability claim is supported.
