# After-Task: API Keyword Grid Tier-2 Reference

## Goal

Port the legacy `api-keyword-grid.Rmd` into the current public site as
the first Tier-2 technical reference article, without expanding into
the larger response-family or mixed-response article queue.

## Scope

This task was one article:

- `vignettes/articles/api-keyword-grid.Rmd`

Supporting hygiene updates are limited to `_pkgdown.yml`, `NEWS.md`,
and `docs/dev-log/check-log.md`.

## Reader And Tier

The reader is an applied or methods user who already knows they need
`gllvmTMB` and wants a syntax lookup page. Tier 2 is justified because
this is a grammar reference, not a new worked biological example.

## Contract

The article must match the current 3 x 5 grid:

```text
correlation x mode = none / phylo / spatial x scalar / unique / indep / dep / latent
```

It does not change formula grammar, likelihood, exported functions, or
the keyword grid.

## Checks Run

Before editing:

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,files`
  showed only PR #43 and PR #44, both adding their own audit files with
  no overlap with this branch.
- `git log --all --oneline --since="6 hours ago"` confirmed PR #45 had
  just merged and this branch starts from current `main`.

Final validation:

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/api-keyword-grid", new_process = FALSE)'`:
  passed. The render emitted only the known missing `../logo.png`
  pkgdown warning.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`:
  passed with "No problems found".
- Rose pre-publish gate: PASS. The article's 3 x 5 grid matches
  `README.md`, `docs/design/00-vision.md`, and `R/gllvmTMB.R`; it
  correctly names `phylo_slope()` and `meta_known_V()` as outside-grid
  helpers; it does not introduce method/default claims.
- `git diff --check`: passed.

## Consistency Audit

The article was checked against:

- `README.md` and `docs/design/00-vision.md` for the grid table;
- `R/brms-sugar.R` and `R/gllvmTMB.R` for keyword names and helper
  names;
- `docs/design/02-data-shape-and-weights.md` for long/wide
  `traits(...)` shorthand.

## What Did Not Go Smoothly

The legacy article was mostly reusable, but the port had to narrow its
claim from "all cells are wired in the TMB engine" to a reader-facing
grammar reference. The current article keeps ordinary random intercepts
and outside-grid helpers separate from the 3 x 5 table.

## Team Learning

- **Boole** owns the grammar surface: keep the 3 x 5 grid exact and
  call `phylo_slope()` / `meta_known_V()` helpers outside the grid.
- **Pat** owns reader fit: this is a lookup page, so examples are short
  and routed to worked articles for interpretation.
- **Rose** owns cross-file consistency before publish.

## Known Limitations And Next Actions

The ordinal-probit, mixed-response, profile-CI, and lambda-constraint
Tier-2 ports remain separate queue items. Do not fold them into this
article.
