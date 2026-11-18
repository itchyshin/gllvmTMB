# After Task: pkgdown build broken by the spatial `rho` grouping token

**Branch**: `claude/inspiring-knuth-mg3d2q`
**Date**: `2026-10-11`
**Roles (engaged)**: Claude Code (diagnosis, fix, tests); three read-only
review lenses run as general workflow agents, not the standing persona agents.

## 1. Goal

The scheduled pkgdown build on `main` failed on 10-10 and 10-11 at
`vignettes/articles/structured-source-strength.Rmd`, so the site had not
rebuilt since 10-04. Find the cause and fix it.

**Cause.** Commit `7a72e0f` (#1361, 10-04) changed the article's two
estimated-`rho` spatial fits from `| location` to `| coords`, to avoid the
one-time notice that a spatial keyword's grouping token "is ignored". That
notice is true only at the default `rho = 1`. With `rho = NULL` or a value
other than 1, the structured-`rho` parser reads the token as the column that
identifies each location (`spec$grouping`) and aborts if it is not a data
column: "Spatial attenuation requires an observed grouping column with no
missing values." The article stopped at that fit and could not render.
Reproduced locally by running the article's code on `main`.

## 2. Implemented

**Mathematical contract:** no public API, likelihood, grammar or family change.
Only the condition under which one warning fires, plus documentation.

- `.warn_spatial_grouping_token()` stays silent for a spatial term whose `rho`
  is not 1. It knows this in two ways: `gllvmTMB()` records the token the
  structured-`rho` parser consumed (the parser strips `rho` before the sugar
  rewriter runs), and callers that rewrite the formula directly
  (`screen_gllvmTMB()`, `suggest_lambda_constraint()`) still see a literal
  `rho =` argument that is not 1.
- The article names the `location` column again in both estimated-`rho` fits.
- The help for `spatial_latent()`, `spatial_indep()` and `spatial_dep()` says
  that with `rho` other than 1 the name after `|` must be a real column.
- The iSDM article's two blanket statements that the token is inert now say
  "at the default `rho = 1`", and no longer claim that nothing warns.

## 3. Files Changed

- `R/brms-sugar.R`: the warning condition, the consumed-token environment and
  its setter, and roxygen for the three spatial keywords.
- `R/gllvmTMB.R`: sets the consumed token after the first structured-`rho`
  capture and clears it with `on.exit()`.
- `man/spatial_latent.Rd`, `man/spatial_indep.Rd`, `man/spatial_dep.Rd`:
  edited by hand to match the roxygen text (the installed roxygen2 is 7.3.1;
  the project pins 8.0.0, and regenerating would rewrite unrelated pages).
- `vignettes/articles/structured-source-strength.Rmd`: `| location` in the two
  estimated-`rho` fits.
- `vignettes/articles/isdm-canada-warbler.Rmd`: qualified two statements.
- `tests/testthat/test-issue-1361-spatial-location-token.R`.
- `NEWS.md`: one bullet.
- This report.

## 3a. Decisions and Rejected Alternatives

- **Decision**: fix the warning, and restore `| location` in the article.
  **Rationale**: the warning is false at `rho != 1`, and an article that shows
  a false message beside text explaining the location column is worse than the
  abort it avoided. **Rejected alternative**: wrap the fits in
  `quiet_grammar_notes = TRUE` (hides a wrong message instead of removing it),
  or restore `| location` without touching the warning. **Confidence**: high.
- **Decision**: keep `| coords` as the placeholder for `rho = 1`.
  **Rationale**: there the token really is ignored. **Confidence**: high.
- **Decision**: hand-edit the three Rd pages. **Rationale**: roxygen2 version
  skew. **Rejected alternative**: regenerate with 7.3.1. **Confidence**: high.

## 4. Checks Run

R 4.3.3 / TMB 1.9.10 (apt build), `NOT_CRAN=true`, `pkgload::load_all()`.

- `test-issue-1361-spatial-location-token.R`, `test-gapclose-signposting.R`,
  `test-structured-rho-spatial.R`, `test-structured-rho-contract.R`: pass
  (first run 9, 22, 184 and 67 expectations before the extra cases below).
- All 55 spatial, structured-`rho`, signposting and control-field test files:
  8,198 pass, 1 fail, 79 skipped. The one failure is
  `test-control-field-surface.R` (`optimizer_diagnostics` is used but not
  declared); it fails identically on `origin/main`.
- The article's R code run end to end with the notice enabled
  (`gllvmTMB.quiet_grammar_notes = FALSE`): completes, zero warnings.
- `tools::checkRd()` on the three edited Rd files: no problems.
- Not run: a full `pkgdown::build_site()` (not installable offline here) and
  `R CMD check`.

## 5. Tests of the Tests

- **Failure-before-fix:** with the R change removed, the new warning test fails
  (2 expectations in the first version); the article test matched the old text
  and not the new one.
- **Feature-combination:** `spatial_latent`, `spatial_indep` and `spatial_dep`
  x `rho = NULL` and `0.5` x long and `traits()` wide input, plus a direct
  `desugar_brms_sugar()` call, plus the positive control that the notice still
  fires at the default and at an explicit `rho = 1`.
- The original article test passed vacuously: its pattern used `[^\n]` under
  R's default regex engine, where it excludes the letters `n` and `\`, so it
  could not match any line containing "unique". The new pattern uses
  `perl = TRUE`, and requires both estimated-`rho` fits to name `location`.
- The test restores the one-shot warning tracker it unbinds.

## 6. Consistency Audit

Verbatim searches, run at the end:

```
rg -n 'spatial_(latent|indep|dep)\([^)]*\|\s*coords[^)]*rho\s*=\s*(NULL|0?\.[0-9]+)' vignettes man R docs/design README.md inst dev
rg -n -i 'token.{0,40}(inert|ignored|never read)|(inert|ignored).{0,40}token' vignettes README.md R man docs/design
```

- First search: no matches, so no other example would abort the same way.
- Second search: the warning text and its comments, the iSDM article (now
  qualified), and the new code comments. No other prose says the token is
  inert without the `rho = 1` qualifier.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

- #1361 (the earlier notice change this partly supersedes): inspected through
  commit `7a72e0f` and its test; no comment posted.
- #1331 and #1330: unrelated to this change; they were given status comments
  earlier the same day and stay open.
- No issue opened, closed or edited.

## 8. What Did Not Go Smoothly

- The earlier fix for the notice (`7a72e0f`) guarded the article with a test
  that could not fail, so the regression it caused went unseen until the
  scheduled build.
- `screen_gllvmTMB()` and `suggest_lambda_constraint()` call the sugar rewriter
  without going through `gllvmTMB()`, so the first version of this fix, which
  used only the recorded token, did not cover them. A review lens caught this.

## 9. Team Learning

- **Curie-style test discipline:** a pattern test that cannot match is not a
  guard. Check any new regex test against both the broken and the fixed text.
- **Rose-style consistency:** a convention change ("write `| coords`") needs
  its exceptions written next to it in the help, not only in the parser.

## 10. Known Limitations and Next Actions

- A positional `rho` together with a literal `NULL` `coords`
  (`spatial_dep(0 + trait | group, NULL, mesh, 0.5)`) fails with "subscript out
  of bounds" inside `.shared_rewrite`, before this code runs. It predates this
  change and is not touched here.
- The PR description should say plainly that this supersedes `7a72e0f`'s
  convention for `rho != 1` terms.
- `gllvmTMB` pkgdown should be re-run (scheduled or by dispatch) once this
  lands; I could not run `pkgdown::build_site()` offline.
