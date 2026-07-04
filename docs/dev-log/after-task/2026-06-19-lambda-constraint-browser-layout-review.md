# Lambda Constraint Browser Layout Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Start the true browser/layout review for the hidden `lambda-constraint` article.
This slice fixes the first-viewport title overflow and records the remaining
Confidence Eye visual/statistical blocker instead of promoting the page.

## Files Touched

- `vignettes/articles/lambda-constraint.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-lambda-constraint-browser-layout-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/lambda-constraint.html` successfully.
- Headless Chrome desktop screenshot
  - `/tmp/gllvm-lambda-browser/lambda-desktop-top-final.png`
  - 1440 x 1600.
  - First viewport renders with the shortened title, internal gate, right-hand
    contents rail, and no visible overlap.
- Rendered HTML scope check
  - Confirmed the shortened title and the new diagnostic Confidence Eye blocker
    wording.
  - No hits for `release ready`, `scientific coverage passed`, or
    `publication-grade`.
- Figure asset dimension check
  - Seven PNG assets exist with nonzero dimensions.
  - `confidence-eye-1.png` exists at 1536 x 864 but remains a blocker: it shows
    hollow points only because the Wald loading-CI path is unavailable under a
    non-positive-definite Hessian.

## Status

The article no longer has the long `lambda_constraint` token in the visible H1,
so the desktop first viewport is cleaner. The Confidence Eye section now tells
the truth about the current rendered output: it is an internal review signal,
not a public-ready loading-uncertainty figure. Public return still requires a
fixture with positive-definite loading intervals or a profile/bootstrap
loading-interval path, plus final browser/mobile and public-placement review.

This is not public promotion, bridge completion, release readiness, or
scientific coverage.
