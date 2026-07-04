# Psychometrics IRT Rendered Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Align the internal `psychometrics-irt` preview with the article-council Tier 3
contract and record rendered evidence. This page remains behind the binary
lambda/JSDM and comparator-design gates.

## Files Touched

- `vignettes/articles/psychometrics-irt.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-psychometrics-irt-rendered-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/psychometrics-irt", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/psychometrics-irt.html` successfully.
- Rendered HTML scope check
  - Passed for the internal article gate, cross-domain preview wording,
    `lambda_constraint`, diagnostic wording, and M2.5 boundary.
  - No rendered hits for `release ready`, `scientific coverage passed`,
    `publication-grade`, or `cross-domain validation`.
- Figure asset dimension check
  - `sigma-exp-corr-1.png`: 1228 x 1113.

## Status

The article now has explicit Tier 3 YAML, standard internal-gate wording, and
rendered evidence. It remains internal until the binary lambda/JSDM article and
`mirt` comparator path are designed. This is not public promotion, comparator
validation, bridge completion, release readiness, or scientific coverage.
