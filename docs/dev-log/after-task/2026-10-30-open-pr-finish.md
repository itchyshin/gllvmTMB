# After Task: finish open PRs (merge main, no merge to main)

**Branch**: `cursor/pr-finish-campaign-4127`
**Date**: `2026-10-30`
**Roles (engaged)**: Shannon, Rose, Grace

## 1. Goal

Rebase (merge main, no force-push) the open PRs that this campaign is
allowed to touch, fix merge conflicts and known CI traps, add the
`intended-closes` label on every `Closes #N` PR, and leave Ready
comments only after the new CI is green. Do not merge to main. Do not
edit `src/gllvmTMB.cpp` or lineage files. Do not touch `codex/` branches.

## 2. Implemented

- Merged `origin/main` (`80b0129f`) into #1700, #1695, #1698, #1692,
  #1615, #1644, and #1070.
- NEWS conflicts on #1692 and #1615 resolved by keeping both bullets.
- #1644: `test-lme4-style-weights.R` now sets its own seed after
  `simulate_site_trait()`, so the heteroscedastic check no longer
  depends on leftover simulator draws. NEWS line added.
- `intended-closes` added on #1700, #1695, #1692, #1644.
- #1687 commented as superseded by #1689 (already on main; #1356 closed).
- Parked: #1506 and #981 (`src/gllvmTMB.cpp`), #1283 (`codex/` + prior
  PARK), #1065 (C++ follow-on; do not merge against #1070).

## 3. Files Changed

This campaign branch carries only the after-task and check-log. The PR
edits live on their own branches.

- `docs/dev-log/after-task/2026-10-30-open-pr-finish.md`
- `docs/dev-log/check-log.d/2026-10-30-open-pr-finish.md`

## 3a. Decisions and Rejected Alternatives

Decision: merge main, never rebase-force. Rationale: the campaign
forbids force-push. Rejected: rebase + force-push. Confidence: high.

Decision: park every PR that touches `src/gllvmTMB.cpp` or a `codex/`
branch. Rationale: standing rule for this pass. Rejected: drive-by
template edits. Confidence: high.

Decision: option (a) on #1644 (own `set.seed()` after simulate).
Rationale: smallest fix that unblocks the known shard-4 fail without
rewriting the weights claim. Rejected: skip the test, or a multi-seed
rewrite in this pass. Confidence: high for unblocking; the weighted
`sigma_eps` identification question is still open.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-30-open-pr-finish.md`.

## 5. Tests of the Tests

The #1644 weights-test seed pin is prophylactic against the documented
shard-4 fail. The new CI run is the evidence. Local `devtools::test()`
was not run: this VM had no R until apt-installed 4.3.3, and compiling
the package plus TMB was out of slice.

## 6. Consistency Audit

- `rg -n "gllvmTMB_tweedie_negative_y|tweedie_rows" R/fit-multi.R` on
  main: the #1687 check is already present.
- `git grep -n "^<<<<<<<"` on the merged PR worktrees after resolution:
  no leftover markers in NEWS, R/, tests/, or man/.
- No `src/gllvmTMB.cpp` edit in any campaign commit.

## 7. Roadmap Tick

N/A. No ROADMAP row moved.

## 7a. GitHub Issue Ledger

Inspected: #1572, #1590, #1570, #1356, #1602, #1578, #750.

Not closed: none of the `Closes #N` issues is closed here. The
campaign does not merge, so those issues stay open until Shinichi
merges the PRs.

#1356 is already closed on main via #1689. Evidence: issue state
closed, comment of 25 Oct 2026, `tweedie_rows` on `origin/main`.

Created: the weighted `sigma_eps` identification issue, if the
search found no existing home (see the campaign PR body).

## 8. What Did Not Go Smoothly

- `gh label create` returned 403; `EditPullRequestLabels` still added
  `intended-closes`.
- GitHub MCP `add_issue_comment` returned 403; PR comments went
  through `ManagePullRequest`.
- This VM had no R at boot. CI is the test evidence.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Shannon: the Oct 25 drafts were already small and mostly green; the
real work was merging main and labelling `Closes #N`. Older MSPL and
`src/` PRs are a different class and stay parked.

Rose: #1687 looked finishable until the #1689 close-out on #1356 was
read. A "Refs" PR that is 98 behind can be superseded even when its
own CI was green.

Grace: previous CI greens on #1698 and #1615 do not carry over after
a main merge. Ready comments wait for the new shards.

## 10. Known Limitations And Next Actions

- Ready comments and undraft wait on the new CI.
- #750 still needs a coverage study and slope-augmented SPDE redraw.
- #1578 part 2 (unidentified example) stays open.
- #1070 stays planned; do not merge #1065 against it.
- Weighted `sigma_eps` next to `latent(..., d = 1)` is not claimed
  robust by the single-seed weights test.
