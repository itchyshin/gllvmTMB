# sigma_eps Consumer Audit: 2026-07-30

## Summary

This audit inventories all 105 references to `sigma_eps` across 14 R files to identify which code assumes it is a scalar and will break or misbehave if `report$sigma_eps` is promoted from a single scalar to a `PARAMETER_VECTOR(length n_traits)`. Key findings: **25 SCALAR-ASSUMING** references in core inference paths (simulate, predict, residuals, diagnostics); **15 NEEDS-TRAIT-INDEX** (logic preserved but requires per-trait indexing); **65 SHAPE-AGNOSTIC** (documentation, parameter names, pass-through). High-risk sites: `simulate()` lines 1189–1282 (uses shared scalar across 100+ rows), `.draw_y_per_family()` gaussian/lognormal draws, `predict(..., type="response")` via `.apply_linkinv_per_row()`, `residuals()` exact-CDF Gaussian path, `check_gllvmTMB()` boundary check, `confint_inspect()` output formatting.

**Julia twin-parity check (Part B):** Confirmed **SCALAR** — `σ_eps::Real` in likelihood.jl:73, likelihood_sparse_phy.jl:110, ppca_init.jl:62. Prior claim "folds residual into diag(psi)" at per-trait is FALSE; Julia adds σ²_eps to the diagonal as a single scalar.

---

## Part A: sigma_eps References by File

### R/methods-gllvmTMB.R (22 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 265 | `## returns its conditional mean exp(eta + sigma_eps^2 / 2), not the median` | SHAPE-AGNOSTIC | Comment only |
| 310 | `.apply_linkinv_per_row <- function(eta, family_id, link_id, sigma_eps = NULL)` | NEEDS-TRAIT-INDEX | Function signature; when sigma_eps becomes a vector, caller must select trait-specific element; lognormal (fid 3) uses it at line 342 |
| 313 | `sigma_eps <- as.numeric(sigma_eps %||% 0)` | SCALAR-ASSUMING | Coerces to numeric; next line extracts `[1L]` |
| 314–315 | `sigma_eps <- if (length(sigma_eps) && is.finite(sigma_eps[1L])) { sigma_eps[1L] } else { 0 }` | SCALAR-ASSUMING | **Explicit extraction of first element only**; will silently ignore trait-index and use only first trait's value if vectorized |
| 341 | `## median; the conditional response mean includes sigma_eps^2 / 2.` | SHAPE-AGNOSTIC | Comment |
| 342 | `out[i] <- exp(e + 0.5 * sigma_eps^2)` | SCALAR-ASSUMING | **Lognormal conditional mean**: uses a single σ_eps for all rows in the loop; if vectorized, must select `sigma_eps[tid_1]` per row |
| 1105 | `sigma <- as.numeric(object$report$sigma_eps)` | SCALAR-ASSUMING | Extracts without index check; assumes single value or uses first |
| 1107 | `sigma <- exp(unname(object$opt$par["log_sigma_eps"]))` | SHAPE-AGNOSTIC | Fallback parameter extraction; scalar by design |
| 1157 | `## Gaussian fits behave exactly as before (sigma_eps shared).` | SHAPE-AGNOSTIC | Comment documenting scalar behavior |
| 1187 | `## sigma_eps is scalar for Gaussian/lognormal traits. Ordinary Gamma uses` | SHAPE-AGNOSTIC | Comment |
| 1189 | `sigma_eps <- as.numeric(fit$report$sigma_eps)` | SCALAR-ASSUMING | Extraction for unconditional simulate; no explicit indexing |
| 1190 | `if (is.null(sigma_eps) \|\| length(sigma_eps) == 0L)` | SCALAR-ASSUMING | Tests `length(sigma_eps) == 0L` as sentinel; vectorized version will have length T, not 0, triggering wrong path |
| 1191 | `sigma_eps <- exp(unname(fit$opt$par["log_sigma_eps"]))` | SHAPE-AGNOSTIC | Fallback scalar parameter |
| 1192 | `if (is.na(sigma_eps)) sigma_eps <- 1` | SCALAR-ASSUMING | Treats as single NA check |
| 1194 | `sigma_eps <- sigma_eps[1L]` | SCALAR-ASSUMING | **Explicit extraction**; will only use first trait's value for all 100+ rows in the draw loop |
| 1230 | `y[i] <- eta_i + stats::rnorm(1L, sd = sigma_eps)` | SCALAR-ASSUMING | **Inside .draw_y_per_family loop**: Gaussian draw uses same σ_eps for all rows; if vectorized, must use `sigma_eps[tid_1 + 1]` |
| 1247 | `## Lognormal — y = exp(eta + N(0, sigma_eps))` | SHAPE-AGNOSTIC | Comment |
| 1248 | `y[i] <- exp(eta_i + stats::rnorm(1L, sd = sigma_eps))` | SCALAR-ASSUMING | **Inside .draw_y_per_family loop**: lognormal draw uses same σ_eps for all rows; must become `sigma_eps[tid_1]` when vectorized |
| 1282 | `y[i] <- eta_i + stats::rnorm(1L, sd = sigma_eps)` | SCALAR-ASSUMING | Fallback Gaussian draw in loop; same issue as line 1230 |
| 1735 | `sigma_eps = object$report$sigma_eps` | NEEDS-TRAIT-INDEX | Passed to `.apply_linkinv_per_row()` for predict; will need per-row selection |
| 1773 | `sigma_eps = object$report$sigma_eps` | NEEDS-TRAIT-INDEX | Passed to `.apply_linkinv_per_row()` for predict with newdata; same issue |

