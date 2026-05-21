# Recovery checkpoint: launch audit pass

**Date:** 2026-05-21 06:37:44 MDT
**Agent:** Codex / Ada
**Branch:** `codex/article-audit-2026-05-20`

## Git status

```text
## codex/article-audit-2026-05-20
 M R/plot-gllvmTMB.R
 M README.md
 M ROADMAP.md
 M _pkgdown.yml
 M docs/design/46-visualization-grammar.md
 M docs/dev-log/check-log.md
 M docs/dev-log/team-improvements.md
 M man/plot.gllvmTMB_multi.Rd
 M tests/testthat/test-plot-gllvmTMB.R
 M vignettes/articles/api-keyword-grid.Rmd
 M vignettes/articles/covariance-correlation.Rmd
 M vignettes/articles/morphometrics.Rmd
 M vignettes/articles/pitfalls.Rmd
 M vignettes/articles/response-families.Rmd
 M vignettes/gllvmTMB.Rmd
?? data-raw/examples/
?? docs/design/52-example-object-contract.md
?? docs/design/53-report-ready-extractor-plot-contract.md
?? docs/dev-log/after-task/2026-05-20-article-surface-reset-drmtmb-lessons.md
?? docs/dev-log/after-task/2026-05-20-example-object-contract-morphometrics.md
?? docs/dev-log/after-task/2026-05-20-public-surface-reset-implementation.md
?? docs/dev-log/after-task/2026-05-21-covariance-edge-case-example.md
?? docs/dev-log/after-task/2026-05-21-extraction-plotting-contract.md
?? docs/dev-log/after-task/2026-05-21-figure-3-plot-suite.md
?? docs/dev-log/audits/2026-05-20-article-gate-matrix.md
?? docs/dev-log/audits/2026-05-20-article-surface-reset.md
?? docs/dev-log/audits/2026-05-20-drmtmb-lessons-for-gllvmtmb.md
?? docs/dev-log/recovery-checkpoints/2026-05-21-052517-codex-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-05-21-063743-codex-launch-audit-checkpoint.md
?? docs/dev-log/roadmap-archive/
?? inst/extdata/examples/
?? tests/testthat/test-example-covariance-edge-cases.R
?? tests/testthat/test-example-morphometrics.R
```

## Diff stat

```text
 R/plot-gllvmTMB.R                             |  910 +++++++++++++++--
 README.md                                     |  225 ++---
 ROADMAP.md                                    | 1311 ++-----------------------
 _pkgdown.yml                                  |   73 +-
 docs/design/46-visualization-grammar.md       |   62 +-
 docs/dev-log/check-log.md                     |  524 ++++++++++
 docs/dev-log/team-improvements.md             |   26 +
 man/plot.gllvmTMB_multi.Rd                    |   44 +-
 tests/testthat/test-plot-gllvmTMB.R           |  172 +++-
 vignettes/articles/api-keyword-grid.Rmd       |   19 +-
 vignettes/articles/covariance-correlation.Rmd |  151 ++-
 vignettes/articles/morphometrics.Rmd          |  292 +++---
 vignettes/articles/pitfalls.Rmd               |   94 +-
 vignettes/articles/response-families.Rmd      |   10 +-
 vignettes/gllvmTMB.Rmd                        |  131 +--
 15 files changed, 2175 insertions(+), 1869 deletions(-)
```

## Commands already run

- `git status --short --branch` -> broad reset working tree on `codex/article-audit-2026-05-20`.
- `git diff --stat` -> large public-surface/example-object/plotting reset diff.
- `gh pr list --state open --repo itchyshin/gllvmTMB` -> no open PRs returned.
- `git log --all --oneline --since='6 hours ago'` -> no recent commits returned.
- Read latest `docs/dev-log/check-log.md` entry and latest recovery checkpoint.

## Commands still needed

- `devtools::test()` or targeted fallback if full test exceeds time.
- `pkgdown::build_site()` or `pkgdown::build_articles(lazy = FALSE)` plus `pkgdown::check_pkgdown()`.
- Rendered public-page inspection for landing, Get Started, Roadmap, and six visible articles.
- Hidden-link and stale-claim scans.
- `git diff --check`.

## Next safest action

Run the launch audit pass. Fix only launch blockers: broken nav, visible hidden-page routing, stale overclaims, missing rendered page, or check failures.

## Blocking question

None. Keep this bounded to launch readiness for the revised webpage and roadmap.
