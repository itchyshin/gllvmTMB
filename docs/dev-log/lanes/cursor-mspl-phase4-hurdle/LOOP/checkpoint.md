GOAL: see GOAL.md.   STATE: **GOAL LANDED** — planned-only hurdle prep; oracles PASS 66; draft PR [#1004](https://github.com/itchyshin/gllvmTMB/pull/1004).

ARCS DONE (verified):
- A0 — LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/`.
- A1 — research note
  `docs/dev-log/research/2026-08-15-mspl-phase4-hurdle-prep.md`.
- A2 — oracles PASS **66**
  (`E1 8, E2 7, E3 6, E4 4, E5 5, E6 2, E7 6, E8 3, E9 5, E10 17, no-live 3`).
  Registry PASS 35. Gaussian heywood PASS 75. Poisson oracles PASS 42.
  Fenced tapes PASS 23. `src/` / `R/mspl.R` / NEWS empty diff.
- A3 — commit `26a62110`; draft PR https://github.com/itchyshin/gllvmTMB/pull/1004

ARC IN PROGRESS: none (merge is human).

NEXT: Shinichi review/merge of #1004. HARD STOP = admit / prepare widen / NEWS covered.

OPEN GATES (need human): merge draft PR; do not admit hurdle; do not widen prepare.

TRUTH LIVES IN: `cursor/mspl-phase4-hurdle` · PR https://github.com/itchyshin/gllvmTMB/pull/1004 · worktree `/tmp/gllvmtmb-mspl-hurdle` · this LOOP kit.

RESUME (post-merge / new work):
```text
GOAL for cursor/mspl-phase4-hurdle is landed (planned rows + oracles).
HARD STOP: prepare widen, registry admit, NEWS covered,
live estimator=mspl on delta_*, src/, se=TRUE.
```