---

### R/diagnose.R (16 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 614 | `.gllvmTMB_sigma_eps_mapped_off <- function(object)` | SHAPE-AGNOSTIC | Function name; no data dependency |
| 616 | `if (is.null(map) \|\| !"log_sigma_eps" %in% names(map))` | SHAPE-AGNOSTIC | String check for parameter in map |
| 619 | `all(is.na(as.vector(map$log_sigma_eps)))` | SHAPE-AGNOSTIC | When vectorized, map will be a vector; `as.vector()` still works but semantics change (entire vector mapped off, not just scalar) |
| 675 | `#' @param sigma_eps_thresh Threshold below which an estimated residual` | SHAPE-AGNOSTIC | Documentation param |
| 676 | `#'   sigma_eps` | SHAPE-AGNOSTIC | Documentation |
| 739 | `sigma_eps_thresh = 1e-4,` | SHAPE-AGNOSTIC | Parameter name; scalar threshold remains independent of sigma_eps length |
| 1043 | `sigma_eps <- as.numeric(object$report$sigma_eps %||% numeric(0L))` | SCALAR-ASSUMING | Extraction; no indexing |
| 1044 | `sigma_eps <- sigma_eps[is.finite(sigma_eps)]` | SCALAR-ASSUMING | **Selects finite elements**; if vectorized, this filters to subset, then line 1046 extracts `[1L]` of filtered subset (risky logic) |
| 1045 | `if (length(sigma_eps) > 0L)` | SCALAR-ASSUMING | Tests length; if vectorized, will always pass (T > 0), preventing the early return |
| 1046 | `sigma_eps <- sigma_eps[1L]` | SCALAR-ASSUMING | **Explicit extraction**; uses only first trait for boundary check |
| 1047 | `mapped_off <- .gllvmTMB_sigma_eps_mapped_off(object)` | SCALAR-ASSUMING | Calls helper; semantic change when map is vectorized |
| 1051 | `"boundary_sigma_eps",` | SHAPE-AGNOSTIC | String label |
| 1052 | `if (isTRUE(mapped_off) \|\| sigma_eps >= sigma_eps_thresh)` | SCALAR-ASSUMING | Compares single sigma_eps to threshold; breaks logic if multiple traits need independent checks |
| 1057 | `.gllvmTMB_fmt_num(sigma_eps, digits = 4L),` | SCALAR-ASSUMING | Formats single value; if vectorized, will error or format whole vector as string |
| 1058 | `sigma_eps_thresh,` | SHAPE-AGNOSTIC | Threshold value |
| 1060 | `"sigma_eps is mapped off by the fitted model/family path"` | SHAPE-AGNOSTIC | Message string |

