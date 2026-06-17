# After Task: cran-comments Current Branch Evidence

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Grace, Rose, Shannon

## 1. Goal

Keep the CRAN submission cover note aligned with the current draft PR evidence.
The old wording described the post-fix check tally as an expectation; PR #489
head `b0fe50a` now has observed local and GitHub check evidence.

## 2. Implemented

- Updated the draft date to 2026-06-16.
- Stated that the PDF-manual Unicode warning, DOI notes, and Julia bridge
  namespace note are fixed on the branch.
- Replaced the post-fix expectation with the observed no-Julia local check
  result: `0 errors | 1 warning | 1 note` at PR #489 head `b0fe50a`.
- Added that GitHub Actions R-CMD-check passes at `b0fe50a`.
- Kept the boundary that final CRAN submission still needs a release-branch
  `--as-cran` rerun, including CRAN incoming checks, and a maintainer decision
  on the NEWS heading note.

## 3. Files Changed

- `cran-comments.md`
- `docs/dev-log/check-log.md`
- This after-task report

## 4. Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,headRefName,baseRefName,isDraft,updatedAt,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" -- cran-comments.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints NEWS.md`
  -> recent overlapping edits were from the current Codex bridge stack only.
- Prose/readiness scan:
  `rg -n "Draft \\(2026-06-16\\)|0 errors \\| 1 warning \\| 1 note|R code namespace note|final release-branch|checking R code" cran-comments.md`
  -> expected current branch evidence and release-boundary lines present.
- Whitespace:
  `git diff --check`
  -> clean.

## 5. Consistency Audit

- No package code, generated Rd, NAMESPACE, NEWS, README, vignette, pkgdown
  navigation, likelihood, formula grammar, CI route, or validation-row status
  changed.
- `cran-comments.md` remains outside the built package through `.Rbuildignore`.
- The note does not claim CRAN readiness; it records branch evidence and names
  the remaining release-branch check and NEWS decision.

## 6. Definition Of Done

- **Implementation:** complete for this release-prose alignment; not yet merged.
- **Simulation recovery:** not applicable.
- **Documentation:** `cran-comments.md` now matches current branch evidence.
- **Runnable example:** not applicable.
- **Check-log:** this task appended a check-log entry with exact commands.
- **Review pass:** Grace/Rose/Shannon scope: release evidence is concrete, not
  overclaimed, and the final release gate remains explicit.
