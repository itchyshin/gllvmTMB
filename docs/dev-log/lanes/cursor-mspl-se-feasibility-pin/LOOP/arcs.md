# Arcs — cursor-mspl-se-feasibility-pin

Status: `pending` | `in_progress` | `done` | `blocked`.
Overwrite `checkpoint.md` after every status change.

| id | status | gate | depends | work |
|---|---|---|---|---|
| A0 | pending | — | — | Write LOOP kit under this folder. Never repo-root `LOOP/`. |
| A1 | pending | — | A0 | Shannon snapshot. Branch `cursor/mspl-se-feasibility-pin` from tapes tip while #978 is open. Do not merge #972–#976. |
| A2 | pending | — | A1 | Read-only Codex teacher via `git -C`. Write `docs/dev-log/research/2026-08-15-mspl-binary-se-teacher.md`. |
| A3 | pending | — | A2 | Estimand pick `docs/dev-log/research/2026-08-15-mspl-se-estimand-pick.md`. Locked: both Hessians. |
| A4 | pending | — | A3 | Failing tests `test-mspl-bernoulli-se-feasibility.R` and `test-mspl-poisson-se-feasibility.R`. Verify RED. |
| A5 | pending | — | A4 | Implement internal pin only. No `src/`. No Codex helper paste. No `fit-multi.R` withholding edit. |
| A6 | pending | — | A5 | Targeted tests GREEN, or checkpoint the exact RED. `OMP_NUM_THREADS=1`. |
| A7 | pending | — | A6 | Rose fence + after-task + plan-actual + check-log + lane-split + checkpoint. No admit. |
| A8 | pending | open PR | A7 | Open SE-pin PR. |
| A9 | pending | merge | — | Squash-merge #978 when CI green. |
| A10 | pending | merge | A8, A9 | Squash-merge SE-pin PR when CI green. |
| A11 | pending | — | A7 | Morning brief `docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md`. |

A9 may complete before A8 if #978 CI finishes first.