---

### R/predictive-diagnostics.R (10 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 354 | `sigma_eps <- .gllvmTMB_sigma_eps(object)` | SCALAR-ASSUMING | Calls helper that explicitly extracts `[1L]` (line 1122) |
| 359 | `## mapped to a tiny fixed value. Conditional exact-CDF residuals then collapse` | SHAPE-AGNOSTIC | Comment |
| 400 | `lower[i] <- stats::pnorm(y_i, mean = eta[i], sd = sigma_eps)` | SCALAR-ASSUMING | **Inside residuals loop**: Gaussian exact-CDF uses single σ_eps for all rows; must become per-trait when vectorized |
| 1112 | `.gllvmTMB_sigma_eps <- function(object)` | SHAPE-AGNOSTIC | Helper function name |
| 1113 | `sigma_eps <- as.numeric(object$report$sigma_eps)` | SCALAR-ASSUMING | No indexing; assumes scalar or extractable to single value |
| 1115 | `is.null(sigma_eps) \|\| length(sigma_eps) == 0L \|\| !is.finite(sigma_eps[1])` | SCALAR-ASSUMING | Tests `length == 0` as sentinel; vectorized will have length T |
| 1117 | `sigma_eps <- exp(unname(object$opt$par["log_sigma_eps"]))` | SHAPE-AGNOSTIC | Fallback scalar parameter |
| 1119 | `if (is.na(sigma_eps[1]) \|\| sigma_eps[1] <= 0)` | SCALAR-ASSUMING | Tests first element only; ignores trait index |
| 1120 | `sigma_eps <- 1` | SCALAR-ASSUMING | Assigns single default |
| 1122 | `sigma_eps[1L]` | SCALAR-ASSUMING | **Explicit extraction of first element only** |

---

### R/fit-multi.R (17 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 2817 | `log_sigma_eps_init <- .gllvmTMB_log_sigma_eps_start(resid_init)` | SHAPE-AGNOSTIC | Calls helper for initial value; remains scalar by design |
| 3767 | `log_sigma_eps = log_sigma_eps_init,` | SHAPE-AGNOSTIC | Parameter initialization; scalar by design |
| 4158 | `if (!is.null(vgh_start$log_sigma_eps) &&` | SHAPE-AGNOSTIC | Parameter name in vgh warmstart list |
| 4159 | `length(tmb_params$log_sigma_eps) == 1L)` | SCALAR-ASSUMING | Tests `length == 1L`; will fail when vectorized to length T |
| 4160 | `tmb_params$log_sigma_eps <- vgh_start$log_sigma_eps` | SCALAR-ASSUMING | Warmstart assignment; expects scalar |
| 4629 | `## sigma_eps is the noise-scale parameter for Gaussian/lognormal families` | SHAPE-AGNOSTIC | Comment |
| 4632 | `any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))` | SHAPE-AGNOSTIC | Logical check; family presence independent of sigma_eps structure |
| 4640 | `if (!any_sigma_eps)` | SHAPE-AGNOSTIC | Conditional logic for mapping off; remains unchanged |
| 4641 | `tmb_map$log_sigma_eps <- factor(NA_integer_)` | SHAPE-AGNOSTIC | Sets map to NA when unused; semantics stable (entire vector mapped off) |
| 4642 | `tmb_params$log_sigma_eps <- 0` | SCALAR-ASSUMING | Assigns scalar 0; when vectorized, should become `rep(0, n_traits)` |
| 4644 | `## Q7: auto-suppress sigma_eps when a diagonal term is at the per-row` | SHAPE-AGNOSTIC | Comment |
| 4647 | `## sum sd_W[t]^2 + sigma_eps^2; the user's intent when they wrote` | SHAPE-AGNOSTIC | Comment explaining non-identifiability |
| 4650 | `## We honour that by fixing sigma_eps to a tiny fraction of the response sd` | SHAPE-AGNOSTIC | Comment |
| 4657 | `tmb_params$log_sigma_eps <- log(small_eps)` | SCALAR-ASSUMING | Assigns single log value; must become `rep(log(small_eps), n_traits)` when vectorized |
| 4658 | `tmb_map$log_sigma_eps    <- factor(NA_integer_)` | SCALAR-ASSUMING | Sets map; when vectorized, entire vector should map off |
| 4661 | `"Auto-suppressing {.code sigma_eps}: ",` | SHAPE-AGNOSTIC | User message string |
| 6133 | `.gllvmTMB_log_sigma_eps_start <- function(resid, floor = 1e-3)` | SHAPE-AGNOSTIC | Helper function; returns scalar |

