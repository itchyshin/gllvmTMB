# Codex Recovery Checkpoint — 0.6 P0 / M1 Entry

**Timestamp**: 2026-07-20 12:38:22 MDT

**Platform**: Codex

**Continuing from**: Shinichi / newest committed handovers plus the approved
five-macro plan

**Hands to**: none; Codex remains the sole programme owner

## Repository State

```text
BUILDER_BRANCH = codex/gllvmtmb-060-m1-baseline-20260720
SOURCE_SHA = de211f762812c574646938adaca22cbf41c6175e
BUILDER = /private/tmp/gllvmtmb-060-m1-builder (clean at creation)
VERIFIER = /private/tmp/gllvmtmb-060-m1-verifier (detached, clean)
PRIMARY_CHECKOUT = quarantined; do not mutate
HISTORICAL_WORKTREES = 36; parked; do not mutate
OPEN_PRS = 0
ACTIVE_WRITER = Codex builder only
OVERLAP = none by construction
```

The old primary checkout is on `claude/profile-coverage-remeasure-20260718`,
52 commits ahead and 45 behind the pre-fetch remote-tracking main, with modified
shared dev-log files and untracked prior-session material. No switch, stash,
clean, prune, rebase, or merge was performed there.

## Evidence State

- Fresh fetch confirmed `origin/main` at `de211f762812c574646938adaca22cbf41c6175e`.
- Fast R-CMD-check and pkgdown evidence is green at that SHA.
- The latest scheduled-heavy receipt, run `29729444717` at `ff045a38`, is red
  with 46 failures/errors; eight consecutive nightly heavy runs are red.
- The parked repair commit `0f1ef2bc` must not be cherry-picked wholesale.
  Independently reviewed expectation repairs may be transplanted selectively.
- Mission Control was updated and committed in the local-only brain vault as
  `44b8764`; its claim guard says not release-ready and EVA not admitted.

## Compute Preflight

Existing SSH ControlMaster sockets were observed for Totoro and the requested
DRAC CPU fleet (Fir, Nibi, Rorqual, Trillium, Narval). No SSH connection, remote
inventory command, compilation, simulation, or job submission was performed.
Cluster selection, account/module/resource discovery, Totoro smoke, and DRAC
pilot remain behind their explicit maintainer gates.

## Commands Already Run

```sh
git fetch origin main --prune
git worktree add -b codex/gllvmtmb-060-m1-baseline-20260720 /private/tmp/gllvmtmb-060-m1-builder origin/main
git worktree add --detach /private/tmp/gllvmtmb-060-m1-verifier origin/main
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
```

## Next Safest Action

Commit this checkpoint and the after-task skeleton as the branch's first commit.
Then reproduce the current-main heavy suite from the clean builder before
changing tests. Do not start Design 86 or remote compute.

## Blocking Question

None for M1. Separate maintainer approval remains required at the named compute,
scientific-admission, public-feature, freeze, tag, submission, and claim gates.
