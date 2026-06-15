# After Task: Plot CI-Status Propagation

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Florence / Fisher / Hopper / Rose`

## 1. Goal

Close the next R-first reporting gap after extractor `ci_status` columns landed:
plot helpers should keep row-level CI-status information in their returned data,
so articles, bridge parity tests, and visual QA can distinguish finite intervals
from boundary, failed, unavailable, or missing interval rows.

## 2. Implemented

- Added `.gtmb_plot_ci_table()` to normalize plot-facing interval rows into
  `lower`, `upper`, `method`, `ci_status`, and coarse `interval_status`.
- Propagated `ci_status` and `ci_method` into
  `plot(type = "integration")` `gllvmTMB_data`.
- Propagated `ci_status` and `ci_method` into
  `plot(type = "communality")` `gllvmTMB_data`.
- Taught `plot_correlations()` to add `ci_status` to plot data when input rows
  do not already provide it.
- Added regression coverage that `plot_Sigma_table()` preserves an existing
  `ci_status` column from report-ready rows.

## 3. Files Changed

R code:

- `R/plot-gllvmTMB.R`
- `R/plot-covariance-tables.R`

Tests:

- `tests/testthat/test-plot-gllvmTMB.R`
- `tests/testthat/test-plot-covariance-tables.R`

Docs and ledger:

- `NEWS.md`
- `man/plot.gllvmTMB_multi.Rd`
- `man/plot_correlations.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-plot-ci-status-propagation.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep plot geometry stable and expose `ci_status` in
`gllvmTMB_data`.

Rationale: this is an audit/reporting contract slice. Changing visual encoding
for every status belongs in a broader Florence review with rendered figure
evidence.

Decision: `plot_correlations()` computes `ci_status` when the column is absent,
but `plot_Sigma_table()` only preserves an existing `ci_status`.

Rationale: correlation rows have a direct `method`/`lower`/`upper` CI contract
via `extract_correlations()`. Sigma-table rows are broader report-ready rows,
where `interval_status` and `interval_method` can mean supplied bootstrap rows,
known-truth rows, or point-estimate-only extraction.

Rejected alternative: promote `ci_status` into captions immediately. That would
be more visible, but it also changes user-facing figure language and needs a
rendered visual review rather than object-level tests alone.

## 4. Checks Run

- `Rscript -e 'devtools::test(filter="plot-gllvmTMB|plot-covariance-tables")'`
  - `PASS 493`, `SKIP 0`, `FAIL 0`, `WARN 0` in `15.8s`.
- `Rscript -e 'devtools::document()'`
  - completed; regenerated `man/plot.gllvmTMB_multi.Rd` and
    `man/plot_correlations.Rd`.
  - pre-existing unresolved-link roxygen warnings remain.
  - unrelated generated Rd churn was reverted.
- `Rscript -e 'devtools::test()'`
  - `PASS 2976`, `SKIP 724`, `FAIL 0`, `WARN 3` in `120.7s`.
  - warnings: existing `nadiv::makeAinv()` selfing warning and existing
    `glmmTMB`/`TMB` version mismatch.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `git diff --check`
  - clean.

## 5. Tests of the Tests

The new tests cover both finite and non-finite interval rows:

- `integration` plot data now distinguishes `ok`, `partial_interval`, and
  `bootstrap_failed` rows.
- `communality` plot data keeps `bootstrap_failed` on both shared and uniqueness
  rows derived from the same failed `c^2` interval.
- `plot_correlations()` now carries computed `ci_status` into forest,
  confidence-eye, and matrix-style plot data.
- `plot_Sigma_table()` preserves explicit `ci_status` values supplied by a
  report-ready table.

## 6. Consistency Audit

- No point estimates, likelihoods, optimization, CI endpoints, or bootstrap
  algorithms changed.
- The previous extractor-table slice remains the source of CI-status semantics.
- This slice only makes plot/report data payloads preserve those semantics.
- NEWS and check-log state that `ci_status = "ok"` is not a coverage-calibration
  claim.

## 7. Roadmap Tick

R-first visual/reporting surface: one more gap closed. Julia bridge parity can
now target plot/report payloads that retain CI-status labels instead of only
finite lower/upper booleans.

## 7a. GitHub Issue Ledger

No issue comments were posted. This supports the R-first inference/visualization
surface and should be linked to the bridge/inference issue when this branch is
pushed.

## 8. What Did Not Go Smoothly

The first edit attempted to patch a roxygen block using stale wrapping; splitting
the patch into exact hunks avoided unrelated churn. `devtools::document()` also
generated unrelated Rd changes in spatial/helper topics; those were manually
reverted so this slice stays scoped to plot CI-status propagation.

## 9. Team Learning

Florence: visual helpers need audit-ready plot data before figure grammar can be
reviewed seriously.

Fisher: interval status must travel with every displayed or reportable interval,
even when the visual geometry remains point-only.

Hopper: R plot payloads now give the Julia bridge a clearer target for future
post-fit parity.

Rose: this closes a reporting gap, not a calibration or release-readiness gate.

## 10. Known Limitations And Next Actions

- Captions do not yet enumerate every `ci_status` value.
- No vdiffr or rendered visual snapshot was added.
- Julia bridge post-fit CI-status parity is still future work.
- Broader bridge gate-vs-engine drift remains the next R-first contract slice.

## 11. Rose Verdict

Rose verdict: PASS WITH NOTES - row-level CI status now reaches the main
plot/report data paths, but public visual encoding, rendered article review,
Julia bridge parity, and calibration evidence remain open.
