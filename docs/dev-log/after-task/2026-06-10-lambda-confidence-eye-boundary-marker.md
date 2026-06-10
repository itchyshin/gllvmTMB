# After Task: Lambda Confidence Eye Boundary Marker

Date: 2026-06-10
Branch: `main`
Roles engaged: Ada, Florence, Fisher, Rose, Grace

## Goal

Repair the technical Lambda-suggestion article's lower
`profile_retention` Confidence Eye plot after review showed a full-height red
stripe in the LV2 panel.

## Mathematical Contract

No public R API, likelihood, formula grammar, generated Rd, NAMESPACE, or
pkgdown navigation change. The article still uses the supported
`profile_retention` refit and Wald loading intervals. The display now treats
extreme off-scale Wald rows as boundary markers rather than drawing their huge
intervals as confidence-eye polygons inside a clipped y-axis.

## Files Changed

- `vignettes/articles/lambda-constraint-suggest.Rmd`
  - Builds `ci_pr` explicitly for the lower `profile_retention` plot.
  - Detects off-scale Wald rows relative to the article display window.
  - Places those rows at the display boundary and removes their eye polygons.
  - Adds text naming `B_drought_4` / `LV2` and its raw Wald interval.
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-10-lambda-confidence-eye-boundary-marker.md`

## Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,isDraft,url` -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/after-task vignettes/articles/lambda-constraint-suggest.Rmd` -> only `9d0548b Codex worktree snapshot: archive-cleanup`.
- Diagnostic R cache read with `loading_ci(e$fit_pr, level = "unit", method = "wald")` -> `B_drought_4` / `LV2` has estimate -56.7155, SE 48.4278, lower -151.6323, upper 38.2013.
- `air format vignettes/articles/lambda-constraint-suggest.Rmd` -> clean.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", lazy = FALSE, new_process = FALSE)'` -> wrote `pkgdown-site/articles/lambda-constraint-suggest.html`.
- `rg -n "path is fine here|full-height eye|boundary points|B_drought_4|Off-scale Wald" vignettes/articles/lambda-constraint-suggest.Rmd pkgdown-site/articles/lambda-constraint-suggest.html` -> boundary-marker text and raw interval are present; stale "path is fine here" wording is absent.
- Visual PNG review of `pkgdown-site/articles/lambda-constraint-suggest_files/figure-html/profile-confidence-eye-1.png` -> lower LV2 full-height red stripe is gone.
- Browser check at `http://localhost:8123/articles/lambda-constraint-suggest.html?v=20260610-boundary-eye#confidence-eye-for-the-two-data-driven-refits` -> article and refreshed profile Confidence Eye image load.
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> completed with
  no generated-file churn.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> 0 errors, 1 install WARNING, 2 NOTEs. The warning was local
  install/compiler noise; the notes were unable-to-verify-current-time and
  existing NEWS heading extraction notes.
- `R CMD INSTALL --preclean --no-multiarch .` -> `* DONE (gllvmTMB)` after the
  same local compiler/toolchain warnings (`xcrun` SDK lookup and upstream
  Eigen/R clang warnings).

## Consistency Audit

Rose: PASS. The article no longer says the Wald path is simply "fine here";
it distinguishes "available" from "compact enough to draw directly" and names
the off-scale diagnostic row.

Florence: PASS. The previous figure failed the visual gate because the clipped
polygon looked like an accidental vertical line. Boundary points preserve the
warning without dominating the readable finite intervals.

Fisher: PASS with caveat. The extreme Wald row is a real weak-curvature /
small-binary-fixture diagnostic, not a plotting bug. The article now reports
the raw estimate and interval instead of hiding the numerical issue.

Grace: PASS for the targeted article render and browser check. Full package
check was run as a deployment closeout gate, but the local macOS toolchain
emitted an install WARNING. Direct install succeeded; CI remains the clean
multi-platform deployment gate.

## Tests Of The Tests

No test file was added. The failure was visual and article-local. The diagnostic
R read confirmed the raw Wald interval causing the stripe, and the rendered PNG
review confirmed the repaired plot no longer shows a full-height LV2 stripe.

## What Did Not Go Smoothly

The first pass had treated "positive-definite Hessian" too casually as
"Wald path is fine." The corrected wording separates interval availability from
whether an interval is visually useful on the raw loading scale.

## Team Learning

Ada: Positive-definite is not the same as visually well-conditioned. The
article needs to surface extreme Wald rows rather than forcing them into the
standard eye geometry.

Florence: A confidence-eye plot should never make an uncertainty warning look
like a stray drawing artefact.

Fisher: The raw interval belongs in the prose because it is statistically
meaningful, but drawing it as an eye inside a clipped panel is misleading.

Rose: For approval checks, scan the actual rendered PNGs as well as the HTML
claims; this caught an issue that `pkgdown` cannot.

Grace: Targeted article rebuild was enough for this display patch; a later
pre-upload sweep can still run the full package gates if requested.

## Design Docs, NEWS, Roadmap

No design doc, NEWS, ROADMAP, or validation-debt register row changed. The
underlying methods were already documented; this is a display and explanation
repair in a technical article.

## Known Limitations And Next Actions

- `bootstrap_retention` remains planned, not implemented.
- The profile-retention plot now marks off-scale raw-loading Wald rows at the
  boundary; a future exported helper option could make this behaviour reusable.
- `pkgdown::build_site()` was not run locally; affected articles were rendered
  individually and `pkgdown::check_pkgdown()` passed.
- Full local `devtools::check()` ran but returned an install WARNING from the
  local compiler/toolchain rather than a clean green result.