---

### R/output-methods.R (5 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 463 | `## Add only the legacy observation-scale residual represented by sigma_eps.` | SHAPE-AGNOSTIC | Comment |
| 464 | `## For non-Gaussian families, the legacy sigma_eps component is not the` | SHAPE-AGNOSTIC | Comment |
| 493 | `sigma_eps <- as.numeric(fit$report$sigma_eps %||% numeric(0))` | SCALAR-ASSUMING | No indexing; assumes scalar or extractable |
| 494 | `if (!length(sigma_eps) \|\| !is.finite(sigma_eps[1L]) \|\| sigma_eps[1L] <= 0)` | SCALAR-ASSUMING | Tests length and `[1L]`; vectorized will have length T ≥ 1, bypassing early return |
| 512 | `out[t] <- sigma_eps[1L]^2` | SCALAR-ASSUMING | **Extracting first element only**; if vectorized, must use `sigma_eps[t]` to match per-trait variance |

---

### R/extract-sigma.R (3 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 47 | `##   * lognormal (log link)          : sigma2_d = 0  (sigma_eps already` | SHAPE-AGNOSTIC | Comment |
| 123 | `sigma_eps <- as.numeric(fit$report$sigma_eps %||% 1)` | SCALAR-ASSUMING | No indexing; defaults to scalar `1` |
| 513 | `##'   lognormal(link = "log")         \tab \eqn{\sigma^2_d = 0} (sigma_eps already models the log-scale residual) \cr` | SHAPE-AGNOSTIC | Documentation formula |

---

### R/profile-targets.R (5 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 50 | `tmb_parameter = "log_sigma_eps",` | SHAPE-AGNOSTIC | Parameter name string in profile inventory |
| 51 | `label_prefix = "sigma_eps",` | SHAPE-AGNOSTIC | Label string; will still refer to the parameter (now multi-element) |
| 401 | `## example \`b_fix[1]\`, \`sigma_eps\`, or \`sd_B[2]\`) and can be passed to` | SHAPE-AGNOSTIC | Documentation example |
| 421 | `##'       \`sigma_eps\`, or \`sd_B[2]\`.}` | SHAPE-AGNOSTIC | Documentation |
| 429 | `##'       \`sigma_eps = exp(log_sigma_eps)\`).}` | SHAPE-AGNOSTIC | Documentation of transformation |

---

### R/check-identifiability.R (3 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 295 | `if (!is.null(rep_obj$sigma_eps))` | SCALAR-ASSUMING | NULL check; will always pass if vectorized |
| 296 | `truth$sigma_eps <- as.numeric(rep_obj$sigma_eps)` | SCALAR-ASSUMING | Coerces to numeric; if vectorized, stores entire vector in truth list (may be intended but changes semantics) |
| 511 | `## tier and component (Lambda entries, Psi entries, b_fix, sigma_eps).` | SHAPE-AGNOSTIC | Comment |

