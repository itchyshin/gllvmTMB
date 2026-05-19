# After Task: M3.3 production artifact review

**Branch**: `codex/m3-production-artifact-review-2026-05-19`
**Date**: 2026-05-19
**Roles (engaged)**: Ada, Curie, Fisher, Grace, Rose

## 1. Goal

Run the manual M3.3 production grid, inspect the resulting R = 200
artifacts, and update the repository according to the evidence rather
than assuming the production grid would clear the coverage gate.

## 2. Implemented

- Dispatched GitHub Actions run 26100827665 with `n_reps = 200`,
  `init_strategy = "single_trait_warmup"`, and `retention_days = 14`.
- Downloaded all 15 per-cell artifacts and aggregated the full grid
  files, not just the per-cell summaries.
- Filed `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`.
- Kept CI-08 and CI-10 in `partial` status because only 2/15 cells
  cleared the 94 % profile-psi coverage gate.
- Patched `m3_summarise()` so failed replicate fits are counted before
  unavailable coverage rows are filtered out.
- Added `tests/testthat/test-m3-grid-summary.R` to catch that summary
  failure path.

No public R API, likelihood, formula grammar, response family,
roxygen, generated Rd, vignette, README, NEWS, or pkgdown navigation
changed.

## 3. Files Changed

- `dev/m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/42-m3-dgp-grid.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `ROADMAP.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-m3-production-artifact-review.md`

No example file changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: do not promote the production RDS files to
  `inst/extdata/`.
  **Rationale**: the workflow passed, but 13/15 cells failed the
  statistical gate.
  **Rejected alternative**: commit the production RDS files as
  reader-facing evidence anyway.
  **Confidence**: high.
- **Decision**: compute the audit table from full grid RDS files.
  **Rationale**: the uploaded summaries undercounted failed refits
  because `m3_summarise()` filtered out failed rows first.
  **Rejected alternative**: trust the per-cell `n_failed = 0`
  summaries.
  **Confidence**: high.
- **Decision**: keep CI-08 and CI-10 as `partial`.
  **Rationale**: only `gaussian-d1` and `gaussian-d3` cleared the
  94 % gate; mixed-family and nbinom2 cells are far below the target.
  **Rejected alternative**: mark Gaussian-only evidence as broad M3
  coverage.
  **Confidence**: high.

## 4. Checks Run

- `gh pr list --state open --limit 20` -> no open PR rows before this
  branch.
- `git log --all --oneline --since="6 hours ago"` -> inspected recent
  merge order through PR #198.
- `gh workflow run m3-production-grid.yaml --ref main -f n_reps=200 -f init_strategy=single_trait_warmup -f retention_days=14`
  -> dispatched run 26100827665.
- `gh run watch 26100827665 --exit-status --interval 60` -> success;
  all 15 matrix jobs completed and uploaded artifacts.
- `gh run view 26100827665 --json status,conclusion,url,createdAt,updatedAt`
  -> `status = completed`, `conclusion = success`, created
  `2026-05-19T13:36:55Z`, updated `2026-05-19T15:01:30Z`.
- `gh run download 26100827665 --dir /tmp/gllvmtmb-m3-artifacts-26100827665`
  -> downloaded 15 artifact directories.
- `find /tmp/gllvmtmb-m3-artifacts-26100827665 -maxdepth 3 -type f | sort`
  -> confirmed 30 RDS files: grid + summary for every cell.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); root <- "/tmp/gllvmtmb-m3-artifacts-26100827665"; gfiles <- list.files(root, pattern = "grid[.]rds$", recursive = TRUE, full.names = TRUE); grids <- lapply(gfiles, function(f) readRDS(f)$grid); grid <- do.call(rbind, grids); s <- m3_summarise(grid); s <- s[order(s$family, s$d), ]; print(s, row.names = FALSE)'`
  -> only 2/15 cells passed; 236/3000 replicate fits failed.
- `air format dev/m3-grid.R tests/testthat/test-m3-grid-summary.R`
  -> completed.
- `Rscript --vanilla -e 'parse("dev/m3-grid.R"); parse("tests/testthat/test-m3-grid-summary.R")'`
  -> parsed both files.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  -> PASS 10, WARN 0, SKIP 0, FAIL 0.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

The new summary test is a failure-before-fix test: it constructs a
cell with one failed replicate whose `covered_prof` value is `NA`.
Before the patch, `m3_summarise()` dropped that row before counting
failures and returned `n_failed = 0`. The test now checks both the
acceptance path with converged coverage rows and the boundary path
where a cell has no converged coverage rows.

## 6. Consistency Audit

- `rg -n "M3\\.3 production|m3-production-grid|26100827665|profile-psi|coverage gate|CI-08|CI-10" ROADMAP.md docs/design docs/dev-log`
  -> repository surfaces now point to the same production-run outcome.
- `rg -n "n_failed = 0|n_failed.*0|n_completed.*985|n_completed.*990" docs/dev-log/audits docs/design ROADMAP.md`
  -> one intentional hit in the audit explaining the old artifact
  summary bug; no design or roadmap surface claims zero failures.
- `rg -n "inst/extdata/m3-coverage-grid-production|m3-coverage-grid-production" README.md NEWS.md vignettes docs/design docs/dev-log`
  -> two expected hits: Design 44's deferred promotion condition and
  this command record. No user-facing surface claims the production
  RDS has shipped.
- Convention-change cascade: not applicable. No argument name,
  keyword, default, function signature, syntax requirement, roxygen,
  Rd, or example changed.

## 7. Roadmap Tick

M3 remains `███░░░░░` 3/8. M3.3 did not complete because the
production evidence failed the 94 % gate. ROADMAP now directs the next
small lane to failure-mode triage before rerunning the grid or moving
reader-facing claims.

## 8. What Did Not Go Smoothly

The workflow passed, but the statistical evidence was not close to the
advertised claim for most families. The artifact review also found a
summary bug that hid failed replicate counts in the uploaded
per-cell summaries. Reading the full grid artifacts caught the issue
before the validation-debt register could accidentally promote a weak
claim.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada: kept the lane in evidence-review mode rather than treating
  green CI as a coverage success.
- Curie: verified the production artifacts cell by cell and patched
  the failed-replicate summary contract.
- Fisher: kept CI-08 / CI-10 partial because the 94 % profile-psi gate
  failed in 13/15 cells.
- Grace: confirmed the Actions matrix, artifact upload, and artifact
  download path worked end to end.
- Rose: aligned ROADMAP, Design 42, Design 44, the validation-debt
  register, check-log, coordination board, and this after-task report
  to the same evidence.

## 10. Known Limitations And Next Actions

- The production grid does not validate the current profile-psi
  coverage claim.
- The audit did not diagnose the cause of undercoverage; it only
  classifies the outcome and fixes the summary-count bug.
- Next lane: diagnose profile target / transform calibration and
  failed-refit patterns, then rerun a minimal subset before scheduling
  another full 15-cell production grid.
