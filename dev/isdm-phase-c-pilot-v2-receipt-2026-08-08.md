# Phase C corrected pilot-v2 decision receipt — 2026-08-08

## Gate C verdict

**PASS.** The full corrected pilot completed at immutable instrument source
`e2741b031ec753b67d7e8d67a9e25d2bb1580180`. G1 is frozen at **100 seeds**,
the common `BETA0` shift is frozen at **0**, and the campaign route is
**Totoro**.

Only the four prospectively permitted pilot summaries were opened. No broader
pilot trend and no C-lite or sealed-old-pilot statistic entered the decision.

## Structural receipt

- host: `totoro`
- R: `4.5.3`
- processes: 96
- BLAS threads per process: 1
- start: `2026-08-09 00:55:55 UTC`
- end: `2026-08-09 01:06:35 UTC`
- expected / actual rows: 1,500 / 1,500
- unique-key verdict: PASS
- fit-error rows: 0
- unlabelled non-finite rows: 0
- A6-null collapsed rows: 10
- resumable parts: 3
- source dirty: false
- predecessor preflight SHA-256:
  `1cae5639cd9518bb11f88fa1b1277b5da5dfe65e9ea38293c5a6a78010e7b982`

## Permitted pilot decisions

| Quantity | Frozen value |
|---|---:|
| completed A1 REF pairs | 10 |
| `sd(dD_bias)` for A1 REF | 0.0217528326736202 |
| projected `3 MCSE` at S=100 | 0.00652584980208607 |
| G1 seeds | **100** |
| pooled PA prevalence | 0.331574794157677 |
| common `BETA0` shift | **0** |
| mean seconds per fit | 19.7213139139811 |
| campaign route | **Totoro** |
| fit errors / exclusion rate | 0 / 0 |

The precision value is below the frozen 0.05 boundary, so S=200 is not
triggered. Prevalence is inside `[0.25, 0.50]`, so calibration is not triggered.
Both `rho` levels, including `rho = 0`, remain in G1.

## Immutable Totoro artifacts

Directory:

`/home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/pilot-v2-run1/`

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `pilot-v2-results.rds` | 105,048 | `72d574c5fb4982ad402968f1c370ba5dde518aea4f86eeb1707272dc994fc4aa` |
| `pilot-v2-compute.receipt` | 2,077 | `fec94e72481918f78b615e574bb5c070aeec895dd866be5e8fa0a333c7168ffa` |
| `pilot-decision.receipt` | 1,068 | `fc5009a4223c14a7654d8361400a36fa6ecd38dadd70e0dd954001d286cbedd3` |
| `pilot-v2.log` | 448,552 | `7bcc0f5ea1eeee72eebf7d8e3c727c14989e0d0ba05d2d3b5d036b4687517da5` |

No calibration receipt exists because calibration was not required.

## Frozen campaign command

The command below is the only authorized G1--G6 launch. The launcher runs the
blocks sequentially, uses resumable parts, and refuses unmatched receipts or
overwrites.

```sh
cd /home/snakagaw/hsq_work/gllvmTMB-isdm-phase-c-e2741b03
export PHASE_C_CORES=96 NOT_CRAN=true OPENBLAS_NUM_THREADS=1
nohup bash dev/isdm-phase-c-totoro-campaign.sh \
  /home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1 \
  /home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1/preflight.receipt \
  /home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1/pilot-decision.receipt \
  100 \
  > /home/snakagaw/hsq_work/isdm-phase-c-artifacts/e2741b03/campaign-run1/campaign.log 2>&1 &
```

No G1--G6 scientific trend may be inspected until every block has a PASS
compute receipt.
