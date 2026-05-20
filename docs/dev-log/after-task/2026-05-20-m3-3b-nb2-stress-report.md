# After Task: M3.3b NB2 Stress Map And Diagnostic Report Scaffold

**Branch**: `codex/m3-3b-nb2-stress-report-2026-05-20`
**Date**: `2026-05-20`
**Roles (engaged)**: `Ada / Fisher / Curie / Florence / Grace / Rose / Shannon`

## 1. Goal

Turn rolling slices 4, 6, and 9 into the first executable M3.3b
bundle: define the NB2 point-only stress map, preserve the estimated-
phi source-map fields, and create the dev-facing diagnostic report v0
that later slices can render before r50/r200 scaling.

The same lane also opens the control hooks needed for slices 12 and
13: a Poisson count-family control and a Gaussian low-noise control.

## 2. Implemented

- Added `m3_nb2_stress_surfaces()` to define the point-only NB2 stress
  register: baseline, low-dispersion, and weak-variance surfaces under
  estimated and known `phi_nbinom2`.
- Added optional Gaussian and Poisson controls via
  `m3_nb2_stress_surfaces(include_controls = TRUE)`.
- Added `m3_run_surface_register()` so the stress register can run
  through the existing M3 grid machinery without hand-written loops.
- Added `ci_method = "none"` for `n_boot = 0` `Sigma_unit_diag`
  diagnostics and `pilot_status = "POINT_ONLY"` in summaries.
- Added `m3_diagnostic_report_data()` and
  `m3_write_diagnostic_report()` for the first dev-facing Markdown
  report.
- Added `dev/precompute-m3-grid.R --nb2-stress-map`; the stress-map
  defaults now match the diagnostic protocol:
  `single_trait_warmup`, residual starts, `optim`/BFGS, `n_init = 3`,
  `se = FALSE`, `target = "Sigma_unit_diag"`, and `n_boot = 0`.
- Added tests for the stress register, Poisson/Gaussian controls,
  point-only summary status, and report-data tables.
- Added a smoke audit at
  `docs/dev-log/audits/2026-05-20-m3-3b-nb2-stress-report-smoke.md`.

No public R API, roxygen, generated Rd, formula grammar, TMB
likelihood, NAMESPACE, vignette, or pkgdown navigation changed.

## 3. Files Changed

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-m3-3b-nb2-stress-report-smoke.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-m3-3b-nb2-stress-report.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep the first stress-map/report machinery in `dev/`, not in
the exported package API.

Rationale: the scaffold is inference infrastructure for M3.3b, not a
stable user-facing function. Keeping it in `dev/` lets Fisher and Curie
iterate on the evidence shape before Pat sees any public tutorial.

Rejected alternative: immediately add a public plotting helper for M3
diagnostics.

Confidence: high. Florence's own gate says the table report is useful
infrastructure but not yet a publication-quality figure.

Decision: label `n_boot = 0` rows as `ci_method = "none"` and
`pilot_status = "POINT_ONLY"`.

Rationale: point-only diagnostics must not be interpreted as interval
coverage or as failed bootstrap intervals.

Rejected alternative: keep `ci_method = "bootstrap"` with missing CIs.
That would make `n_boot = 0` look like a compute failure rather than an
intentional point-estimate diagnostic.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt,url`
  -> no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago" | head -50`
  -> reviewed recent issue-ledger and M3.3b surface-gate commits
  through `e2a5660`.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  -> passed: 40 tests.
- `Rscript --vanilla dev/precompute-m3-grid.R --nb2-stress-map --include-controls --n-reps=1 --out-dir=/tmp/gllvmtmb-m3-3b-stress-smoke --out-prefix=m3-nb2-stress-smoke`
  -> passed in about 64 seconds; wrote grid, summary, and
  diagnostic-report artifacts under
  `/tmp/gllvmtmb-m3-3b-stress-smoke/`.
