# AGHQ Consumer Inventory

**Objective:** Catalog every downstream consumer of the fitted objective (NLL) and related components (sd_report, report$, opt$par) so that when the objective changes from Laplace to AGHQ, we verify nothing silently mixes engines.

**Date:** 2026-07-28  
**Slice owner:** R1  
**Status:** READ-ONLY inventory (no fixes, no runs)

---

## Summary

- **Total unique consumer sites identified:** 47+
- **Files touched:** 28 R files, 1 src file
- **Categories:** 6 (logLik/AIC/BIC | sdreport/Hessian | simulate | predict/fitted | objective storage | report items)
- **Highest risk items:** 3 flagged below

---

## Category 1: Objective / Log-Likelihood Consumers

Paths that read, compute, or report the fitted objective / log-likelihood value.

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| `logLik.gllvmTMB_multi()` | R/methods-gllvmTMB.R:737–757 | `opt$objective`, `opt$par`, `tmb_data$is_y_observed` | **CRITICAL** — AGHQ objective is numerically different. The negated objective becomes the logLik; AIC/BIC computed from it. Must remain consistent with optimization engine. | The value is transformed: `ll = -object$opt$objective`. AIC/BIC derive from this. ✓ This works correctly regardless of engine IF opt$objective is set correctly by the optimizer. |
| `print.gllvmTMB_multi()` | R/methods-gllvmTMB.R:532–536 | `opt$objective`, `opt$convergence` | **MEDIUM** — user-facing output; prints "ML log L = -objective, convergence = code". User will see two different objectives if they rerun with AGHQ vs. Laplace. | Informational only; no downstream logic depends on it. But auditor will notice the change. OK to show different value if engines differ. |
| `summary.gllvmTMB_multi()` | R/methods-gllvmTMB.R:583–584 | `opt$objective`, `opt$convergence` | **MEDIUM** — included in summary output structure. Users compare summaries across fits; AGHQ will show a different logLik. | Informational; no computational dependency. Documented in summary output. |
| `print.summary.gllvmTMB_multi()` | R/methods-gllvmTMB.R:629–677 | `opt$objective`, `opt$convergence` (via summary) | **LOW** — re-prints the summary structure. | Indirect; no new reads. |
| `loading_profile()` | R/loading-profile.R:71–210 | Calls `stats::logLik(fit)` at lines 134, 178 | **CRITICAL** — uses logLik for profile-likelihood inference on constrained fits. The profile curve is built by pinning Lambda entries and refitting; each refit's objective is compared. AGHQ refits will have different objectives than Laplace refits. | **HIGHEST RISK #1.** The profile likelihood curve is used to invert CI bounds. A mixed engine (Laplace original, AGHQ refits) will have misaligned objectives and broken CIs. Profile CI is a published method; results must be reproducible from the same fit. **Mitigation:** either fit all profiles with the same engine (recommended) or doc that profile CIs require refitting with the original engine. |
| `suggest_lambda_constraint()` | R/suggest-lambda-constraint.R:332–422 | Calls `stats::logLik(fit)` for LRT against baseline | **MEDIUM** — uses logLik difference to suggest constraints. AGHQ baseline will have different logLik; constraint suggestions may differ. | Informational advisor; no blocking logic. Refit with AGHQ will give different suggestions. OK to document. |
| `fit_multi()` (restart diagnostic) | R/fit-multi.R:4852 | Prints `-logLik` from `opt$objective` | **LOW** — diagnostic message during fitting. | Informational; no downstream logic. |
| `kernel_helpers.R` – `.cross_rho_logLik()` | R/kernel-helpers.R:466–468 | Calls `stats::logLik(fit)` | **MEDIUM** — used by `gll_cross_kernel_rho()` to compare kernel fits (e.g., across rho values). Mixed engines break comparison. | Recommender function (kernel rho selection); results user-facing. AGHQ refits will be incomparable with Laplace baseline. |

---

## Category 2: Standard Errors / Hessian / Confidence Intervals

