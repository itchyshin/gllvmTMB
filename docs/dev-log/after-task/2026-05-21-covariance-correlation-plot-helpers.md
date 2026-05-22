# After Task: Covariance/Correlation Plot Helpers And Raindrops

**Branch**: `codex/florence-covariance-plots-2026-05-21`
**Date**: `2026-05-21`
**Roles (engaged)**: `Ada / Emmy / Florence / Fisher / Pat / Rose / Grace`

## 1. Goal

Add report-ready plot helpers that consume the tidy covariance/correlation
tables from `extract_correlations()` and `extract_Sigma_table()` without
forcing article authors to index matrices by hand. The slice also tested the
maintainer's raindrop idea: uncertainty should read as a compatibility shape,
not as a flat probability bar across a confidence interval.

## 2. Implemented

- `plot_correlations()` now plots tidy rows from `extract_correlations()` or a
  fitted `gllvmTMB_multi` object.
- `plot_Sigma_table()` now plots tidy rows from `extract_Sigma_table()` or a
  fitted `gllvmTMB_multi` object.
- Both helpers return `ggplot2` objects with `gllvmTMB_meta` and
  `gllvmTMB_data`; raindrops also attach `gllvmTMB_raindrop_data`.
- `style = "interval"` is the default forest plot.
- `style = "raindrop"` reconstructs frequentist compatibility shapes from
  finite interval bounds. Correlations use Fisher's z scale; covariance rows
  use the displayed estimate scale.
- Raindrops omit CI interval lines by default. `show_intervals = TRUE` keeps an
  opt-in overlay for technical checks.
- Rows without finite interval bounds are drawn as open points so they do not
  look like full uncertainty displays.
- Caption and documentation language now gives the next inference path: fitted
  correlation open points can often be investigated with
  `extract_correlations(..., method = "bootstrap")`; Sigma-table raindrops need
  bootstrap-derived or otherwise interval-bearing rows.
- Facet spacing now uses additive y padding and optional `facet_wrap(space =
  "free_y")` support, so sparse facets do not look visually overweight.
- `_pkgdown.yml`, `NAMESPACE`, generated Rd files, `NEWS.md`, the report-ready
  plot contract, and validation row `EXT-19` were updated.

## 3. Files Changed

Implementation and tests:

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`

Public API and docs:

- `NAMESPACE`
- `man/plot_correlations.Rd`
- `man/plot_Sigma_table.Rd`
- `_pkgdown.yml`
- `NEWS.md`

Design and audit:

- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-covariance-correlation-plot-helpers.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep forest intervals as the default, and make raindrops an explicit
`style`.
Rationale: forest plots are familiar for table review; raindrops are better
when the display needs to show that interval compatibility is not uniform.
Rejected alternative: replacing all intervals with raindrops immediately.
Confidence: high.

Decision: omit CI interval lines from raindrops by default.
Rationale: the midpoint plus compatibility shape is cleaner and less
misleading. The line overlay makes the display busier and pulls attention back
to the flat-interval reading.
Rejected alternative: always draw both the drop and the CI line.
Confidence: high after visual QA.

Decision: call raindrops frequentist compatibility displays, not posterior
densities.
Rationale: the shape is reconstructed from estimates and interval bounds; it
is not a Bayesian posterior sample or density.
Rejected alternative: posterior-like wording in captions.
Confidence: high.

## 4. Checks Run

- `gh pr list --state open` -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"` -> only the current PR #233
  branch was visible as recent package work.
- `Rscript --vanilla -e 'parse("R/plot-covariance-tables.R")'` -> parsed
  successfully.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> wrote
  `man/plot_correlations.Rd` and `man/plot_Sigma_table.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 70 passes, 0 failures, 0 warnings, 0 skips after adding open-point
  coverage for missing interval bounds.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables|plot-gllvmTMB|extract-sigma-table")'`
  -> 234 passes, 0 failures, 0 warnings, 0 skips.
