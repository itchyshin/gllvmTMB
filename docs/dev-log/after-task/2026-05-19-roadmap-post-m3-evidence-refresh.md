# After Task: ROADMAP post-M3 evidence refresh

**Branch**: `codex/roadmap-post-m3-evidence-refresh-2026-05-19`
**Date**: 2026-05-19
**Roles (engaged)**: Ada, Grace, Rose

## 1. Goal

Refresh roadmap and coordination-board status after PR #199 merged, so
the top-level summary, detailed milestone sections, and live
coordination state agree on the M3 production-evidence outcome.

## 2. Implemented

- Merged PR #199 to `main` after green 3-OS R-CMD-check.
- Added PR #197, #198, and #199 to the roadmap's "Since last refresh"
  section.
- Synced the detailed M3 section from `0/8` to `3/8`, matching the
  phase-at-a-glance row and the shipped M3.1 / M3.2 / M3.6 slices.
- Replaced stale `in flight` / `LOCAL DRAFT` roadmap wording for
  verified merged PRs #120, #122, #125, and #170.
- Updated the coordination board to mark PR #199 resolved and this
  roadmap-refresh lane active.

No public R API, likelihood, formula grammar, response family, roxygen,
generated Rd, vignette, README, NEWS, pkgdown navigation, validation
status, or test expectation changed.

## 3. Files Changed

- `ROADMAP.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-roadmap-post-m3-evidence-refresh.md`

No example file changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: keep this as a roadmap consistency PR, not an M3.3
  statistical-diagnosis PR.
  **Rationale**: PR #199 already establishes the evidence outcome; the
  next technical lane should diagnose coverage and failed-refit causes.
  **Rejected alternative**: start profile-target and convergence triage
  inside the roadmap refresh.
  **Confidence**: high.
- **Decision**: fix verified stale Phase 1b and M2 roadmap phrases in
  the same pass.
  **Rationale**: those phrases said merged PRs were still in flight or
  local drafts, and `gh pr view` verified the actual merge state.
  **Rejected alternative**: leave known stale status because the
  original trigger was M3.
  **Confidence**: high.

## 4. Checks Run

- `gh pr view 199 --repo itchyshin/gllvmTMB --json number,state,mergedAt,mergeCommit,url`
  -> PR #199 merged at `2026-05-19T17:42:48Z` as merge commit
  `6a1e5d5f5f26545d7d2a1d23194e27cf70ef2ce8`.
- `git switch main` -> switched from the PR #199 branch to `main`.
- `git pull --ff-only` -> fast-forwarded `main` from `020e305` to
  `6a1e5d5`.
- Pre-edit lane check: `gh pr list --state open --limit 20` -> no open
  PR rows.
- Pre-edit lane check: `git log --all --oneline --since="6 hours ago"`
  inspected recent merges through PR #199.
- `gh pr view 170 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #170 merged at `2026-05-18T01:09:12Z`.
- `gh pr view 120 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #120 merged at `2026-05-15T19:45:43Z`.
- `gh pr view 122 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #122 merged at `2026-05-15T20:28:41Z`.
- `gh pr view 125 --repo itchyshin/gllvmTMB --json number,title,state,mergedAt,url`
  -> PR #125 merged at `2026-05-15T20:35:38Z`.
- ``rg -n 'PR #170, in flight|2/3 in main; 1 in flight|cross-reference fix in flight|PR #122.*held|simulation-verification\\.Rmd.*LOCAL DRAFT|### ⚪ M3 -- Inference completeness across families -- `░░░░░░░░` 0/8' ROADMAP.md``
  -> no remaining stale roadmap status hits.
- `rg -n "PR #197|PR #198|PR #199|M3\\.3 production|26100827665|2/15|CI-08|CI-10|failure-mode triage" ROADMAP.md docs/dev-log/coordination-board.md`
  -> expected current-status hits only.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

N/A. This PR changes roadmap and coordination prose only.

## 6. Consistency Audit

- ROADMAP phase-at-a-glance M3 row and detailed M3 heading both now
  report `3/8`.
- ROADMAP "Since last refresh" now includes PR #197, #198, and #199.
- Coordination board no longer shows PR #199 as active or CI-running.
- Verified stale "in flight" / "local draft" phrases were removed only
  where GitHub PR state or committed files confirmed the replacement.

## 7. Roadmap Tick

M3 remains `███░░░░░` 3/8. The tick did not move; this PR aligns the
roadmap narrative to the already-merged evidence.

## 8. What Did Not Go Smoothly

The roadmap had diverged in multiple places: the top table had the
right M3 count, but the detailed M3 section still reported `0/8`.
The same pass exposed older Phase 1b and M2 "in flight" wording that
had become stale after PRs merged.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada: kept the lane bounded to roadmap and coordination state.
- Grace: verified merge and CI state before editing status prose.
- Rose: checked for stale status phrases across the roadmap and kept
  the evidence trail in the check-log / after-task pair.

## 10. Known Limitations And Next Actions

This PR does not diagnose the M3.3 coverage failure. The next technical
lane remains M3.3 failure-mode triage: profile target / transform
calibration, failed-refit patterns, and family-specific undercoverage.
