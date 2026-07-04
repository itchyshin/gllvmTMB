# After-task report: narrow standalone unique example cleanup

Date: 2026-06-18
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This was a small post-coevolution `unique()` deprecation cleanup. It removes
two remaining copy-first public examples that still made ordinary standalone
`unique()` look like new-user syntax.

## Changes

- `R/brms-sugar.R`: removed the legacy standalone `unique(0 + trait | site)`
  worked example from the `indep()` roxygen examples.
- `man/indep.Rd`: regenerated from roxygen.
- `vignettes/articles/functional-biogeography.Rmd`: changed the wide-format
  teaser from `latent() + unique()` to default `latent()` alone.
- `docs/dev-log/check-log.md`, `docs/dev-log/dashboard/status.json`, and
  `docs/dev-log/dashboard/sweep.json`: recorded the slice.

## Article-tier audit

The functional-biogeography page remains an internal article surface in the
current cleanup lane. This edit is a tiny consistency correction, not a tier
promotion or public-navigation change.

## Verification

- `parse("R/brms-sugar.R"); devtools::document(quiet = TRUE)` passed.
- `rmarkdown::render("vignettes/articles/functional-biogeography.Rmd", output_file = tempfile(fileext = ".html"), quiet = TRUE)`
  passed.
- `devtools::test(filter = "canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")`
  passed with three expected INLA skips.
- `pkgdown::check_pkgdown()` passed.
- Focused stale-copy scan for the removed `unique()` example and wide teaser
  returned no hits.
- `git diff --check` passed.
- Final latest-tree `devtools::check(args = "--no-manual", quiet = TRUE)`
  completed with `0 errors`, `1 warning`, and `0 notes`; the warning is the
  known local Apple clang / R-header install warning class.

## Not claimed

- No `unique()` removal.
- No source-specific/kernel latent-Psi fold.
- No broad article rewrite.
- No bridge completion, release readiness, or scientific coverage completion.