- Visual render script wrote
  `/tmp/gllvmTMB-plot-check/plot-correlations-raindrop-spaced.png` and
  `/tmp/gllvmTMB-plot-check/plot-sigma-raindrop-spaced.png`; both were viewed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. The warning was local SDK/compiler
  noise (`xcrun --show-sdk-version` status 1, Eigen/TMB warnings, existing
  unused `n_mesh`). Notes were existing `air.toml`, legacy NEWS section
  parsing, and unused `nlme`.

## 5. Tests of the Tests

The new tests were useful, not decorative. They caught a vector-length bug in
the raindrop row bookkeeping after the `show_intervals = NULL` change. They
also caught that an empty `GeomSegment` layer was still being attached to
raindrop plots even when no CI line was drawn. After the maintainer flagged the
point-only row, the tests were extended to require rows without finite interval
bounds to remain visible as a separate point-only layer. All failures were
fixed before the focused and broader test runs passed.

## 6. Consistency Audit

- `rg -n 'plot_correlations|plot_Sigma_table|raindrop|EXT-19|show_intervals' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R man/plot_correlations.Rd man/plot_Sigma_table.Rd NEWS.md _pkgdown.yml docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md NAMESPACE`
  -> helper surface appears in exports, docs, tests, NEWS, pkgdown, validation,
  and design contract.
- `rg -n 'Florence-reviewed|posterior density|credible distributions|Bayesian|compatibility' R/plot-covariance-tables.R man/plot_correlations.Rd man/plot_Sigma_table.Rd NEWS.md docs/design/53-report-ready-extractor-plot-contract.md docs/design/35-validation-debt-register.md`
  -> no stale Florence-only phrasing remains; raindrops are consistently
  described as compatibility displays and not posterior densities.
- `rg -n 'space = "free_y"|expansion\\(add|GeomSegment|\\.draw_interval' R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> spacing, optional CI-line behavior, and point-only row behavior are
  implemented and tested.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. Validation-debt row `EXT-19` was added for the
new exported plot helpers.

## 7a. GitHub Issue Ledger

- `gh issue list --state open --search "raindrop plot" --limit 10` -> no
  matching open issues.
- `gh issue list --state open --search "plot helper covariance" --limit 10`
  -> found #230, "Article surface reset and user-first tooling gate". No
  comment added because this helper infrastructure supports that gate but does
  not complete the Morphometrics/article integration.

## 8. What Did Not Go Smoothly

The first raindrop implementation still carried the CI line by default. The
maintainer correctly pushed for fewer visual elements, so `show_intervals =
NULL` now means ordinary interval lines for forest plots and no line for
raindrops. The first spacing pass also made sparse facets look too tall; the
facet helper now uses row-proportional free-y space when ggplot2 supports it.

One short check was started before that spacing change and terminated; it is
not counted as evidence.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the slice bounded: exported helpers, tests, docs, validation row, and
logs, without moving Morphometrics itself yet.

Emmy's API lesson is that the helpers should accept standardized extractor
tables and expose prepared plot data, not ask users to learn layer internals.

Florence's visual lesson is that beauty is not decoration. Row spacing, default
CI-line omission, and clear midpoint/drop structure all affect whether the
reader interprets uncertainty honestly.

Fisher's inference lesson is that raindrops must be named as compatibility
displays, not posterior densities. The helper displays supplied intervals; it
does not invent Sigma uncertainty.

Pat's reader lesson is that applied users need simple defaults: one helper call
for the common plot, one explicit style change for raindrops, and no hidden
matrix indexing.

Rose's audit lesson is that "Florence-reviewed" was too narrow. The design
contract now names team-reviewed figure integration: Florence, Fisher, Pat,
and Rose.

Grace's build lesson is that the exported helpers document and test cleanly;
the remaining short-check warning is the existing local SDK/compiler warning,
not a new plotting failure.

## 10. Known Limitations And Next Actions

- `plot_Sigma_table(style = "raindrop")` can only draw raindrops when the
  supplied rows already have finite interval bounds. `extract_Sigma_table()`
  still returns point-estimate rows with interval placeholders.
- No `vdiffr` snapshots were added. Current tests inspect class, metadata,
  prepared data, interval-line behavior, and buildability.
- Next slice: put one of these helpers into Morphometrics or the
  covariance/correlation article and run the team review path on rendered HTML.
