# After-Task Report: Extractor Reference Wording

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Fisher, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned the next reference cluster after the method/plot pages: covariance,
correlation, communality, repeatability, and the profile-derived helpers that
sit behind them.

This is a documentation and boundary-message slice. It does not change model
fitting, estimator definitions, bootstrap calculations, plotting geometry, or
article examples.

## Files Touched

- `R/extract-sigma.R`
- `R/extract-sigma-table.R`
- `R/extract-correlations.R`
- `R/extractors.R`
- `R/extract-repeatability.R`
- `R/profile-derived.R`
- `man/extract_Sigma.Rd`
- `man/extract_Sigma_table.Rd`
- `man/compare_Sigma_table.Rd`
- `man/extract_correlations.Rd`
- `man/extract_Sigma_B.Rd`
- `man/extract_Sigma_W.Rd`
- `man/extract_ICC_site.Rd`
- `man/extract_communality.Rd`
- `man/extract_repeatability.Rd`
- `man/profile_ci_repeatability.Rd`
- `man/profile_ci_phylo_signal.Rd`
- `man/profile_ci_communality.Rd`
- `man/profile_ci_correlation.Rd`
- `docs/dev-log/check-log.md`

## What Changed

- Replaced class-first argument text with "fit returned by `gllvmTMB()`" on
  extractor and profile-helper pages.
- Updated wrong-object errors in the touched extractors to ask for a fit
  returned by `gllvmTMB()` rather than exposing `gllvmTMB_multi` as the thing
  users need to know.
- Reworded `extract_correlations()` around canonical input levels:
  `unit`, `unit_obs`, `phy`, and `spatial`. The return section still states
  that the current `tier` output column stores internal labels (`B`, `W`,
  `phy`, `spde`), so the docs do not overpromise a schema change.
- Reframed bootstrap correlation intervals as a practical uncertainty path
  when Hessian/profile intervals are unsuitable, with a reminder to inspect
  bootstrap warnings, failed replicates, and interval width.
- Passed canonical level names into `profile_ci_correlation()` from
  `extract_correlations()`, and suppressed the second internal warning when
  `profile_ci_correlation()` delegates to `extract_Sigma()`.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated affected Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|sigma-rename|extract-correlations|extract-communality|extract-repeatability|plot-covariance-tables", stop_on_failure = TRUE)'`
  -> 376 passes, 0 failures, 0 warnings, 1 known skip.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|sigma-rename|extract-correlations|extract-communality|extract-repeatability|plot-covariance-tables|profile-ci", stop_on_failure = TRUE)'`
  -> 417 passes, 0 failures, 2 warnings, 1 known skip. The warnings came from
  existing profile tests that still exercise legacy `B` / `Sigma_B` inputs,
  which should be handled in the later `confint()` naming sweep.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the report/check-log entry.
- Stale wording scan:

  ```sh
  rg -n 'gllvmTMB_multi model|A `gllvmTMB_multi` fit|A `gllvmTMB_multi` object|A \\code\\{gllvmTMB_multi\\} fit|fitted gllvmTMB_multi model|posterior uncertainty|5 tiers|non, spde|c\\("B", "W", "phy", "spde"\\)' ...
  ```

  -> no hits in the touched source/Rd files.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice changes reference docs,
  wrong-object messages, and one warning-suppression boundary only.
- Documentation: roxygen and generated Rd were updated together.
- Runnable user-facing example: unchanged; no examples or articles were edited.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Fisher/Rose-style checks were applied through source/Rd
  wording review, focused extractor tests, stale scans, and pkgdown checks.

## Residuals

- `confint.gllvmTMB_multi()` still documents and tests `Sigma_B` / `Sigma_W`.
  That needs a separate naming sweep because it is both an argument convention
  and an output-parameter convention.
- Full package tests, full `devtools::check()`, and 3-OS CI were not run in
  this local reference slice.
