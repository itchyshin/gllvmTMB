# checkpoint — cursor-mspl-phase4-beta

GOAL: see GOAL.md.   STATE: **B0–B3 landed** — planned-only Beta
Phase-4 prep; awaiting human review of the PR.

ARCS DONE (verified):
- B0 — isolated worktree + LOOP kit.
- B1 — research note copied unchanged from the shared worktree
  (`docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md`).
- B2 — oracles copied unchanged; re-run
  `test-mspl-beta-phase4-oracles.R` **PASS 65/65**
  (10 `test_that` blocks; E1–E9 + no-live-fit fence).
- B3 — after-task + PR (this closeout).

ARC IN PROGRESS: none (merge is human).

NEXT: Shinichi review/merge when CI green. Do **not** admit Beta.
Do **not** land registry rows from this lane without a coordination
PR. Poisson admission remains a separate HARD STOP.

OPEN GATES (need human): merge this PR; any later `planned` registry
row for `beta:logit:ordinary:q1/q2`; any tape / prepare widen.

TRUTH LIVES IN: `cursor/mspl-phase4-beta` · worktree
`/private/tmp/gllvmtmb-mspl-phase4-beta` · LOOP this kit.

RESUME:
```text
Read docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/GOAL.md then
checkpoint.md. Planned-only Beta Phase-4 prep is landed. Do not
admit Beta. Do not transplant Bernoulli/Poisson/Gaussian atoms.
Do not edit R/mspl.R, src/, or the shared registry from this lane.
```
