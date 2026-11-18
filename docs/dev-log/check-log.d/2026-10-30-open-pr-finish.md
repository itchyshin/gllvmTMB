# Check-log: open PR finish campaign

**Goal:** Confirm which open PRs could take a main merge, which were
already landed, and that no campaign commit touched `src/gllvmTMB.cpp`.

**Commands:**

    git fetch origin main
    git rev-parse origin/main
    gh pr list --state open --limit 50
    git rev-list --count origin/main..origin/<branch>
    git rev-list --count origin/<branch>..origin/main
    rg -n "gllvmTMB_tweedie_negative_y|tweedie_rows" R/fit-multi.R
    git grep -n "^<<<<<<<" -- NEWS.md R tests man  # in each worktree after merge
    git worktree add + git merge origin/main  # no rebase, no force-push

**Results:**

- `origin/main` at `80b0129f`.
- #1687 superseded: `tweedie_rows` already on main; #1356 closed by #1689.
- Merge clean: #1700, #1695, #1698, #1644, #1070.
- NEWS-only conflict, both sides kept: #1692, #1615.
- Parked (no merge): #1506, #981 (`src/`), #1283 (`codex/`), #1065 (C++ follow-on).
- Leftover conflict markers after resolution: none in NEWS / R / tests / man.
- Local package tests: not run (R 4.3.3 installed late; no TMB compile).
- New CI on the pushed heads is the suite evidence.

**Claim boundary:** This log records merge hygiene and the #1687
supersede finding. It does not claim the new CI is green, does not
close any `Closes #N` issue, and does not change package defaults.
