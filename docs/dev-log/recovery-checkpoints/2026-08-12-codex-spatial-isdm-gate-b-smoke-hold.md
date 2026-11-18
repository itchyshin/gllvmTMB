# Recovery checkpoint — Gate-B private spatial iSDM smoke HOLD

**Branch:** `codex/isdm-spatial-information-design`
**HEAD before closeout commit:** `87bec5a9a877d8c349c101a945dbd99a441c1010`

## State

One authorised local smoke was launched against immutable root
`dev/isdm-package-recovery/results/spatial-isdm-gate-b-smoke-20260812-r2`.
It exited non-zero after 16.313 seconds. No `fit.rds` or all-attempt ledger
exists because the runner attempted a Linux-only `/proc/self/status` read while
writing peak RSS after the protected fit call.

## Changed files

- `dev/isdm-package-recovery/run-spatial-isdm-gate-b-smoke.R` — records an
  optimizer-entry sentinel and makes peak-RSS collection portable.
- This checkpoint and the forthcoming after-task report.

The ignored immutable result root retains `root-receipt.rds`, `truth.rds`,
`mesh.rds`, `file-manifest.csv`, `time-estimate.md`, and
`observability-failure-receipt.md`. It deliberately contains no fit result.

## Commands run

- Fixture validation: `SPATIAL_ISDM_GATE_B_FIXTURE_VALIDATION_PASS (no fit)`.
- Immutable preflight at `87bec5a9...`: `SPATIAL_ISDM_GATE_B_PREFLIGHT_PASS`.
- One smoke command: failed with `Error in file(con, "r") : cannot open the connection`.
- Corrected-runner validation: `SPATIAL_ISDM_GATE_B_FIXTURE_VALIDATION_PASS (no fit)`.
- Failure-root integrity check: `HOLD_RECEIPT_INTEGRITY_PASS`.

## Next safest action

Do not rerun. Finish independent outcome adjudication, commit this receipt
repair and closeout records, and return `PRIVATE_SPATIAL_SMOKE_HOLD` for an
explicit maintainer decision. A future smoke requires a new approved Gate-B
attempt and a fresh immutable root.
