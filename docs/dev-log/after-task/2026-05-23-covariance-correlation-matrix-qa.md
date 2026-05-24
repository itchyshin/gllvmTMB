# After Task: Covariance/Correlation Matrix QA

**Branch**: `codex/covariance-correlation-matrix-qa-2026-05-23`
**Date**: `2026-05-23`
**Roles (engaged)**: Ada, Florence, Pat, Grace, Rose

## 1. Goal

Put the supported `plot_correlations()` estimate/interval matrix into
the public covariance/correlation article, so readers see the same
row-first matrix display now used in Get Started.

## 1a. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, pkgdown navigation, README, or NEWS change. The article
now displays already-supplied correlation point estimates and
Fisher-z interval bounds from `extract_correlations()`; the plot does
not compute new intervals or change the fitted model.

## 2. Implemented

- `vignettes/articles/covariance-correlation.Rmd` now calls
  `plot_correlations(corr_B, style = "heatmap", matrix_layout = "estimate_ci")`
  in the report-surface correlation example.
- The rendered figure uses a short plot caption so the PNG does not
  clip text at the article's figure size.
- The article now states the EXT-30 boundary next to the example:
  matrix plotting displays supplied rows and interval columns; it does
  not compute or calibrate uncertainty.

## 3. Files Changed

- Public article: `vignettes/articles/covariance-correlation.Rmd`.
- Dev log: `docs/dev-log/check-log.md`.
- After-task report:
  `docs/dev-log/after-task/2026-05-23-covariance-correlation-matrix-qa.md`.

No generated pkgdown files or article PNGs were committed. The rendered
`pkgdown-site/articles/covariance-correlation.html` and PNG were used
for QA only.

## 3a. Decisions and Rejected Alternatives

Decision: replace the older pairwise interval plot with the matrix
layout in this report-surface section.

Rationale: the article is about covariance/correlation matrices, and
the new matrix layout lets readers see point estimates and finite
interval bounds in the same trait-by-trait surface without hand-indexing
matrix cells.

Rejected alternative: keep the pairwise interval plot in this section
and only mention the matrix layout elsewhere. That would leave the
visible article one step behind the supported EXT-30 plotting surface.

## 4. Checks Run

- `gh run watch 26351959053 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> post-merge `main` CI for PR #241 passed on macOS in 25m03s,
  Ubuntu in 27m31s, and Windows in 36m51s.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"` -> only the merged
  Get Started PR #241, merged correlation-matrix PR #240, and their
  source-branch commits were in the recent lane.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("covariance-correlation", quiet = FALSE, new_process = FALSE)'`
  -> failed with `Can't find article 'covariance-correlation'`.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", quiet = FALSE, new_process = FALSE)'`
  -> completed; `pkgdown-site/articles/covariance-correlation.html`
  was created.
- Florence visual QA via
  `view_image("/Users/z3437171/Dropbox/Github Local/gllvmTMB/pkgdown-site/articles/covariance-correlation_files/figure-html/communality-correlation-matrix-1.png")`
  -> first render failed/warned because the default plot caption
  clipped; rerender after adding a shorter caption passed for legible
  labels, stable triangle meanings, readable legend, and no overlap.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pc <- formals(plot_correlations); ec <- formals(extract_correlations); stopifnot(identical(eval(pc$matrix_layout), c("by_level", "estimate_ci", "levels"))); stopifnot(identical(eval(pc$style), c("interval", "eye", "raindrop", "heatmap", "ellipse", "oval"))); stopifnot(identical(eval(ec$method), c("fisher-z", "profile", "wald", "bootstrap"))); writeLines("Rose covariance article formals check ok")'`
  -> `Rose covariance article formals check ok`.
- `rg -n "gllvmTMB\\(" vignettes/articles/covariance-correlation.Rmd`
  -> long-format examples pass `trait =`; wide-format examples use
  `traits(...)` and no `trait =`.
- `rg -n "EXT-30|matrix_layout|estimate_ci|plot does not compute|Latent \\+ unique trait correlations|Upper-triangle cells" vignettes/articles/covariance-correlation.Rmd pkgdown-site/articles/covariance-correlation.html`
  -> source and rendered HTML both contain the EXT-30 boundary and the
  new matrix layout.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(" vignettes/articles/covariance-correlation.Rmd`
  -> no matches.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "covariance correlation matrix OR plot_correlations matrix OR EXT-30 OR Article surface reset" --json number,title,url,labels,updatedAt --limit 20`
  -> found #230.
- `git diff --check` -> clean.

## 5. Tests of the Tests

No tests were added or modified. This is an article-only teaching-path
change. The executable guard is the touched article render, which would
fail if the example code or arguments were unsupported.

## 6. Consistency Audit

Rose verdict: PASS.

- Method/default claims: source formals and touched article wording
  agree on `fisher-z`, `style = "heatmap"`, and
  `matrix_layout = "estimate_ci"`.
- Scope-boundary claim: EXT-30 is the relevant covered register row for
  matrix-style `plot_correlations()` displays; EXT-04 covers the
  `extract_correlations()` interval source.
- Stale-wording scan found no legacy `S_B` / `S_W`, deprecated primary
  syntax, primary `gllvmTMB_wide()`, or profile-default wording in the
  touched article.
- Convention-change cascade: not applicable. No argument name, keyword
  default, function signature, or syntax requirement changed.

## 7. Roadmap Tick

N/A. This slice does not change ROADMAP status. It advances the
reader-facing follow-through for EXT-30 and the broader article surface
reset.

## 7a. GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling gate".
  This slice advances that issue by replacing an older pairwise plot in
  a visible Tier-1 article with the supported EXT-30 matrix display.
- No issue was closed. #230 remains broader than this single article
  update.

## 8. What Did Not Go Smoothly

The first article render used the bare slug
`pkgdown::build_article("covariance-correlation")`; pkgdown rejected it.
The corrected path is
`pkgdown::build_article("articles/covariance-correlation")`.

The first rendered matrix exposed a Florence issue: the helper's default
caption was too long for this article figure size and clipped at the
PNG edge. The article now passes a shorter plot caption.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept this as a one-article follow-through slice after the Get
Started PR merged and waited for `main` CI before opening another lane.

Florence: matrix labels can be technically correct but still fail if
captions clip in the rendered PNG; visual QA needs the actual article
asset, not only source review.

Pat: the covariance/correlation article is a natural place for the
matrix surface because readers arrive thinking in matrices rather than
only pairwise rows.

Grace: for this doc-only slice, the useful local gates were the touched
article render, rendered PNG inspection, `pkgdown::check_pkgdown()`, and
then PR CI.

Rose: the EXT-30 boundary belongs beside the public example that
advertises the display, even though the plotting helper itself already
documents the same limitation.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- The matrix display still shows supplied intervals only; it does not
  compute or calibrate uncertainty.
- The broader #230 article surface reset remains open.
- Next safest action: push this branch, open a narrow article PR, and
  let CI validate it before merge.
