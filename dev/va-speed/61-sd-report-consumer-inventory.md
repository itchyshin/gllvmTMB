# Complete sd_report NULL-Handling Inventory

**Analysis Date:** 2026-08-04  
**Repository:** gllvmTMB (worktree at `/private/tmp/gllvmtmb-va-lane2`)  
**Focus:** All locations reading `fit$sd_report` and classification by error-handling strategy

---

## 1. sd_report Read Sites: Classification

### ABORTS — Calls cli_abort/stop when NULL (8 sites)

| File:Line | Function | Condition Class | Signature |
|-----------|----------|-----------------|-----------|
| re-uncertainty.R:115 | `getREsd()` | `gllvmTMB_getREsd_no_sdreport` | `if (is.null(sd_rep)) cli_abort(...)` |
| output-methods.R:217 | `getLV_se()` | `gllvmTMB_getLV_se_no_sdreport` | `if (is.null(sd_rep)) cli_abort(...)` |
| methods-gllvmTMB.R:432 | `.gllvmTMB_predict_se_link()` | `gllvmTMB_predict_se_no_sdreport` | `if (is.null(object$sd_report)) cli_abort(...)` |
| communality-ci.R:98 | `extract_communality()` (inner) | *(none specified)* | `if (is.null(fit$sd_report) \|\| !inherits(...)) cli_abort(...)` |
| phylo-signal-ci.R:224 | `.phylo_signal_wald_ci()` | *(none specified)* | `if (is.null(fit$sd_report) \|\| !inherits(...)) cli_abort(...)` |
| proportions-ci.R:290 | `proportions_ci()` | *(none specified)* | `if (is.null(fit$sd_report) \|\| !inherits(...)) cli_abort(...)` |
| loading-uncertainty-helpers.R:87 | `.lambda_se_internal()` | *(none specified)* | `if (is.null(fit$sd_report) \|\| !inherits(...)) cli_abort(...)` |
| extract-repeatability.R:126 | `.repeatability_wald_ci()` | *(none specified)* | `if (is.null(cov_fix)) cli_abort(...)` |

**Abort Idiom Examples:**

*Pattern 1 (re-uncertainty.R:115-119):*
```r
sd_rep <- fit$sd_report
if (is.null(sd_rep)) {
  cli::cli_abort(c(
    "{.fn getREsd} requires the fit's TMB {.fn sdreport}.",
    "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
    ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
  ), class = "gllvmTMB_getREsd_no_sdreport")
}
```

*Pattern 2 (methods-gllvmTMB.R:431-437):*
```r
if (is.null(object$sd_report)) {
  cli::cli_abort(c(
    "{.code se.fit = TRUE} requires the fit's TMB {.fn sdreport}.",
    "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
    ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
  ), class = "gllvmTMB_predict_se_no_sdreport")
}
```

---

### SILENT-NA — Returns NA/NULL without warning (1 site)

| File:Line | Function | Return | Code Location |
|-----------|----------|--------|---------------|
| methods-gllvmTMB.R:209 | `.gllvmTMB_b_fix_se()` | `rep(NA_real_, n)` | `if (is.null(fit$sd_report)) return(rep(NA_real_, n))` |

**Risk:** This function is called by user-facing functions without wrapping the NA return in a guard or warning.

---

### INDIFFERENT — Graceful NULL handling (18+ sites)

Handle NULL via:
- Conditional checks with `is.null()` + `isTRUE()` guards
- `tryCatch()` blocks with NA fallback
- Initialization to NA, populate only if non-NULL
- Direct NULL comparison with short-circuit evaluation

