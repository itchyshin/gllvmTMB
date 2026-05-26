# Psychometrics IRT Preview Figure And Scope Repair

**Date:** 2026-05-26  
**Branch:** `codex/psychometrics-irt-figure-scope-2026-05-26`  
**Lead:** Ada / Codex  
**Standing perspectives:** Pat, Rose, Florence, Shannon  
**Spawned subagents:** none

## Claim

The `psychometrics-irt` preview article now has a register-backed scope
boundary and an accessible rendered correlation heatmap, without
claiming that the full M2.5 binary-IRT rewrite is complete.

## Files Touched

- `vignettes/articles/psychometrics-irt.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-26-psychometrics-irt-figure-scope.md`

No package code, roxygen, generated Rd, `_pkgdown.yml`, validation-debt
register rows, structural-slope files, or lambda-constraint files changed.

## Article Changes

- Added a scope boundary below the existing Preview banner:
  - **IN:** long-format Gaussian + binary CFA examples using FAM-02,
    MIX-01 / MIX-02, LAM-03, and EXT-27.
  - **PARTIAL:** the broader M2.5 teaching surface, including the live
    `mirt` comparator chunk, the "Stay Laplacian" pedagogy note, and
    final binary-IRT rewrite.
  - **DEFERRED:** polytomous mixed-family IRT examples while FAM-14
    remains partial, plus modification-index workflows.
- Added `fig.cap` and `fig.alt` to the exploratory item-correlation
  heatmap.
- Suppressed the helper's internal "Heatmaps do not display uncertainty
  intervals" caption for this article.

The existing M2.5 Preview banner remains. This is a pre-rewrite repair,
not the M2.5 re-authoring slice.

## Verification

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/psychometrics-irt", lazy = FALSE, new_process = FALSE, quiet = TRUE)'`
  -> wrote `pkgdown-site/articles/psychometrics-irt.html`.
- `Rscript --vanilla -e 'library(xml2); html <- read_html("pkgdown-site/articles/psychometrics-irt.html"); imgs <- xml_find_all(html, "//img[contains(@src, \"sigma-exp-corr-1.png\")]"); stopifnot(length(imgs) == 1L); alt <- xml_attr(imgs, "alt"); stopifnot(!is.na(alt), nzchar(alt)); cap <- xml_text(xml_find_first(html, "//img[contains(@src, \"sigma-exp-corr-1.png\")]/following-sibling::p[contains(@class, \"caption\")][1]")); stopifnot(grepl("Exploratory item correlations", cap)); stopifnot(!grepl("Heatmaps do not display uncertainty intervals", readLines("pkgdown-site/articles/psychometrics-irt.html"), fixed = TRUE)); cat("irt heatmap alt chars=", nchar(alt), "\ncaption=", trimws(cap), "\n")'`
  -> heatmap alt text length 270; caption present; helper caption absent.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## Stale-Wording And Register Scans

- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" vignettes/articles/psychometrics-irt.Rmd pkgdown-site/articles/psychometrics-irt.html`
  -> no hits.
- `rg -n "gllvmTMB\\(" vignettes/articles/psychometrics-irt.Rmd pkgdown-site/articles/psychometrics-irt.html`
  -> all long-format `gllvmTMB()` calls in source include `trait = "trait"`;
  the wide Gaussian sub-fit intentionally uses the `traits(...)` LHS.
- `rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|meta_known_V|gllvmTMB_wide|trio|profile-likelihood default" vignettes/articles/psychometrics-irt.Rmd pkgdown-site/articles/psychometrics-irt.html`
  -> no hits.
- `rg -n "FAM-02|FAM-14|MIX-01|MIX-02|LAM-03|EXT-27|M2.5|Scope boundary" vignettes/articles/psychometrics-irt.Rmd pkgdown-site/articles/psychometrics-irt.html docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md docs/design/41-binary-completeness.md`
  -> article row IDs and M2.5 deferral language match the register and
  rewrite-prep contract.

## Review Gates

- **Pat / article-tier:** WARN-PASS. The article remains Preview-gated,
  not fully restored, but the new scope boundary tells an applied reader
  what can and cannot be treated as validated today.
- **Rose / pre-publish:** PASS. The new claims map to FAM-02, MIX-01,
  MIX-02, LAM-03, EXT-27, and FAM-14. The M2.5 banner remains.
- **Florence / figure:** PASS for the touched heatmap. The plot is
  readable at pkgdown size, now has non-empty rendered alt/caption, and
  no longer shows the helper's internal caveat caption.
- **Shannon / coordination:** PASS. Open PR #275 touches only
  `vignettes/articles/lambda-constraint.Rmd`; open PR #277 touches only
  `docs/design/55-structural-slope-grammar.md`. This branch touches
  neither surface.

## Definition Of Done Notes

- Implementation: documentation-only article change; no package code.
- Simulation recovery: not applicable; no new family, keyword,
  likelihood, estimator, or formula grammar.
- Documentation: article updated and rendered locally.
- Runnable example: existing article chunks still render.
- Check log: appended in this PR.
- Scope review: Pat, Rose, Florence, and Shannon checks recorded above.

## Deliberately Not Run

- No `devtools::document()`; roxygen and Rd files were not changed.
- No full `devtools::test()`; no package code or tests changed, and the
  rendered article exercised the touched article path.
- No `devtools::check(args = "--no-manual")`; this branch should use the
  ordinary PR R-CMD-check if GitHub attaches checks.
- No Preview-banner removal, live `mirt` comparator chunk, or full M2.5
  reauthoring.
- No edits to PR #275 lambda-constraint files or PR #277 Design 55 files.
