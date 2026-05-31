# After Task: pkgdown `phylo_signal_mi()` reference hotfix

**Branch**: `codex/pkgdown-phylo-signal-mi`
**Date**: `2026-05-31`
**Roles (engaged)**: `Ada / Rose / Grace`

## 1. Goal

Restore the main-branch pkgdown deploy after #402 added
`phylo_signal_mi()` without adding the exported topic to the pkgdown
reference index.

## 2. Implemented

- Added `phylo_signal_mi` to the "Methods and plots on fitted models"
  reference group in `_pkgdown.yml`, next to `predict_missing` and
  `imputed`.
- Left runtime code, roxygen, Rd files, and the missing-data article
  untouched.

## 3. Files Changed

- `_pkgdown.yml`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-31-pkgdown-phylo-signal-mi-hotfix.md`

## 3a. Decisions and Rejected Alternatives

Decision: place `phylo_signal_mi()` near the missing-predictor fitted
model helpers rather than under the general covariance extractors.

Rationale: `phylo_signal_mi()` diagnoses the fitted `mi()` covariate
model and is documented alongside `imputed()` in
`R/missing-predictor.R`.

Rejected alternative: put it beside `extract_phylo_signal()`. That
would also satisfy pkgdown, but it makes the helper look like a general
trait-covariance extractor.

## 4. Checks Run

- `gh pr list --state open --limit 20` -> open PRs were #403, #390,
  #374, and #369.
- `git log --all --oneline --since="6 hours ago"` -> no newer
  main-branch fix for `phylo_signal_mi()`.
- `gh pr view 403 --json files --jq '.files[].path'`; `gh pr view 390
  --json files --jq '.files[].path'`; `gh pr view 374 --json files
  --jq '.files[].path'`; `gh pr view 369 --json files --jq
  '.files[].path'` -> only draft #374 also touches `_pkgdown.yml`.
- `gh pr diff 374 --patch | sed -n '/diff --git a\\/_pkgdown.yml/,/diff --git/p'`
  -> #374's `_pkgdown.yml` hunk adds `articles/missing-data`; this
  hotfix edits the reference-topic hunk.
- `rg -n "phylo_signal_mi|imputed|extract_phylo_signal" R man _pkgdown.yml NAMESPACE`
  -> confirmed export, Rd topic, and missing `_pkgdown.yml` entry.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems
  found.`
- `git diff --check` -> clean.

## 5. Tests of the Tests

No test code changed. The relevant gate is pkgdown reference-index
parity, and `pkgdown::check_pkgdown()` failed on main before this
one-line navigation repair.

## 6. Consistency Audit

- `phylo_signal_mi|imputed|extract_phylo_signal` -> expected source,
  NAMESPACE, man, and `_pkgdown.yml` hits after the fix.
- No stale wording scan was needed because this PR adds no public
  prose beyond a pkgdown topic name already generated from roxygen.

## 7. Roadmap Tick

N/A. This is a documentation-build repair for an already-merged
missing-data helper, not a new roadmap slice.

## 7a. GitHub Issue Ledger

No issue was opened. The failure was directly visible in the
main-branch pkgdown workflow for #402's merge commit.

## 8. What Did Not Go Smoothly

The topic was exported and documented but missed in `_pkgdown.yml`.
This repeats the exact export-to-reference-index class that Rose's
pre-publish gate is meant to catch.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the fix narrow because main deploy is red.

Rose: exported helpers need `_pkgdown.yml` parity at the same time as
roxygen/Rd generation.

Grace: `pkgdown::check_pkgdown()` is the right local reproducer for
this failure class; full package tests are not informative for a
navigation-only repair.

## 10. Known Limitations And Next Actions

- This hotfix does not alter or validate the missing-data Phase 3
  model.
- Draft PR #374 also edits `_pkgdown.yml` in an article-nav hunk and
  may need to rebase after this hotfix merges.
