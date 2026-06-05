# After Task: Power-Pilot Scoring Audit Helper

**Branch**: started on `main`; protected on
`codex/power-pilot-scoring-audit-2026-06-05`
**Date**: `2026-06-04`
**Roles (engaged)**: `Ada / Curie / Rose / Grace`

## 1. Goal

Add a local diagnostic path for issue #340 so the Design 66 power pilot can
audit target-scale alignment before treating the current CI-excludes-zero panel
as power or Type-I evidence.

## 2. Implemented

- Added `pilot_read_cell_grids()` as the shared result-store loader for
  `pilot_collect()` and scoring audits.
- Added `pilot_scoring_audit()`, `pilot_scoring_audit_record()`, and supporting
  helpers in `dev/m3-pilot-report.R`.
- Added a `--scoring-audit` CLI path that writes Markdown and RDS audit
  artifacts.
- Posted the combined-store audit result to issue #340:
  <https://github.com/itchyshin/gllvmTMB/issues/340#issuecomment-4626708344>.

## 3. Files Changed

- `dev/m3-pilot-report.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-04-power-pilot-scoring-audit.md`

No package exports, roxygen blocks, Rd files, vignettes, likelihood code, or
formula grammar changed.

## 3a. Decisions and Rejected Alternatives

Decision: keep the audit in `dev/m3-pilot-report.R` rather than adding a package
function.

Rationale: the helper reads build-ignored pilot result stores and diagnoses the
simulation campaign; it is not a user-facing package API.

Rejected alternative: change the power plot immediately. The audit first records
why the current zero-exclusion metric is not a target-aligned Type-I / power
quantity for `Sigma_unit_diag`.

Confidence: high for the scoring diagnosis; moderate for downstream plot
replacement until the maintainer chooses the final detection target.

## 4. Checks Run

- `pwd && git status --short --branch`
  - clean startup on `main`.
- `gh pr list --state open --limit 20 --json number,title,headRefName,baseRefName,updatedAt,url`
  - `[]`; no open PR collision.
- `git log --all --oneline --since="6 hours ago"`
  - only `db033cf power-pilot: accumulate reps (run 20)` on the results branch.
- `Rscript --vanilla -e 'f <- "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local/gaussian-d1-n150-sig0p0.rds"; x <- readRDS(f); print(dim(x)); print(names(x)); print(utils::head(x, 3)); str(x[1:min(nrow(x), 5), ], max.level = 1)'`
  - confirmed the stored pilot rows carry target, truth, estimate, interval,
    miss-side, seed, and fit-health fields.
- `air format dev/m3-pilot-report.R`
  - completed.
- `Rscript --vanilla dev/m3-pilot-report.R --scoring-audit --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local --audit-out=/tmp/gllvmtmb-pilot-scoring-audit.md --audit-rds=/tmp/gllvmtmb-pilot-scoring-audit.rds`
  - completed after a Markdown-table format fix.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-report.R"); dirs <- c("/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results", "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local"); df <- pilot_collect(results_dirs = dirs); stopifnot(nrow(df) == 48L, sum(df$n_sim, na.rm = TRUE) >= 45992L); cat("collect ok: ", nrow(df), " cells, reps=", sum(df$n_sim, na.rm = TRUE), "\n", sep = "")'`
  - `collect ok: 48 cells, reps=45992`.
- `Rscript --vanilla dev/m3-pilot-report.R --emit-issues --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local`
  - existing issue-summary CLI still reports 28 flagged cells.

Closeout rerun after protecting the dirty `main` worktree on
`codex/power-pilot-scoring-audit-2026-06-05`:

- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,headRefName,baseRefName,updatedAt,url`
  - `[]`; no open PR collision.
- `git log --all --oneline --since="6 hours ago"`
  - showed #453 and #454 merged on `origin/main`; no same-file collision with
    this branch.
- `Rscript --vanilla dev/m3-pilot-report.R --scoring-audit --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local --audit-out=/tmp/gllvmtmb-pilot-scoring-audit-rerun.md --audit-rds=/tmp/gllvmtmb-pilot-scoring-audit-rerun.rds`
  - completed, writing fresh temp artifacts.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-report.R"); dirs <- c("/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results", "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local"); df <- pilot_collect(results_dirs = dirs); stopifnot(nrow(df) == 48L, sum(df$n_sim, na.rm = TRUE) >= 45992L); cat("collect ok: ", nrow(df), " cells, reps=", sum(df$n_sim, na.rm = TRUE), "\n", sep = "")'`
  - `collect ok: 48 cells, reps=50492`.
- `Rscript --vanilla dev/m3-pilot-report.R --emit-issues --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local`
  - existing issue-summary CLI still reports 28 flagged cells.

Post-rebase verification on `origin/main` (`bda8190`):

- `git rebase origin/main`
  - completed cleanly.
- `git diff --check origin/main...HEAD`
  - clean.