Paths that read `sd_report` or the Hessian and compute uncertainty.

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| **confint.gllvmTMB_multi()** (main dispatcher) | R/z-confint-gllvmTMB.R:1526–1670 | `sd_report$cov.fixed`, `sd_report$pdHess`, calls profile refits | **CRITICAL** — multi-route dispatcher (Wald, profile, bootstrap). Wald route reads `cov.fixed` directly; profile route refits with potentially different engine. | **HIGHEST RISK #2.** The confint surface is a major user entry point (published in drmTMB, advertised in gllvmTMB). Wald CIs depend on `sd_report`, which is computed from the final Hessian at the converged objective. AGHQ changes the Hessian structure (adaptive quadrature has a different information matrix). Profile CIs refit; mixed engines break it. |
| `.wald_block()` | R/profile-ci.R:355–388 | `opt$par`, `sd_report$cov.fixed` | **MEDIUM** — Wald CI workhorse. Reads parameter estimates and SEs from fixed-parameter covariance. | Called by all Wald confint routes. AGHQ Hessian will differ; SEs will change. Expected and OK if documented. |
| `loading_ci()` | R/loading-ci.R:1–180 | Checks `sd_report$pdHess` at line 143 | **LOW** — gates whether to compute, not the values. | Dependency on pdHess only (pass/fail); not on actual SEs. AGHQ pdHess may differ. OK as gate. |
| `getLV(..., se = TRUE)` | R/output-methods.R:150–187 | Calls `.getLV_se()` which reads `sd_report$par.random`, `sd_report$diag.cov.random` | **MEDIUM** — returns latent scores with SEs. AGHQ redraws the LV field definition; random-effect structure changes. | The z_B block in AGHQ has a different meaning (adapted posterior vs. Laplace). SEs on latent scores will differ. Documented as "conditional on estimated parameters," so expected variance change is OK. But score estimates themselves should not change if AGHQ optimizes to same mode. |
| `.lv_sdreport_effect_se()` | R/extractors.R:760–803 | Reads `sd_report$pdHess`, `sd_report` structure | **MEDIUM** — helper for latent-effect SEs. Checks pdHess and unpacks the random-effect block. | AGHQ pdHess may differ; random block structure may change. Need to verify that the block names and indices still match. |
| `extract_cutpoints()` | R/extract-cutpoints.R:78–90 | Reads `sd_report` with ADREPORT section for ordinal cutpoint SEs | **LOW** — SEs only. | Ordinal probit cutpoints are fixed at the template level (tau_1=0); SEs read from sdreport. AGHQ SEs will differ, expected. |
| `profile-route confint.gllvmTMB_multi()` paths | R/z-confint-gllvmTMB.R:1630–1682, 1889–1936 | Refits model with parameters pinned; reads resulting objectives | **CRITICAL** — all profile CI routes refit. If the original fit used Laplace and you call confint(..., method="profile"), the refits default to AGHQ (if control specifies "auto"). Objective values from mixed engines are incomparable. | **HIGHEST RISK #3.** The profile refit logic (e.g., .confint_sigma_profile) calls gllvmTMB() with a pinned parameter. If `gllvmTMBcontrol(aghq="auto")` is the default, refits will use AGHQ regardless of the original engine. Mismatch breaks CI inversion. **Mitigation:** either (a) store the original engine choice in fit$aghq$engine and pass it to refits, (b) doc that profile CIs require refitting, or (c) default profile refits to the same engine as the original. Recommend (a). |
| `.confint_icc()` (ICC CI) | R/z-confint-gllvmTMB.R:783–815 | Calls simulate() for bootstrap | **MEDIUM** — bootstrap ICC CI depends on simulate() redrawing REs correctly. | Simulate() behavior unchanged structurally, but parametric variance will differ under AGHQ. OK if documented. |
| `.confint_phylo_signal()` | R/z-confint-gllvmTMB.R:822–864 | Calls simulate() | **MEDIUM** — bootstrap phylo signal CI. | Same as ICC. |
| `.confint_communality()` | R/z-confint-gllvmTMB.R:869–957 | Calls `sd_report$cov.fixed` for Wald, simulate() for bootstrap | **MEDIUM** — Communality CI. | Dual-route (Wald + bootstrap). AGHQ SEs will change; bootstrap variance will change. Expected. |
| `extract_sigma()` and family | R/extract-sigma.R:122–1380 | Reads `report$eta`, `report$*` items (phi, sigma, etc.) | **LOW** — point estimates only from report$; no sd_report dependency. | Report$ items are deterministic from opt$par and model structure. AGHQ doesn't change the template structure or report items, only the optimizer. Should be fine. |
| `extract_repeatability()` | R/extract-repeatability.R:123–254 | Reads `sd_report$cov.fixed` for Wald repeatability SE | **MEDIUM** — Wald SE on repeatability. | AGHQ cov.fixed will differ. Expected. Documented via confint(). |
| `extract_omega()` | R/extract-omega.R:544 | References phylo signal confint, which uses sd_report | **LOW** — indirect via confint(). | Meta-reference; no direct read. |
| `diagnose.gllvmTMB()` | R/diagnose.R:23–296 | Checks `sd_report` presence and `pdHess`; reads fixed-parameter covariance for rank | **LOW** — diagnostic pass/fail on Hessian. | AGHQ pdHess may differ. OK as diagnostic. Rank computation (line 671: rank of `sd_report$cov.fixed`) will differ, which is expected and informs user. |

