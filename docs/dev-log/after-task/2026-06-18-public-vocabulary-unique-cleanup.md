# Public Vocabulary Unique Cleanup

Date: 2026-06-18 23:25 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Continue the post-coevolution `unique()` deprecation cleanup on public prose and
reference topics. A few passages still taught the ordinary diagonal `Psi`
component as something the `unique()` keyword itself supplies, rather than
teaching default ordinary `latent()` and standalone `indep()` first.

## Changed

- Updated `vignettes/articles/gllvm-vocabulary.Rmd` so the `Psi` definition
  says ordinary `latent()` includes the diagonal companion by default, while
  `unique()` remains compatibility spelling for explicit `Psi`.
- Updated `vignettes/articles/profile-likelihood-ci.Rmd` so the fallback note
  describes shared `latent()` axes plus diagonal `Psi`, not a factor model on
  top of `unique()`.
- Updated `R/extract-repeatability.R` and regenerated
  `man/extract_repeatability.Rd` so repeatability documentation describes
  unit- and observation-level diagonal variance components, with default
  `latent()` / explicit `indep()` as new ordinary syntax and `unique()` as
  compatibility.
- Updated `R/simulate-unit-trait.R` and regenerated
  `man/simulate_unit_trait.Rd` so helper output no longer describes
  `unit_observation` as matching gllvmTMB's `unique()` grouping contract.

Article-tier audit: `gllvm-vocabulary` and `profile-likelihood-ci` received
narrow consistency repairs only; no tier change.

## Verification

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `extract_repeatability.Rd` and `simulate_unit_trait.Rd`.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/gllvm-vocabulary", "articles/profile-likelihood-ci")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> rendered both articles.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-repeatability|profile-derived|simulate-unit-trait|example", reporter = "summary")'`
  -> passed; expected heavy skips reported, and the broad `example` filter
  surfaced two lifecycle warnings from the intentional legacy covariance-edge
  compatibility fixture.
- `rg -n -F 'The `unique()` keyword in the formula estimates this' R vignettes man README.md NEWS.md docs/design || true; rg -n -F 'factor model on top of `unique()`' R vignettes man README.md NEWS.md docs/design || true; rg -n -F 'unique(0 + trait | <unit>)' R vignettes man README.md NEWS.md docs/design || true; rg -n -F 'unit_observation` -- the row id matching gllvmTMB' R vignettes man README.md NEWS.md docs/design || true; rg -n -F "unit_observation} -- the row id matching gllvmTMB" R vignettes man README.md NEWS.md docs/design || true`
  -> no hits.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## Definition-Of-Done Notes

- Implementation: documentation/prose only; no behavior changed.
- Simulation recovery: not applicable.
- Documentation: roxygen/Rd regenerated; both articles rendered.
- Runnable example: existing examples remain in place and now use the updated
  ordinary syntax where touched.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: lifecycle and article-tier guidance applied. No formula grammar,
  likelihood, or TMB parameterization changed.

Still not claimed: keyword removal, source-specific/kernel latent-Psi folding,
Paper 2 multi-kernel explicit-Psi support, bridge completion, release
readiness, or scientific coverage completion.
