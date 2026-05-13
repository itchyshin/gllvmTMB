# After-Task: Ordinal-Probit Tier-2 Reference

## Goal

Add a compact Tier-2 article for `ordinal_probit()` that explains the
threshold-trait scale, cutpoint convention, and extractor
interpretation without turning the page into a simulation study.

## Scope

This task adds one article:

- `vignettes/articles/ordinal-probit.Rmd`

Supporting hygiene updates are limited to `_pkgdown.yml`, `NEWS.md`,
`vignettes/articles/response-families.Rmd`, the `extract_cutpoints()`
example, and `docs/dev-log/check-log.md`.

## Reader And Tier

The reader is an applied or methods user with ordered categorical
traits who needs to know whether `ordinal_probit()` is the right
family and how to interpret its variance scale. Tier 2 is justified
because the page is a technical family reference, not a new worked
biological example.

## Contract

The article must match current source behavior:

- `ordinal_probit()` uses a probit threshold model with latent
  residual variance `sigma_d^2 = 1`;
- categories are integer-coded `1, ..., K`;
- `tau_1 = 0` is fixed, so a `K`-category trait estimates `K - 2`
  free cutpoints;
- `K = 2` reduces exactly to `binomial(link = "probit")`;
- observation-level `unique()` residuals are mapped off for
  ordinal-probit traits.

No family implementation, likelihood parameterisation, formula
grammar, or exported API changed.

## Checks Run

Before editing:

- `git status --short --branch` showed clean `main`.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json ...`
  initially showed PRs #47, #48, and #49. None touched
  `_pkgdown.yml`, `NEWS.md`, or
  `vignettes/articles/ordinal-probit.Rmd`; PR #48 touched public prose
  in README/design files but not this article. The final recheck
  showed #48 and #50 open; neither touches this branch's files.
- `git log --all --oneline --since="6 hours ago"` confirmed PR #46
  had merged and local `main` had been fast-forwarded.

Final validation:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  and regenerated only `man/extract_cutpoints.Rd`;
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  pkgdown::build_article("articles/ordinal-probit", new_process =
  FALSE); pkgdown::build_article("articles/response-families",
  new_process = FALSE)'` completed with only the existing `../logo.png`
  pkgdown warning;
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with "No
  problems found";
- `Rscript --vanilla -e 'devtools::test(filter =
  "ordinal-probit|traits-keyword")'` passed with `FAIL 0 | WARN 0 |
  SKIP 1 | PASS 74`; the skip is the existing fixed-effect-only
  fallback skip in `test-traits-keyword.R`.

## Consistency Audit

The article was checked against:

- `R/families.R` for the family constructor documentation;
- `R/fit-multi.R` for category validation, `K = 2`, and OLRE mapping;
- `R/extract-cutpoints.R` for the cutpoint return convention;
- `R/extract-sigma.R` for the exact `sigma_d^2 = 1` link residual;
- `tests/testthat/test-ordinal-probit.R` and
  `tests/testthat/test-mixed-family-olre.R` for recovery and guardrail
  coverage.

## Known Limitations And Next Actions

The article is intentionally not a live simulation vignette. The
simulation evidence remains in the test suite; a later Tier-1 article
could show an applied ordinal threshold-trait workflow if needed.
