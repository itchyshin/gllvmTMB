# After Task: Get Started Correlation Matrix QA

**Branch**: `codex/get-started-correlation-matrix-qa-2026-05-23`
**Date**: `2026-05-23`
**Roles (engaged)**: Ada, Florence, Pat, Grace, Rose

## 1. Goal

Put the newly merged correlation matrix display into the public Get
Started path, so readers see the supported `plot_correlations()` matrix
workflow rather than an older `extract_Sigma_table()` plus
`plot_Sigma_heatmap()` workaround.

## 1a. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, pkgdown navigation, README, or NEWS change. The vignette
now displays already-supplied correlation estimates and finite
Fisher-z interval bounds; it does not compute new intervals or change
the model fit.

## 2. Implemented

- `vignettes/gllvmTMB.Rmd` now calls
  `plot_correlations(corr_rows, style = "heatmap", matrix_layout = "estimate_ci")`
  for the matrix example.
- The chunk dimensions were widened to keep lower-triangle interval
  labels readable in the rendered article.
- The vignette text now states the EXT-30 IN/OUT boundary: matrix
  plotting displays supplied estimates and finite interval bounds, but
  does not calibrate uncertainty.

## 3. Files Changed

- Public vignette: `vignettes/gllvmTMB.Rmd`.
- Dev log: `docs/dev-log/check-log.md`.
- After-task report:
  `docs/dev-log/after-task/2026-05-23-get-started-correlation-matrix-qa.md`.

No generated vignette PNGs were committed. The rendered
`pkgdown-site/articles/gllvmTMB.html` output was used for QA only.

## 3a. Decisions and Rejected Alternatives

Decision: keep the Get Started matrix example row-first by reusing
`corr_rows` from `extract_correlations()`.

Rationale: the adjacent pairwise plot and matrix plot now share one
extractor output, which is easier for applied readers to copy and makes
the uncertainty source explicit.

Rejected alternative: keep `extract_Sigma_table()` in this section and
tell readers to use the pairwise table for intervals. That hid the new
EXT-30 capability and split one teaching path across two row schemas.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"` -> only the merged
  correlation-matrix PR #240 and its source branch commits were in the
  recent lane.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("gllvmTMB", quiet = FALSE, new_process = FALSE)'`
  -> completed; `pkgdown-site/articles/gllvmTMB.html` was created.
- Florence visual QA via
  `view_image("/Users/z3437171/Dropbox/Github Local/gllvmTMB/pkgdown-site/articles/cor-matrix-1.png")`
  -> PASS for legible labels, stable triangle meanings, readable legend,
  and no overlap in the rendered matrix image.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pc <- formals(plot_correlations); ec <- formals(extract_correlations); stopifnot(identical(eval(pc$matrix_layout), c("by_level", "estimate_ci", "levels"))); stopifnot(identical(eval(pc$style), c("interval", "eye", "raindrop", "heatmap", "ellipse", "oval"))); stopifnot(identical(eval(ec$method), c("fisher-z", "profile", "wald", "bootstrap"))); writeLines("Rose method/default/formals check ok")'`
  -> `Rose method/default/formals check ok`.
- `rg -n "gllvmTMB\\(" vignettes/gllvmTMB.Rmd` -> wide call uses the
  `traits(...)` formula object and no `trait =`; long call passes
  `trait = morph$fit_args$trait`.
- `rg -n "EXT-30|matrix_layout|estimate_ci|calibrate uncertainty|finite Fisher-z interval" vignettes/gllvmTMB.Rmd pkgdown-site/articles/gllvmTMB.html`
  -> source and rendered HTML both contain the EXT-30 boundary and
  `estimate_ci` layout.
- `rg -n "method *=|default|fisher-z|profile|wald|bootstrap|matrix_layout|estimate_ci|plot_correlations|extract_correlations" R/plot-covariance-tables.R vignettes/gllvmTMB.Rmd man/plot_correlations.Rd man/extract_correlations.Rd docs/design/35-validation-debt-register.md`
  -> touched prose aligns with source formals, generated Rd, and the
  validation-debt register.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(" vignettes/gllvmTMB.Rmd`
  -> no matches.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "Get Started correlation matrix OR plot_correlations matrix OR EXT-30 OR Article surface reset" --json number,title,url,labels,updatedAt --limit 20`
  -> found #230.
- `git diff --check` -> clean.
- `git ls-files --others --exclude-standard` -> no untracked files after
  transient vignette PNG cleanup.

## 5. Tests of the Tests

No tests were added or modified. This is a vignette-only teaching-path
change. The executable guard is the touched article render, which
would fail if the example code or arguments were unsupported.

## 6. Consistency Audit

Rose verdict: PASS.

- Method/default claims: source formals, generated Rd, and touched
  vignette wording agree on `fisher-z`, `profile`, `wald`, `bootstrap`,
  `style = "heatmap"`, and `matrix_layout = "estimate_ci"`.
- Scope-boundary claim: EXT-30 is the relevant covered register row for
  matrix-style `plot_correlations()` displays; EXT-04 covers
  `extract_correlations()` methods.
- Stale-wording scan found no legacy `S_B` / `S_W`, deprecated primary
  syntax, primary `gllvmTMB_wide()`, or profile-default wording in the
  touched vignette.
- Convention-change cascade: not applicable. No argument name, keyword
  default, function signature, or syntax requirement changed.

## 7. Roadmap Tick

N/A. This slice does not change ROADMAP status. It advances the
reader-facing follow-through for EXT-30 after PR #240.

## 7a. GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling gate".
  This slice advances that issue by replacing an older matrix workaround
  in the Get Started article with the supported EXT-30 matrix display.
- No issue was closed. #230 remains broader than this single vignette
  update.

## 8. What Did Not Go Smoothly

The first Rose formals check asserted the wrong order for
`extract_correlations(method = ...)`. The source order is
`c("fisher-z", "profile", "wald", "bootstrap")`; the check was rerun
with that order and passed. This was an audit-command error, not a
package failure.

The article render creates transient PNGs under `vignettes/`. They were
removed before commit because the source `.Rmd` is the tracked
artifact.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the slice to one public vignette and avoided changing the
plot helper after the implementation PR had already merged.

Florence: the figure needs chunk dimensions large enough for interval
labels, not only a correct plotting call.

Pat: row-first teaching is clearer here: readers create
`corr_rows` once, inspect it as a table, then reuse it for both the
pairwise and matrix displays.

Grace: local validation is render-first for this vignette-only slice:
the touched article render and `pkgdown::check_pkgdown()` are the
relevant checks; full package check is deferred to CI.

Rose: public capability prose needs the EXT-30 boundary next to the
example, even when the capability was implemented in a previous PR.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- The matrix display still shows supplied intervals only; it does not
  compute or calibrate uncertainty.
- The broader #230 article surface reset remains open.
- Next safest action: after the post-merge `main` R-CMD-check for PR
  #240 passes, push this branch, open a narrow vignette PR, and let
  CI validate it before merge.
