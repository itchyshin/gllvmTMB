# Mixed Family Broader Family Map

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Move the `mixed-family-extractors` article one step closer to a coherent
mixed-response teaching path by adding a compact family map. This does not
promote the article publicly or close the NB/beta/delta/hurdle blockers.

## Files Touched

- `vignettes/articles/mixed-family-extractors.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-mixed-family-broader-family-map.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/mixed-family-extractors.html`
    successfully.
- Rendered HTML scope check
  - Passed for the internal article gate, broader family map,
    negative-binomial/beta boundary, `MIX-10`, delta/hurdle boundary, and
    coverage-proof caveat.
  - No rendered hits for `release ready`, `scientific coverage passed`, or
    `publication-grade`.
- Figure asset dimension check
  - `corr-1.png`: 1113 x 921.

## Status

The article now explains what the compact fixture covers and what remains
outside public teaching. It still lacks a runnable NB/beta fixture, delta/hurdle
latent-scale correlation remains blocked, CI-10 remains partial, and browser
review remains open. This is not public promotion, bridge completion, release
readiness, or scientific coverage.
