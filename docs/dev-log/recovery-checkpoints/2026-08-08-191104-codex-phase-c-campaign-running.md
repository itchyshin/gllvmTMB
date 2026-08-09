# Recovery checkpoint — Phase C campaign running

Time: 2026-08-08 19:11:04 MDT  
Platform / lane: Codex / integrated-SDM Phase C  
Branch: `claude/experiment-integrated-sdm`  
Local HEAD: `072d5b62`  
Local status at checkpoint: clean and equal to origin

## Completed

- Recovered and pushed historical P0 at `c8fc3ade`.
- Quarantined C-lite and sealed the old pilot provenance at `f595b159`.
- Prospectively repaired and independently reviewed the Phase C instrument at
  `e2741b03`.
- Corrected local preflight passed; receipt committed at `c707d0a7`.
- Corrected Totoro pilot-v2 completed with 1,500/1,500 rows, zero fit errors,
  and zero unlabelled non-finite rows.
- Pilot decision froze `beta0_shift = 0`, G1 `S = 100`, and Totoro routing;
  receipt and launcher committed at `072d5b62`.

Phase A/B were not rebuilt or rerun. C-lite and the sealed old pilot contributed
no new statistical evidence.

## Active external compute

Host: `totoro`  
Checkout: `/home/snakagaw/hsq_work/gllvmTMB-isdm-phase-c-e2741b03`  
Campaign source SHA: `072d5b62`  
Artifact root:
`/home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1`  
Launcher PID: `3364406`  
Launcher start: `2026-08-09T01:09:54Z`  
Current block at checkpoint: G1  
Processes: 96; `OPENBLAS_NUM_THREADS=1`; `NOT_CRAN=true`

The launcher runs G1--G6 sequentially and saves resumable parts. Do not inspect
scientific trends between blocks. Structural monitoring only:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=15 totoro \
  "pstree -p 3364406 | head; find /home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1 -maxdepth 2 -type f -name '*receipt' -o -name 'part-*.rds'"
```

## Required next actions

1. Let the existing launcher continue. Do not start a second campaign.
2. Monitor only processes, part counts, row counts, hashes, and PASS receipts.
3. If infrastructure interrupts the launcher, rerun the exact frozen command
   from `dev/isdm-phase-c-pilot-v2-receipt-2026-08-08.md`; the runner resumes
   only missing parts and retains model-level failures.
4. After all six receipts exist, verify hashes/counts independently before
   opening any trend.
5. Run `dev/isdm-phase-c-analyse-official.R` with the corrected pilot, G1--G6
   RDS files, and every matching receipt.
6. Run the fresh D-43 panel, then Rose/Shannon/Grace/Luna/Melissa closure.

## Fences

- Main untouched; no PR or merge.
- Issues #943--#946 remain open.
- Do not touch `src/`, package API, public docs, #944/#945, #946 state, or the
  `link_residual` implementation.
- Do not filter completed fits by convergence or `pdHess`.
- Do not use GitHub Actions for compute or store campaign RDS files on GitHub.
