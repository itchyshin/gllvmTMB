# Recovery checkpoint: Florence figure slice

**Date:** 2026-05-21 05:25:17 America/Edmonton
**Agent:** Codex / Ada, with Florence as visual lead
**Branch:** `codex/article-audit-2026-05-20`

## Git status

```text
 M R/plot-gllvmTMB.R
 M README.md
 M ROADMAP.md
 M _pkgdown.yml
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
?? docs/dev-log/audits/2026-05-20-article-gate-matrix.md
?? docs/dev-log/audits/2026-05-20-article-surface-reset.md
?? docs/dev-log/audits/2026-05-20-drmtmb-lessons-for-gllvmtmb.md
?? docs/dev-log/roadmap-archive/
?? inst/extdata/examples/
?? tests/testthat/test-example-covariance-edge-cases.R
?? tests/testthat/test-example-morphometrics.R
```

## Diff stat

```text
 R/plot-gllvmTMB.R                             |  160 ++-
 README.md                                     |  225 ++---
 ROADMAP.md                                    | 1311 ++-----------------------
 _pkgdown.yml                                  |   73 +-
 docs/dev-log/check-log.md                     |  359 +++++++
 docs/dev-log/team-improvements.md             |   20 +
 man/plot.gllvmTMB_multi.Rd                    |    6 +-
 tests/testthat/test-plot-gllvmTMB.R           |   57 +-
 vignettes/articles/api-keyword-grid.Rmd       |   19 +-
 vignettes/articles/covariance-correlation.Rmd |  151 ++-
 vignettes/articles/morphometrics.Rmd          |  269 ++---
 vignettes/articles/pitfalls.Rmd               |   94 +-
 vignettes/articles/response-families.Rmd      |   10 +-
 vignettes/gllvmTMB.Rmd                        |  131 +--
 14 files changed, 1122 insertions(+), 1763 deletions(-)
```

## Commands already run

- `git status --short --branch` -> on `codex/article-audit-2026-05-20`.
- `git diff --stat` -> large reset/example-object/plotting lane diff shown above.
- `gh pr list --state open --repo itchyshin/gllvmTMB` -> no open PRs returned.
- `git log --all --oneline --since='6 hours ago'` -> no recent commits returned.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'` -> passed before this checkpoint: 92 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> regenerated `man/plot.gllvmTMB_multi.Rd`.

## Commands still needed

- Re-run `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`.
- Re-run `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`.
- Run `git diff --check`.
- Rebuild or render affected article pages if the Morphometrics caption or plot output changes.

## Next safest action

Continue the Florence figure slice in `R/plot-gllvmTMB.R`:

1. add a package-local colourblind-safe palette and publication theme;
2. update correlation/loadings/integration/variance/ordination helpers;
3. preserve plot data and status fields;
4. fix the Morphometrics caption drift from `Sigma_B = Lambda Lambda^T` to total `Sigma_B = Lambda Lambda^T + Psi`;
5. update design docs, check-log, and the after-task report.

## Blocking question

None. Keep the plot helpers honest: this slice may improve figure quality, but it should not mark the figures as publication-ready until rendered HTML and Florence review pass.
