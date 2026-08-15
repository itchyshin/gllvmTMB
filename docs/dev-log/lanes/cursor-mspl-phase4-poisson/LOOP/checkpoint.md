# checkpoint — cursor-mspl-phase4-poisson

GOAL: see GOAL.md.   STATE: **A0–A3 LANDED** — docs+test PR #972 open.
HARD STOP: no admit, no merge-to-main.

ARCS DONE (verified):
- A0 — isolated worktree `/private/tmp/gllvmtmb-mspl-phase4-poisson` on
  `cursor/mspl-phase4-poisson` from `cursor/mspl-point-programme-continue`
  @ `43b928a4`. LOOP kit written.
- A1 — note + E1–E7 strengthened (P5 log-det identity, P6 all-zero
  kernel, trait-wise path, rate-transplant, prepare source pin).
- A2 — `test-mspl-poisson-phase4-oracles.R` **10 tests / 102
  expectations / 0 failed / 0 error**. Registry 26/26. `src/` and
  `R/mspl.R` diffs empty.
- A3 — commit `8f936953`; PR
  https://github.com/itchyshin/gllvmTMB/pull/972 stacked on #971.

ARC IN PROGRESS: none.

NEXT: human review of #972. Do not admit Poisson. Do not merge to main.

OPEN GATES (need human): review #972; admit Poisson; merge-to-main.
Neither admit nor merge is this lane's job.

TRUTH LIVES IN: `cursor/mspl-phase4-poisson` @ `8f936953` · PR #972 ·
this LOOP kit ·
`docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md` ·
`tests/testthat/test-mspl-poisson-phase4-oracles.R` ·
`docs/dev-log/after-task/2026-08-15-mspl-phase4-poisson.md`.

RESUME:
```text
You are cursor/mspl-phase4-poisson. Isolated worktree
/private/tmp/gllvmtmb-mspl-phase4-poisson. READ LOOP/GOAL.md then
checkpoint.md. GOAL landed as prep+PR #972 (102/102 oracle
expectations). HARD STOP: do not admit Poisson; do not merge to main.
```
