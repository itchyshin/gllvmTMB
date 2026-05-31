# Missing-data Phase 0 — source audit (gllvmTMB lane)

**Issue:** #333 (≙ drmTMB MD0). **Contract:** `docs/design/59-missing-data-layer.md`. **Branch base:** `main` `2c02b51`. **Date:** 2026-05-31. **Read-only — no engine change.**

Goal: record the *current* missing-data behavior with precise `file:line`, and the exact hook points where the **Phase 1 response mask** (`miss_control(response="include")`, `is_y_observed`, keep-don't-drop, `predict_missing()`, `fit$missing_data`) attaches. Stop before any syntax/likelihood change.

> **Line-ref correction:** Design 59 §5 cited `fit-multi.R:699-700 / 1926-1930 / 1048` — those were from a pre-slope-campaign checkout. `fit-multi.R` has since grown; the *current* lines are below. Design 59 §5 is updated to match in the same PR (line-refs only; no contract-semantics change).

## 1. Missing RESPONSE handling (current)

| What | `file:line` | Behavior |
|---|---|---|
| Long scalar `y` | `R/gllvmTMB.R:638-700` `drop_missing_response_rows()` | `model.frame(na.action=na.pass)` → `model.response()` → `is.na()` → `data <- data[keep, , drop=FALSE]`. **Original row identity discarded.** |
| Binomial `cbind(succ,fail)` | same fn (`rowSums(is.na(y_raw)) > 0L`) | row dropped if **either** column is `NA`. |
| Wide `traits(...)` cells | `R/traits-keyword.R:366-372` | `tidyr::pivot_longer(..., values_drop_na = TRUE)` — per-`(unit,trait)` cell `NA`s **silently dropped at pivot**; no index preserved. |
| User report | `R/gllvmTMB.R:696` | logs `"dropped {n} row(s) with NA response"`; `n_dropped` **not stored** on the fit. |

**Phase 1 hook:** intercept **before** the drop — gate `drop_missing_response_rows()` (`gllvmTMB.R:~694`) and the wide pivot (`traits-keyword.R:371`) on `miss_control(response=)`. For `"include"`: keep full data, build `is_y_observed` (1=observed, 0=missing) over the *long* stacked rows, carry `original_row`/`model_row`. **Risk:** the wide pivot is the irreversible one — the mask must be constructed at/before the pivot so cell identity survives.

## 2. Fixed-effects design matrix + missing PREDICTORS (current)

- `R/fit-multi.R:937-938` — `mf <- model.frame(parsed$fixed, data, na.action = na.pass)`; `X_fix <- model.matrix(parsed$fixed, mf)`.
- `R/fit-multi.R:1010-1014` — `if (any(is.na(X_fix))) cli::cli_abort("NA in the fixed-effect design matrix…")` — hard stop; `NaN` does **not** reach TMB.
- The abort message mentions response-row dropping — slightly misleading for predictors (they error, not drop). Tidy when Phase 2 lands.

**Phase 1 hook:** none (response-only). `predictor="fail"` (default) keeps this hard stop, so Phase 1 is safe. **Phase 2a** intercepts at `:937` to split `mi(x)` columns into `x_obs` + `x_mis` index.

## 3. `random` vector + `MakeADFun` (current)

- `R/fit-multi.R:2416` `random <- character(0)`; `:2417-2435` conditionally appends RE blocks (`z_B,s_B,z_W,s_W,p_phy,q_sp,omega_spde*,b_phy_aug,g_phy_slope,u_re_int,…`) by `use_*` flag.
- `R/fit-multi.R:2456-2460` `TMB::MakeADFun(data=tmb_data, parameters=tmb_params, map=tmb_map, random=random, …)`.
- `tmb_data` slots: `y`, `n_trials`, `X_fix`, `trait_id`, `site_id`, `site_species_id`, `family_id_vec`, `link_id_vec`, dims, + phylo/spatial blocks by `use_*`.

**Phase 2 hook:** append `"x_mis"` to `random` at `:2435` under a `use_mi_predictor` flag; add covariate-model data (`Ainv_x`, …) near the `tmb_data` assembly. **Phase 1 hook:** add `is_y_observed` to `tmb_data`.

## 4. TMB DATA contract + likelihood loop (current)

- `src/gllvmTMB.cpp:36` `DATA_VECTOR(y)` — long stacked, length `n_obs`; `:37` `DATA_VECTOR(n_trials)`; `:43-45,164` `DATA_IVECTOR(trait_id/site_id/site_species_id/family_id_vec)` (0-indexed, length `n_obs`).
- `:1366` `for (int o = 0; o < y.size(); o++)`; `:1367` `int fid = family_id_vec(o)`; `:1372-1541` per-family `nll -= …` blocks. **No per-observation gate — every row contributes unconditionally.**

**Phase 1 hook:** add `DATA_IVECTOR(is_y_observed)` (length `n_obs`) after `:36`; wrap each family block (`:1372-1541`) in `if (is_y_observed(o)) { … }`. When 0, the row adds nothing. **Sentinel discipline:** missing-`y` entries get a safe sentinel in `y`; the §9 sentinel-invariance test (two sentinels → byte-identical fit) guards leaks.

## 5. Extractor row accounting (current)

- `R/methods-gllvmTMB.R:481-487` `logLik()` → `attr(,"nobs") <- length(object$tmb_data$y)` = **fitted (post-drop) rows**.
- `R/methods-gllvmTMB.R:1189-1290` `predict()` keys off `object$data` (post-drop, stored `:~2644-2775`) → reports fitted rows only. No original↔fitted mapping.

**Phase 1 hook:** store `fit$data_original` (pre-drop) + `fit$missing_data` (`original_row`, `model_row`, `observed_y`, response-pattern counts, slice/version metadata — the shared contract slot). Keep `nobs()` = likelihood-contributing; surface original-row counts via `fit$missing_data` / `summary()$missing` / `check_gllvmTMB()`, **not** by redefining `nobs()`.

## 6. Existing mask/observed concept

**None.** No `is_y_observed`/`observed_y`/`original_row`/`model_row` in R or C++. `n_dropped` is computed (`gllvmTMB.R:657`) + printed but not stored. Phase 1 builds the machinery from scratch.

## Phase 1 hook summary (what #334 will touch)

| # | Hook | `file:line` |
|---|---|---|
| 1 | gate response drop on `miss_control(response=)` | `gllvmTMB.R:~694`, `traits-keyword.R:371` |
| 2 | build `is_y_observed` over long rows (before wide pivot) | `traits-keyword.R:366-372`, `gllvmTMB.R:638-700` |
| 3 | add `is_y_observed` to `tmb_data` | `fit-multi.R:~2440` |
| 4 | gate the C++ likelihood loop | `src/gllvmTMB.cpp:1366-1541` |
| 5 | `fit$missing_data` + `fit$data_original` + `summary()$missing` | `fit-multi.R:~2644-2775`, `methods-gllvmTMB.R` |
| 6 | `predict_missing()` (responses) | new fn in `methods-gllvmTMB.R` |

## Shared-spec gates carried into Phase 1 (§9)

1. **Deterministic match** — `response="include"` fit == complete-case fit on observed rows (coef + logLik); `residuals()` is `NA` where response missing.
2. **Sentinel-invariance (SHARED, both lanes)** — missing-`y` sentinel ∈ {`0`, `1e6`} → byte-identical logLik/coef/gradient.
3. **No-op** — complete-data fits unchanged under default `miss_control(response="drop")`.

## Stop boundary

No syntax, no `miss_control()`, no `mi()`, no likelihood change in Phase 0. Phase 1 (#334) begins on greenlight, on a fresh branch off `main`, TDD with the §9 gates above written first.
