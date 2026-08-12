# After Task: Private spatial iSDM Gate-B smoke

**Branch:** `codex/isdm-spatial-information-design`
**Date:** `2026-08-12`
**Status:** `PRIVATE_SPATIAL_SMOKE_HOLD`

## 1. Goal

Prepare one immutable, seed-pinned smallest-admissible spatial fixture, estimate
its local runtime, and run exactly one local smoke only if the estimate was at
most 30 minutes. Retain all attempt evidence and return a private verdict.

## 2. Implemented

The committed fixture at `87bec5a9` attempted Paper 1 `S=3`, `C=360`, `r=3`,
rank one, 4,320 long rows, and a 118-node shared mesh. Its ecological and
GBIF-only fields shared DGP range 0.22; the fit map remains the approved
intercept plus `isdm_gbif` slope architecture with a nonspatial diagonal Psi
companion. The immutable root records fixture/runner hashes, truth, mesh, and
source map.

The pre-run estimate was 12–20 minutes (30-minute stop). One local smoke was
launched. It failed operationally in 16.313 seconds when the runner read
Linux-only `/proc/self/status` after the fit call and before persistence. No
fit or all-attempt ledger was written. This is a retained observability failure,
not a scientific numerical result; it forces HOLD. Independent technical review
also found that its DGP correlation 0.25 violates the fitted engine's
independent intercept/slope field columns, so it could not support recovery
even if telemetry had persisted. No rerun occurred.

## 4. Files Touched

- `dev/isdm-package-recovery/spatial-isdm-gate-b-smoke-fixture.R` — seed-pinned
  DGP, truth, and mesh-alignment validator.
- `dev/isdm-package-recovery/run-spatial-isdm-gate-b-smoke.R` — immutable root,
  one-smoke runner, and portable receipt hardening.
- Ignored result root `dev/isdm-package-recovery/results/spatial-isdm-gate-b-smoke-20260812-r2/` — retained immutable preflight and failure receipt.
- This report and the recovery checkpoint.

No public API, docs, pkgdown, article, empirical input, protected G2/Paper 2
record, likelihood/DGP/map/threshold change, separate mesh/range/rank, or
campaign surface changed.

## 3a. Decisions and Rejected Alternatives

- **Decision:** classify the outcome HOLD. **Rationale:** required all-attempt
  numerical/field receipt is absent and cannot be reconstructed. **Rejected
  alternative:** treating the short wall time as a successful fit. **Confidence:** high.
- **Decision:** do not rerun. **Rationale:** Gate B authorised exactly one
  smoke. **Rejected alternative:** repeat after the portable-RSS repair.
  **Confidence:** high.

## 5. Checks Run

- Fixture validation — PASS, no fit.
- Immutable preflight — PASS; receipt confirms seed 86201, 4,320 rows, 118 mesh nodes and source map.
- One smoke — failed after 16.313 seconds with an `/proc` read error before receipt persistence.
- Corrected runner validation — PASS, no fit.
- Failure-root integrity — PASS; immutable root has the preflight and failure receipt but no `fit.rds` or all-attempt ledger.
- `git diff --check` — PASS.

## 6. Tests of the Tests

The fixture validation is a feature-combination check for source-pure PA rows,
GBIF-only B values, three visits, truth dimensions, and mesh alignment. The
runner hardening is tested only through its no-fit validation path; it is not
evidence from another smoke.

## 8. Consistency Audit

`find ...spatial-isdm-gate-b-smoke-20260812-r2` showed the retained root
contains the immutable preflight files and `observability-failure-receipt.md`,
but no fit output. This supports only the operational HOLD.

## 7. Roadmap Tick

N/A — private evidence only.

## 9. What Did Not Go Smoothly

The first runner implementation made a macOS-incompatible Linux `/proc`
assumption after optimizer return. This destroyed observability for the one
authorised attempt, even though its wall time was retained by the execution
wrapper. Independent review also caught the DGP correlation mismatch and that
the runner rebuilt rather than checked the saved mesh. The portable-RSS,
entry-sentinel, independent-field, and receipt-comparison repairs are
preventative only.

## 11. Team Learning

Gauss/Noether technical review and Rose/Fisher outcome adjudication both
returned HOLD. The reusable lesson is that a campaign runner must write its
attempt-started sentinel before a fit, reject an already-consumed root, bind
all preflight inputs in the manifest, and use platform-safe telemetry; absent
all-attempt persistence is a hard operational HOLD, not permission to retry.

## 10. Known Residuals

No objective, convergence code, gradient, Hessian, boundary flag, field map,
or recovery metric is observable. Hence there is no numerical-admission,
source-purity, ecological-field, GBIF-bias-field, or performance conclusion.
The only justified result is `PRIVATE_SPATIAL_SMOKE_HOLD`.

Do not open a recovery campaign or `C=1,000`. A new smoke requires explicit
approval, a fresh root, independent-field DGP, and corrected runner. G2/Paper
2 HOLDs remain historical and unchanged.

## 7a. Issue Ledger

No issue was changed or created. This private observability HOLD does not
resolve #904, #941, #945, or #946 and is retained on disk rather than promoted
as package capability work.

## 12. Cross-Product Coverage

The only executed combination was private Paper 1 `S=3`, `C=360`, `r=3`, rank
one, shared-range two-field spatial iSDM, one local attempt. It does NOT cover
recovery, scale, REML, penalties, alternative engines, missing-data routes,
aggregation, Paper 2, `C=1,000`, empirical inputs, or any public product cell.