| File:Line | Pattern | Notes |
|-----------|---------|-------|
| profile-ci.R:505 | Initialize to NA, conditional populate | `se <- rep(NA_real_, length(hits)); if (!is.null(fit$sd_report)) { ... }` |
| z-confint-gllvmTMB.R:1895 | Conditional extract via tryCatch | `if (length(ix_diag) >= ... && !is.null(object$sd_report)) { se_vec <- tryCatch(...) }` |
| extract-cutpoints.R:80 | Initialize to NA, conditional populate | `ses <- rep(NA_real_, length(taus)); if (!is.null(fit$sd_report)) { ... }` |
| loading-profile.R:126 | `isTRUE()` on property | `pd_ok <- isTRUE(fit$sd_report$pdHess)` — safe via `isTRUE()` |
| vgh-verify.R:64,66 | Double guard: `!is.null()` then `isTRUE()` | `has_pdhess <- !is.null(fit$sd_report$pdHess); ... isTRUE(fit$sd_report$pdHess)` |
| z-confint-gllvmTMB.R:424 | `isTRUE()` on property | `pd_ok <- isTRUE(object$sd_report$pdHess)` |
| profile-derived.R:1080 | Compound guard | `has_sd <- !is.null(...) && inherits(...); pd_ok <- has_sd && isTRUE(...pdHess)` |
| cv-internal.R:356 | Return TRUE if NULL (degenerate fit detection) | `if (is.null(sd_rep)) return(TRUE)` |
| suggest-lambda-constraint.R:370-371 | `isTRUE()` guards | `!is.null(fit$sd_report) && isTRUE(fit$sd_report$pdHess == FALSE)` |
| diagnose.R:23-30 | Ternary with NULL check | `se <- if (!is.null(object$sd_report)) { tryCatch(...) } else { NA_real_ }` |
| confint-inspect.R:273 | `tryCatch()` on extraction | `wald_se_link <- tryCatch(sqrt(diag(fit$sd_report$cov.fixed))[idx], error = function(e) NA_real_)` |
| missing-predictor.R:2760-2773 | Return diagnostic string | `gll_standard_error_status()` returns "sdreport_skipped" if NULL |
| standard-errors.R:100 | Early return if non-NULL | `if (!is.null(fit$sd_report)) { return(fit) } # else compute it` |
| z-confint-gllvmTMB.R:1310 | `tryCatch()` on extraction | `se <- tryCatch(sqrt(diag(object$sd_report$cov.fixed))[idx], error = ...)` |
| check-identifiability.R:355 | `isTRUE()` on property | `isTRUE(refit$sd_report$pdHess)` |
| check-identifiability.R:455 | `tryCatch()` on solve | `H <- tryCatch(solve(refit$sd_report$cov.fixed), error = function(e) NULL)` |

*Note:* Additional ~20+ sites use sd_report properties (`.pdHess`, `.cov.fixed`, `.par.random`) only within conditions that first check `!is.null()`.

---

## 2. Downstream Consumers of `.gllvmTMB_b_fix_se()`

### Call Sites (5 locations):

| Caller | File:Line | Context | User-Facing? |
|--------|-----------|---------|--------------|
| `.gllvmTMB_b_fix_table()` | methods-gllvmTMB.R:249 | Builds `Std.Err` column | — |
| `summary.gllvmTMB_multi()` | methods-gllvmTMB.R:991 | Calls `.gllvmTMB_b_fix_table()` | **YES** |
| `print.summary.gllvmTMB_multi()` | methods-gllvmTMB.R:1652 | Via tryCatch | **YES** |
| `gllvmTMB_diagnose()` | diagnose.R:25 | Via tryCatch | **YES** |
| `gll_standard_error_status()` | missing-predictor.R:2767 | Status diagnostic | — |

### User-Facing Surface Impact (3 functions affected):

1. **`summary(fit, ...)`** → `fit$sd_report = NULL` ⟹ `std.error` column = `NA`
   - Called by: `summary.gllvmTMB_multi()` (methods-gllvmTMB.R:991)
   - Returns data.frame with `Std.Err = NA` for all b_fix entries
   - No warning or error

2. **`print(summary(fit), ...)`** → Prints `NA` in the std.error column
   - Called by: `print.summary.gllvmTMB_multi()` (methods-gllvmTMB.R:1650-1662)
   - Computes `max(se)` which is `NA` if all entries are `NA`
   - No special handling

3. **`confint(fit, method="wald")`** → `tidy()` ⟹ CI bounds = `NA`
   - Call chain: `confint.gllvmTMB_multi()` (z-confint-gllvmTMB.R:1705) 
     → `tidy(object, "fixed", conf.int=TRUE)` (methods-gllvmTMB.R:1007-1010)
     → `out$conf.low/conf.high = estimate ± qnorm(...) * NA` = `NA`
   - No warning

4. **`gllvmTMB_diagnose(fit, ...)`** → Returns diagnostic structure with `NA` for `max_se`
   - Called at diagnose.R:25, wrapped in `tryCatch()`
   - Propagates `NA` upward to user

---