- `Rscript --vanilla dev/m3-pilot-report.R --scoring-audit --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local --audit-out=/tmp/gllvmtmb-pilot-scoring-audit-rebased.md --audit-rds=/tmp/gllvmtmb-pilot-scoring-audit-rebased.rds`
  - completed and wrote fresh temp artifacts on the rebased branch.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-report.R"); dirs <- c("/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results", "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local"); df <- pilot_collect(results_dirs = dirs); stopifnot(nrow(df) == 48L, sum(df$n_sim, na.rm = TRUE) >= 50492L); cat("collect ok: ", nrow(df), " cells, reps=", sum(df$n_sim, na.rm = TRUE), "\n", sep = "")'`
  - `collect ok: 48 cells, reps=50492`.
- `Rscript --vanilla dev/m3-pilot-report.R --emit-issues --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local`
  - existing issue-summary CLI still reports 28 flagged cells.

Final Markdown-table separator polish changed `paste()` to `paste0()` in the
audit writer. Final checks completed:

- `git diff --check origin/main...HEAD && git diff --check`
- `Rscript --vanilla dev/m3-pilot-report.R --scoring-audit --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local --audit-out=/tmp/gllvmtmb-pilot-scoring-audit-final.md --audit-rds=/tmp/gllvmtmb-pilot-scoring-audit-final.rds`
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-report.R"); dirs <- c("/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results", "/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local"); df <- pilot_collect(results_dirs = dirs); stopifnot(nrow(df) == 48L, sum(df$n_sim, na.rm = TRUE) >= 50492L); cat("collect ok: ", nrow(df), " cells, reps=", sum(df$n_sim, na.rm = TRUE), "\n", sep = "")'`
- `Rscript --vanilla dev/m3-pilot-report.R --emit-issues --results-dir=/tmp/gllvmtmb-pilot-results.Goztld/dev/m3-pilot-results,/Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-results-local`
- outcomes: `collect ok: 48 cells, reps=50492`; `--emit-issues` still reports
  28 flagged cells.

## 5. Tests of the Tests

This was a dev-reporting helper, not a new package test. The critical regression
check was that the refactored result-store loader preserved the existing
`pilot_collect()` output shape and the `--emit-issues` CLI path.

## 6. Consistency Audit

- `rg -n "power pilot|pilot_collect|coverage_primary|Sigma_unit_diag|Type-I|target mismatch|M3|CI-08|CI-10" /Users/z3437171/.codex/memories/MEMORY.md`
  - used to recover the relevant CI-08 / CI-10 overclaim boundary.
- `rg -n "nbinom1.*slope|phylo_.*slope.*nbinom1|spatial_.*slope.*nbinom1|augmented.*nbinom1|nbinom1.*augmented|PHY-18|SPA-10|spatial_dep.*nbinom1|phylo_dep.*nbinom1" tests/testthat R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md`
  - this branch did not edit #350. Current `origin/main` records nbinom1
    augmented slopes as admitted in PR #441; issue #350 is still open and
    appears stale relative to the register.

## 7. Roadmap Tick

N/A. No roadmap or validation-register row moved. CI-08 and CI-10 remain
partial.

## 7a. GitHub Issue Ledger

- Commented on #340 with the scoring-audit readout:
  <https://github.com/itchyshin/gllvmTMB/issues/340#issuecomment-4626708344>.
- Did not edit #350. Current `origin/main` records nbinom1 augmented slopes as
  admitted in PR #441; the still-open issue should be reconciled against that
  evidence before any new nbinom1 slope work.

## 8. What Did Not Go Smoothly

The first scoring-audit run succeeded, but after improving the table display the
Markdown writer had an invalid `%d` format for character miss-side cells. The
bug was caught by the CLI rerun and fixed before closeout.

`air format` reformatted existing portions of `dev/m3-pilot-report.R`, so the
diff is larger than the logical change.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: the next useful action was a diagnostic helper, not another pilot rerun or
an engine change.

Curie: for `Sigma_unit_diag`, a CI-excludes-zero rate is not Type-I error when
the signal-zero DGP still has a positive variance target.

Rose: the issue comment and check-log now carry the same bounded claim: this is
diagnostic evidence only, with no validation-register movement.

Grace: existing `pilot_collect()` and `--emit-issues` behavior was checked after
the loader refactor.

## 10. Known Limitations And Next Actions

- The current power plot should be renamed/demoted as a zero-exclusion
  diagnostic or replaced with target-aligned summaries: coverage, bias/RMSE,
  miss side, and CI width for `Sigma_unit_diag`.
- The Gaussian audit cell shows one-sided misses below the lower bound; that
  needs a target-scale estimator/CI diagnosis before promotion.
- nbinom2 high non-PD rates remain a separate fit-health issue.
- Issue #350 should be reconciled or closed against the PR #441 / register
  evidence before launching any new nbinom1 augmented-slope work.
