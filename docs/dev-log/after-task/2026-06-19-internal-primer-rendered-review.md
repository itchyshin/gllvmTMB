# Internal Primer Rendered Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Close a narrow article-council evidence slice for the Tier 3 internal primer
pages `data-shape-flowchart` and `stacked-trait-gllvm`. These pages remain
internal; this review checks that they build cleanly and keep the internal
scope boundary in rendered HTML.

## Files Touched

- `vignettes/articles/data-shape-flowchart.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-internal-primer-rendered-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/data-shape-flowchart", "articles/stacked-trait-gllvm")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  - Both articles rendered.
  - The first `data-shape-flowchart` render reported MathML warnings from
    `\rm` subscripts.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/data-shape-flowchart", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rerendered cleanly after replacing `\rm` with `\mathrm{...}`.
- Rendered HTML scope check
  - Passed for both pages: internal article gate present; no rendered hits for
    `release ready`, `scientific coverage passed`, or `publication-grade`.
- Figure asset check
  - No PNG asset directories were produced for these pages.
- Stale notation/overclaim scan
  - No `\rm`, `_{\rm`, `release ready`, `scientific coverage passed`, or
    `publication-grade` hits in the two source/rendered pages.

## Status

`data-shape-flowchart` and `stacked-trait-gllvm` remain Tier 3 internal pages.
This is rendered-review and notation-cleanup evidence only; it is not public
promotion, bridge completion, release readiness, or scientific coverage.
