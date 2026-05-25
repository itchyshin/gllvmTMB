# After Task: Diagnostic Teaching Surface And Reset Queue

**Branch**: `codex/diagnostic-teaching-reset-2026-05-25`
**Date**: `2026-05-25`
**Roles (engaged)**: `Ada / Shannon / Fisher / Florence / Pat / Grace / Rose`
**Spawned subagents**: none

## 1. Goal

Carry the next slices after the #228 public API branch without widening the
#228 implementation PR: add a small public teaching surface for fitted-response
diagnostics, keep profile/bootstrap language honest, and reset the hidden
article queue around infrastructure gates.

## 2. Implemented

- Added README routing and status text for fitted diagnostics.
- Added a Get Started section that runs `check_gllvmTMB()`,
  `residuals(type = "randomized_quantile")`, and
  `predictive_check(type = "rq_qq")` on the shipped morphometrics fixture.
- Updated convergence-triage wording so users inspect fitted-response mismatch
  before interpreting covariance tables or routing uncertainty to bootstrap /
  profile workflows.
- Updated ROADMAP queue and restoration gates for diagnostic teaching, hidden
  article restoration, and profile/bootstrap uncertainty.
- Recorded the check-log entry for this follow-on branch.
- Triggered manual R-CMD-check run `26406417946` for #260 because the stacked
  PR base branch does not auto-trigger the pull-request workflow.
- Confirmed run `26406417946` passed on macOS, Ubuntu, and Windows, then
  posted the run link on #260.
- Opened draft PR #261 stacked on #260.

## 3. Scope Boundary

This branch changes public prose and vignette examples only. It does not add a
new likelihood, formula keyword, family, estimator, extractor, or TMB path.

IN: public examples now show how DIA-08 / DIA-10 fit-health checks connect to
DIA-11 / DIA-12 fitted-response diagnostics in the first morphometrics workflow.

PARTIAL: these docs still describe diagnostics, not interval calibration or
Bayesian posterior prediction.

PLANNED: one hidden article at a time can restart after its fixture, long/wide
example status, diagnostic table, validation rows, figure review, and rendered
HTML review are prepared.

## 4. Files Changed

- `README.md`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/convergence-start-values.Rmd`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-25-diagnostic-teaching-reset.md`

## 5. Checks Run

Completed:

- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); morph <- readRDS("inst/extdata/examples/morphometrics-example.rds"); fit <- gllvmTMB(morph$formula_wide, data=morph$data_wide, unit=morph$fit_args$unit, family=morph$fit_args$family); print(names(check_gllvmTMB(fit))); rq <- residuals(fit, type="randomized_quantile", seed=1); print(names(rq)); print(head(rq[, c("trait","family","observed","residual","status")], 4)); p <- predictive_check(fit, type="rq_qq", seed=1); print(class(p)); print(names(attr(p, "gllvmTMB_diagnostic")))'`
  -> confirms the teaching calls and metadata shape on the shipped fixture.
- `Rscript --vanilla -e 'tmp <- tempfile(fileext = ".html"); rmarkdown::render("vignettes/gllvmTMB.Rmd", output_file = tmp, envir = new.env(parent = globalenv()), quiet = FALSE); cat("rendered", tmp, "\n")'`
  -> failed because the local installed package did not yet export
  `predictive_check()`; this was recorded as an environment-lag render probe.
- `R CMD INSTALL --no-docs --no-help --no-html --no-test-load -l /tmp/gllvmTMB-lib-BD7vYS .`
  -> installed the current branch to a temporary library for source-style
  render checks.
- `Rscript --vanilla -e '.libPaths(c("/tmp/gllvmTMB-lib-BD7vYS", .libPaths())); tmp <- tempfile(fileext = ".html"); rmarkdown::render("vignettes/gllvmTMB.Rmd", output_file = tmp, envir = new.env(parent = globalenv()), quiet = FALSE); cat("rendered", tmp, "\n")'`
  -> rendered successfully.
- `Rscript --vanilla -e '.libPaths(c("/tmp/gllvmTMB-lib-BD7vYS", .libPaths())); tmp <- tempfile(fileext = ".html"); rmarkdown::render("vignettes/articles/convergence-start-values.Rmd", output_file = tmp, envir = new.env(parent = globalenv()), quiet = FALSE); cat("rendered", tmp, "\n")'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Rose scope and stale-wording scans listed in `docs/dev-log/check-log.md`
  -> no blocking inconsistency.
- `git diff --check`
  -> clean.
- `gh workflow run R-CMD-check.yaml --repo itchyshin/gllvmTMB --ref codex/public-diagnostics-228-2026-05-25`
  -> run `26406417946` queued for #260.
- `gh run view 26406417946 --repo itchyshin/gllvmTMB --json status,conclusion,jobs`
  -> success on macOS, Ubuntu, and Windows.

Deliberately not run:

- `devtools::test()`; this documentation-only branch did not change R code
  beyond the #260 base. The #228 implementation branch already ran focused,
  base-stack, and full tests.
- `devtools::check(args = "--no-manual")`; use CI after the stacked PR is
  pushed.

## 6. Definition Of Done Review

1. **Implementation.** Documentation-only follow-on branch; no implementation
   change.
2. **Simulation recovery test.** Not applicable; no new likelihood, family,
   keyword, or estimator.
3. **Documentation.** Public README and Get Started route added; affected
   rendered-document checks passed from a temporary install of the branch.
4. **Runnable user-facing example.** Uses the shipped morphometrics fixture;
   render checks passed from a temporary install of the branch.
5. **Check-log entry.** Added in `docs/dev-log/check-log.md`.
6. **Review pass.** Shannon pre-edit check done; Grace render/pkgdown checks
   passed; Rose stale-wording and scope scans passed with intentional hits
   only.
