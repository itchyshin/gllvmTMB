# Checkpoint — A0–A3 / Arc 0–3 closed; Gate B approval required

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

## Do not resume by running

No fit, implementation, simulation, profile, or local/remote compute is
authorized. The next safe action is Gate B: obtain explicit approval to
implement only the no-fit A4 contract, stop, or return to design. Any later
run still needs a time estimate and, if expected to exceed 30 minutes, a
pre-run test followed by renewed approval.

## Held evidence

`G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD` remain unchanged.  This lane does not alter their
thresholds, denominators, DGP, or interpretation.