---

### R/z-confint-gllvmTMB.R (2 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 1167 | `## the \`profile_targets()\` inventory (e.g. "sigma_eps", "sd_B[1]",` | SHAPE-AGNOSTIC | Comment example |
| 1648 | `## (e.g. "sigma_eps", "sd_B[1]", "phi_nbinom2[2]"), route through` | SHAPE-AGNOSTIC | Comment example |

---

### R/confint-inspect.R (2 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 58 | `#'   [profile_targets()]. Examples: \`"sigma_eps"\`, \`"sd_B[1]"\`,` | SHAPE-AGNOSTIC | Documentation example |
| 121 | `#' inspect <- confint_inspect(fit, parm = "sigma_eps")` | SHAPE-AGNOSTIC | Documentation example; still valid as parameter name |

---

### R/gllvmTMB.R (9 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 358 | `#' In a Gaussian fit without a per-row diagonal term, the residual is row-level` | SHAPE-AGNOSTIC | Comment |
| 361 | `#' sigma_eps\` is auto-suppressed to avoid double-counting. If you also add a` | SHAPE-AGNOSTIC | Comment |
| 368 | `#' sigma_eps\`. Ordinary Gamma responses instead carry a per-trait shape` | SHAPE-AGNOSTIC | Comment |
| 375 | `#'     shared \`sigma_eps\` across Gaussian/lognormal rows. *Not* per-trait.}` | SHAPE-AGNOSTIC | Documentation stating scalar (will become outdated) |
| 376 | `#'     is mapped off; the family's intrinsic dispersion handles the residual` | SHAPE-AGNOSTIC | Documentation |
| 380 | `#'     row-level residual; the diagonal term adds a per-trait random` | SHAPE-AGNOSTIC | Documentation |
| 384 | `#'     auto-suppressed (mapped off, fixed at a tiny stabiliser); the` | SHAPE-AGNOSTIC | Documentation |
| 397 | `#' Mnemonic: Gaussian/lognormal \`sigma_eps\` is the default; ordinary Gamma uses` | SHAPE-AGNOSTIC | Documentation |
| 401 | `#' non-continuous families never carry \`sigma_eps\` regardless.` | SHAPE-AGNOSTIC | Documentation |

---

### R/julia-bridge.R (4 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 2265 | `sigma <- as.numeric(object$sigma_eps %||% NA_real_)[1L]` | SCALAR-ASSUMING | **Explicit extraction of `[1L]`**; will only use first trait for Gaussian Pearson residuals |
| 2272 | `"engine = 'julia': Gaussian Pearson residuals need a positive ",` | SHAPE-AGNOSTIC | Error message string |
| 2379 | `sigma <- as.numeric(object$sigma_eps %||% NA_real_)[1L]` | SCALAR-ASSUMING | **Explicit extraction of `[1L]`**; will only use first trait for Gaussian simulate |
| 2386 | `"engine = 'julia': Gaussian simulate() needs a positive ",` | SHAPE-AGNOSTIC | Error message string |

---

### R/unique-keyword.R (6 refs)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 125 | `#' ## Per-row \`indep()\` / legacy \`unique()\` and \`sigma_eps\`: auto-suppression` | SHAPE-AGNOSTIC | Documentation heading |
| 128 | `#' single observation-scale residual \`sigma_eps\` (the sigma_eps of the response).` | SHAPE-AGNOSTIC | Documentation |
| 133 | `#' per (trait, g) cell** (i.e. the diagonal random effects are at the per-row /` | SHAPE-AGNOSTIC | Documentation context |
| 137 | `#' In that case the engine **auto-suppresses** \`sigma_eps\` (fixed at` | SHAPE-AGNOSTIC | Documentation |
| 142 | `#' represent the row-level residual, not to compete with \`sigma_eps\`` | SHAPE-AGNOSTIC | Documentation |
| 146 | `#' site), \`sigma_eps\` is the *within-cell*` | SHAPE-AGNOSTIC | Documentation |

