# Phase C corrected preflight receipt — 2026-08-08

## Verdict

**Gate C preflight: PASS.** The corrected pilot is authorized on Totoro from
instrument commit `e2741b031ec753b67d7e8d67a9e25d2bb1580180`.

This preflight used `NOT_CRAN=true`, `OPENBLAS_NUM_THREADS=1`, and
`devtools::load_all()`. It did not read the corrected pilot, the sealed old
pilot, or C-lite.

## Structural and recovery checks

- REF data shape: 6,400 long-format rows.
- Family dispatch: PA rows used family ID 1; PO rows used family ID 2.
- A5 `diag_B_skip`: 0.
- A5 residual correlation: `8 x 8`, no missing values, maximum absolute
  off-diagonal `0.7166`.
- Trial routing: PA rows retained `n_trials = 3`; PO rows retained
  `n_trials = 1`.
- Biased A6: exactly eight `trait:bstar` columns.
- Changing only `phi_bias` from 0 to 0.4 preserved the exact environmental
  and response-uniform streams while changing the bias fields.
- Null A6 used the A5 right-hand side and matched the A5 parameter vector
  exactly.
- Ten-seed A5 null recovery: mean `D_rmse = 0.0516`; mean
  `D_bias = -0.0044`; MCSE `0.0043`; `3 MCSE = 0.0128`; pooled prevalence
  `0.3316`.
- Mean local A5 time: `20.735` seconds per fit; frozen compute route:
  **Totoro**.

## Corrected structural smoke

The low/high smoke returned all 12 expected logical rows with finite headline
metrics and no fit errors. Its high-minus-low `D_bias` deltas were printed as
diagnostics only; no direction or magnitude threshold was applied. This does
not alter C1--C3, R1--R5, or any campaign threshold.

## Immutable artifacts

External directory:

`/Users/z3437171/local-scratch/isdm-phase-c/2026-08-08-e2741b03/preflight/`

| Artifact | SHA-256 |
|---|---|
| `preflight-results.rds` | `5f8caf2d045f34c1634c0731c5cc3372a487ef43d2fd9a52e9323a87acd2be33` |
| `preflight.receipt` | `1cae5639cd9518bb11f88fa1b1277b5da5dfe65e9ea38293c5a6a78010e7b982` |

Receipt facts:

- host: `psychdhcp68.psych.ualberta.ca`
- R: `4.6.0`
- cores: 4
- start: `2026-08-09 00:49:14 UTC`
- end: `2026-08-09 00:53:06 UTC`
- source dirty: false
- instrument ID: the Gate B bundle recorded in
  `dev/isdm-phase-c-instrument-repair-receipt-2026-08-08.md`

## Authorized next action

Run the full corrected `pilot_v2` grid on Totoro with 96 processes and one
BLAS thread, using this exact preflight receipt. Inspect no scientific trends
until the pilot compute receipt passes structural integrity.
