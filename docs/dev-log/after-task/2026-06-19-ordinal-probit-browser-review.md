# After-task report: ordinal-probit browser review

Date: 2026-06-19 05:00 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Goal

Close the true-browser review gap for the internal `ordinal-probit` article
after the runnable-fixture slice, without promoting the page to the public
article surface.

## Implemented

This slice updated only the control artifacts: article council ledger,
check-log, dashboard status/sweep, and this after-task report. It records that
the rendered ordinal article passed system-Chrome visual/layout checks and
local HTML image/link checks.

## Mathematical Contract

No likelihood, formula grammar, or model parameterisation changed. The browser
review preserves the existing ordinal threshold-trait contract from the article:
FAM-14 family-recovery evidence is covered, while EXT-10/cutpoint depth,
ordinal interval examples, and exact ordinal randomized-quantile residual
diagnostics remain open.

## Files Changed

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-ordinal-probit-browser-review.md`

No article source, R code, tests, roxygen, generated Rd, or pkgdown HTML was
changed in this slice.

## Checks Run

Inherited from the previous sitting:

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/ordinal-probit", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed and wrote `pkgdown-site/articles/ordinal-probit.html`.
- System Chrome wrote `/tmp/ordinal-probit-desktop.png`,
  `/tmp/ordinal-probit-mobile.png`, `/tmp/ordinal-probit-desktop-full.png`,
  and `/tmp/ordinal-probit-mobile-full.png`.
- Chrome DevTools Protocol metrics reported title
  `Ordinal-probit threshold traits • gllvmTMB`, H1
  `Ordinal-probit threshold traits`, mobile H1 inside the viewport, mobile
  `documentScrollWidth = 390` at viewport width `390`, and only expected
  scrollable code/output overflow.

Run in this sitting:

- `view_image` inspection of the four ordinal screenshots.
- Local HTML image/link parser for `pkgdown-site/articles/ordinal-probit.html`
  - `images 1 missing 0`
  - `local_links 48 missing 0`
- `rg -n "release-ready|release ready|scientific coverage|scientific coverage passed|publication-ready|publication ready|public article dropdown|not ready|Internal article gate|PR green|bridge complete" pkgdown-site/articles/ordinal-probit.html vignettes/articles/ordinal-probit.Rmd`
  - Only the intended internal-gate wording matched.
- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.

## Tests Of The Tests

No tests were added or changed. This was a rendered/browser review of an
already-rendered internal article.

## Consistency Audit

The article council ledger now says the browser-review blocker is closed, but
keeps the article internal. The dashboard status and sweep entries must still
state that this is internal article evidence only. The stale-claim scan above
is the exact pattern used for release-ready, public-ready, bridge-complete, and
scientific-coverage overclaims.

## What Did Not Go Smoothly

The in-app browser was unavailable in the previous sitting, so the browser
evidence used system Chrome. That is acceptable for this internal browser gate,
but the after-task record names the tool path and screenshot files so the check
can be repeated.

## Team Learning

Pat/Grace/Rose evidence is enough to close the browser-review gap, but not
enough to make the page public. Fisher and Noether caveats still govern the
ordinal interval, extractor-depth, and residual-diagnostic story.

## Known Limitations

- No public promotion or final placement decision.
- No EXT-10/cutpoint-depth closure.
- No ordinal interval calibration.
- No exact ordinal residual diagnostic availability.
- No model-code change.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.

## Next Actions

Return to the dashboard/article-council backlog and take the next single gate:
likely the `random-slopes-nongaussian` true browser review, final placement
decisions for browser-reviewed internal articles, the lambda Confidence Eye
repair, or the broader mixed-family NB/beta teaching fixture.