- `Rscript --vanilla -e 'x <- readRDS("/tmp/gllvmtmb-m3-3b-stress-smoke/m3-nb2-stress-smoke-grid.rds"); cat("trait coverage unique: "); print(unique(x$diagnostic_report$trait_ratios$coverage)); print(unique(x$diagnostic_report$summary[, c("ci_method", "coverage", "pilot_status")]))'`
  -> confirmed trait-level and summary coverage stay `NA`, while
  `ci_method = "none"` and `pilot_status = "POINT_ONLY"`.
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`

## 5. Tests of the Tests

The new tests are boundary/contract tests, not simulation-recovery
claims:

- stress-register expansion verifies the intended 3 NB2 surfaces x 2
  fit-phi modes;
- control-surface test verifies the Poisson control path can simulate
  non-negative counts without changing the default M3 family grid;
- point-only status test checks the `n_boot = 0` boundary so no-CI rows
  cannot masquerade as coverage evidence;
- report-data test verifies the trait-ratio and failure-ledger tables
  preserve fit-phi mode and `POINT_ONLY` status.

## 6. Consistency Audit

- `rg -n 'POINT_ONLY|ci_method = "none"|nb2-stress-map|m3_nb2_stress_surfaces|m3_diagnostic_report_data' dev tests ROADMAP.md docs/dev-log`
  -> expected hits in the dev driver, M3 grid library, tests, roadmap,
  audit, check-log, coordination board, and this after-task report.
- `rg -n 'coverage evidence|point-estimate evidence|POINT_ONLY|n_boot = 0' docs/design/50-m3-3b-surface-admission.md docs/design/46-visualization-grammar.md ROADMAP.md docs/dev-log/audits/2026-05-20-m3-3b-nb2-stress-report-smoke.md docs/dev-log/after-task/2026-05-20-m3-3b-nb2-stress-report.md`
  -> expected hits confirming point-only rows remain diagnostic.

## 7. Roadmap Tick

**Roadmap tick**: M3 stays `3/8` and M3.3 stays red. `ROADMAP.md`
now records that the M3.3b scaffold exists, but the next evidence step
is still a real r10/r20 NB2 stress-map run and surface-admission
decision. EXT-13, CI-08, and CI-10 remain unchanged.

## 7a. GitHub Issue Ledger

- Inspected open issues #217 and #218 before starting this branch.
- Commented on #217 with the branch checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/217#issuecomment-4498901315`.
- Commented on #218 with the diagnostic-report checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/218#issuecomment-4498903633`.
- #217 and #218 remain open. This PR advances both but does not close
  either, because no r10/r20 evidence or rendered Florence figure has
  been accepted yet.

## 8. What Did Not Go Smoothly

The first report helper accidentally turned point-only trait coverage
into `0` instead of `NA` because the no-CI row stored `covered = FALSE`.
That was fixed before commit: unavailable intervals now stay `NA`, and
the focused test asserts that point-only trait coverage remains `NA`.

The first smoke also exposed a misleading CLI header: it printed global
`n_units = 60` even when stress surfaces were surface-specific. The
stress-map header now says `surface-specific`.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: the lane should stay as dev infrastructure until the report
proves useful on r10/r20 evidence.

Fisher: the scaffold now separates point-estimate diagnostics from
coverage evidence. No row can move CI-08 or CI-10 while
`ci_method = "none"`.

Curie: the surface register gives the next run a small, reproducible
grid shape before any r50/r200 compute.

Florence: the Markdown report is a preflight artifact only. It earns
`REVISE`, not `PASS`, until rendered figure panels exist.

Grace: the change avoids new public dependencies and keeps the
workflow under `dev/`; focused tests and a `/tmp` smoke are the right
verification level for this PR.

Rose: the roadmap, issues, check-log, audit, and after-task report all
say the same thing: scaffold shipped; evidence status unchanged.

Shannon: the coordination board was updated at branch start and should
move back to WIP 0 after merge and post-merge checks.

## 10. Known Limitations And Next Actions

- Run the real r10/r20 NB2 stress map without controls first.
- Turn the Markdown report tables into rendered diagnostic figures for
  Florence review.
- Decide whether fixed-phi bootstrap needs a mapped-parameter refit
  path before any fixed-phi coverage claim.
- Keep #217 and #218 open until the first surface is admitted,
  redesigned, or held with evidence.
