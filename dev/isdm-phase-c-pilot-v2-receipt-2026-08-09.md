# Phase C corrected pilot-v2 decision receipt

Date: 2026-08-09  
Lane: `claude/experiment-integrated-sdm`  
Frozen compute source: `7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b`  
Artifact root: `/home/snakagaw/hsq_work/isdm-phase-c-artifacts/7e26e1bd/run4-aligned`

## Decision

The corrected exact-geometry pilot completed all 1,500 planned result rows and
the sealed decision program returned `PASS`. The campaign uses `beta0_shift=0`.
G1 uses 100 seeds and retains the full preregistered grid, including `rho=0`.

The four prospectively permitted summaries were:

| Summary | Value |
|---|---:|
| A1 REF paired rows | 10 |
| `sd(dD_bias)` for A1 REF | 0.0173074595697227 |
| projected `3 * MCSE` at S=100 | 0.00519223787091682 |
| pooled PA prevalence | 0.331574794157677 |
| mean seconds per fit | 21.7346112923622 |
| fit errors | 0 |
| exclusion rate | 0 |

The locked precision rule was
`3 * sd(dD_bias_A1_REF) / sqrt(100) <= 0.05`; therefore S=100 is sufficient.
Prevalence is inside `[0.25, 0.50]`, so no calibration receipt was created.

## Immutable evidence

| Artifact | SHA-256 |
|---|---|
| preflight result | `972f21dd1adb32452adc1a212d9fc9ab2a5f1da61b6948aa57a915177aa602b7` |
| preflight compute receipt | `bb5368f7801d86d3a71db1a274a99d452cdf9191dd04c647dbaa9b26fae9f3b6` |
| pilot result | `c4970ff5e91a051c97e8bb77c779a19d56be9fadb08e853e927c9e6d36784ee2` |
| pilot compute receipt | `a914c4b0b96ae7beb89ac1961a0e7a5fff6424d4a2ce579bee1d4f8030ceb68e` |
| pilot decision receipt | `50cd81447a72a6c26459b49b0a8f30e99d40d9b1217a3f3e36d374e22f19357b` |

The preflight canonical configuration SHA-256 is
`0c63620d4a2db561fd91c37c72356b0e62d4c2050da5bc4ce52ecb4e9a5fc1d3`;
the pilot canonical configuration SHA-256 is
`117d084cb5178b5c194a9c69892253525d46ccf5ed0328cede796f2a0bcf52a7`.
Both reproduced exactly on macOS R 4.6 and Totoro R 4.5.3. Raw RDS
configuration hashes remain compute-host provenance only.

## Superseded attempts

- The `ce6c0671` pilot completed structurally but remains sealed and
  uninterpreted because its raw-RDS configuration hash was not portable across
  R builds.
- The `5e40aef1` replacement preflight stopped before any fit when the inner
  geometry helper used a stale `1e-10` tolerance. Totoro reported maximum Gram
  error `2.497e-10`, within the already frozen outer `1e-9` contract. It wrote
  no result or receipt. Amendment 4 aligned the inner and outer tolerances.
- Neither attempt contributes statistical evidence.

## Frozen campaign invocation

All blocks run from the clean Totoro checkout
`/home/snakagaw/hsq_work/gllvmTMB-isdm-phase-c-7e26e1bd`, with
`NOT_CRAN=true`, `OPENBLAS_NUM_THREADS=1`, 48 processes unless server load
requires fewer, and the preflight and pilot-decision receipts above. Outputs
remain under the same external artifact root. G1 receives `--g1-seeds=100`;
G6 additionally receives the authenticated G1 compute receipt. Each block is
launched separately and may resume only its exact hashed part files.

This file is a durable decision receipt, not part of the eight-file compute
instrument. Adding it does not alter the frozen campaign source or instrument
ID.
