# After-task report: correlation ellipse bootstrap intervals

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose  
**Spawned subagents:** none

## Scope

This slice gives the built-in correlation heatmap and ellipse plot access to
precomputed bootstrap correlation intervals:

- `plot(type = "correlation", boot = boot)` now merges `R_B` / `R_W`
  percentile bounds from a `bootstrap_Sigma()` object into the heatmap data.
- `plot(type = "correlation_ellipse", boot = boot)` uses the same interval
  metadata to mark correlations whose supplied intervals do not cross zero with
  black borders and stars.
- Plot metadata now reports `interval_status` for the correlation and
  correlation-ellipse plot types.
- Validation-debt row `EXT-23` records the evidence for the interval-aware
  correlation plot path.

## Files touched

- `R/plot-gllvmTMB.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `man/plot.gllvmTMB_multi.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-correlation-ellipse-bootstrap-intervals.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice does not add a
   likelihood, family, keyword, estimator, or new bootstrap algorithm; it
   reuses correlation intervals already computed by `bootstrap_Sigma()`.
3. **Documentation:** roxygen regenerated `man/plot.gllvmTMB_multi.Rd`;
   `NEWS.md`, plot contract, and validation-debt register updated.
4. **Runnable user-facing example:** not added as an article example in this
   slice because public article bootstrap examples need a lightweight fixture
   rather than refits inside rendered chunks.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked plot metadata shape, Fisher checked
   interval-significance semantics, Florence checked the rendered ellipse
   overlay, Pat checked that no hand-indexing is needed, Grace checked package
   commands, and Rose checked stale wording / validation-row parity. No
   likelihood, formula grammar, or TMB plumbing changed, so Boole, Gauss, and
   Noether were not active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed only the current
  covariance/plot lane and PR #233 base commits.
- `air format R/plot-gllvmTMB.R tests/testthat/test-plot-gllvmTMB.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  `man/plot.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  returned 176 passes, 0 failures, 0 warnings, 0 skips after formatter and
  documentation regeneration.
- Synthetic visual QA render:
  `plot(fit, type = "correlation_ellipse", boot = boot)` wrote
  `/tmp/gllvmTMB-correlation-ellipse-bootstrap.png`.
  Florence review verdict: PASS; black borders/stars are visible where supplied
  bootstrap intervals do not cross zero, and the caption now states that
  interpretation directly.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n "EXT-23|correlation ellipse|correlation_ellipse|R_B|R_W|interval-aware summaries|do not cross zero" NEWS.md R/plot-gllvmTMB.R man/plot.gllvmTMB_multi.Rd tests/testthat/test-plot-gllvmTMB.R docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md`
  confirms the interval-aware correlation plot surface is present in code,
  tests, Rd, NEWS, and design / validation docs.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this narrow plotting
  slice. Focused plot tests, documentation regeneration, visual QA,
  `pkgdown::check_pkgdown()`, `git diff --check`, and a short no-tests package
  check were run.
- No rendered article was updated and no vdiffr snapshot was added.
