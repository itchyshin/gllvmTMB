# checkpoint — cursor-mspl-phase4-nbinom1

GOAL: see GOAL.md.   STATE: **A0–A3 LANDED** — stacked PR #976; do not merge.

ARCS DONE (verified):
- A0 — LOOP kit under `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
- A1 — initial note + oracles copied from sibling; superseded by R1 review repair.
- A2 — initial 68-oracle run; superseded by R1.
- A3 — commit `753c1acb`; PR https://github.com/itchyshin/gllvmTMB/pull/976 stacked on #971.
- R1 — exact NB1 Fisher information summed from the `size = mu / phi`
  pmf; quasi \(W=\mu/(1+\varphi)\) explicitly non-Jeffreys; success
  probability corrected to \(1/(1+\varphi)\);
  `test-mspl-nbinom1-phase4-oracles.R` **74/74 PASS** (14 blocks).

ARC IN PROGRESS: none (merge is human).

NEXT: Shinichi review/merge after #971. Do **not** add a registry row. Do **not** admit nbinom1.

OPEN GATES (need human): merge of #976 (not this lane).

TRUTH LIVES IN: `cursor/mspl-phase4-nbinom1` · WT `/private/tmp/gllvmtmb-mspl-phase4-nbinom1` · PR #976.

RESUME:
```text
nbinom1 Phase-4 exact-information review repaired and verified 74/74
on PR #976. HARD STOP: registry row, prepare widen, R/mspl.R, src/,
admit, merge.
```
