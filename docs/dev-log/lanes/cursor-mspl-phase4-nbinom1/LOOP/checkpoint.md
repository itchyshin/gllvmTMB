# checkpoint — cursor-mspl-phase4-nbinom1

GOAL: see GOAL.md.   STATE: **A0–A2 LANDED** (68/68 oracles). A3 = commit/push/PR.

ARCS DONE (verified):
- A0 — LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
- A1 — note + oracles `cmp`-identical to sibling shared-worktree files.
- A2 — `test-mspl-nbinom1-phase4-oracles.R` **68/68 PASS** (14 blocks; see `arcs.md`). Registry file untouched (26). `git diff -- src/ R/mspl.R R/mspl-registry.R` empty.

ARC IN PROGRESS: A3 — explicit-path commit + push + stacked PR on #971.

NEXT: do not merge. Do not add a registry row.

OPEN GATES (need human): merge of this PR (not this lane).

TRUTH LIVES IN: `cursor/mspl-phase4-nbinom1` · WT `/private/tmp/gllvmtmb-mspl-phase4-nbinom1`.

RESUME:
```text
nbinom1 Phase-4 prep copied and verified 68/68. HARD STOP: rewrite
science, registry row, prepare widen, R/mspl.R, src/, admit, merge.
```
