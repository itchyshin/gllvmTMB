# After Task: reader-first tree-axis and covariance-grid rewrite

**Branch:** `codex/column-slope-family`
**Date:** 2026-08-24
**PR:** #1208 (open; not merged)

## 1. Goal

Replace the confusing bird/iSDM tree-axis article with two small plant examples:
one where phylogeny relates sampled species and one where it relates species
response columns. Make the 5 × 3 covariance lookup visually and conceptually
separate from the response-column slope helpers.

## 2. Mathematical contract

No likelihood, public R API, formula grammar, response family, or generated Rd
file changed. The teaching contract remains: `*_slope()` means predictor
coefficients varying across response columns. It is outside the 5 × 3
random-effect trait-covariance grid. The taught route is Gaussian long format
only; wide grammar, non-Gaussian/mixed families, latent predictor covariance,
simultaneous slope sources, and intervals remain deferred.

## 3. Files changed

- `vignettes/articles/where-does-the-tree-go.Rmd`: complete reset to two
  reproducible alpine-plant examples; no birds, stored RDS fixture, large
  figure program, or integrated-observation story.
- `vignettes/articles/api-keyword-grid.Rmd`: correct `unique()` wording and
  move the slope-helper family into a visibly separate, short lookup block.
- `_pkgdown.yml`: reader-facing article title.
- `pkgdown/extra.css`: responsive tables, safer navigation/TOC wrapping,
  readable code comments, and a restrained slope-family callout.
- `dev/trait-axis-bridge/verify-scope.R`: guard the rewritten teaching and
  scope boundary against reintroducing the old integrated-model story.
- This report and `docs/dev-log/check-log.md`.

`README.md`, `NEWS.md`, `ROADMAP.md`, `NAMESPACE`, `man/`, likelihood code,
and tests were inspected and not changed: this was a reader-facing repair,
not a new capability.

## 4. Checks run

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); rmarkdown::render("vignettes/articles/where-does-the-tree-go.Rmd", output_dir = "/private/tmp/tree-article-render", quiet = TRUE); rmarkdown::render("vignettes/articles/api-keyword-grid.Rmd", output_dir = "/private/tmp/grid-article-render", quiet = TRUE)'
# PASS: both standalone HTML vignettes rendered.
Rscript --vanilla dev/trait-axis-bridge/verify-scope.R
# PASS: SCOPE SCAN PASS.
Rscript --vanilla dev/trait-axis-bridge/verify-article.R
# PASS: ARTICLE BUILD PASS.
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'
# PASS: no problems found.
Rscript --vanilla -e 'pkg <- pkgdown:::section_init(".", "articles"); for (nm in c("articles/api-keyword-grid", "articles/where-does-the-tree-go")) pkgdown::build_article(nm, pkg = pkg, lazy = FALSE, quiet = FALSE)'
# PASS: both actual pkgdown article pages written under pkgdown-site/articles/.
git diff --check
# PASS.
```

The app browser was unavailable and the supplied PDF renderer produced an empty
document, so a pixel-level browser screenshot was not claimed. Structural
inspection of the actual pkgdown HTML confirmed 3 wrapped tables in the tree
article and 2 wrapped tables plus the slope callout in the grid. The CSS makes
the same overflow behaviour explicit for standalone vignettes and pkgdown.

## 5. Consistency audit

```sh
rg -n 'What does the tree relate|Response- column|iSDM|observation model|occupancy' vignettes/articles/where-does-the-tree-go.Rmd vignettes/articles/api-keyword-grid.Rmd dev/trait-axis-bridge/verify-scope.R
# PASS: no old title, broken line-break wording, or integrated-model teaching remains.
rg -n 'gllvmTMB\\(' vignettes/articles/where-does-the-tree-go.Rmd vignettes/articles/api-keyword-grid.Rmd
# PASS after inspection: each taught long-format fit supplies trait = explicitly.
rg -n 'gllvmTMB_wide|meta_known_V|non-Gaussian|deferred|intervals' vignettes/articles/where-does-the-tree-go.Rmd vignettes/articles/api-keyword-grid.Rmd
# PASS: only explicit scope boundaries and the documented deprecated meta alias remain.
```

## 6. Tests of the checks

`verify-scope.R` now fails if the old iSDM/observation narrative returns and
requires the five plain-language boundaries that the new article teaches.
Both direct R Markdown rendering and pkgdown's own article builder exercised
the runnable fits rather than merely parsing source.

## 7. What did not go smoothly

The previous closeout treated a source review and a successful build as if they
were a visual reader review. A supplied live-site screenshot showed navbar and
right-TOC clipping, while the first standalone render exposed cramped tables.
GitHub DNS was unavailable for the required shared-file pre-edit PR listing,
so no external-state conclusion was inferred from that failed call.

## 8. Team learning

**Boole (Sol):** identified the category error: response-column slope helpers
are not a 5 × 3 cell or modifier. The grid is now a Tier-2 lookup and the
worked decision lives elsewhere.

**Pat (Sol):** found that the old article made a reader wait for the fit and
mixed up axes. The new sequence is question, axis table, compact fit, then
matrix interpretation; the follow-up review passed pedagogy but caught the
responsive-table gap.

**Rose (Sol):** caught the incorrect claim that `unique()` had become
`latent(unique = TRUE)` and required explicit compatibility and deferred-scope
language.

**Florence / visual review (Sol):** used the provided screenshot to identify
the real navigation/TOC failure and required a responsive layout repair. The
browser limitation is recorded rather than hidden.

**Grace:** pkgdown validation and the two actual pkgdown page builds passed.

## 9. Design-doc updates

N/A. The implementation contract remains in Design 130; this task makes the
reader-facing explanation faithfully reflect it.

## 10. Pkgdown and roadmap

The navigation title and two article pages are updated locally. **Roadmap
tick:** N/A; no capability or roadmap status changed.

## 11. GitHub issue ledger and next action

No issue was created or closed. `gh pr list --state open --limit 20` was
attempted before the shared-document edit but failed at DNS resolution; no
conclusion about other open work was drawn from it. The current worktree's
shared Git metadata is also read-only here (`index.lock: Operation not
permitted`), so this verified docs-only diff is deliberately uncommitted. The
next safe external action is to commit and push it to PR #1208 from a checkout
with writable Git metadata, await the required CI matrix, and inspect the
deployed/pkgdown page in a real browser before merging. Do not merge
automatically.
