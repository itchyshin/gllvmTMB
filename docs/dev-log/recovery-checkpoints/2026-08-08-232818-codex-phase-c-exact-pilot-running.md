# Recovery checkpoint — Phase C exact-geometry pilot running

**Local time:** 2026-08-08 23:28 MDT  
**Platform / lane:** Codex / integrated-SDM Phase C  
**Branch:** `claude/experiment-integrated-sdm`  
**Frozen source:** `ce6c06713947eb0d9a68c06391449b67f45e802e` (pushed)  
**Main / issues:** untouched; #943--#946 remain open

## Completed

- Amendment 2, exact finite-sample geometry, receipt-v2, official-analysis,
  supplement-reportability, retrospective-receipt, and independent-verifier repairs were
  committed and pushed at `ce6c0671`.
- Pure-logic checks passed: 54-case exact geometry, 68-seed preflight contract, R1--R5
  aggregation, clustered-SE supplement, historical augmentation, and the independent
  19,800-row synthetic verifier.
- Corrected local preflight completed `PASS` from the frozen source:
  - 28 retained rows / 30 exact model-front-end attempts;
  - source dirty `FALSE`;
  - exact A5/A6 null collapse;
  - null mean `D_rmse = 0.0516`;
  - null mean `D_bias = -0.0044`, MCSE `0.0043`;
  - pooled prevalence `0.3316`;
  - timing route `totoro`.
- Local immutable preflight root:
  `/Users/z3437171/local-scratch/isdm-phase-c/2026-08-09-ce6c0671/run2-exact/`
- Totoro checkout:
  `/home/snakagaw/hsq_work/gllvmTMB-isdm-phase-c-ce6c0671`
- Totoro artifact root:
  `/home/snakagaw/hsq_work/isdm-phase-c-artifacts/ce6c0671/run2-exact`
- Local and Totoro preflight hashes match:
  - RDS `7dd27bc44d8a6b5040bd1657aabc0dc451f680dc3f4b2c2cadbc5fcee35c5d39`
  - receipt `d34bc021557055f6238c7e7fcf2c65a48944a947da6afd27265b774382e5ae8f`

## Active compute

- Host: `totoro`
- Pilot launcher PID: `3715095`
- Processes: `48` (reduced from 96 because launch-time load was about 124)
- `OPENBLAS_NUM_THREADS=1`; `NOT_CRAN=true`; `devtools::load_all()` via harness
- Output: `pilot-v2-results.rds`
- Receipt: `pilot-v2-compute.receipt`
- Log: `pilot-v2.log`
- At checkpoint: process running, zero completed part files, receipt pending.

## Resume safely

Monitor structural state only:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=15 totoro \
  'if kill -0 3715095 2>/dev/null; then echo PILOT_RUNNING; else echo PILOT_EXITED; fi; \
   find /home/snakagaw/hsq_work/isdm-phase-c-artifacts/ce6c0671/run2-exact/pilot-v2-results.rds.parts \
     -maxdepth 1 -name "part-*.rds" 2>/dev/null | wc -l; \
   test -f /home/snakagaw/hsq_work/isdm-phase-c-artifacts/ce6c0671/run2-exact/pilot-v2-compute.receipt \
     && echo RECEIPT_PRESENT || echo RECEIPT_PENDING'
```

When the compute receipt exists, authenticate hashes/counts first. Then run
`dev/isdm-phase-c-pilot-decision.R` from the same clean Totoro checkout. Inspect only the four
permitted summaries: A1 REF precision, pooled prevalence, timing, and fit/structural-failure
rates. Do not inspect any other pilot trend.

## Next safest action

Let PID `3715095` finish. Do not start another pilot. If the process exits without a PASS receipt,
inspect infrastructure/log state only and resume exact missing parts from the same source and
configuration; never selectively rerun a model-level fit error.
