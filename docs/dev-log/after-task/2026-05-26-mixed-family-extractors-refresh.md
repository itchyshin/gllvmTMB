# Mixed-Family Extractors Article Refresh

**Date:** 2026-05-26  
**Branch:** `codex/mixed-family-extractors-refresh-2026-05-26`  
**Lead:** Ada / Codex  
**Standing perspectives:** Pat, Rose, Florence, Shannon  
**Spawned subagents:** none

## Claim

The mixed-family extractors article now states its validation boundary,
shows `diagnostic_table()` output before interpretation, gives the main
heatmap a rendered caption and alt text, and records that mixed-family
delta / hurdle latent-scale correlations remain blocked under MIX-10.

## Files Touched

- `vignettes/articles/mixed-family-extractors.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-26-mixed-family-extractors-refresh.md`

No package code, roxygen, generated Rd, `_pkgdown.yml`, or validation-debt
register rows changed.

## Article Changes

- Added the AGENTS.md scope-boundary statement:
  - **IN:** long-format mixed-family fits with latent residual scales
    backed by MIX-01..MIX-09 and `diagnostic_table()` extraction backed
    by DIA-13.
  - **PARTIAL:** profile / bootstrap uncertainty on mixed-family targets
    backed by CI-10 / EXT-04.
  - **BLOCKED:** delta / hurdle mixed-family latent-scale correlations
    backed by MIX-10.
- Added a long-format-only note because the teaching fixture uses
  per-row `family_var` dispatch. A wide-data companion needs a separate
  family-by-trait teaching fixture before it can be shown honestly.
- Added a diagnostic-status chunk using:

```r
rq_resid <- residuals(fit, type = "randomized_quantile", seed = 1)
gllvmTMB::diagnostic_table(rq_resid, table = "row_status")
gllvmTMB::diagnostic_table(rq_resid, table = "fit_health_status")
```

- Added `fig.cap` and `fig.alt` to the mixed-family correlation heatmap
  and suppressed the helper's internal "Heatmaps do not display
  uncertainty intervals" caption for this article.
- Reworded the uncertainty section so Fisher-z and bootstrap are named
  as the two total-Sigma routes shown in the article. The profile path
  remains described as a different shared-factor target rather than a
  total-Sigma substitute.
- Added the MIX-10 blocked row to the article's coverage table.

## Verification

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); fixture <- gllvmTMB:::load_mixed_family_fixture(n_families = 3L); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1), data = fixture$data, trait = "trait", family = fixture$family_list); rq_resid <- residuals(fit, type = "randomized_quantile", seed = 1); print(diagnostic_table(rq_resid, table = "row_status")); print(diagnostic_table(rq_resid, table = "fit_health_status"))'`
  -> row-status table returned `ok = 120` and `unsupported_family = 60`;
  fit-health table returned `PASS = 11`, `WARN = 1`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", lazy = FALSE, new_process = FALSE, quiet = TRUE)'`
  -> wrote `pkgdown-site/articles/mixed-family-extractors.html`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'library(xml2); html <- read_html("pkgdown-site/articles/mixed-family-extractors.html"); imgs <- xml_find_all(html, "//img[contains(@src, \"corr-1.png\")]"); stopifnot(length(imgs) == 1L); alt <- xml_attr(imgs, "alt"); stopifnot(!is.na(alt), nzchar(alt)); cap <- xml_text(xml_find_first(html, "//img[contains(@src, \"corr-1.png\")]/following-sibling::p[contains(@class, \"caption\")][1]")); stopifnot(grepl("Mixed-family latent-scale trait correlations", cap)); stopifnot(!grepl("Heatmaps do not display uncertainty intervals", readLines("pkgdown-site/articles/mixed-family-extractors.html"), fixed = TRUE)); cat("corr alt chars=", nchar(alt), "\ncaption=", trimws(cap), "\n")'`
  -> heatmap alt text length 275; caption present; helper caption absent.

Plain `pkgdown::build_article("articles/mixed-family-extractors", lazy =
FALSE)` failed before the source-loaded render because the local installed
package did not yet export `diagnostic_table()`. Source `NAMESPACE` does
export it, and `devtools::load_all()` confirmed `gllvmTMB::diagnostic_table`
resolves from the current source namespace.

## Stale-Wording And Register Scans

- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> no hits.
- `rg -n "gllvmTMB\\(" vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> the long-format call includes `trait = "trait"` in the article source.
- `rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|meta_known_V|gllvmTMB_wide|trio|profile-likelihood default" vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> no hits.
- `rg -n "in prep|in preparation" vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html`
  -> no hits.
- `rg -n "MIX-10|DIA-13|CI-10|EXT-04|MIX-0[1-9]|MIS-05|Scope boundary" vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/mixed-family-extractors.html docs/design/35-validation-debt-register.md`
  -> article row IDs match the validation-debt register.

## Review Gates

- **Pat / article-tier:** PASS. This remains a Tier-1 worked example.
  The wide companion is explicitly deferred because the current fixture
  is per-row mixed-family dispatch.
- **Rose / pre-publish:** PASS. New public claims map to MIX-01..MIX-10,
  DIA-13, EXT-04, CI-10, and MIS-05. No stale aliases or unsupported
  delta / hurdle claim were found.
- **Florence / figure:** PASS. The heatmap is readable at pkgdown size,
  has a non-empty rendered caption and alt text, and no longer shows the
  helper's internal uncertainty-caveat caption in the article.
- **Shannon / coordination:** PASS. Open PR #275 touches only
  `vignettes/articles/lambda-constraint.Rmd`; no overlap with this
  article branch. No structural-slope A0/A1 files were touched.

## Definition Of Done Notes

- Implementation: documentation-only article change; no package code.
- Simulation recovery: not applicable; no new likelihood, keyword,
  estimator, or formula grammar.
- Documentation: article updated and rendered locally.
- Runnable example: existing mixed-family fixture still runs in the
  article; diagnostic table chunk renders from the fitted object.
- Check log: appended in this PR.
- Scope review: Rose / Pat / Florence / Shannon checks recorded above.

## Deliberately Not Run

- No `devtools::document()`; roxygen and Rd files were not changed.
- No full `devtools::test()`; no package code or tests changed, and the
  diagnostic smoke plus article render exercised the touched article
  path.
- No `devtools::check(args = "--no-manual")`; this branch should use the
  ordinary PR R-CMD-check if GitHub attaches checks.
- No `_pkgdown.yml` change and no article-tier promotion.
- No edits to `vignettes/articles/lambda-constraint.Rmd` while PR #275 is
  open.
- No structural-slope parser, TMB, or Design 55 edits; Claude/CLO owns
  A0/A1 of that plan.
