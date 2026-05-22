# After-task report: repeatability bootstrap interval rows

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose  
**Spawned subagents:** none

## Scope

This slice mirrors the communality bootstrap-object bridge for
repeatability / ICC summaries:

- `extract_repeatability()` now accepts a `bootstrap_Sigma` object when it
  contains `ICC_site`, returning `trait`, `R`, `lower`, `upper`, and
  `method = "bootstrap"` without rerunning refits.
- `plot(type = "integration", boot = boot)` now accepts a raw
  `bootstrap_Sigma()` object and pulls repeatability plus communality
  intervals directly.
- The integration plot now uses `geom_errorbar(orientation = "y")` for
  interval layers, avoiding the ggplot2 4.0.0 `geom_errorbarh()` deprecation.
- Validation-debt row `EXT-22` records the evidence for this bridge.

## Files touched

- `R/extract-repeatability.R`
- `R/plot-gllvmTMB.R`
- `tests/testthat/test-extract-repeatability-bootstrap.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `man/extract_repeatability.Rd`
- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-repeatability-bootstrap-interval-rows.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice does not add a
   likelihood, family, keyword, estimator, or new bootstrap algorithm; it
   reuses summaries already computed by `bootstrap_Sigma()`.
3. **Documentation:** roxygen regenerated `man/extract_repeatability.Rd`;
   `NEWS.md`, extractor contract, plot contract, and validation-debt register
   updated.
4. **Runnable user-facing example:** roxygen `extract_repeatability()` example
   now shows the `bootstrap_Sigma()` reuse path inside `\dontrun{}`.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked API shape, Fisher checked interval semantics,
   Florence checked the rendered integration overlay, Pat checked that no
   hand-built joins are required, Grace checked package commands, and Rose
   checked stale wording / row parity. No likelihood, formula grammar, or TMB
   plumbing changed, so Boole, Gauss, and Noether were not active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed only the current
  covariance/plot lane and PR #233 base commits.
- `Rscript --vanilla -e 'parse("R/extract-repeatability.R"); parse("R/plot-gllvmTMB.R")'`
  parsed successfully.
- `air format R/extract-repeatability.R R/plot-gllvmTMB.R tests/testthat/test-extract-repeatability-bootstrap.R tests/testthat/test-plot-gllvmTMB.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  `man/extract_repeatability.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-repeatability-bootstrap|plot-gllvmTMB")'`
  returned 171 passes, 0 failures, 0 warnings, 0 skips after formatter and
  documentation regeneration.
- Synthetic visual QA render:
  `plot(fit, type = "integration", boot = boot)` wrote
  `/tmp/gllvmTMB-integration-bootstrap-overlay.png`.
  Florence review verdict: PASS after removing the stale open-ring caption
  clause when no intervals are missing.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n "EXT-22|repeatability bootstrap|bootstrap_Sigma\\(.*ICC|plot\\(type = \"integration\"|ICC_site|extract_repeatability\\(boot" NEWS.md R/extract-repeatability.R R/plot-gllvmTMB.R man/extract_repeatability.Rd man/plot.gllvmTMB_multi.Rd tests/testthat/test-extract-repeatability-bootstrap.R tests/testthat/test-plot-gllvmTMB.R docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md`
  confirms the repeatability bootstrap-object path appears in code, tests, Rd,
  NEWS, and design / validation docs.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this narrow reporting
  and plotting slice. Focused extractor/plot tests, documentation
  regeneration, visual QA, `pkgdown::check_pkgdown()`, `git diff --check`, and
  a short no-tests package check were run.
- No vdiffr snapshot was added; current plot evidence is object-shape tests
  plus manual rendered PNG review.
