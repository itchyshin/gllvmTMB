# After-task report: bootstrap provenance in plot metadata

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Fisher, Grace, Rose
**Spawned subagents:** none

## Scope

This slice preserves extractor notes in the exported covariance/correlation
table plot helpers:

- `plot_correlations()` now forwards `attr(input, "notes")` into
  `attr(p, "gllvmTMB_meta")$notes`.
- `plot_Sigma_table()` does the same for Sigma/correlation table rows.
- Bootstrap-derived rows therefore carry provenance such as `n_boot`,
  `n_failed`, and `conf` into report and article plot objects.

## Files touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `NEWS.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-bootstrap-provenance-plot-metadata.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice changes plot metadata
   only; it does not add a likelihood, family, keyword, estimator, or bootstrap
   algorithm.
3. **Documentation:** NEWS and the report-ready plot contract were updated. No
   roxygen source changed.
4. **Runnable user-facing example:** not changed; this slice affects plot
   metadata consumed by reports and articles.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked the metadata contract, Fisher checked interval
   provenance visibility, Grace checked local package commands, and Rose
   checked cross-file consistency. No visual geometry, likelihood, formula
   grammar, or TMB plumbing changed, so Florence, Boole, Gauss, and Noether
   were not active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed the current
  covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  returned 100 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n 'Bootstrap provenance|gllvmTMB_meta.*notes|n_boot|n_failed|plot_correlations\\(\\)|plot_Sigma_table\\(\\)|EXT-19|EXT-20|EXT-24' NEWS.md R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R docs/design/53-report-ready-extractor-plot-contract.md`
  confirmed the provenance metadata surface is present in NEWS, code, tests,
  and the plot contract.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this narrow metadata
  slice. Focused plot tests, pkgdown check, whitespace check, stale-wording
  scan, and a short no-tests package check were run.
- No article render was needed because no vignette changed.
