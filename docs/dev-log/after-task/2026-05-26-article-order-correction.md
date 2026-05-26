# Article Order Correction: Binary First, Mixed-Family Later

**Date:** 2026-05-26
**Branch:** `codex/article-binary-lambda-coordination`
**Lead:** Ada / Codex
**Standing perspectives:** Ada, Pat, Fisher, Florence, Rose, Shannon
**Spawned subagents:** none

## Claim

The article queue now records the maintainer's ordering correction:
public expansion is paused; `lambda-constraint` is the next binary
loading-constraint teaching lane; `mixed-family-extractors` and
`psychometrics-irt` remain internal until their separate gates are ready.

## Files Touched

- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md`
- `docs/dev-log/coordination-board.md`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-26-article-order-correction.md`

No package code, roxygen, generated Rd, `_pkgdown.yml`, validation-debt rows,
lambda-constraint article code, Claude/CLO structural-slope files, or PR #279
files were edited.

## What Changed

- Added the 2026-05-26 article-order correction to the live roadmap:
  the public article surface remains `morphometrics`,
  `covariance-correlation`, `api-keyword-grid`, `response-families`,
  `convergence-start-values`, and `pitfalls`.
- Updated the article gate matrix and coordination board with the hard
  coordination note: no public promotion of `mixed-family-extractors`,
  `psychometrics-irt`, or `lambda-constraint` until the binary
  lambda/JSDM plan lands.
- Added a superseding note to the older hidden-article validation map so
  agents do not follow the stale ranked queue out of sequence.
- Marked `mixed-family-extractors` as an internal draft pending a broader
  mixed-response expansion: Gaussian, binomial, Poisson/NB,
  beta/proportion, and blocked delta/hurdle cases.
- Clarified that `psychometrics-irt` is not the final IRT article and
  remains Preview/internal until the binary lambda/JSDM article is coherent
  and the `mirt` comparator path is designed.
- Repaired the psychometrics wording that claimed both data shapes give the
  same fit. The wide code is now described as a Gaussian-only Likert sanity
  check, not the full mixed-family fit.
- Added the figure/model contract: full covariance decomposition or
  communality teaching uses `latent + unique`; latent-only examples say so;
  interval-bearing correlation matrices use
  `plot_correlations(..., style = "heatmap", matrix_layout = "estimate_ci")`,
  while `plot_Sigma_heatmap()` remains point-estimate-only.

## Verification

- `git pull --ff-only`
  -> fast-forwarded local `main` to `8e9d2c4`; this brought in PR #279/#280
  structural-slope design files, which this branch did not edit.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"`
  -> recent history includes PRs #274, #275, #276, #277, #278, #279, and
  #280; this branch does not touch the structural-slope files from #279/#280.
- `gh pr view 279 --repo itchyshin/gllvmTMB --json number,title,headRefName,baseRefName,files,mergeStateStatus,statusCheckRollup,updatedAt,url`
  -> PR #279 files were `docs/design/56-augmented-lhs-engine-stage3.md` and
  `docs/dev-log/audits/2026-05-26-design-55-a1-closeout.md`; not touched here.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/psychometrics-irt", lazy = FALSE, new_process = FALSE, quiet = FALSE); pkgdown::build_article("articles/mixed-family-extractors", lazy = FALSE, new_process = FALSE, quiet = FALSE); pkgdown::build_article("articles/roadmap", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> wrote `pkgdown-site/articles/psychometrics-irt.html`,
  `pkgdown-site/articles/mixed-family-extractors.html`, and
  `pkgdown-site/articles/roadmap.html`.
