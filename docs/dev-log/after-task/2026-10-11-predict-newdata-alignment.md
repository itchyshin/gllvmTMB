# After Task: predict(newdata) row alignment

**Branch**: `cursor/predict-newdata-alignment-8e89`
**Date**: `2026-10-11`
**Roles (engaged)**: `Boole / Curie / Rose / Emmy`

## 1. Goal

Stop `predict(newdata)` from putting values on the wrong rows when a covariate is missing, when a data-dependent transform is re-evaluated on the new rows, or when a character or contrast-coded factor rebuilds a different design than the fit.

## 2. Implemented

`predict(newdata)` now returns one row for every row of `newdata`. A missing covariate stays `NA` there. `scale()` / `poly()` / `ns()` reuse the training centre, scale and basis. Character predictors use the training levels. User-set factor contrasts are copied onto the restored factor. A design that is still missing a fitted column aborts instead of treating the dummy as zero. `simulate(newdata)` calls `predict()` and inherits the same alignment. The temporal-forecast design rebuild uses the same helpers.

## 3. Files Changed

- `R/methods-gllvmTMB.R` — restore helper, missing-column abort, training-frame design rebuild
- `R/temporal-forecast.R` — same design helper
- `man/predict.gllvmTMB_multi.Rd` — newdata contract
- `tests/testthat/test-predict-newdata-alignment.R` — failure-before-fix tests
- `dev/predict-newdata-repro/` — issue scripts and the before-fix record on `9354ac2f`
- `NEWS.md` — last bullet of the unreleased section
- `docs/design/35-validation-debt-register.md` — MIS-07 evidence note
- `docs/dev-log/check-log.md`

Intentionally not touched: `R/fit-multi.R`, `R/julia-bridge.R`, `R/diagnose.R` (pending #1476 / #1478 / #1474).

## 3a. Decisions and Rejected Alternatives

Decision: rebuild `predvars` / `xlevels` / contrasts from the training model frame at predict time, rather than storing a terms object at fit time. Rationale: avoids `R/fit-multi.R` while the neighbouring PRs are open. Rejected: documenting `scale()` as unsupported. Confidence: high — this is how `predict.lm` works.

Decision: fix #1424 in this PR because `restore_newdata_factor_levels()` is on the same path. Rejected: listing it only as a follow-up.

## 4. Checks Run

Before-fix on `main` `9354ac2f` (installed 0.8.0.9000):

- #1384: `x = c(NA, 1, NA, 1)` recycles 1.748 / 0.789; complete row 2 gets the t2 value. Row-by-row row 2 is 1.748.
- #1423: precomputed `xs` max|diff| = 0; `scale(x)` = 0.3751; one-row errors `arguments imply differing number of rows: 1, 0`.
- #1425: `b` rows without baseline are 0.71 below in-sample.
- #1424: `newdata = training` errors `Unknown column(s): "gb" and "gc"`.

Focused tests and after-fix repros are recorded after the first installed check on this branch.

Stale-wording scans:

```
rg -n "model.matrix\\(stats::delete.response" R
rg -n "Fixes |Closes |Resolves " docs/dev-log NEWS.md
rg -n "recycle|predvars|contr.sum" R/methods-gllvmTMB.R tests/testthat/test-predict-newdata-alignment.R
```

The only remaining `model.matrix(delete.response(terms(...)))` call in `R/` is gone; both `predict()` and temporal forecast go through `.gllvmTMB_newdata_model_matrix()`.

## 5. Tests of the Tests

Every new test is a failure-before-fix of a filed issue. The stub tests isolate the helper; the real-fit tests replay the issue scripts. Revert the helpers and they fail again. The missing-column test calls `.gllvmTMB_predict_fixed_eta()` with a short design so the abort cannot be skipped.

## 6. Consistency Audit

- `rg -n "model.matrix\\(stats::delete.response" R` — no remaining predict-path hits.
- `rg -n "gllvmTMB_wide" NEWS.md` — not introduced.
- `rg -n "meta_known_V" NEWS.md` — not introduced.
- Reader-facing NEWS has no register codes.

## 7. Roadmap Tick

N/A. No ROADMAP row changed.

## 7a. GitHub Issue Ledger

Inspected: #1384, #1423, #1425, #1424, and the #1384 comments pointing at `R/temporal-forecast.R` / #1402. PR body uses `refs #N` only. Not closed from this report.

## 8. What Did Not Go Smoothly

`graft` is not on PATH in this environment, so location used the indexed `R/methods-gllvmTMB.R` helpers already named in the issues. fmesher needed apt `r-cran-sf` before a CRAN install would succeed.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Boole: newdata designs have to carry the fitted terms object, not a fresh `terms(formula)`. Curie: each test forces the filed failure, including a row-by-row compare for NA rows. Rose: NEWS stays at the end of the unreleased section so the pending NEWS edits in #1476 / #1478 / #1474 conflict on one hunk. Emmy: `simulate(newdata)` already called `predict()`, so it inherits; `engine = "julia"` still refuses newdata and is listed as a follow-up.

## 10. Known Limitations And Next Actions

- `engine = "julia"` `predict(newdata)` remains a gate (GJL-GATE-NEWDATA-PREDICT).
- `fitted()` and `residuals()` are training-row methods; no newdata path to fix.
- Temporal `predict(newdata)` is still refused for `temporal_latent` fits; only the forecast helper shared the broken `model.matrix` call.
- #1402 is the same NA recycle at the forecast site; this PR uses the shared helper there.