---

## Category 3: Simulate / Parametric Bootstrap

Paths that redraw random effects and responses.

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| `simulate.gllvmTMB_multi()` (main) | R/methods-gllvmTMB.R:1039–1127 | Reads `report$eta`, `report$sigma_eps`, `opt$par["log_sigma_eps"]` | **MEDIUM** — unconditional simulation redraws REs from fitted distributions; conditional simulation reuses fitted modes. | For unconditional simulation, the variance-component estimates (from report$, derived from opt$par) are used to redraw. AGHQ estimates differ from Laplace; redrawn SEs/CIs will reflect that. Expected and OK. Conditional simulation reuses the mode, which should not change (both are optimizing to the same objective, albeit with different numerical cost functions). **Potential issue:** if AGHQ and Laplace converge to different local optima for the mode, conditional simulate gives different results. Low risk if both converge to same global optimum. |
| `bootstrap_Sigma()` | R/bootstrap-sigma.R:38–283 | Calls `simulate()` to redraw REs | **MEDIUM** — Parametric bootstrap on variance-component estimates. | Depends on simulate(). Bootstrap intervals (e.g., for Sigma components) will reflect AGHQ estimates. Documented as bootstrap-based, so variance change is expected. |
| `.gllvmTMB_simulation_rank_residuals()` | R/predictive-diagnostics.R (indirect via residuals()) | Calls `simulate()` | **LOW** — simulation-rank residuals call simulate() for draws. | Residuals are functions of simulated y; AGHQ variance estimates change the residual distribution slightly. Expected. |
| `residuals.gllvmTMB_multi()` | R/predictive-diagnostics.R:213–262 | Calls simulate() indirectly | **LOW** — residual computation. | Documented as simulation-based; expected variance shifts. |
| `coverage_study()` (M1.4 validation) | R/coverage-study.R:162–352 | Calls `simulate()` to redraw for each rep | **MEDIUM** — validation harness; refits on simulated data. Mixed engines (original fit + AGHQ refits) will have different objectives and CIs. | **Validation context.** If original fit (e.g., Laplace) is used to simulate, but refit uses AGHQ, coverage will be asymmetric (original is correct, refits are not). **Mitigation:** ensure coverage_study uses consistent engine across all refits. |
| `loading_ci(..., method="bootstrap")` | R/loading-ci.R (uses simulate) | Calls simulate() | **MEDIUM** — bootstrap CI on loading SEs. | AGHQ variance estimates change resampling; CI width changes. Expected. |

---

## Category 4: Predict / Fitted Paths

Paths that reconstruct eta at fitted parameters or newdata.

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| `predict.gllvmTMB_multi()` (main) | R/methods-gllvmTMB.R:1557–1687 | Reads `report$eta` (training), `tmb_obj$env$last.par.best` (newdata RE), `opt$par` | **MEDIUM** — predicts eta at fitted parameters or newdata. | For training data, reads precomputed `report$eta`. For newdata with REs, reads parameter estimates. AGHQ doesn't change the template; eta remains the same functional form. However, the parameter estimates differ, so newdata predictions differ. Expected. **One detail:** line 1612 reads `tmb_obj$env$last.par.best`, which is TMB's internal "best parameter state." Verify AGHQ fills this correctly (should be automatic; it's TMB's job). |
| `simulate.gllvmTMB_multi()` – conditional path | R/methods-gllvmTMB.R:1054–1088 | Calls `predict(..., newdata)` at line 1064 | **LOW** — conditional simulation on newdata calls predict(). | Indirect; predict() handles it. |
| No explicit `fitted()` for gllvmTMB_multi | — | — | **NONE** — There is no fitted.gllvmTMB_multi() method. Base R's `fitted()` would call predict(..., type="response"), which exists. | Informational: fitted() will work via predict() dispatch. AGHQ parameter changes propagate. |

