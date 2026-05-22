# After-task report: Symbol-to-syntax alignment first pass

Date: 2026-05-21
Branch: `codex/symbol-syntax-alignment-2026-05-21`
Issue: #230

## Purpose

Reintroduce enough mathematical notation in the visible public articles to
help users connect model symbols to R syntax, without turning the reset site
back into an equation wall.

This slice targets the first pass of roadmap Slice 12: pair each central
equation with defined symbols, the matching R formula or extractor, and a
plain-language interpretation.

## Files changed

- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/convergence-start-values.Rmd`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-symbol-syntax-alignment.md`

## Review lenses

- Ada: kept the slice narrow and waited for PR #232 to merge before touching
  shared ledger files.
- Boole: checked that formula syntax and extractor calls are explicit.
- Noether: checked that `Sigma`, `Lambda`, `Psi`, and `psi` remain aligned.
- Pat: kept each table readable for applied users.
- Rose: ran stale-wording scans for legacy `S`/`s`, `two-U`, and
  `gllvmTMB_wide` wording.
- Grace: checked pkgdown configuration and targeted article rendering.

## What changed

`covariance-correlation` now defines `level`, `Lambda`,
`Lambda Lambda^T`, `Psi` / `psi_tt`, `Sigma`, and `R` beside the
corresponding formula terms and extractor calls. The communality section now
states which extractor output supplies the numerator and denominator.

`api-keyword-grid` now has a mode-to-math table that pairs long syntax, wide
`traits(...)` syntax, and the mathematical covariance target for `latent`,
`unique`, `latent + unique`, `indep`, and `dep`.

`convergence-start-values` now starts its small-model example with a compact
`Lambda` / `Psi` / `Sigma` alignment table before diagnostics and start-value
advice.

`ROADMAP.md` records this as a first pass, not a blanket completion claim.
`pitfalls` and `response-families` remain wording-review targets as their
examples are made more systematic.

## Checks

- `Rscript --vanilla -e 'pkgdown::build_article("articles/covariance-correlation")'`
  passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/api-keyword-grid")'`
  passed.
- `Rscript --vanilla -e 'pkgload::load_all(export_all = FALSE); stopifnot(exists("check_gllvmTMB")); pkgdown::build_article("articles/convergence-start-values", new_process = FALSE)'`
  passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed.
- `git diff --check` passed.
- `rg -n "diag\\(S\\)|diag\\(s\\)|boldsymbol\\{S\\}|gllvmTMB_wide|two-U" vignettes/articles/covariance-correlation.Rmd vignettes/articles/api-keyword-grid.Rmd vignettes/articles/convergence-start-values.Rmd`
  returned no matches.
- Browser DOM checks confirmed the new alignment blocks rendered in:
  `articles/covariance-correlation.html#the-decomposition`,
  `articles/api-keyword-grid.html#the-five-modes`, and
  `articles/convergence-start-values.html#fit-a-small-model`.

## Not run

- `devtools::document()` was not run because no roxygen or exported API files
  changed.
- `devtools::test()` and `devtools::check()` were not run because the slice is
  article prose only.

## Follow-up

Next infrastructure slice should move to Florence-grade plotting deliberately:
plot helpers need uncertainty-aware variants for loadings, communality,
repeatability, correlation displays, score distributions, and 1D/2D/3D
ordination. That work should not be treated as cosmetic; figures are part of
the model interpretation contract.
