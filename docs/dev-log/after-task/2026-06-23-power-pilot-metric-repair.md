# After Task: Power Pilot Metric Repair

**Branch**: `codex/power-pilot-metric-repair-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose`

## 1. Goal

Repair the pilot reporting semantics identified by the run-144 audit without
launching new simulations: stop describing `signal = 0` rows as Type-I/power,
show the binary harness as logit evidence, and add MCSE plus explicit
fit-health denominators to the pilot reporting layer.

## 2. Implemented

- Added `evidence_family = "binomial_logit_harness"` to the pilot grid while
  preserving existing `binomial_probit-*` cell IDs for old result stores.
- Reworded `pilot_status()` and `pilot_accum_status()` so `signal = 0` rows are
  signal-zero coverage diagnostics, not Type-I error or power.
- Extended `pilot_collect()` rows with explicit denominators and MCSEs:
  attempted fits, converged fits, optimizer-converged fits, PD-Hessian fits,
  sdreport-usable fits, bootstrap attempts, coverage-eligible rows, coverage
  MCSE, zero-exclusion denominator/MCSE, and failure-rate MCSEs.
- Updated `pilot_plot_coverage()`, `pilot_record_lines()`, and the issue-board
  status table to display MCSEs, denominators, evidence labels, and fit-health
  rates.
- Updated Design 66 wording so the pilot gate matches the repaired report
  semantics.
- Added a no-fit source-level test for the reporting math and board labels.

## 3. Mathematical Contract

No likelihood, DGP, estimator, bootstrap interval, formula grammar, or response
family changed. The repair changes only reporting semantics around the existing
`Sigma_unit_diag` bootstrap target.

Coverage MCSE is now computed as `sqrt(p * (1 - p) / n_sim)`, using the
independent replicate count. The separate `coverage_eligible_n` column records
how many primary interval rows entered the coverage mean. This keeps the MCSE
aligned with the Design 66 power-study arithmetic while still exposing the
coverage-row denominator.

`CI-08` and `CI-10` remain partial.

## 3a. Decisions and Rejected Alternatives

- Decision: keep existing `binomial_probit-*` cell IDs. Rationale: renaming the
  files would orphan the current `power-pilot-results` store. The new
  `evidence_family` column makes the logit harness explicit instead.
- Decision: keep the legacy `power` alias in `pilot_collect()` for
  compatibility, but all new prose and tables use `zero_exclusion_rate`.
- Rejected alternative: implement true binary probit in this slice. That changes
  the DGP/fit path and belongs in a separate audit-mini repair.

## 4. Files Touched

- `dev/m3-pilot-launch.R`
- `dev/m3-pilot-report.R`
- `dev/power-pilot-run.R`
- `docs/design/66-capstone-power-study.md`
- `tests/testthat/test-m3-pilot-report.R`
- `docs/dev-log/after-task/2026-06-23-power-pilot-metric-repair.md`
- `docs/dev-log/check-log.md`

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url --limit 20`
  - PASS before dev-log edits: no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  - PASS for coordination: recent work is #537-#540 plus the run-144 result
    branch.
- `Rscript --vanilla -e 'invisible(parse("dev/m3-pilot-report.R")); invisible(parse("dev/m3-pilot-launch.R")); invisible(parse("dev/power-pilot-run.R")); invisible(parse("tests/testthat/test-m3-pilot-report.R")); cat("parse ok\n")'`
  - PASS.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-m3-pilot-report.R")'`
  - PASS: 23 expectations.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-pilot-report|m3-grid-summary")'`
  - PASS: 23 passed, 13 heavy M3 summary tests skipped by the existing
    `GLLVMTMB_HEAVY_TESTS` gate.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); source("dev/m3-pilot-report.R"); df <- pilot_collect(results_dirs = "/tmp/pilot-run144-metric-repair/dev/m3-pilot-results"); ...'`
  - PASS against the archived run-144 result store: 48 collected cells with the
    new columns present.
- `Rscript --vanilla dev/power-pilot-run.R --mode=status --results-dir=/tmp/pilot-run144-metric-repair/dev/m3-pilot-results --n-sim-cap=10000 --status-out=/tmp/pilot-status-metric-repair.md`
  - PASS against the archived run-144 store; the status output used
    signal-zero diagnostic wording and wrote the richer board table.
- One-cell status smoke using `/tmp/pilot-one-cell-store`
  - PASS; pending binomial cells and the stored binomial cell all displayed
    `binomial_logit_harness`.
- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  - PASS: no matches after the repair.
- `git diff --check`
  - PASS.

## 6. Tests of the Tests

The new `test-m3-pilot-report.R` test is a boundary/semantic test, not a
happy-path fit. It builds synthetic primary-target rows with two reps, four
coverage rows, one non-PD draw, one optimizer-convergence failure, and one
failed bootstrap attempt. It would fail if `pilot_collect_cell()` lost the
explicit denominators, used the old evidence label, or computed MCSE with the
wrong replicate denominator.

## 7a. Issue Ledger

- Issue #340 was not manually edited. The next workflow status update will use
  the richer table once this PR lands.
- No new issue was opened.

## 8. Consistency Audit

Exact scans run:

- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
- `rg -n "binomial_probit|binomial_logit_harness|zero-exclusion|coverage_mcse|coverage_eligible" dev/m3-pilot-launch.R dev/m3-pilot-report.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`

Result: stale Type-I/power-proxy language is gone from the pilot status/report
path. `binomial_probit` remains in cell IDs and the intended-family design
language; `binomial_logit_harness` now marks the actual current evidence.

## 9. What Did Not Go Smoothly

The first full-artifact smoke used row-level coverage MCSE. Fisher corrected
that to the replicate-level denominator so the report matches Design 66's
`n_sim = 2000` MCSE arithmetic.

The generated markdown table briefly lost spaces at `paste0()` boundaries.
A one-cell status smoke caught it before commit.

Full run-144 report folding takes about a minute on the local machine. That is
acceptable for status jobs, but it is a useful cost signal before larger result
stores accumulate.

## 10. Known Residuals

- True binary probit is still not implemented in the M3 harness.
- Ordinal-probit cells still lack `coverage_primary` and need a separate repair
  or a documented exclusion from confirmatory coverage conclusions.
- No durable run/session manifest was added in this slice.
- No new simulation, Totoro check, DRAC login, SLURM job, or GPU check was run.
- `CI-08` and `CI-10` remain partial.

## 11. Team Learning

Ada: preserve old result-store filenames while adding clearer evidence labels.

Curie: report denominators separately; do not make a pretty MCSE by using the
wrong denominator.

Fisher: keep zero-exclusion as a diagnostic until the target-aligned detection
and false-positive rule exists.

Grace: verify the exact workflow status path, not only helper functions.

Rose: stale wording scans should be narrow enough that planned future work does
not hide current overclaims.
