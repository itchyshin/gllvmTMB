# Codex -> Claude Coordination Note: Lambda Article Boundary Marker

Date: 2026-06-10 10:21:34
Branch: `main`
Author: Codex

## Current Status

Codex has **not** implemented `bootstrap_retention`.

This pass was article-only:

- repaired the public SDM article's loading Confidence Eye display by switching
  the displayed constrained refit to the already-supported
  `profile_retention` path;
- repaired the technical `lambda-constraint-suggest` article's lower
  `profile_retention` Confidence Eye display by marking off-scale Wald rows at
  the plot boundary instead of drawing huge clipped eye polygons;
- kept `bootstrap_retention` documented as planned / queued, not implemented.

## Dirty Tree At Handoff

`git status --short --branch` at note time:

```text
## main...origin/main
 M docs/dev-log/check-log.md
 M vignettes/articles/joint-sdm.Rmd
 M vignettes/articles/lambda-constraint-suggest.Rmd
?? docs/dev-log/after-task/2026-06-10-joint-sdm-confidence-eye-repair.md
?? docs/dev-log/after-task/2026-06-10-lambda-confidence-eye-boundary-marker.md
?? docs/dev-log/recovery-checkpoints/2026-06-10-054926-codex-to-claude-jsdm-handover.md
?? docs/dev-log/recovery-checkpoints/2026-06-10-102134-codex-lambda-boundary-claude-note.md
```

`git diff --stat` at note time, excluding untracked files:

```text
 docs/dev-log/check-log.md                        | 176 +++++++++++++++++++++++
 vignettes/articles/joint-sdm.Rmd                 |  40 +++---
 vignettes/articles/lambda-constraint-suggest.Rmd |  42 +++++-
 3 files changed, 228 insertions(+), 30 deletions(-)
```

## Commands Already Run By Codex

- `air format vignettes/articles/joint-sdm.Rmd`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/joint-sdm", lazy = FALSE, new_process = FALSE)'`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- diagnostic R script comparing `varimax_threshold`, `wald_retention`, and
  `profile_retention` for the SDM article
- `air format vignettes/articles/lambda-constraint-suggest.Rmd`
- diagnostic R cache read confirming the stripe-causing row:
  `B_drought_4` / `LV2`, estimate -56.7155, SE 48.4278, 95 percent Wald CI
  [-151.6323, 38.2013]
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", lazy = FALSE, new_process = FALSE)'`
- browser checks for both affected local article pages
- `git diff --check`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found`
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> no generated
  file churn
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> 0 errors, 1 local install WARNING, 2 NOTEs
- `R CMD INSTALL --preclean --no-multiarch .` -> `* DONE (gllvmTMB)` after local
  compiler/toolchain warnings

## Commands Still Needed Before Upload / Merge

- None before handing off the article-only repair. `pkgdown::check_pkgdown()`
  is green and both affected articles were rendered locally.
- Note: full local `devtools::check(args = "--no-manual")` ran but returned an
  install WARNING from the local macOS compiler/toolchain, plus two existing
  NOTEs. Direct `R CMD INSTALL` completed successfully. Treat GitHub Actions as
  the clean multi-platform deployment gate after push.

## Collision Boundary For Claude

Please do not assume `bootstrap_retention` exists. It remains a planned method
mentioned in prose only.

If Claude is going to implement `bootstrap_retention`, that should be a separate
implementation lane touching `R/suggest-lambda-constraint.R`, tests, roxygen,
generated Rd, validation-debt status, and articles. Codex has not started that
implementation.

If Claude is only reviewing / uploading the two articles, the current Codex lane
is limited to:

- `vignettes/articles/joint-sdm.Rmd`
- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `docs/dev-log/check-log.md`
- the two new after-task reports listed above
- this recovery checkpoint

## Next Safest Action

If the maintainer approves, push the article-only repair to `main` and watch
GitHub Actions / pkgdown. If Claude takes over before that, start from this
note and do not begin `bootstrap_retention` in the same lane.