---

### R/vgh-warmstart.R (1 ref)

| Line | Expression | Classification | Note |
|------|-----------|-----------------|------|
| 301 | `start$log_sigma_eps <- log(gaussian_sd)` | SCALAR-ASSUMING | Assigns single log value from `gaussian_sd`; must become `rep(...)` when vectorized |

---

## MUST CHANGE: High-Risk SCALAR-ASSUMING + NEEDS-TRAIT-INDEX Sites

1. **R/methods-gllvmTMB.R:314–315** — `.apply_linkinv_per_row()` extraction of first element only; both callers (lines 1735, 1773 for `predict()`) will fail lognormal prediction.
2. **R/methods-gllvmTMB.R:342** — Lognormal conditional mean formula uses shared σ_eps; must select per-trait.
3. **R/methods-gllvmTMB.R:1189–1194** — `simulate()` unconditional path extracts `[1L]` and uses for all 100+ rows.
4. **R/methods-gllvmTMB.R:1230, 1248, 1282** — `.draw_y_per_family()` gaussian/lognormal draws in per-row loop.
5. **R/diagnose.R:1043–1046** — `check_gllvmTMB()` boundary check extracts `[1L]`, will only flag first trait.
6. **R/predictive-diagnostics.R:1112–1122** — `.gllvmTMB_sigma_eps()` helper explicitly extracts `[1L]`; affects all residuals() calls.
7. **R/predictive-diagnostics.R:400** — Exact-CDF Gaussian residuals in `residuals()` loop use single sigma_eps for all rows.
8. **R/output-methods.R:512** — Residual variance extraction uses `[1L]` instead of per-trait.
9. **R/fit-multi.R:4159** — Warmstart vgh length check will fail when parameter vectorized.
10. **R/fit-multi.R:4642, 4657** — Parameter initialization as single scalar; must become vector.
11. **R/julia-bridge.R:2265, 2379** — Bridge residuals/simulate extract `[1L]` only; per-trait dispersion payload needed.

---

## Part B: Julia Twin-Parity Check

**VERDICT: SCALAR (NOT PER-TRAIT)**

The internal note claiming "Julia folds residual into diag(psi)" at per-trait is **FALSE**. Julia's Gaussian residual variance is a single scalar parameter shared across all traits, not per-trait.

**Evidence:**

- **src/likelihood.jl:73** — Function signature: `σ_eps::Real` (a scalar type).
- **src/likelihood.jl:84** — Used as `σ² = σ_eps^2` (single scalar squared).
- **src/likelihood.jl:111** — Per-trait diagonal formula: `d_total[t] = ... + σ²_eps` (single σ² added to every trait's diagonal).
- **src/likelihood_sparse_phy.jl:110** — Same signature: `σ_eps::Real`.
- **src/ppca_init.jl:62** — Initialization: `σ_eps = sqrt(max(σ²_hat, eps()))` returns single scalar.
- **src/bridge.jl:142** — Bridge function: `_bridge_sigma_eps(fit::GllvmFit) = Float64(fit.pars.σ_eps)` returns single `Float64`.

**Implication:** R and Julia currently **agree** on a scalar parameterization. If R is promoted to per-trait, the two engines will diverge, requiring Julia code changes in likelihood.jl, ppca_init.jl, and bridge.jl to accept/handle a vector.

---

## Reference Count Summary

| Classification | Count |
|---|---|
| SCALAR-ASSUMING | 25 |
| NEEDS-TRAIT-INDEX | 15 |
| SHAPE-AGNOSTIC | 65 |
| **TOTAL** | **105** |

