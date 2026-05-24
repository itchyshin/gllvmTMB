# After Task: Correlation Matrix Full-Layout Plot Options

**Branch**: `codex/correlation-matrix-plots-2026-05-23`
**Date**: `2026-05-23`
**Roles (engaged)**: Ada, Florence, Pat, Fisher, Grace, Rose

## 1. Goal

Make `plot_correlations()` matrix views useful as report-ready figures without hand-indexing matrices and without wasting half the matrix. The immediate maintainer request was to support designs such as upper-triangle point estimates with lower-triangle interval bounds, and one-matrix between/within displays such as `unit` over `unit_obs`.

## 1a. Mathematical Contract

No likelihood, formula grammar, family, TMB, NAMESPACE, or estimator change. This slice only changes how existing tidy correlation rows are rendered: cell fill and ellipse geometry show the supplied point estimate, and interval labels/outlines/stars display already-supplied finite bounds without computing or calibrating new uncertainty.

## 2. Implemented

- `plot_correlations()` now accepts `style = "heatmap"`, `style = "ellipse"`, and alias `style = "oval"` for tidy correlation rows.
- Matrix views now expose `matrix_layout = "by_level"`, `"estimate_ci"`, and `"levels"`.
- `matrix_layout = "estimate_ci"` uses the full matrix for each level: upper cells label point estimates and lower cells label supplied interval bounds.
- `matrix_layout = "levels"` combines exactly two levels into one matrix: the upper triangle shows the first level and the lower triangle shows the second level. Canonical `unit` / `unit_obs` ordering is preferred when present.
- Plot data preserve `.matrix_layout`, `.label_type`, `.triangle`, `.display_level`, interval status, and significance markers in `attr(p, "gllvmTMB_data")`.

## 3. Files Changed

- Plot helper: `R/plot-covariance-tables.R`.
- Tests: `tests/testthat/test-plot-covariance-tables.R`.
- Generated documentation: `man/plot_correlations.Rd`.
- User-facing scope note: `NEWS.md`.
- Validation register: `docs/design/35-validation-debt-register.md` row EXT-30.
- Visualization design: `docs/design/46-visualization-grammar.md`.
- Dev log: `docs/dev-log/check-log.md`.
- After-task report: `docs/dev-log/after-task/2026-05-23-correlation-matrix-full-layouts.md`.
- Recovery checkpoint: `docs/dev-log/recovery-checkpoints/2026-05-23-183642-ada-checkpoint.md`.

## 3a. Decisions and Rejected Alternatives

Decision: keep `matrix_layout = "by_level"` as the first formal value for compatibility, but make the new examples and docs point to `matrix_layout = "estimate_ci"` when the reader needs the full matrix to carry both estimates and intervals.

Rationale: mirroring estimates in both triangles is visually redundant, but changing the default layout for every matrix style would be a larger behavior change. The new API lets articles choose the richer display explicitly.

Rejected alternative: always facet `unit` and `unit_obs` as separate matrices. That remains available, but the one-matrix layout is better for compact reports where the scientific comparison is between covariance levels.

## 4. Checks Run

- `gh pr list --state open` -> no open PRs.
- `git log --all --oneline --since="6 hours ago"` -> recent history was #239 / #238 / #237 only.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R` -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> wrote `man/plot_correlations.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables", stop_on_failure = TRUE)'` -> 232 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); f <- formals(plot_correlations); stopifnot(identical(eval(f$style), c("interval", "eye", "raindrop", "heatmap", "ellipse", "oval"))); stopifnot(identical(eval(f$label_type), c("auto", "estimate", "ci", "estimate_ci", "none"))); stopifnot(identical(eval(f$matrix_layout), c("by_level", "estimate_ci", "levels"))); writeLines("plot_correlations matrix formals ok")'` -> `plot_correlations matrix formals ok`.
- `Rscript --vanilla -e 'n <- sum(grepl("^\\\\keyword", readLines("man/plot_correlations.Rd"))); cat(n, "\\n"); stopifnot(n == 0)'` -> `0`.
- `Rscript --vanilla -e 'ns <- readLines("NAMESPACE"); x <- grep("^export(", ns, value = TRUE, fixed = TRUE); exports <- substring(x, 8, nchar(x) - 1); yml <- readLines("_pkgdown.yml"); covered <- sub("^    - ", "", grep("^    - ", yml, value = TRUE)); missing <- setdiff(exports, covered); missing <- missing[!missing %in% c("Beta", "VP", "Families")]; if (length(missing)) { writeLines(missing); quit(status = 1) } else { writeLines("export/pkgdown parity ok") }'` -> `export/pkgdown parity ok`.
- `git diff --check` -> clean.
- `gh issue list --state open --search "plot_correlations matrix OR correlation heatmap OR EXT-30 OR covariance matrix" --json number,title,url,labels,updatedAt --limit 20` -> found #230, "Article surface reset and user-first tooling gate".
- Visual QA renders were written to `/tmp/gllvmtmb-correlation-matrix/correlation-estimate-ci-layout.png`, `/tmp/gllvmtmb-correlation-matrix/correlation-levels-layout.png`, and `/tmp/gllvmtmb-correlation-matrix/correlation-levels-ovals.png`.
  Florence inspection passed for legible cell labels, visible uncertainty
  outlines/stars, stable triangle meanings, and no overlapping title, legend,
  axis, or caption text at the checked size.
