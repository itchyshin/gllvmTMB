# Lambda Suggest Routine Render Unblock

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Unblock routine rendering of the hidden `lambda-constraint-suggest` companion
article. The prior cold-cache render stalled in the `profile_retention` path;
this slice keeps the expensive maintainer code visible but stops routine
pkgdown builds from executing it.

## Files Touched

- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-lambda-suggest-routine-render-unblock.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/lambda-constraint-suggest.html`
    successfully.
- Rendered HTML scope check
  - Confirmed the internal article gate, display-only profile-retention note,
    `profile_retention` code, and absence of `release ready`,
    `scientific coverage passed`, and `publication-grade` wording.
- Rendered asset check
  - No article figure assets are referenced by the current rendered HTML.
    Stale PNG files remain in the old output directory but are not linked.

## Status

The companion page is now buildable in routine article renders. The expensive
`suggest-profile-retention`, data-driven refit, model-comparison, and
Confidence Eye chunks are display-only in routine builds and should be run
manually when the retained-loading evidence is refreshed. This is a build
unblock for an internal companion page, not refreshed profile-retention
evidence, public promotion, bridge completion, release readiness, or
scientific coverage.
