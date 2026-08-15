# checkpoint — cursor-mspl-phase4-nbinom1

GOAL: see GOAL.md.   STATE: **A0–A3 LANDED** — stacked PR #976; do not merge.

ARCS DONE (verified):
- A0 — LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
- A1 — note + oracles `cmp`-identical to sibling shared-worktree files.
- A2 — `test-mspl-nbinom1-phase4-oracles.R` **68/68 PASS** (14 blocks; see `arcs.md`). Registry file untouched (26). `git diff -- src/ R/mspl.R R/mspl-registry.R` empty.
- A3 — commit `753c1acb`; PR https://github.com/itchyshin/gllvmTMB/pull/976 stacked on #971.

ARC IN PROGRESS: none (merge is human).

NEXT: Shinichi review/merge after #971. Do **not** add a registry row. Do **not** admit nbinom1.

OPEN GATES (need human): merge of #976 (not this lane).

TRUTH LIVES IN: `cursor/mspl-phase4-nbinom1` · WT `/private/tmp/gllvmtmb-mspl-phase4-nbinom1` · PR #976.

RESUME:
```text
nbinom1 Phase-4 prep copied and verified 68/68 on PR #976. HARD STOP:
rewrite science, registry row, prepare widen, R/mspl.R, src/, admit, merge.
```