- Full local package check was attempted with `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`, but the tool session did not return a final result. A follow-up process check found no matching Rscript or R CMD check process, so this is not counted as validation evidence.

## 5. Tests of the Tests

- Feature combination: the `estimate_ci` test combines matrix style, interval-bearing tidy rows, triangle override, automatic label routing, and generated subtitle/caption text.
- Feature combination: the `levels` test combines two covariance levels in one matrix and checks that upper cells map to `unit`, lower cells map to `unit_obs`, and no facet is added.
- Boundary case: the validation test rejects `matrix_layout = "levels"` unless exactly two levels are present.
- Boundary case: `label = FALSE` now suppresses both cell text and label-specific caption wording for the `estimate_ci` layout.
- Regression guard: the ellipse matrix test keeps `.facet` in polygon data so faceted ovals do not leak into both panels.

## 6. Consistency Audit

Stale-wording scan:

```sh
rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary" R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R man/plot_correlations.Rd NEWS.md docs/design/35-validation-debt-register.md docs/design/46-visualization-grammar.md
```

Verdict: no hits.

Rose verdict: PASS for the touched helper, generated Rd, NEWS entry, validation-debt register row EXT-30, and visualization-grammar update.

## 7. Roadmap Tick

No ROADMAP row was edited. This is an EXT-30 visualization helper slice tracked in `docs/design/35-validation-debt-register.md`.

## 7a. GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling gate". This slice advances tooling gate 3 by making tidy correlation rows usable as explicit, metadata-backed matrix displays for report figures.
- No issue was closed. The helper remains part of the broader figure/tooling gate until rendered article/gallery usage and broader visual snapshots land.
- No issue comment was posted yet; do that when the PR or first-50 stop report is ready so the issue ledger points to a durable branch/PR rather than this local checkpoint alone.

## 8. What Did Not Go Smoothly

The full local `devtools::check()` attempt did not return a final result through the command session even though no matching Rscript or R CMD check process remained. The slice therefore relies on focused tests, `pkgdown::check_pkgdown()`, roxygen generation, formals checks, visual QA renders, `git diff --check`, and Rose scans until a PR/CI run or a clean local full check is available.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the slice narrow: one public helper, one EXT row, no article rewrite.

Florence: the better design is not merely a prettier triangle. Each matrix half must have a declared meaning: estimates, interval bounds, or a named covariance level.

Pat: one-matrix `unit` / `unit_obs` comparison should help applied readers compare between- and within-level correlations without jumping between facets.

Fisher: all interval information is displayed as supplied; the helper does not compute, calibrate, or imply new uncertainty.

Grace: pkgdown and focused tests pass; full local check remains inconclusive and should be replaced by CI or a rerun before PR update.

Rose: scope claims are tied to EXT-30 and the touched prose keeps IN / PARTIAL / PLANNED boundaries explicit.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- Matrix styles still display supplied intervals only as labels and outlines/stars; they do not calibrate bootstrap or profile uncertainty.
- Broader visual snapshots for matrix layouts remain future QA.
- Next safest action: review the rendered matrix examples, then either add a small vignette/gallery use or open a PR and let 3-OS CI replace the inconclusive local full-check attempt.
