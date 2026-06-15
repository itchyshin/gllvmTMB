# After Task: R Extractor CI-Status Columns

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Fisher / Hopper / Rose`

## 1. Goal

Make the native R extractor tables expose interval status directly, so the
R-side contract is complete before Julia bridge parity follows it.

## 2. Implemented

- Added `.gtmb_add_ci_status_column()` for data-frame interval returns.
- Vectorized `.gtmb_ci_status()` over method rows and handled zero-row interval
  objects without adding phantom statuses.
- Added `ci_status` to `extract_repeatability()` Wald/bootstrap table returns.
- Added `ci_status` to `extract_communality(ci = TRUE)` profile/bootstrap table
  returns and reused bootstrap-summary returns.
- Added `H2_ci_status` to `extract_phylo_signal(ci = TRUE)`.
- Wired `extract_phylo_signal(ci = TRUE, method = "wald")` and
  `method = "bootstrap"` to the existing native H2 helper implementations.

## 3. Files Changed

R code:

- `R/ci-status.R`
- `R/extract-repeatability.R`
- `R/extractors.R`
- `R/extract-omega.R`

Tests:

- `tests/testthat/test-extract-repeatability-bootstrap.R`
- `tests/testthat/test-extract-communality-bootstrap.R`
- `tests/testthat/test-profile-ci.R`
- `tests/testthat/test-m1-6-extract-repeatability-mixed-family.R`
- `tests/testthat/test-m2-2b-binary-cis-extractors.R`
- `tests/testthat/test-phylo-signal-ci.R`

Docs and ledger:

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-r-extractor-ci-status.md`
- generated Rd files pending `devtools::document()`

## 3a. Decisions and Rejected Alternatives

Decision: put row-level status in extractor tables, while keeping matrix-style
`confint()` statuses as attributes.

Rationale: extractor tables are user-facing data frames used in reports and
figures; status must be visible there instead of hidden in attributes.

Decision: wire `extract_phylo_signal()` to existing H2 Wald/bootstrap helpers.

Rationale: the helpers already define the native R target. Leaving the public
extractor on placeholder bootstrap `NA` bounds would make the R side incomplete
and give Julia a moving target.

Rejected alternative: change low-level helper schemas such as
`profile_ci_communality()` or `.phylo_signal_wald_ci()`. That would broaden the
slice and risk unnecessary downstream churn.

## 4. Checks Run

- `Rscript -e 'devtools::load_all(".", quiet=TRUE); print(gllvmTMB:::.gtmb_ci_status(c("profile", "bootstrap", "wald(approx)", "(unavailable)"), c(NA, 0.1, NA, 0.2), c(0.9, 0.8, NA, 0.3))); print(gllvmTMB:::.gtmb_ci_status("profile", numeric(0), numeric(0)))'`
  - passed; returned `profile_boundary`, `ok`, `wald_unavailable`,
    `interval_unavailable`; `character(0)`.
- `Rscript -e 'devtools::test(filter="extract-repeatability-bootstrap|extract-communality-bootstrap|profile-ci|m1-6-extract-repeatability-mixed-family|m2-2b-binary-cis-extractors|phylo-signal-ci")'`
  - `PASS 0`, `SKIP 28`, `FAIL 0`, `WARN 0`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::test(filter="extract-repeatability-bootstrap|extract-communality-bootstrap|profile-ci|m1-6-extract-repeatability-mixed-family|m2-2b-binary-cis-extractors|phylo-signal-ci")'`
  - `PASS 141`, `SKIP 0`, `FAIL 0`, `WARN 1` in `125.8s`.
  - warning: known conditional-bootstrap warning from phylogenetic
    random-effect simulation.
- `Rscript -e 'devtools::document()'`
  - completed; regenerated `man/extract_communality.Rd`,
    `man/extract_phylo_signal.Rd`, and `man/extract_repeatability.Rd`.
    Pre-existing unresolved-link warnings remain.
- `Rscript -e 'devtools::test()'`
  - `PASS 2951`, `SKIP 724`, `FAIL 0`, `WARN 3` in `129.8s`.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `git diff --check`
  - clean.

## 5. Tests of the Tests

The heavy targeted tests exercise real fitted objects, bootstrap-summary
objects, and public extractor calls. The new phylogenetic-signal assertion
checks that `extract_phylo_signal(ci = TRUE, method = "wald")` agrees with the
native H2 Wald helper on endpoints and status.

## 6. Consistency Audit

- R extractor interval table schemas now surface status where users inspect the
  intervals.
- Low-level CI helper schemas are unchanged.
- Numeric point estimates and interval endpoint formulas are unchanged except
  that `extract_phylo_signal()` now reaches the already-existing H2 helper
  routes.
- NEWS and check-log frame this as R-side contract completion, not coverage
  calibration.

## 7. Roadmap Tick

R-first inference surface: one more gap closed. Julia bridge work can now target
visible status fields for repeatability, communality, and phylogenetic signal.

## 7a. GitHub Issue Ledger

No issue comments were posted. This supports the local R-first inference and
bridge-contract work and should be linked to the bridge/inference issue when
the branch is pushed.

## 8. What Did Not Go Smoothly

The first helper edit needed a zero-row correction: empty filtered interval
objects must return `character(0)`, not a recycled placeholder status. Heavy
tests also surface the existing conditional-bootstrap warning for phylogenetic
random-effect tiers; this is expected but remains a real limitation.

## 9. Team Learning

Fisher: interval status belongs beside every interval that users can report.

Hopper: complete R-side extractor contracts make Julia bridge validation less
ambiguous.

Rose: the R side must be honest before the Julia side can claim parity.

## 10. Known Limitations And Next Actions

- No calibrated coverage claim is made.
- Phylogenetic-signal bootstrap remains conditional on fitted random effects.
- Julia bridge CI endpoint parity is still future work.
- Visual/table methods still need a pass to display `ci_status` clearly.

## 11. Rose Verdict

Rose verdict: PASS WITH NOTES - extractor status is now visible on native R
interval tables, but coverage calibration, unconditional phylogenetic bootstrap,
and Julia bridge endpoint parity remain open.
