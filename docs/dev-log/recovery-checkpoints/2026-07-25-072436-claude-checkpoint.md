# Recovery checkpoint — 2026-07-25 07:24:36 (Claude)

Written on rehydration from
`docs/dev-log/handover/2026-07-25-active-lane-split.md`, **before any edit**, per
AGENTS.md "Recovery Checkpoints" and the profile/Tier-2a resume boundary in
`docs/dev-log/handover/2026-07-25-claude-handover.md`. This is a state record,
not a capability or release claim.

## Why this checkpoint exists

A fresh Claude session was resumed with the standard lane-split prompt. The
human lane choice was **neither lane yet** — first resolve the stale
`CLAUDE.md`. Nothing in the profile/Tier-2a lane has been mutated, reset, or
cleaned. No Codex lane was touched.

## Current branch and status

Branch: `claude/profile-coverage-remeasure-20260718` @ `6fcf0998`
(tracking `origin/claude/profile-coverage-remeasure-20260718`).
Divergence from `origin/main`: **141 behind, 52 ahead**.

```
 M docs/dev-log/check-log.md
 M docs/dev-log/handover/2026-07-18-claude-handover-profile-route.md
?? .claude/
?? dev/phylo-multinomial-harness-DRAFT.R
?? docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md
?? docs/dev-log/2026-07-22-quadrature-regime-trap-and-the-correlation-boundary-gap.md
?? docs/dev-log/after-task/2026-07-17-tier2a-s0-planning-and-codemap.md
?? docs/dev-log/handover/2026-07-17-claude-handover-tier2-phylo-multinomial.md
?? docs/dev-log/handover/2026-07-17-tier2a-S2-codex-build-brief-DRAFT.md
?? docs/dev-log/handover/2026-07-17-tier2a-inflight-S0-done.md
?? tests/testthat/_snaps/plot-visual-snapshots/dispatcher-communality-stacked-bars-plot.new.svg
?? tests/testthat/_snaps/plot-visual-snapshots/dispatcher-variance-partition-plot.new.svg
```

## Changed files (tracked)

```
 docs/dev-log/check-log.md                                   | 303 +++++++++++++
 .../2026-07-18-claude-handover-profile-route.md              |  21 ++
 2 files changed, 324 insertions(+)
```

Both diffs are **dev-log prose only** — no R, C++, test, or DESCRIPTION change
is pending in this lane. The two `.new.svg` files are unreviewed plot-snapshot
candidates from a prior session, not accepted snapshots.

These 12 paths are the CARRIED-OVER state named in the 2026-07-25 handover.
They are local-only and must be resumed **only** in this checkout.

## Commands already run, with exact outcomes

| Command | Outcome |
| --- | --- |
| `git status --short --branch` | as above; 2 modified, 10 untracked |
| `git worktree list` | 27 worktrees; all 5 lane-relevant directories confirmed to **exist** on disk (git labels 4 legacy ones `prunable`) |
| `git branch -a --contains 9825f743` | `handover/2026-07-25-claude` + its origin ref only |
| `git show 9825f743:...active-lane-split.md` | read the lane map without switching branches |
| `git show 9825f743:...2026-07-25-claude-handover.md` | read the Claude handover |
| `gh pr list --state open --limit 20` | **exactly one** open PR: #786, `handover/2026-07-25-claude` |
| `gh pr view 786 --json ...` | base `main`, `MERGEABLE` / `CLEAN`, 3 files: `CLAUDE.md` + the two 07-25 handovers |
| `git show origin/main:CLAUDE.md \| sed -n 1,10p` | `main` carries the **2026-07-21** single-lane snapshot |
| `git diff --quiet origin/main -- CLAUDE.md` | DIFFERENT — this checkout is not even at `main`'s version |
| `git diff --quiet 9825f743^ -- CLAUDE.md` | DIFFERENT — this checkout predates the 07-21 snapshot too |
| `git log --all --oneline --since="6 hours ago"` | `9825f743` (the CLAUDE.md edit) + `fe8388d9` (merge of #785) |

No test, check, build, or simulation command was run. No compute was dispatched
to Totoro or DRAC.

## The finding

`CLAUDE.md` is stale on **two independent surfaces**, and they need different fixes:

1. **`origin/main`** carries the 2026-07-21 *single active lane* snapshot
   (pointing at `codex/gllvmtmb-060-m1-baseline-20260720`, draft PR #778).
   Fixed by merging PR #786.
2. **This checkout / this branch** carries the older **2026-07-19** version,
   whose banner reads *"the 0.6-finishing core arc moves to Codex (SAME repo)"*
   and directs every new session to one `START HERE`. Merging #786 into `main`
   does **not** fix this, because this branch is 141 commits behind `main`.

Surface 2 is the one that actually misdirected this session: the working-tree
`CLAUDE.md` is what gets loaded at session start in this checkout. It tells a
fresh Claude that the repo belongs to Codex — the precise failure the lane-split
note forbids ("Do not collapse the lane split back to a single `START HERE`
pointer").

## Why Claude did not fix it

Both available routes terminate in a human act:

- **Merging PR #786** is excluded by the 2026-07-25 handover's own mission-control
  row: *"human review/merge only; do not auto-merge."*
- **Editing `CLAUDE.md` in this checkout** trips the AGENTS.md
  "Pre-edit lane check": `gh pr list --state open` returns PR #786, which
  modifies `CLAUDE.md`, and `git log --all --since="6 hours ago"` shows that
  edit landed inside the window. AGENTS.md's instruction on a detected
  collision is explicit — *"post a coordination comment and wait"* — not edit.
  A second, divergent edit of the same `CLAUDE.md` snapshot block is exactly
  the parallel-edit double-ship the rule was written to stop (2026-05-11).

## Commands that still need to run

None by Claude. The two resolving acts are Shinichi's:

```sh
gh pr merge 786 --squash            # fixes surface 1 (main)
```

Surface 2 then needs a deliberate decision for the profile branch — either
bring `main` into it, or cherry-pick just the `CLAUDE.md` snapshot block:

```sh
cd '/Users/z3437171/Dropbox/Github Local/gllvmTMB'
git merge origin/main               # after #786 lands; expect conflicts (141 behind)
```

Neither was run. The merge is **not** a safe unattended act in a dirty
checkout 141 commits behind, and it is not authorised by any lane boundary.

## Next safest action

Await the lane decision. Do not switch, reset, clean, stash, or merge in this
checkout. Do not touch `/private/tmp/gllvmtmb-design100-progress-oracle`
(Codex eta simulation) or the Design-103 worktree.

## Blocking question for the maintainer

Merge PR #786 to fix `main`, and then say explicitly how the profile/Tier-2a
branch should pick up the lane split — merge `main` in (conflict-prone, 141
commits), or leave the branch stale and rely on the lane-split note being read
first? Until one of those happens, any fresh session started in this checkout
will read the superseded "moves to Codex" banner again.
