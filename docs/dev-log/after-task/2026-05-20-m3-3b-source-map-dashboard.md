# After-Task Report: M3.3b Source-Map Dashboard

Date: 2026-05-20

Branch: `codex/m3-3b-source-map-dashboard-2026-05-20`

## Scope

This slice adds the first rendered, dev-facing M3.3b source-map
dashboard for issue #218. It turns the existing diagnostic report data
into ggplot panels and writes a PNG contact sheet beside the Markdown
report for `--nb2-stress-map` and `--nb2-start-probe` modes.

The slice does not change the TMB likelihood, does not add a public
plot helper, does not admit an NB2 surface to r50, and does not create
interval-coverage evidence. The dashboard deliberately keeps current
NB2 rows labelled `POINT_ONLY` and `NOT_EVALUATED`.

## Files Touched

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `docs/design/46-visualization-grammar.md`
- `docs/design/50-m3-3b-surface-admission.md`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/audits/2026-05-20-m3-3b-source-map-dashboard-florence.md`
- `docs/dev-log/after-task/2026-05-20-m3-3b-source-map-dashboard.md`

## Evidence

- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  passed with 63 tests and no warnings.
- `Rscript --vanilla dev/precompute-m3-grid.R --nb2-start-probe --probe-config=current_res_bfgs_n3_j005 --n-reps=1 --out-dir=/tmp/gllvmtmb-m3-3b-dashboard-smoke --out-prefix=m3-nb2-dashboard-smoke`
  passed in 62.2 s and wrote a Markdown diagnostic report, long-grid
  RDS, summary RDS, and source-map dashboard PNG.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); art <- readRDS("/tmp/gllvmtmb-m3-3b-dashboard-smoke/m3-nb2-dashboard-smoke-grid.rds"); m3_write_source_map_dashboard(art$grid, "/tmp/gllvmtmb-m3-3b-dashboard-smoke/m3-nb2-dashboard-smoke-source-map-dashboard-v2.png")'`
  passed and rerendered the dashboard after the Florence layout
  revision.
- Visual inspection of the rendered PNG passed the dev-facing
  Florence gate recorded in
  `docs/dev-log/audits/2026-05-20-m3-3b-source-map-dashboard-florence.md`.

## Issue Ledger

- #218 should close when this PR merges, provided CI passes. The issue
  requested a small rendered diagnostic report, a figure-quality review
  note, and a documented data-grain contract; this slice supplies all
  three for the dev-facing M3.3b gate.
- #217 is already closed. This slice does not reopen surface admission
  because no surface is admitted to r50.
- #222 remains open. This slice does not implement posterior
  predictive checks or randomized-quantile diagnostics.
- #223 remains open. This slice does not refresh literature citations.

## Definition of Done Check

1. Implementation: dev-only dashboard data, plot panels, PNG writer,
   and precompute wiring added. Main merge/CI status is pending until
   PR review.
2. Simulation recovery test: not applicable. This is a diagnostic
   visualization/reporting slice, not a new likelihood, family,
   keyword, or estimator.
3. Documentation: Design 46, Design 50, ROADMAP, check-log, audit, and
   this after-task report updated. No exported function or Rd file
   changed.
4. Runnable user-facing example: not applicable. The feature is
   deliberately dev-only and not advertised to package users.
5. Check-log entry: added with exact commands and outcomes.
6. Review pass: Florence reviewed the rendered figure; Fisher kept
   point estimates separate from interval evidence; Grace/Rose checks
   are local until PR CI completes.

## Role Notes

- Ada: kept the lane scoped to issue #218 and did not open a public
  plotting API.
- Florence: rejected the first cramped contact sheet, then passed the
  revised dev-facing tile/ratio layout.
- Fisher: required `POINT_ONLY` and `NOT_EVALUATED` labels on the
  figure itself.
- Pat: checked that a reader can see weak cells without reading the
  surrounding Markdown report.
- Grace: kept the artefact generated from dev scripts and ordinary
  tests, not from a new CI job.
- Rose/Shannon: kept issue, roadmap, coordination board, check-log,
  and after-task ledgers aligned.

## Next Step

Use the dashboard on deliberate selected-seed source-map artefacts. If
the next artefact adds bootstrap/profile intervals, the contact sheet
must separate point-only rows, profile-psi diagnostics, and
target-explicit `Sigma_unit_diag` interval evidence before any r50 or
r200 scaling decision.
