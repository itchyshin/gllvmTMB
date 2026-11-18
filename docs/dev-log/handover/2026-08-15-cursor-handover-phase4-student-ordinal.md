# Cursor handover — MSPL Student-t + ordinal Phase-4 prep

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-student-ordinal`
**Worktree:** `/tmp/gllvmtmb-mspl-student-ordinal`
**Base:** `origin/main` @ `fe867e40`

## What landed

Planned-only LA-MSPL Phase-4 prep for **Student-t (identity)** and
**`ordinal_probit`**. Board status **na → planned prep**. Not
admitted. No registry row. No public door. No NEWS covered.
`se=FALSE`.

- Notes:
  `docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md`
  `docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md`
- Oracles: student **51/51**, ordinal **45/45** (RED then GREEN).
- LOOP: `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`

## Do not do next

- Do not add a `student` or `ordinal_probit` registry row.
- Do not widen `.gllvmTMB_mspl_prepare()`.
- Do not tape C++. Do not call `estimator="mspl"` on either family.
- Do not write NEWS covered. Do not implement public `se=TRUE`.
- Do not merge this DRAFT PR from the lane.
- Do not use `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

## START HERE

`docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/GOAL.md`,
then the after-task
`docs/dev-log/after-task/2026-08-15-mspl-phase4-student-ordinal-prep.md`.

**PROTECTED:** `codex/lane-b-mspl-interval-feasibility`.
