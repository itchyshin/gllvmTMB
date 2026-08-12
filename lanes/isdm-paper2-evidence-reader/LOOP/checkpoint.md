# Checkpoint — A4 safeguards closed; S = 6 local pre-run is HOLD

**Branch:** `codex/isdm-paper2-evidence-reader-a0`
**Base commit:** `0f668c469228f1799a989e112176fd931f2f88a8`
**Date:** 2026-08-12

## Completed

- A0: reconciled the exact G2o state and created this lane-local durable loop.
- A1: wrote the cited, non-ranking model-choice map.
- A2: froze the Case-C estimator/Psi information, recovery, and measured-scale
  protocol.
- Arc 1: created the scoped third-party NotebookLM record
  `d83800ea-9ba3-43d2-8cd2-b7d2ace30563` and filed a bounded source synthesis.
- Arc 2: independently concluded that Case C remains `NO_CANDIDATE` and froze
  the S = 6, 20, 60 Psi-information design.
- Arc 3: froze the A4 no-fit acceptance matrix; it specifies future tests but
  does not create or run them.
- A4 safeguards: committed pure-logic Case-C non-entry/Case-B isolation tests
  at `c7aa1f2c`; focused A4, G2n, and G2m tests passed.
- One authorised S = 6 seed `86122` attempt at `57613984` completed in
  448.155 seconds with verified closure. It is Case C / `NO_CANDIDATE` due to
  raw `b_fix` gradient 0.002726537; Psi variance error 0.2156398 also exceeds
  the frozen 0.20 threshold, with weak lower profiles for sp2/sp5/sp6. It is
  a one-attempt private HOLD, not eligible for rerun or reader promotion.

## Do not resume by running

No additional fit, implementation, simulation, profile, or local/remote
compute is authorized. The next safe action is explicit approval for the next
evidence decision; it must not rerun this seed, reclassify Case C, or alter the
model. Any later new run still needs a time estimate and, if expected to exceed
30 minutes, a pre-run test followed by renewed approval.

## Held evidence

`G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD` remain unchanged.  This lane does not alter their
thresholds, denominators, DGP, or interpretation.
