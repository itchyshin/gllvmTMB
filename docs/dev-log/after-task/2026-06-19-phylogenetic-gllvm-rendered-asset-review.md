# Phylogenetic GLLVM Rendered Asset Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Close the rendered HTML and asset evidence slice for the internal
`phylogenetic-gllvm` candidate article. This does not replace true browser
scroll-through or public placement review.

## Files Touched

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-phylogenetic-gllvm-rendered-asset-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- Browser availability check through the in-app browser plugin
  - `iab` was unavailable, so true browser scroll-through remains blocked.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/phylogenetic-gllvm", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/phylogenetic-gllvm.html` successfully.
- Rendered HTML scope check
  - Passed for the internal article gate, diagnostic labels, and
    phylogenetic wording.
  - No rendered hits for `release ready`, `scientific coverage passed`, or
    `publication-grade`.
- Figure asset dimension check
  - `extract-total-correlations-1.png`: 1420 x 883.

## Status

The article has rendered HTML and asset evidence. It remains internal until a
true browser review and final public-placement decision pass. This is not
bridge completion, release readiness, or scientific coverage.