- `Rscript --vanilla -e 'library(xml2); files <- c("pkgdown-site/articles/psychometrics-irt.html", "pkgdown-site/articles/mixed-family-extractors.html", "pkgdown-site/articles/roadmap.html"); for (f in files) { html <- read_html(f); imgs <- xml_find_all(html, "//img[contains(@src, \"figure-html\")]"); if (length(imgs) == 0L) { cat(f, "figures=0\n"); next }; alts <- xml_attr(imgs, "alt"); bad_alt <- which(is.na(alts) | !nzchar(alts)); caps <- vapply(imgs, function(img) trimws(xml_text(xml_find_first(img, "following-sibling::p[contains(@class, \"caption\")][1]"))), character(1)); bad_cap <- which(!nzchar(caps)); cat(f, "figures=", length(imgs), " bad_alt=", length(bad_alt), " bad_cap=", length(bad_cap), "\n", sep=""); if (length(bad_alt) || length(bad_cap)) stop("Missing alt/caption in ", f) }'`
  -> psychometrics figures=1 bad_alt=0 bad_cap=0; mixed-family figures=1
  bad_alt=0 bad_cap=0; roadmap figures=0.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## Rose Scans

- `rg -n 'Both data shapes give the same fit|same mixed-family fit|full mixed-family CFA.*wide|M2\.5 re-authoring complete|public promotion of|No public promotion|interval-aware correlation matrix|lower triangle carries|point-estimate-only|latent-only|Sigma = shared \+ unique|matrix_layout = "estimate_ci"|plot_Sigma_heatmap\(' ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md docs/dev-log/coordination-board.md vignettes/articles/psychometrics-irt.Rmd vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/psychometrics-irt.html pkgdown-site/articles/mixed-family-extractors.html pkgdown-site/articles/roadmap.html`
  -> confirms the stale "same fit" claim is gone and the new latent-only /
  point-estimate / `estimate_ci` wording appears in source and rendered HTML.
- `rg -n 'upper triangle|lower triangle|interval bounds|interval labels|estimate_ci|plot_correlations\(|plot_Sigma_heatmap\(' vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd README.md ROADMAP.md`
  -> interval-in-matrix displays in Get Started and covariance/correlation use
  `matrix_layout = "estimate_ci"`; touched psychometrics wording explicitly
  says the current heatmap is point-estimate-only and future interval matrices
  should use `estimate_ci`.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S|\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|meta_known_V|gllvmTMB_wide|trio|profile-likelihood default' ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md docs/dev-log/coordination-board.md vignettes/articles/psychometrics-irt.Rmd vignettes/articles/mixed-family-extractors.Rmd pkgdown-site/articles/psychometrics-irt.html pkgdown-site/articles/mixed-family-extractors.html pkgdown-site/articles/roadmap.html`
  -> only historical `gllvmTMB_wide` mentions in the older coordination-board
  timeline; no new/touched public prose uses stale aliases or notation.

## Review Gates

- **Pat / article-tier:** PASS. The public surface remains small; hidden
  articles are not promoted.
- **Fisher:** PASS. The wording separates point-estimate figures from
  interval displays and keeps mixed-family, lambda constraints, and IRT
  comparator claims in separate evidence lanes.
- **Florence:** PASS. Touched rendered article figures have non-empty alt text
  and captions; the matrix-interval display contract now points to
  `plot_correlations(..., matrix_layout = "estimate_ci")`.
- **Rose / pre-publish:** PASS. Capability claims are kept behind internal /
  Preview boundaries, and the stale wide-fit equivalence wording is repaired.
- **Shannon / coordination:** PASS. Open PR census is empty; this branch
  records the article handoff in repo files and avoids PR #279 / structural
  slope files.

## Definition Of Done Notes

- Implementation: documentation/coordination-only; no package code.
- Simulation recovery: not applicable; no new family, keyword, likelihood,
  estimator, or formula grammar.
- Documentation: ROADMAP, article gate matrix, coordination board, hidden
  audit map, and affected internal article sources were updated.
- Runnable example: affected articles rendered locally with source load and
  `new_process = FALSE`.
- Check log: appended in this PR.
- Scope review: Pat, Fisher, Florence, Rose, and Shannon checks recorded
  above.

## Deliberately Not Run

- No `devtools::document()`; roxygen and Rd files were not changed.
- No full `devtools::test()`; no package code or tests changed, and the
  rendered articles exercised the touched article paths.
- No `devtools::check(args = "--no-manual")`; this branch should use ordinary
  PR R-CMD-check if GitHub attaches checks.
- No lambda article re-authoring, no mixed-family expansion, no `mirt`
  comparator work, no `_pkgdown.yml` promotion, no validation-debt status
  change, and no r200 dispatch.
