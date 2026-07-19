# Shannon coordination audit — Gaussian REML certificate

**Date:** 2026-07-19  
**Auditor:** Shannon (read-only coordination gate)  
**Subject branch:** `codex/gaussian-reml-certificate-20260719` at `9ec6520a`  
**Draft PR:** [#767](https://github.com/itchyshin/gllvmTMB/pull/767)

## Verdict: FAIL — do not merge or rebase this worktree

The isolated worktree is clean and its branch is pushed.  The statistical
certificate has correctly been withheld: the predeclared profile-screen gate
did not admit either target to the 500-profile or 15,000-replicate stages.
That result is recorded in the Rose, D-43, after-task, and handover records.

The draft PR is nevertheless not mergeable.  At this audit, GitHub reports it
as `CONFLICTING` / `DIRTY` with no branch check run.  `origin/main` has moved to
`ab3098e4` since the immutable baseline used to start the isolated lane.
Merge-tree inspection shows conflicts in shared developer-log material,
including the explicitly protected `docs/dev-log/check-log.md`, alongside
the Bartlett and other active-lane history.  The PR file inventory also
contains historical baseline material that is outside this slice.

Resolving those conflicts here would violate the lane boundary: this arc must
not edit `check-log.md`, Bartlett material, CI-11, multinom/tier-2a, or Ayumi.
No rebase, conflict resolution, or merge was attempted.

## Required next ownership decision

A maintainer-approved fresh worktree based on the then-current `origin/main`
must reconstruct a focused patch, reviewing each intended file against main
rather than indiscriminately cherry-picking this branch.  It must exclude all
protected developer-log and historical-coverage material.  Only after that
reconciliation can a clean PR receive the usual checks and be considered for
landing.

Until then, the valid outcome is **WITHHELD / not release-ready**, not a
Gaussian-REML capability promotion.  The parked lanes remain untouched.
