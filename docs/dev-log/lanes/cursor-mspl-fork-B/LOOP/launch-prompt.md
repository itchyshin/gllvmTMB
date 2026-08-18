# Launch / resume prompt — paste into a FRESH Cursor chat opened in the worktree

```
cd "/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-forkB-goal"
```

---

## COLD START (first run)

```markdown
/goal

Ultra-plan G0 approved. Run this plan to completion via LOOP/.

LANE: cursor-mspl-fork-B   (Design 125 fork B — G0 SIGNED 2026-08-18)
BRANCH: cursor/mspl-fork-B-goal-kit
WORKTREE: ~/local-scratch/lanes/gllvmTMB-mspl-forkB-goal
KIT: docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/

READ FIRST, IN ORDER:
  docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/GOAL.md
  docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/checkpoint.md
  docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/ultra-plan.md
  ./AGENTS.md

RUN the goal skill (Cursor arc-loop adapter): re-read GOAL at the top of EVERY arc; verify by
reading the LOG and the returned OBJECT, never the exit code; stay a lean conductor and delegate
heavy reads/edits; pause at every OPEN GATE; overwrite checkpoint.md after every arc and commit it;
recommend a fresh chat at the A5 batch barrier.

START ARC: A0.
NEXT GATE: A3 (L0 verdict). HARD GATE: L2 and every Totoro/DRAC gate — needs Shinichi G0.

FILE FENCE (non-negotiable): this lane writes docs only. R/, src/, tests/ and
docs/dev-log/decisions.md belong to lane L0 (cursor/g0-unlock-design125-forkB), which is live and
uncommitted on them. If an arc cannot proceed without touching them, STOP and surface — lane
ownership is Shinichi's call, not the loop's.
```

---

## RESUME (later sitting or after a fresh chat)

```markdown
/goal

You are cursor-mspl-fork-B, resuming the Design 125 fork B goal loop. RESUME — do NOT cold start,
and do NOT redo landed work.

WORKSPACE: reattach ~/local-scratch/lanes/gllvmTMB-mspl-forkB-goal on cursor/mspl-fork-B-goal-kit
and pull. Do NOT recreate the worktree.

READ FIRST: LOOP/GOAL.md -> LOOP/checkpoint.md -> LOOP/ultra-plan.md -> ./AGENTS.md
  (kit path: docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/)

CONTINUE FROM: the NEXT line in checkpoint.md.
PAUSE AT: the first OPEN GATE named in checkpoint.md.
PROHIBITED: redoing any arc marked done in LOOP/arcs.md; editing R/, src/, tests/ or
decisions.md; any Totoro/DRAC compute; undrafting #1077; public se/vcov/confint; flipping MSPL-04.
```
