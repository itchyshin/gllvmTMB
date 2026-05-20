# After-Task Report: M3.3b NB2 Start/Local-Basin Probe Scaffold

Date: 2026-05-20

Branch: `codex/m3-3b-nb2-start-probe-2026-05-20`

## Scope

This slice added a dev-only start/local-basin probe scaffold for the
M3.3b NB2 source-map path. It does not change the TMB likelihood, does
not admit any NB2 surface to r50, and does not create interval
coverage evidence.

The new path compares paired-seed NB2 stress surfaces across named
start/restart configurations. It records `probe_id`, start method,
optimizer, `n_init`, restart counts, objective spread, fitted
`phi_nbinom2`, link-residual diagnostics, and `Sigma_unit_diag`
estimate/truth ratios while preserving `POINT_ONLY` and
`NOT_EVALUATED` labels.

## Files Touched

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-m3-3b-nb2-start-probe.md`

## Evidence

- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  passed with 53 tests.
- `Rscript --vanilla dev/precompute-m3-grid.R --nb2-start-probe --no-optimizer-probe --n-reps=1 --out-dir=/tmp/gllvmtmb-m3-3b-start-probe-smoke --out-prefix=m3-nb2-start-probe-smoke`
  passed and wrote full four-config smoke artifacts. Runtime: 749.4 s.
- `Rscript --vanilla dev/precompute-m3-grid.R --nb2-start-probe --probe-config=current_res_bfgs_n3_j005 --n-reps=1 --out-dir=/tmp/gllvmtmb-m3-3b-start-probe-smoke-selected --out-prefix=m3-nb2-start-probe-selected-smoke`
  passed and wrote selected-config smoke artifacts. Runtime: 60.6 s.
- `git diff --check` passed.

## Issue Ledger

- #217 remains open. This slice supplies the bounded start/local-basin
  scaffold requested by the M3.3b surface-admission path, but the real
  decision still requires a deliberate selected-seed artifact and audit.
- #218 remains open. The scaffold adds dashboard-ready probe metadata,
  but the Florence-rendered source-map report is still the next
  visualization deliverable.
- #222 remains open. This slice does not implement posterior-predictive
  checks or randomized-quantile residuals.
- #223 remains open. This slice does not update citation or terminology
  hygiene beyond the roadmap note.

## Definition of Done Check

1. Implementation: dev-only helper and CLI mode added; PR branch tests
   passed locally. Main merge/CI status is pending until PR review.
2. Simulation recovery test: not applicable. This is a simulation
   harness/probe scaffold, not a new likelihood, family, keyword, or
   estimator.
3. Documentation: dev-log, roadmap, and this after-task report updated.
   No exported function or Rd file changed.
4. Runnable user-facing example: not applicable. The feature is
   deliberately dev-only and not advertised to package users.
5. Check-log entry: added with exact commands and outcomes.
6. Review pass: Fisher/Gauss/Rose framing applied from the read-only
   technical memo; no TMB likelihood changed, so Gauss/Noether
   likelihood review is not required for this slice.

## Role Notes

- Ada: kept the lane bounded to start/local-basin source mapping.
- Fisher: kept point estimates separate from interval evidence.
- Gauss/Noether: confirmed no TMB likelihood change belongs in this
  slice.
- Curie: kept ordinary tests synthetic and moved expensive fitting to
  dev smoke commands.
- Grace: retained CI pacing; this is not ordinary CI work.
- Florence/Pat: preserved dashboard-ready labels for the next rendered
  source-map report.
- Rose: captured the runtime lesson as Kaizen point 48.

## Next Step

Run a selected-seed start/local-basin artifact, not a broad grid:
same NB2 surfaces, same seeds, a small set of named starts, and an
audit comparing objective spread against `Sigma_unit_diag`, fitted
`phi`, and link-residual ratios. If better objectives do not repair
the ratios, the next decision is finite-sample identifiability rather
than more restarts.
