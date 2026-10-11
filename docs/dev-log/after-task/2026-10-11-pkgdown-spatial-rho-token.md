# After Task: pkgdown build broken by the spatial `rho` grouping token

**Branch**: `claude/fix-pkgdown-spatial-rho-token`
**Date**: `2026-10-11`
**Roles (engaged)**: Claude Code (diagnosis, fix, tests, adversarial review)

## 1. Goal

The scheduled pkgdown build on `main` failed on 10-10 and 10-11 at
`vignettes/articles/structured-source-strength.Rmd`, so the site had not
rebuilt since 10-04. Find the cause and fix it.

## 2. Cause

- Commit `7a72e0f` (#1361, 10-04) changed the article's two estimated-`rho`
  spatial fits from `| location` to `| coords`, to avoid the one-time warning
  that a spatial keyword's grouping token "is ignored".
- That warning is true only at the default `rho = 1`. With `rho = NULL` or a
  fixed `rho` other than 1, the structured-`rho` parser reads the token as the
  column that identifies each location (`spec$grouping`) and aborts if it is
  not a data column: "Spatial attenuation requires an observed grouping column
  with no missing values."
- The fit with `| coords` therefore stopped, and the article could not render.
- Reproduced locally by running the article's code on `main`: same abort.

## 3. Implemented

- `R/brms-sugar.R`: `.warn_spatial_grouping_token()` stays silent for the token
  the structured-`rho` spec consumed. The parser removes `rho` from the call
  before the sugar rewriter runs, so the token is passed through a small
  package-level environment, `.gllvmTMB_spatial_token_consumed`, set by
  `.gllvmTMB_set_spatial_token_consumed()`.
- `R/gllvmTMB.R`: `gllvmTMB()` sets that state right after the first
  structured-`rho` capture and clears it with `on.exit()`.
- `vignettes/articles/structured-source-strength.Rmd`: the two estimated-`rho`
  spatial fits name the `location` column again.
- `tests/testthat/test-issue-1361-spatial-location-token.R`:
  - the article check now requires `| location` (and forbids `| coords`) on
    `rho = NULL` fits, using `perl = TRUE` because `[^\n]` is wrong in R's
    default regex engine and the original pattern could never match;
  - a new test shows the warning is silent for `rho = NULL` and `rho = 0.5`,
    still fires at the default `rho = 1`, and leaves no state behind.
- `NEWS.md`: one plain-language bullet.

## 4. Checks Run

R 4.3.3 / TMB 1.9.10 (apt build), `NOT_CRAN=true`, `pkgload::load_all()`.

- Test-the-test: without the R change, the new warning test fails (2
  expectations) and the article test passes only on the new article text; the
  regex matches the old article and not the new one.
- `test-issue-1361-spatial-location-token.R`: 9 pass, 0 fail.
- All 55 spatial, structured-`rho`, signposting and control-field test files:
  8,198 pass, 1 fail, 79 skipped. The one failure is `test-control-field-surface.R`
  (`optimizer_diagnostics` is used but not declared); it fails identically on
  `origin/main`.
- The article's R code run end to end with the grouping-token notice enabled
  (`gllvmTMB.quiet_grammar_notes = FALSE`): completes, with zero warnings.
- Not run: a full `pkgdown::build_site()` (not installable offline here) and
  `R CMD check`.

## 5. Decisions and Rejected Alternatives

- Kept `| coords` as the placeholder for `rho = 1`, where the token really is
  ignored; only the `rho != 1` case changed.
- Rejected: wrapping the article's fits in `quiet_grammar_notes = TRUE`, which
  would hide a warning that is simply wrong here; and restoring `| location`
  without fixing the warning, which would show readers a false message next to
  text that explains the location column.
- Rejected: reading `rho` inside `.warn_spatial_grouping_token()`. It has been
  stripped by then, and re-deriving it would duplicate the parser.

## 6. Follow-up

- The `rho` help text and any article still telling users to write
  `| coords` with a `rho` term should be checked; the adversarial review below
  lists what it found.
- `gllvmTMB` issues #1331 and #1330 stay open; status comments were posted.

## 7. What Did Not Go Smoothly

- The original article test passed vacuously: its pattern used `[^\n]` under R's
  default regex engine, where it excludes the letters `n` and `\`, so it could
  not match any line containing "unique". It guarded nothing.
