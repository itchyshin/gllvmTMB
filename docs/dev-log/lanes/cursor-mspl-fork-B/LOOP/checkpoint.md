# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **kit written, committed, and pushed; docs PR #1127 open. Campaign execution belongs to the
three sibling lanes and has not been claimed from here.**

- **ARCS DONE (verified):**
  - **A3** — docs staleness hygiene. Verified by PR state: [#1100](https://github.com/itchyshin/gllvmTMB/pull/1100) CLOSED, [#1124](https://github.com/itchyshin/gllvmTMB/pull/1124) MERGED.
  - **A6 (first half)** — this kit exists in a ref, not just on disk. Verified by `git log` on
    `cursor/mspl-fork-B-goal-kit` and by reading the six kit files back from
    `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`. PR [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) is **open**.
- **ARC IN PROGRESS:** **A2** — the 2026-08-18 G0 entry is written but **still uncommitted**, on
  `cursor/g0-unlock-design125-forkB`. It has to land on `cursor/mspl-forkB-decision` or be merged
  from where it sits; until then the signed decision lives only in a dirty worktree.
- **NEXT:** **A1** (Design 125 + ADEMP amendment note) and **A2** on the decision lane, then **A4a**
  on the L0 lane. Nothing on this list is executed from this docs kit.
- **OPEN GATES (need a human):**
  1. **L2 and every Totoro / DRAC gate** — blocked, needs Shinichi G0. Never auto-start.
  2. **Merge of PR #1127** and of any sibling PR — merge is a human gate.
  3. **T\* thresholds · undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off
     `blocked`** — hard OUT, not questions.
- **WHERE TRUTH LIVES:**
  - this kit: `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/` on `cursor/mspl-fork-B-goal-kit` @
    `~/local-scratch/lanes/gllvmTMB-mspl-forkB-goal` (PR #1127)
  - siblings: `cursor/mspl-forkB-decision` · `cursor/mspl-forkB-l0-20260818` ·
    `cursor/mspl-forkB-l1-smoke-20260818`
  - the G0: `docs/dev-log/decisions.md`, 2026-08-18 entry — **uncommitted** on
    `cursor/g0-unlock-design125-forkB`, which also carries the live `R/mspl.R` selector work
  - the construction: `docs/design/125-mspl-profile-led-intervals.md`
  - the gates: `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P5
  - repo-root `LOOP/`: the **closed** Poisson \(W_*\) REPLACE `GOAL_MET` record — do not read it as
    this lane's goal, do not overwrite it
- **RESUME:** paste the block in `LOOP/launch-prompt.md` into a fresh Cursor chat. Reattach the
  worktree and pull — do **not** recreate it, and do **not** re-scaffold the kit.
