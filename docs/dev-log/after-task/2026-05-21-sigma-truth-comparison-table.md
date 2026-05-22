# After-task report: Sigma truth-comparison table helper

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Fisher, Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Add a row-first helper that lets simulation and teaching articles compare
estimated Sigma/correlation rows with a known truth matrix without hand-indexing
matrices inside article chunks.

## Mathematical Contract

No likelihood, formula grammar, family, or TMB parameterisation changed. The
new helper compares an estimated covariance/correlation table against a supplied
truth matrix:

```text
error = estimate - truth
abs_error = |error|
```

For `measure = "correlation"`, the supplied truth matrix is converted with
`stats::cov2cor()` before row matching. This is a reporting helper, not a
calibration or uncertainty method.

## Scope

- Added exported `compare_Sigma_table()`.
- Accepted either a `gllvmTMB_multi` fit or precomputed
  `extract_Sigma_table()` rows.
- Added `truth`, `error`, `abs_error`, and `comparison_status` columns.
- Preserved upstream extractor notes and added a comparison note.
- Added tests for the acceptance path and a missing-trait rejection path.
- Registered the helper in `_pkgdown.yml`, `NAMESPACE`, `NEWS.md`, and the
  report-ready extractor/plot contract.

## Files Touched

- `R/extract-sigma-table.R`
- `tests/testthat/test-extract-sigma-table.R`
- `man/compare_Sigma_table.Rd`
- `NAMESPACE`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-sigma-truth-comparison-table.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice adds a table comparison
   helper, not a likelihood, family, keyword, estimator, or simulation engine.
3. **Documentation:** roxygen was added and regenerated to
   `man/compare_Sigma_table.Rd`; `_pkgdown.yml`, `NEWS.md`,
   `docs/design/35-validation-debt-register.md`, and
   `docs/design/53-report-ready-extractor-plot-contract.md` were updated.
4. **Runnable user-facing example:** the generated Rd example constructs a
   small report-ready correlation row and compares it with a named truth
   matrix.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked extractor/table shape, Fisher checked that the
   helper does not claim calibration or uncertainty, Pat checked article
   usability, Grace checked local package commands, and Rose checked
   cross-file consistency. Boole, Gauss, Noether, Curie, Darwin, Florence, and
   Shannon were not active because no grammar, likelihood, simulation, biology
   narrative, rendered figure, or handoff coordination changed.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/extract-sigma-table.R tests/testthat/test-extract-sigma-table.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `NAMESPACE` and `man/compare_Sigma_table.Rd`.
- `tail -5 man/compare_Sigma_table.Rd && grep -c '^\\keyword' man/compare_Sigma_table.Rd`
  -> Rd tail was well formed and keyword count was `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table")'`
  -> 55 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'compare_Sigma_table|EXT-25|estimate-vs-truth|truth matrix|comparison_status|abs_error' NEWS.md R/extract-sigma-table.R man/compare_Sigma_table.Rd tests/testthat/test-extract-sigma-table.R _pkgdown.yml docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md NAMESPACE`
  -> confirmed the new helper appears in export, generated help, tests,
  pkgdown navigation, NEWS, validation debt, and the report-ready contract.

## Tests Of The Tests

The acceptance test combines the new helper with the neighbouring
`bootstrap_Sigma()` -> `extract_Sigma_table()` path and verifies that upstream
bootstrap provenance notes survive the comparison. The rejection test exercises
a malformed/mismatched truth matrix name path. The first focused test run
failed because the test expected every note to match the comparison sentence;
the helper correctly preserved both bootstrap and comparison notes, so the
test was tightened to assert the combined-note contract.

## GitHub Issue Ledger

- Inspected issue #230 (`Article surface reset and user-first tooling gate`)
  with `gh issue view 230 --comments`. This slice advances its table-first
  reporting path but does not close the issue.
- `gh issue list --state open --limit 20 --search "Sigma truth"` and
  `gh issue list --state open --limit 20 --search "estimate truth"` both
  surfaced issue #230 as the relevant open issue.
- No issue was closed and no new issue was created. The next plot-helper slice
  remains small enough to track through #230 and the check-log.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice; the active roadmap already
records the article-surface/tooling lane.

## Known Limitations And Next Actions

- `compare_Sigma_table()` is table-only. It does not draw estimate-vs-truth
  figures, run bootstrap, or validate simulation calibration.
- The next narrow code slice is an estimate-vs-truth plotting helper built on
  this table contract, then article rewiring where hidden/technical examples
  still hand-index covariance matrices.
