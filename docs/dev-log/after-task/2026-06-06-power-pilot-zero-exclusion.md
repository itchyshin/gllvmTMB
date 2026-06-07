# After Task: Power Pilot Zero-Exclusion Scoring

**Branch**: `codex/power-pilot-scoring-ledger-2026-06-06`
**Date**: `2026-06-06`
**Roles (engaged)**: `Ada / Fisher / Grace / Rose`

## 1. Goal

Correct the Design 66 Phase-1 pilot reporting surface so the
CI-excludes-zero diagnostic is not presented as power or Type-I error for
`Sigma_unit_diag`.

## 2. Implemented

- `pilot_collect()` now emits `zero_exclusion_rate`, the target-aligned name
  for the fraction of primary `Sigma_unit_diag` bootstrap CIs that exclude
  zero.
- The legacy `power` column remains as a compatibility alias, so existing
  result stores and readers do not break.
- `pilot_plot()` now returns `coverage` and `zero_exclusion` plots, and writes
  `pilot-zero-exclusion-diagnostic.png`.
- `pilot_plot_power()` remains as a compatibility wrapper around
  `pilot_plot_zero_exclusion()`.
- The Power pilot workflow issue-board text now says coverage and
  zero-exclusion diagnostic figures, and explicitly says this is not a Type-I
  or power claim for `Sigma_unit_diag`.
- Issue #340 and issue #349 were updated with the combined-store scoring audit
  result.

No package API, exported function, roxygen topic, generated Rd file, vignette,
README, NEWS entry, likelihood code, or validation-debt row changed.

## 3. Files Changed

- `dev/m3-pilot-report.R` -- target-aligned column, plot naming, compatibility
  wrapper, and markdown table heading.
- `.github/workflows/power-pilot-sweep.yaml` -- board wording only.
- `docs/dev-log/check-log.md` -- command log and interpretation.
- `docs/dev-log/after-task/2026-06-06-power-pilot-zero-exclusion.md` -- this
  report.

## 3a. Decisions and Rejected Alternatives

**Decision:** keep the old `power` column as an alias.
**Rationale:** result stores and existing downstream code may already read it.
The new name fixes interpretation without invalidating stored artifacts.

**Rejected alternative:** delete the zero-exclusion panel.
**Rationale:** it still helps diagnose saturated intervals and target-scale
misalignment, as long as it is not interpreted as Type-I error or power.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file = "dev/m3-pilot-report.R")); cat("r-parse-ok\n")'`
  -> `r-parse-ok`.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/power-pilot-sweep.yaml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `Rscript --vanilla dev/m3-pilot-report.R --scoring-audit --results-dir=/tmp/gllvmtmb-pilot-results.8xrBCf/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local --audit-out=/tmp/gllvmtmb-pilot-scoring-audit-patched-2026-06-06.md --audit-rds=/tmp/gllvmtmb-pilot-scoring-audit-patched-2026-06-06.rds`
  -> scoring audit wrote markdown and RDS outputs.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-report.R"); x <- pilot_collect(results_dirs = c("/tmp/gllvmtmb-pilot-results.8xrBCf/dev/m3-pilot-results", "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local")); stopifnot("zero_exclusion_rate" %in% names(x)); stopifnot(identical(x$zero_exclusion_rate, x$power)); p <- pilot_plot(x, save = FALSE); stopifnot(all(c("coverage", "zero_exclusion") %in% names(p))); cat("pilot-report-api-ok\n")'`
  -> `pilot-report-api-ok`.
- `air format dev/m3-pilot-report.R`
  -> completed without output.

Not run: `devtools::test()`, `devtools::check()`, `devtools::document()`,
`pkgdown::check_pkgdown()`, or article builds. This slice changes a `dev/`
reporting helper, one workflow board string, and dev-log artifacts only.

## 5. Tests of the Tests

No formal package tests were added. The API smoke is the relevant boundary
check: it verifies that the new `zero_exclusion_rate` column is present, the
legacy `power` alias is byte-identical, and `pilot_plot()` exposes the renamed
`zero_exclusion` plot without breaking the coverage plot.

## 6. Consistency Audit

- `rg -n "power|zero|pilot_plot|pilot_record|zero_reject|CI-excludes|Type-I|coverage|bias|RMSE|miss" dev/m3-pilot-report.R`
  -> identified the stale `power` / Type-I wording before the patch.
- `rg -n "pilot-power-curve|pilot_plot\\(|\\$power|power\\)" .github dev docs tests vignettes README.md NEWS.md`
  -> found only the report helper, workflow board wording, and Design 66
  conceptual power text; no public package docs needed a cascade.

## 7. Roadmap Tick

No roadmap status changed. The Phase-1 pilot remains diagnostic; CI-08 and
CI-10 remain `partial`.

## 7a. GitHub Issue Ledger

- Posted #340 update:
  <https://github.com/itchyshin/gllvmTMB/issues/340#issuecomment-4640838745>.
- Posted #349 update:
  <https://github.com/itchyshin/gllvmTMB/issues/349#issuecomment-4640839299>.

## 8. What Did Not Go Smoothly

The quick summary command used `sum(x$flag %in% TRUE)`, which is wrong for the
character `flag` column. The printed `flag` column still showed the expected
high-failure cells, and the issue comments used the audited rows rather than
that mistaken count.

## 9. Team Learning

**Ada:** The Phase-1 pilot should stay diagnostic until its scoring targets are
aligned. A saturated zero-exclusion curve is useful evidence of a definition
problem, not proof of power.

**Fisher:** Fit health, coverage, miss side, bias, and CI width need separate
columns. Collapsing them into one power-looking curve hides the reason a cell
is failing.

**Grace:** Keeping the old `power` alias avoids breaking existing stores while
the workflow summary and output filename move to the corrected label.

**Rose:** The board and issue ledger now say the same thing as the scoring
audit: no capability or coverage row should move yet.

## 10. Known Limitations And Next Actions

- The report still needs a fuller target-aligned Phase-1 summary surface:
  coverage, bias/RMSE, miss side, CI width, and fit-health panels.
- No validation-debt register update is appropriate until those target-aligned
  summaries clear a pre-agreed gate.
- The RE-03 diagnostic workflow dispatched after #457 is still a separate
  evidence lane and should be summarized back to #341 when complete.
