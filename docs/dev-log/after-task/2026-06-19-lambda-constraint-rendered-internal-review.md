# Lambda Constraint Rendered Internal Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Resolve the next article-council item for the binary loading-constraint lane by
checking the current `lambda-constraint` internal article as rendered HTML. This
slice does not promote the page to public navigation.

## Files Touched

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-lambda-constraint-rendered-internal-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/lambda-constraint.html`.
- Rendered HTML scope check
  - Passed for the internal article gate, binary loading-constraint teaching
    path, `joint-sdm`, `confirmatory_lambda`, and `lambda_constraint`.
  - No rendered hits for `release ready`, `scientific coverage passed`, or
    `publication-grade`.
- Figure asset dimension check
  - `communality-plot-1.png`: 1344 x 768.
  - `confidence-eye-1.png`: 1536 x 864.
  - `constraint-tile-1.png`: 864 x 960.
  - `loadings-compare-1.png`: 1536 x 960.
  - `prevalence-1.png`: 1152 x 576.
  - `side-by-side-heatmap-1.png`: 1440 x 768.
  - `vp-plot-1.png`: 1440 x 768.

## Status

The article now has rendered internal-gate evidence and asset evidence. It
remains internal until the reader/browser review and final placement decision
pass. This is not lambda-constraint promotion, interval calibration, release
readiness, bridge completion, or scientific coverage.
