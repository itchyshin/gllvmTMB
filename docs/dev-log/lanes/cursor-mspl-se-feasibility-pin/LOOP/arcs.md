# Arcs — cursor-mspl-se-feasibility-pin

Status: `pending` | `in_progress` | `done` | `blocked`.
Overwrite `checkpoint.md` after every status change.

| id | status | gate | depends | work |
|---|---|---|---|---|
| A0 | done | — | — | LOOP kit under this folder. |
| A1 | done | — | A0 | Branch from tapes @ `0df6ab30`. #972–#976 untouched. |
| A2 | done | — | A1 | Teacher `2026-08-15-mspl-binary-se-teacher.md`. |
| A3 | done | — | A2 | Estimand pick: both Hessians. |
| A4 | done | — | A3 | Failing tests RED on missing pin. |
| A5 | done | — | A4 | `R/mspl-curvature-pin.R`. No `src/`. |
| A6 | done | — | A5 | Bernoulli 24 / Poisson 29 GREEN. |
| A7 | done | — | A6 | Rose PASS closeout. No admit. |
| A8 | done | open PR | A7 | #979 opened. |
| A9 | done | merge | — | #978 squash-merged `78f6d6b6`. |
| A10 | in_progress | merge | A8, A9 | Squash-merge #979 when CI green. |
| A11 | done | — | A7 | Morning brief written. |
