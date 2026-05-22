# After-task report: Sigma truth-comparison plot helper

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Add a small exported plot helper over `compare_Sigma_table()` so simulation and
teaching articles can show estimate-versus-truth comparisons without rebuilding
ggplot scaffolding by hand.

## Mathematical Contract

No likelihood, formula grammar, family, or TMB parameterisation changed. The
new plot helper visualises rows that already contain:

```text
error = estimate - truth
abs_error = |error|
```

Segments in the plot are comparison residuals, not confidence intervals.

## Scope

- Added exported `plot_Sigma_comparison()`.
- Default `style = "difference"` draws a row-labelled `estimate - truth`
  plot with zero as the reference value.
- `style = "scatter"` draws estimate versus truth with a one-to-one reference
  line.
- The helper accepts precomputed `compare_Sigma_table()` rows or builds them
  from a fitted model / Sigma table plus one supplied truth matrix.
- Plot objects carry `gllvmTMB_meta`, `gllvmTMB_data`, and a
  `comparison_status` metadata field.
- Added focused tests for difference plots, scatter plots, and required-column
  validation.
- Updated roxygen/Rd, pkgdown navigation, NEWS, validation row EXT-26, and the
  report-ready extractor/plot contract.

## Files Touched

- `R/plot-covariance-tables.R`
- `R/extract-sigma-table.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `man/plot_Sigma_comparison.Rd`
- `man/compare_Sigma_table.Rd`
- `NAMESPACE`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-sigma-truth-comparison-plot.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice plots supplied
   comparison rows; it does not add a likelihood, family, keyword, estimator,
   or simulation engine.
3. **Documentation:** roxygen was added and regenerated to
   `man/plot_Sigma_comparison.Rd`; `_pkgdown.yml`, `NEWS.md`,
   `docs/design/35-validation-debt-register.md`, and
   `docs/design/53-report-ready-extractor-plot-contract.md` were updated.
4. **Runnable user-facing example:** the generated Rd example constructs a
   small correlation table and truth matrix, then calls
   `plot_Sigma_comparison()`.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked plot-data metadata shape, Fisher checked that
   residual segments are not described as uncertainty, Florence checked the
   rendered figure, Pat checked the article-user workflow, Grace checked local
   package commands, and Rose checked cross-file consistency. Boole, Gauss,
   Noether, Curie, Darwin, Jason, and Shannon were not active because no
   grammar, likelihood, simulation, biology narrative, external source-map, or
   handoff coordination changed.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `NAMESPACE` and `man/plot_Sigma_comparison.Rd`; after the Rose
  stale-wording cleanup it also rewrote `man/compare_Sigma_table.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 121 passes, 0 failures, 0 warnings, 0 skips.
- Rendered visual QA images:
  `/tmp/gllvmTMB-sigma-comparison-difference.png` and
  `/tmp/gllvmTMB-sigma-comparison-scatter.png`.
- `tail -5 man/plot_Sigma_comparison.Rd && grep -c '^\\keyword' man/plot_Sigma_comparison.Rd`
  -> Rd tail was well formed and keyword count was `0`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.` This was rerun after the stale-wording cleanup.
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'plot_Sigma_comparison|EXT-26|sigma_comparison|estimate-vs-truth|comparison_status|not confidence intervals' NEWS.md R/plot-covariance-tables.R man/plot_Sigma_comparison.Rd tests/testthat/test-plot-covariance-tables.R _pkgdown.yml docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md NAMESPACE`
  -> confirmed the new helper appears in export, generated help, tests,
  pkgdown navigation, NEWS, validation debt, and the report-ready contract.
- `rg -n 'estimate-vs-truth article figures remain future|interval-aware table joins|interval-aware Sigma-table joins|rendered article integration|plotting geometry remains' NEWS.md R docs/design man`
  -> no hits after updating the previous table-helper and plot-helper wording.

## Tests Of The Tests

The acceptance tests cover both supported plot styles and the metadata contract.
The validation test covers the malformed-input path where a precomputed data
frame lacks comparison columns. Visual QA caught clipped scatter subtitle and
caption text at a compact export size; the wording was shortened and the
scatter image was regenerated cleanly. Rose then caught stale "plot helper is
future" language left by the immediately preceding table-helper slice; NEWS,
roxygen, generated Rd, and the design contract were updated before closeout.

## GitHub Issue Ledger

- Inspected issue #230 (`Article surface reset and user-first tooling gate`)
  through the current issue-search results. This slice advances its
  table-first plotting path but does not close the issue.
- `gh issue list --state open --limit 20 --search "plot Sigma comparison"`
  and `gh issue list --state open --limit 20 --search "estimate truth plot"`
  both surfaced issue #230 as the relevant open issue.
- No issue was closed and no new issue was created. The next article-rewiring
  slice remains within #230.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice; the active roadmap already
records the article-surface/tooling lane.

## Known Limitations And Next Actions

- `plot_Sigma_comparison()` is a visual comparison helper only. It does not run
  simulations, bootstrap, or calibration summaries.
- The next narrow slice is to use `compare_Sigma_table()` /
  `plot_Sigma_comparison()` in article code that still hand-indexes covariance
  matrices for known-truth examples.
