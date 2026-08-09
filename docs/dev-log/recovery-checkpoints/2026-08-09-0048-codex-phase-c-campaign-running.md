# Recovery checkpoint — Phase C exact campaign running

Date: 2026-08-09 00:48 MDT  
Lane: `claude/experiment-integrated-sdm`  
Local HEAD: `d392e193`  
Frozen compute source: `7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b`

## Local state

`git status --short --branch` was clean at checkpoint creation:

```text
## claude/experiment-integrated-sdm...origin/claude/experiment-integrated-sdm
```

Main was not touched. Issues #943--#946 remain open. No Phase A/B work was
rebuilt. No package API, `src/`, public documentation, PR, merge, or issue
mutation occurred.

## Completed and verified

- Portable canonical configuration identity committed at `5e40aef1`; the same
  preflight and pilot canonical hashes reproduced on macOS R 4.6 and Totoro R
  4.5.3.
- Inner exact-geometry tolerance aligned to the already frozen `1e-9` contract
  at `7e26e1bd`, after a pure no-fit preflight failure at `5e40aef1`.
- Noether's bounded tolerance review returned DONE with no P0/P1 finding.
- Totoro no-fit 54-case geometry gate: PASS, maximum error `1.776357e-14`.
- Full preflight: PASS, 28 rows, 30 model-front-end attempts, no fit errors,
  clean source, canonical config hash
  `0c63620d4a2db561fd91c37c72356b0e62d4c2050da5bc4ce52ecb4e9a5fc1d3`.
- Corrected pilot: PASS, 1,500 rows, six resumable parts, zero fit errors.
- Sealed pilot decision: `beta0_shift=0`, G1 seeds=100, rho=0 retained,
  projected 3-MCSE `0.00519223787091682`, prevalence
  `0.331574794157677`.
- Durable decision receipt committed and pushed at `d392e193`:
  `dev/isdm-phase-c-pilot-v2-receipt-2026-08-09.md`.

## Immutable external evidence

Artifact root:

```text
/home/snakagaw/hsq_work/isdm-phase-c-artifacts/7e26e1bd/run4-aligned
```

Hashes:

```text
preflight result  972f21dd1adb32452adc1a212d9fc9ab2a5f1da61b6948aa57a915177aa602b7
preflight receipt bb5368f7801d86d3a71db1a274a99d452cdf9191dd04c647dbaa9b26fae9f3b6
pilot result      c4970ff5e91a051c97e8bb77c779a19d56be9fadb08e853e927c9e6d36784ee2
pilot receipt     a914c4b0b96ae7beb89ac1961a0e7a5fff6424d4a2ce579bee1d4f8030ceb68e
decision receipt  50cd81447a72a6c26459b49b0a8f30e99d40d9b1217a3f3e36d374e22f19357b
```

The `ce6c0671` pilot remains sealed and uninterpreted. The `5e40aef1` failed
preflight wrote no result or receipt. Neither is evidence.

## Campaign now running

Totoro launcher PID reported at launch: `3755974`. G1--G6 run sequentially at
24 processes with `NOT_CRAN=true`, `OPENBLAS_NUM_THREADS=1`,
`OMP_NUM_THREADS=1`, and `MKL_NUM_THREADS=1`. The lower allocation keeps the
combined planned use under 150 while a separate Lane B campaign uses about 120
processes. Each block writes its own log, RDS, receipt, and resumable part
directory. `set -e` stops the sequence on the first failing block.

At checkpoint creation G1 was running and had not yet completed its first part.
Monitor only part counts, receipts, process state, and logs for infrastructure
errors; do not inspect scientific trends until G1--G6 all complete.

## Next safest actions

1. Wait for `campaign.status=CAMPAIGN_PASS` and all six compute receipts.
2. Verify expected rows/parts/hashes and run the independent campaign verifier
   before opening scientific outcomes.
3. Mirror immutable artifacts locally without changing bytes.
4. Run official analysis plus supplement, then the fresh Curie/Fisher/Noether
   D-43 completion panel.
5. Finish Grace/Luna/Rose/Shannon/Melissa audits, findings, check-log,
   after-task report, final handover, commits, and push. Keep main and issues
   untouched.