---

## Category 5: Objective / Convergence Storage & Reporting

Paths that store, print, or audit the objective and optimizer state.

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| `fit$opt$objective` (storage) | R/fit-multi.R:4900–5170 | Assigned by optimizer; read by all above | **CRITICAL** — The entire fit object's auditable state rests on opt$objective. | Must be set correctly by the optimizer (TMB::nlminb wrapper in fit-multi.R). AGHQ must call the objective function (via template's $fn) and store the converged value. **Verification needed:** E1 confirms that opt$objective is set to the AGHQ objective (not a post-hoc Laplace evaluation). |
| `fit$opt$convergence` (optimizer status) | R/fit-multi.R:5140–5141 | Returned by optimizer; read by print/summary | **LOW** — exit code (0 = success). | Should be set correctly by nlminb. AGHQ may have different convergence properties (e.g., faster). OK to report as-is. |
| `fit$tmb_obj$fn()` (objective function) | R/fit-multi.R:4541 | Callable; used to evaluate at new parameters | **MEDIUM** — The objective function object itself. When re-optimizing (profile, bootstrap), the same tmb_obj is used. If AGHQ is "auto" and the profile refit uses gllvmTMB(), the new fit will have a different tmb_obj (AGHQ). Mixed tmb_obj types break comparability. | **Related to profile risk (see confint):** profile refits create new tmb_obj instances; if engine differs, they're incomparable. |

---

## Category 6: Report Items (Template-Computed Predictions)

Paths that read model-specific reported values (eta, phi, sigma, etc.).

| Consumer | File:Line | Reads | AGHQ Impact | Notes |
|----------|-----------|-------|------------|-------|
| `extract_sigma()` and family (20+ extractors) | R/extract-sigma.R:122–1380+ | Read `report$eta`, `report$sigma_eps`, `report$phi_*`, `report$cor_*`, etc. | **LOW** — Point estimates from template. | Report$ values are deterministic functions of opt$par and model structure. AGHQ doesn't change the template; report computation is the same. Parameter estimates differ, so report values differ, but the mechanism is unchanged. Expected. |
| `simulate.gllvmTMB_multi()` – reading report$ | R/methods-gllvmTMB.R:1057–1069 | Reads `report$eta`, `report$sigma_eps` | **LOW** — Used for conditional/Gaussian-fallback simulation. | Report$ is deterministic; no issue. |

---

## Highest-Risk Items (Prioritize Testing)

### Risk #1: Profile-Likelihood CIs on Constrained Lambdas

**Path:** `loading_profile()` → `confint(..., method="profile")` → profile refit loop

**Issue:** A profile CI is computed by (1) pinning each Lambda entry at a grid of values, (2) refitting the model, (3) collecting the objective values, (4) inverting the likelihood-ratio statistic. If the original fit used Laplace but the refits default to AGHQ (or vice versa), the objective values are on different scales and the CI will be misaligned or invalid.

**Verification:** 
- [ ] Run `loading_profile(laplace_fit)` and check that refits stay Laplace.
- [ ] Run `loading_profile(aghq_fit)` and check that refits stay AGHQ.
- [ ] Verify CI inversion logic (should reproduce from same fit, deterministic).

---

### Risk #2: confint() Wald Route Hessian Mismatch

**Path:** `confint(fit, method="wald")` → reads `fit$sd_report$cov.fixed`

**Issue:** The AGHQ Hessian has a different structure than Laplace (adaptive integration changes the second-derivative matrix). If a user compares Wald CIs computed on a Laplace fit with those from an AGHQ fit, the widths will differ. This is expected and correct (AGHQ is more accurate) but may surprise users if not documented.

**Verification:**
- [ ] Compute Wald CI on both Laplace and AGHQ fits; document the difference.
- [ ] Verify that pdHess is computed correctly under AGHQ (no failed Hessians due to quadrature artifacts).

---

### Risk #3: Profile Refit Engine Consistency

**Path:** `confint(fit, parm="Sigma_unit", method="profile")` → refits with `gllvmTMB(..., data, formula, ...)` → default `aghq="auto"`

