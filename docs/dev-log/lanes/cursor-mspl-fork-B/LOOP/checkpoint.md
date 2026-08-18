# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **kit scaffolded and committed; execution NOT started.**

- **ARCS DONE (verified):** none. The kit itself is not an arc — it is the plan the arcs run from.
  Verified by `git log` on `cursor/mspl-fork-B-goal-kit` showing the kit commit, and by reading the
  four files back from `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`.
- **ARC IN PROGRESS:** none.
- **NEXT:** **A0** — reattach the lane, read `GOAL → checkpoint → ultra-plan → AGENTS.md`, and
  confirm the state of lane **L0** (`cursor/g0-unlock-design125-forkB`) *without editing its files*.
  Then **A1**, the L0 plumbing verification.
- **OPEN GATES (need a human):**
  1. **L2 and every Totoro/DRAC gate** — blocked, needs Shinichi G0. Never auto-start.
  2. **push / merge of the docs PR** — denied by lane settings by design.
  3. **L0 overlap with lane L0** — if A1/A2 cannot proceed without touching `R/` or `tests/`,
     that is a lane-ownership question and it is **Shinichi's call** (D-87), not this loop's.
- **WHERE TRUTH LIVES:**
  - branch `cursor/mspl-fork-B-goal-kit` @ `~/local-scratch/lanes/gllvmTMB-mspl-forkB-goal`
    (base `origin/main` @ `25cfa0b7`)
  - the kit: `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`
  - the G0: `docs/dev-log/decisions.md`, 2026-08-18 entry — **currently uncommitted on lane L0's
    branch**, `cursor/g0-unlock-design125-forkB`
  - the construction: `docs/design/125-mspl-profile-led-intervals.md`
  - the gates: `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P5
- **RESUME:** paste the block in `LOOP/launch-prompt.md` into a fresh Cursor chat opened in the
  worktree. Do **not** recreate the worktree; reattach and pull.
