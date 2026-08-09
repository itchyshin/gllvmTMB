# Phase C corrected-instrument receipt — 2026-08-08

## Status

**Gate B: PASS.** This receipt was written before opening any corrected pilot
statistic. No C-lite or sealed-old-pilot result was read.

Lane: `claude/experiment-integrated-sdm`  
Predecessor: `f595b159`  
Scope: `dev/` simulation, dispatch, receipt, and analysis instrumentation only  
Package API / `src/` / main / issues: unchanged

## Prospective amendment

`dev/isdm-phase-c-amendment-2026-08-08.md` preserves the original design as
historical and freezes the corrected stage, pairing, range, A6-null, G5,
conditional calibration, precision, exclusion, and receipt contracts.

## Instrument identity

The runtime instrument identifier is the ordered Git-object hash bundle for
the harness, campaign runner, official analysis, pilot-decision gate, and
amendment:

```text
5db5a6660d54ca5b37a4d539833a6fe711da4dfc:cdce15cc5cf19aaa83be391dfdb61fb815db57df:4657f1f02c74a0bd49afb5c37b50e13244171a8f:a2ebcb85140629563cf9e01f854265849b78cb52:a88f89ad6112634bc43dbc5d45131f2bb8621457
```

SHA-256 at the Gate B boundary:

| File | SHA-256 |
|---|---|
| `dev/isdm-bias-harness.R` | `83205c124cb1c03b495352012885eee64c284705a282676d7ffe473e3ffcd2c7` |
| `dev/isdm-bias-campaign.R` | `29f190e716645ee8dc693dd3b486eb7cd0e4052fd42905c3f74aab1cabed3f9a` |
| `dev/isdm-phase-c-contract-check.R` | `60a80e797acc1afabf2cfc0bd2dc47568445608f01fddd929e95139538080dd6` |
| `dev/isdm-phase-c-pilot-decision.R` | `01dfec73fd653e4ee0d8328a49217c22eb956c5e10404b331c430b987244474f` |
| `dev/isdm-phase-c-analyse-official.R` | `43c8a7d8b5b78a8acdce846362451f7d84e0c70b5b2cc0704f9623ef2dd5b3af` |
| `dev/isdm-phase-c-amendment-2026-08-08.md` | `64d6b6d8391d034174b72bfece902a4c5913143bda33ca742d9c1a04f9d4b182` |

## Verification

The following commands passed under `NOT_CRAN=true`,
`OPENBLAS_NUM_THREADS=1`, and `devtools::load_all()`:

```text
Rscript --vanilla dev/isdm-phase-c-contract-check.R
  Phase C corrected instrument contract: PASS

Rscript --vanilla /private/tmp/isdm-phase-c-analysis-selftest.R
  Phase C pilot-decision + official-analysis synthetic self-test: PASS

Rscript parse checks over all Phase C R scripts
  PASS

git diff --check
  PASS
```

The synthetic test generated its own schema-conforming rows. It did not read
the corrected pilot, the sealed old pilot, or C-lite.

## Independent precompute review

Noether's first review withheld the gate for receipt-chain and scoring-error
defects. Those defects were repaired. The final read-only re-review returned
**Gate B: PASS**, specifically confirming:

- exact predecessor binding from preflight through pilot decision and G1--G6;
- one source SHA for preflight/pilot/decision and one for G1--G6, with an
  identical instrument identity across the receipt-only commit transition;
- retained scoring failures rather than selective model retries;
- the arm-level null key; and
- G6, A6-null, and G5/A2 attribution contracts.

## Next authorized action

Commit this instrument before running corrected P0/preflight. Then run the
local preflight and structural smoke from that immutable instrument. Only a
PASS preflight receipt may authorize the corrected Totoro pilot.