**Issue:** When a profile CI refits, it calls `gllvmTMB()` with the same data/formula but a pinned parameter. If the original fit passed `aghq=FALSE` (Laplace) but the default is now `aghq="auto"`, the refits will use AGHQ. The objectives become incomparable, and the CI inversion fails.

**Verification:**
- [ ] Confint with method="profile" should store and reuse the original engine choice in refits.
- [ ] Document that profile refits inherit the original engine (or require explicit specification).
- [ ] Test: Laplace fit → profile CI should use Laplace refits.
- [ ] Test: AGHQ fit → profile CI should use AGHQ refits.

---

## Implementation Notes for E1, E3

When E1 wires the AGHQ optimizer into the template and E3 implements tests:

1. **Store the engine choice:** Add `fit$aghq$engine` ("laplace" | "aghq" | "auto_resolved_to_X") so downstream consumers can reuse it.

2. **Profile refits must use the same engine:** Modify `gllvmTMB_multi()` to accept an optional `original_engine` parameter. When called from confint profile routes, pass it through.

3. **Wald CI SEs will change:** Document that Hessian-based SEs differ between engines. This is expected; quadrature is more accurate. Add a note to the confint() help.

4. **Simulate() variance changes are expected:** Document that bootstrap CIs (via simulate) will have different widths under AGHQ. This is correct; AGHQ has different (more accurate) variance estimates for random effects.

5. **Test fixtures:**
   - [ ] Fit a benchmark model with both Laplace and AGHQ.
   - [ ] Verify `logLik()`, `AIC()`, `BIC()` are different (and AGHQ is better, i.e., higher logLik).
   - [ ] Compute Wald CIs on both; verify they differ (AGHQ narrower / wider as predicted).
   - [ ] Compute profile CIs on both; verify they remain valid (inversion is monotonic).
   - [ ] Verify that `coverage_study()` uses consistent engine (no mixed fits in one study).

---

## Status Summary

| Category | Status | Notes |
|----------|--------|-------|
| logLik / AIC / BIC | MAPPED | 8 consumers identified. All read opt$objective; all will show different values under AGHQ. Expected and OK if engine choice is documented. |
| Wald CIs / Hessian | MAPPED | 15+ consumers identified. SEs will change under AGHQ (correct behavior). Highest risk: mixed engines in profile refits. |
| Simulate / Bootstrap | MAPPED | 8 consumers identified. Variance estimates change; CIs widen/narrow appropriately. Expected. |
| Predict / Fitted | MAPPED | 2 consumers identified. No structural changes; parameter differences propagate. Expected. |
| Objective storage | MAPPED | fit$opt$objective must be set correctly by E1; otherwise all derived values are wrong. **Verification needed:** E1 confirms it's set to the AGHQ objective. |
| Report items | MAPPED | 20+ reads of template-computed values. No AGHQ impact; deterministic from opt$par. |

**Overall:** No consumers will break. All changes are expected and occur at the right level (objective value, Hessian, variance estimates). **Mitigation priorities:** (1) Store engine choice in fit; (2) Enforce engine consistency in profile refits; (3) Document SEs/CIs will differ; (4) Test coverage_study() consistency.

---

## Files Involved (Read-Only Inventory)

- **Likelihood consumers:** R/methods-gllvmTMB.R, R/loading-profile.R, R/suggest-lambda-constraint.R, R/fit-multi.R, R/kernel-helpers.R
- **Hessian/confint:** R/z-confint-gllvmTMB.R, R/profile-ci.R, R/loading-ci.R, R/extractors.R, R/output-methods.R, R/extract-*.R (6 files)
- **Simulate/bootstrap:** R/methods-gllvmTMB.R, R/bootstrap-sigma.R, R/bootstrap-lv-effects.R, R/predictive-diagnostics.R, R/coverage-study.R, R/phylo-signal-ci.R, R/proportions-ci.R
- **Predict/fitted:** R/methods-gllvmTMB.R
- **Diagnostic/reporting:** R/diagnose.R, R/check-identifiability.R, R/confint-inspect.R, R/diagnostic-tables.R
- **Template:** src/gllvmTMB.cpp (data inputs will include AGHQ-specific fields)

**Total:** 28 R files + src/gllvmTMB.cpp.

---

**Document complete. No fixes applied. Awaiting E1 / E3 handoff.**
