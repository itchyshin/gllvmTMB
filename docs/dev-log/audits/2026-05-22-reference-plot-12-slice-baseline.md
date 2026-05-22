# Reference and plotting 12-slice baseline

Date: 2026-05-22 11:39 MDT
Branch: `codex/reference-function-audit-2026-05-22`
Status at baseline: clean working tree, `ahead 30` of `origin/main`

## Shannon checkpoint

Verdict: WARN

The branch is internally consistent and the working tree was clean before this
12-slice continuation. There were no open GitHub pull requests at the time of
the audit, so there is no active PR-file overlap to coordinate. Recent GitHub
Actions on `main` were green for both `R-CMD-check` and `pkgdown` at
`c1dc2e4`.

The warning is scope size rather than conflict: the branch already contains 30
local commits and touches many generated Rd files, tests, plotting helpers,
NEWS, design docs, and after-task reports. The next safe action is to finish
only bounded polish/validation slices, then run Rose/Shannon again before any
push or PR update.

## Rose pre-publish scan

Verdict: WARN

The primary confidence-eye wording now appears in NEWS, the plot contract, and
the validation-debt register. The remaining visible stale public example is in
`vignettes/articles/morphometrics.Rmd`, where the article still calls
`plot_correlations(..., style = "raindrop")`. That call is supported by the
compatibility alias, but it teaches the old name. The next slice should switch
the visible example to `style = "eye"` while keeping alias tests in place.

The scan also found old `Phase 1c-viz` wording in
`docs/design/46-visualization-grammar.md`. That appears to be historical design
context rather than a current reference claim, but it should be addressed in a
separate design-led visual-roadmap update if the figure-roadmap language is
refreshed.

## Grace baseline

Verdict: PASS for focused local checks

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned `No problems
  found.`
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables|plot-gllvmTMB|suggest-lambda-constraint", stop_on_failure = TRUE)'`
  returned 444 passes, 0 failures, 0 warnings, 0 skips.
- `git diff --check` was clean.

Full `devtools::test()`, `devtools::check()`, and 3-OS CI were not run at this
baseline.

## Active lenses

- Ada: keep the continuation bounded and reviewable.
- Shannon: branch/process state and PR overlap.
- Rose: public wording, validation-register consistency, stale names.
- Grace: pkgdown and focused local test surface.
- Florence: confidence-eye and ordination visual honesty.
- Pat: user-facing examples should teach the name users should type.

## Next safe slices

1. Switch the visible morphometrics example to `style = "eye"`.
2. Strengthen confidence-eye visual tests around the preferred attribute and
   hollow estimate marker.
3. Clarify rotation/standardized-loading prose for reference users.
4. Refresh visual-debt wording around rendered figure QA / snapshots.
5. Run a final PR-readiness scan before any push or PR update.
