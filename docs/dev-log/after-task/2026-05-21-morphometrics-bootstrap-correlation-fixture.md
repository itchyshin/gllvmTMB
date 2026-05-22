# After-task report: morphometrics bootstrap correlation fixture

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose
**Spawned subagents:** none

## Scope

This slice gives the morphometrics article a cached bootstrap correlation
fixture so public documentation can render the new direct bootstrap plotting
path without running bootstrap refits during pkgdown:

- Added `data-raw/examples/make-morphometrics-bootstrap-correlation.R`.
- Added `inst/extdata/examples/morphometrics-bootstrap-r.rds`, a small
  `bootstrap_Sigma()` object with `R_B` point estimates and percentile bounds
  from 100 cached bootstrap replicates.
- Updated `vignettes/articles/morphometrics.Rmd` to load the cached object and
  render `plot_correlations(morph_boot_R, style = "raindrop")`.
- The article discloses `n_boot = 100` and `n_failed = 4`, and states that the
  fixture is for rendered plotting / visual QA rather than interval-calibration
  evidence.
- Added validation-debt row `MIS-22`.

## Files touched

- `data-raw/examples/make-morphometrics-bootstrap-correlation.R`
- `inst/extdata/examples/morphometrics-bootstrap-r.rds`
- `tests/testthat/test-example-morphometrics.R`
- `vignettes/articles/morphometrics.Rmd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-morphometrics-bootstrap-correlation-fixture.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice does not add a
   likelihood, family, keyword, estimator, or bootstrap algorithm. The fixture
   stores a small cached bootstrap display object.
3. **Documentation:** `NEWS.md`, the morphometrics article, the report-ready
   plot contract, and the validation-debt register were updated. No roxygen
   source changed.
4. **Runnable user-facing example:** the morphometrics article renders the
   cached bootstrap raindrop figure from a shipped object.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked fixture shape and plot metadata, Fisher
   checked bootstrap provenance / failed-refit disclosure, Florence checked the
   rendered raindrop figure, Pat checked reader wording, Grace checked local
   package commands and article render, and Rose checked register / NEWS /
   article consistency. No likelihood, formula grammar, or TMB plumbing changed,
   so Boole, Gauss, and Noether were not active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed only the current
  covariance/plot lane.
- Trial timing: `bootstrap_Sigma(..., n_boot = 3, what = "R")` completed in
  1.82 seconds with 0 failed refits.
- First full fixture-generation run stopped because the generator required zero
  failed refits; the run reported 4 failed refits. The generator was then
  corrected to warn and store provenance rather than hiding bootstrap failures.
- `Rscript --vanilla data-raw/examples/make-morphometrics-bootstrap-correlation.R`
  saved `inst/extdata/examples/morphometrics-bootstrap-r.rds` (884 bytes) with
  `n_boot = 100`, `seed = 20260521`, and `n_failed = 4`.
- `air format data-raw/examples/make-morphometrics-bootstrap-correlation.R tests/testthat/test-example-morphometrics.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "example-morphometrics")'`
  returned 45 passes, 0 failures, 0 warnings, 0 skips.
- Synthetic visual QA render:
  `plot_correlations(boot, tier = "unit", style = "raindrop", sort = "trait")`
  wrote `/tmp/gllvmTMB-morphometrics-bootstrap-raindrop.png`.
  Florence review verdict: PASS; row spacing is even, point estimates remain
  visible, and the caption no longer implies posterior density or missing
  intervals.
- `Rscript --vanilla -e 'pkgdown::build_article("morphometrics", quiet = TRUE)'`
  failed because pkgdown did not find the nested article slug.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/morphometrics", quiet = TRUE)'`
  failed in a new process because that process used a stale installed package
  without `extract_Sigma_table()`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics", quiet = TRUE, new_process = FALSE)'`
  rendered `pkgdown-site/articles/morphometrics.html` successfully.
- Rendered PNG reviewed at
  `pkgdown-site/articles/morphometrics_files/figure-html/ci-correlation-raindrop-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n "MIS-22|EXT-24|morphometrics-bootstrap-r|cached bootstrap|failed refits|interval-calibration|plot_correlations\\(morph_boot_R|bootstrap_Sigma\\(\\.\\.\\., what = \\\"R\\\"\\)" NEWS.md vignettes/articles/morphometrics.Rmd tests/testthat/test-example-morphometrics.R data-raw/examples/make-morphometrics-bootstrap-correlation.R docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md pkgdown-site/articles/morphometrics.html`
  confirms the fixture, public prose, rendered HTML, tests, NEWS, and register
  rows tell the same story.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|profile-likelihood default|trio|diag\\(U\\)|U_phy|U_non|\\\\bf S|S_B|S_W" vignettes/articles/morphometrics.Rmd NEWS.md docs/design/53-report-ready-extractor-plot-contract.md`
  found no stale terminology in the touched article or plot contract. Hits in
  older NEWS sections were pre-existing compatibility/deprecation text.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this article/fixture
  slice. Focused fixture tests, single-article render, visual QA,
  `pkgdown::check_pkgdown()`, `git diff --check`, and a short no-tests package
  check were run.
- No vdiffr snapshot was added.
