# After Task: predict(newdata) follow-up classes, subset, and forecast

**Branch**: `cursor/predict-newdata-alignment-8e89`
**Date**: `2026-10-11`
**Roles (engaged)**: `Boole / Curie / Rose / Emmy`

## 1. Goal

Land the review follow-ups on PR #1480 before merge: the #1424 `contr.sum` subset case, a `forecast_temporal()` sibling test, and classed predict errors for unseen levels and design rebuild failures. File the deferred fit-time / Julia work as one issue.

## 2. Implemented

Unseen-level aborts now carry `gllvmTMB_predict_unseen_level` for every variable; iSDM observation columns still add `gllvmTMB_predict_isdm_observation_level`. The newdata design-error wrapper is `gllvmTMB_predict_newdata_design`. `predict(newdata = d[d$g != "a", ])` under `contr.sum` matches the in-sample rows. `forecast_temporal()` on `scale(x)` or a subset missing a factor level matches the full future forecast on those rows; an NA covariate row stays NA. Follow-up issue #1481 records the fit-time contrast store and the Julia newdata gate.

## 2a. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown navigation change. Error classes only.

## 3. Files Changed

- `R/methods-gllvmTMB.R` — unseen-level class on every variable; design wrapper class
- `tests/testthat/test-predict-newdata-alignment.R` — #1424 subset; one test per new class
- `tests/testthat/test-temporal-program-forecast.R` — `forecast_temporal()` scale / missing-level / NA row
- `docs/dev-log/check-log.md`
- this report

Intentionally not touched: `R/fit-multi.R`, `R/julia-bridge.R`, `R/diagnose.R` (pending #1476 / #1478 / #1474). No NEWS change: the classes are not an advertised capability.

## 3a. Decisions and Rejected Alternatives

Decision: keep `gllvmTMB_predict_isdm_observation_level` as an extra class on iSDM observation columns. Rationale: existing requalification tests assert that class. Rejected: replacing it. Confidence: high.

Decision: assert that an NA covariate in `forecast_temporal()` stays NA rather than aborting. Rationale: `eta_fixed_new` is NA on that row and the temporal covariance does not use the covariate. Rejected: inventing a classed abort that the helper does not raise. Confidence: high — the test records the observed contract.

## 4. Checks Run

`pkgload::load_all(compile = FALSE)` on R 4.3.3, `/tmp/R-libs`:

- `test-predict-newdata-alignment.R`: FAIL 0 / ERR 0 / WARN 0 / SKIP 0 / PASS 33.
- `test-tidy-predict.R`: FAIL 0 / ERR 0 / WARN 1 / SKIP 4 / PASS 20 (CRAN skips; pre-existing `unit = "site"` deprecation warning).
- `test-isdm-predict.R`: FAIL 0 / ERR 0 / WARN 0 / SKIP 9 / PASS 36.
- `test-isdm-requalification-prediction.R`: FAIL 0 / ERR 0 / WARN 0 / SKIP 0 / PASS 21.
- `test-oct4-news-doc-fixes.R`: FAIL 0 / ERR 0 / WARN 0 / SKIP 0 / PASS 25.
- `test-temporal-program-forecast.R`: FAIL 0 / ERR 0 / WARN 0 / SKIP 0 / PASS 12.

Stale-wording scans (this slice):

```
rg -n "gllvmTMB_predict_unseen_level|gllvmTMB_predict_newdata_design" R tests
rg -n "Fixes |Closes |Resolves " docs/dev-log NEWS.md
rg -n "forecast_temporal" tests/testthat/test-temporal-program-forecast.R
```

Not run: full `devtools::test()` / `R CMD check --as-cran` (R 4.3.3, incomplete Suggests). CI on the repo toolchain is the check. CI on `0a0a2297` was PENDING at report time (4 Ubuntu shards).

## 5. Tests of the Tests

The #1424 subset is a failure-before-fix of the same contrast drop as the full-frame case: `d[d$g != "a", ]` rebuilds a shorter dummy set unless training levels and `contr.sum` survive. The two class tests call `predict()` on a stub so a missing class cannot hide behind a later abort. The forecast test compares a one-occasion `scale(x)` panel and a missing-level subset to the full future forecast; those rows diverge if `predvars` or `xlevels` are ignored. The NA row is asserted as NA, not as an error.

## 6. Consistency Audit

- `rg -n "gllvmTMB_predict_unseen_level" R tests` — set on every unseen factor; iSDM still adds its extra class.
- `rg -n "gllvmTMB_predict_newdata_design" R tests` — wrapper and test agree.
- `rg -n "Fixes |Closes |Resolves " docs/dev-log NEWS.md` — this slice uses `refs` only.
- `rg -n "gllvmTMB_wide" NEWS.md` — not introduced.
- Reader-facing NEWS was not edited.

## 7. Roadmap Tick

N/A. No ROADMAP row changed.

## 7a. GitHub Issue Ledger

Inspected: #1384, #1423, #1424, #1425, #1402, #1154, #1480. Duplicate search for fit-time contrast storage, a classed Julia newdata gate, and "Julia must use the training-design path" found no existing follow-up (only the original predict issues). Created #1481 (`refs #1480`). Did not close #1384 / #1423 / #1424 / #1425 from this report.

## 8. What Did Not Go Smoothly

GitHub MCP `issue_write` returned 403; the issue was filed with `gh issue create`. MCP search with `options(contrasts=)` in the query was a 422; a plainer query was enough.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Boole: an unseen-level class that fires only on iSDM observation columns is the wrong shape — callers of ordinary factors need the same class. Curie: the #1424 subset is the case that actually drops a dummy; the full-frame test can pass while that still fails. Rose: the deferred fit-time store and the Julia gate belong in one issue, not two, because Julia newdata must consume the stored training design. Emmy: `forecast_temporal()` is the sibling that already called the helper; it needed its own alignment test.

## 10. Known Limitations And Next Actions

- `options(contrasts=)` at predict time still rebuilds the training design (`R/methods-gllvmTMB.R` `.gllvmTMB_predict_design_basis`). Store contrasts at fit time in `R/fit-multi.R` after #1476 / #1478 / #1474 — #1481 (a).
- `engine = "julia"` newdata refusal is still an unclassed `stop()` — #1481 (b).
- When that gate lifts, Julia must use `.gllvmTMB_newdata_model_matrix()` — #1481 (c).
- Do not merge #1480 from this lane.