## 3. Silent NA Pattern Analysis: `rep(NA_real_, ...)`

### Instances examined for silent-on-missing-prerequisite (selected from 40+ total):

| File:Line | Context | Is Silent-on-Missing? | Notes |
|-----------|---------|----------------------|-------|
| methods-gllvmTMB.R:209 | `.gllvmTMB_b_fix_se()` NULL guard | **YES** | Returns NA when sd_report is NULL |
| methods-gllvmTMB.R:227-228 | Falls back to NA if not found | **YES** | Accesses `par.random` without guard |
| profile-ci.R:504 | Initialize, conditionally populate | NO | Legitimate NA initialization |
| extract-cutpoints.R:79 | Initialize, conditionally populate | NO | Legitimate NA initialization |
| output-methods.R:240 | Conditional NA return | **YES** | `se_vec <- rep(NA_real_, d*n)` when sd_report is NULL (line 216-221 guard) |
| re-uncertainty.R:179 | Conditional NA return | **YES** | `se_vec <- rep(NA_real_, ...)` when sd_report absent (line 114-120 guard) |
| extractors.R:762 | Status indicator return | NO | `empty(status)` returns intentional NA with reason |
| extractors.R:818-819 | Conditional on pdHess | NO | Legitimate NA when Hessian not PD |

**Finding:** Only **3 definite silent-on-missing-prerequisite cases**:
1. methods-gllvmTMB.R:209 (PRIMARY: `.gllvmTMB_b_fix_se()`)
2. methods-gllvmTMB.R:227-228 (SECONDARY: accessing `par.random` without NULL check)
3. output-methods.R:240 & re-uncertainty.R:179 (These ARE guarded; code is correct)

---

## 4. Existing Abort Idiom (Convention for fix)

### Naming Convention:

All typed aborts use pattern: `class = "gllvmTMB_<function>_<reason>"`

Examples:
- `class = "gllvmTMB_getREsd_no_sdreport"`
- `class = "gllvmTMB_getLV_se_no_sdreport"`
- `class = "gllvmTMB_predict_se_no_sdreport"`

### Message Template (from lines 115-119, 432-436):

```r
cli::cli_abort(c(
  "{.code <operation>} requires the fit's TMB {.fn sdreport}.",
  "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
  ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
), class = "gllvmTMB_<function>_no_sdreport")
```

---

## 5. Test Coverage: Existing Locks-in NA Behavior

### Search: grep -rn "sd_report" tests/testthat/ → 38 hits

**Findings:**

No existing tests explicitly lock in the **silent NA behavior** when `sd_report = NULL`.

**Most relevant test:**
- **test-confint-bootstrap.R:143-144**: Checks `all(is.na(ci$lower))` and `all(is.na(ci$upper))` 
  - **NOT** related to sd_report=NULL; tests legitimate NA case where Sigma_unit is total covariance with reduced rank (line 128 comment explains)
  - Fit used (`make_tiny_B_fit()`) has normal sdreport; this is testing a statistical edge case

**Gap:** No test suite covers:
- `summary(fit)` with `se=FALSE` fit
- `print(summary(fit))` with `se=FALSE` fit  
- `confint(fit, method="wald")` with `se=FALSE` fit
- `coef(fit)` with `se=FALSE` fit (if extractor exists)
- `tidy(fit)` with `se=FALSE` fit

**Implication:** Fixing `.gllvmTMB_b_fix_se()` to abort (instead of silent NA) would **NOT break existing tests**.

---

## Summary Statistics

| Category | Count |
|----------|-------|
| **ABORTS** | 8 |
| **SILENT-NA** | 1 |
| **INDIFFERENT** | 18+ |
| **Total sd_report read sites** | 80+ (from grep) |
| **Downstream user-facing functions** | 3 (summary, print.summary, confint) |
| **Tests locking in NA behavior** | 0 |

---

## Recommendations for Fix

1. **Primary fix**: `.gllvmTMB_b_fix_se()` (methods-gllvmTMB.R:209)  
   Replace silent NA with abort using convention: `class = "gllvmTMB_b_fix_se_no_sdreport"`

2. **Secondary fixes** (access without guard):
   - methods-gllvmTMB.R:227-228 (accessing `par.random` directly)

3. **No test refactoring needed** — no existing tests rely on NA behavior

4. **Documentation**: The existing message template at re-uncertainty.R:115-119 is the gold standard.

