# Ordinal Probit Runnable Fixture

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Move the internal `ordinal-probit` article from syntax-only draft to runnable
article evidence. This closes the immediate "examples are eval = FALSE" blocker
without promoting the article publicly or claiming ordinal interval coverage.

## Files Touched

- `vignettes/articles/ordinal-probit.Rmd`
- `vignettes/articles/response-families.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-ordinal-probit-runnable-fixture.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/ordinal-probit", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/ordinal-probit.html` successfully.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/response-families", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/response-families.html` successfully.
- Rendered HTML scope check
  - Passed for covered FAM-14 wording, runnable long/wide fixture, same
    log-likelihood output, `extract_cutpoints()`, `link_residual = "auto"`,
    and `check_gllvmTMB()` fit-health rows.
  - No rendered hits for stale `eval = FALSE` / non-executable-example wording,
    `release ready`, `scientific coverage passed`, or `publication-grade`.
- Figure asset check
  - No figure assets are expected from this article.

## Status

The article now runs a compact two-trait ordinal-probit example in both long and
wide forms. The rendered output shows a near-zero long/wide log-likelihood
difference, estimated `cutpoint_2` rows, ordinal residual variance added by
`link_residual = "auto"`, and passing fit-health diagnostics. The companion
`response-families` row now matches the register by saying FAM-14 is covered,
while keeping the ordinal article internal for cutpoint extractor depth,
interval calibration, exact ordinal residual diagnostics, browser review, and
public-placement review.

This is not public promotion, bridge completion, release readiness, or
scientific coverage.
