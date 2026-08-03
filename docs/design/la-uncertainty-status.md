# Laplace-engine uncertainty surface: status (2026-08-03)

Integration/closer pass over the two gaps identified in
`docs/design/va-latent-uncertainty.md` and scoped by
`docs/design/la-uncertainty-recon.md`. This document is the durable record of
what is now exposed, what statistical kind of quantity it is, what is still
missing, and what has **not** been validated. Nothing here has been merged or
committed; the working tree carries the changes.

## What is now exposed

### `getREsd(fit, block = ...)` — R/re-uncertainty.R (new file, exported)

Standard errors for six random-effect blocks that previously had a point
estimate somewhere in the package but no uncertainty accessor:

| `block` | TMB parameter | Shape | Requires |
|---|---|---|---|
| `"diag_unit"` | `s_B` | `n_traits x n_sites` | `indep()`/`diag()` on the unit grouping |
| `"diag_unit_obs"` | `s_W` | `n_traits x n_site_species` | `indep()`/`diag()` on `unit_obs` |
| `"diag_species"` | `q_sp` | `n_traits x n_species` | `indep()`/`diag()` on the species grouping |
| `"phylo"` | `p_phy` | `n_species x n_traits` | `propto()` |
| `"re_int"` | `u_re_int` | named list, one vector per `(1\|group)` term | at least one bar term |
| `"equalto"` | `e_eq` | length-`n_obs` vector | `equalto()` / `meta_V()` |

Mechanism: identical to `getLV(se = TRUE)`'s existing `.getLV_se()` — read
`sqrt(pmax(sd_report$diag.cov.random[idx], 0))` at the block's index range in
`sd_report$par.random`, reshaped with the same column-major convention the
package's existing point-estimate readers for that block already use. No
refit, no extra `sdreport()` call: the fit's single production `sdreport()`
call (`R/fit-multi.R`) already ran over the full random vector, so every
block's marginal variance was already sitting in memory.

### `predict.gllvmTMB_multi(..., se.fit = TRUE)` — R/methods-gllvmTMB.R

New optional argument, default `FALSE`. When `TRUE`, adds an `se.fit` column
plus attributes `se.fit.scale` (`"link"`/`"response"`) and
`se.fit.conditional` (always `TRUE`). Computed as a **fixed-effect-only**
delta method: `eta_fix = X_fix %*% b_fix` is exactly linear in `b_fix`, every
random-effect contribution is held at its predicted (conditional-mode) value,
so `Var(eta) = X_free %*% cov.fixed %*% t(X_free)`, read straight from the
fit's existing `sd_report$cov.fixed` — again no extra `sdreport()` call.
`type = "response"` multiplies by the analytic `|d(inverse-link)/d(eta)|`
(new `.dlinkinv_per_row()`, mirroring the existing
`.apply_linkinv_per_row()` family/link dispatch).

Currently supported only for: `newdata = NULL` (training rows), non-
`multinomial()` fits, fits without an active `mi()` missing-covariate model,
and `REML = FALSE` fits. Each unsupported case raises a distinct classed
`cli_abort()` rather than a silently wrong number.

## What these numbers statistically are

Both accessors return a **Wald / `sdreport()`-derived, delta-method standard
error**. Neither is resampled, profiled, or simulation-based, and neither
carries a coverage guarantee — no coverage of intervals built from either
quantity has been measured anywhere in this pass or in prior work on this
codebase. Do not describe or advertise either as exact, and do not call a CI
built from them "certified" without a separate coverage measurement.

- **`getREsd()`** is a **marginal** quantity in the same sense
  `getLV(se = TRUE)` already is: `diag.cov.random` propagates fixed-effect
  uncertainty into the random-effect coordinate's own variance via TMB's
  generalized delta method, but it does **not** include cross-block or
  random-vs-fixed **covariance** (that needs
  `sdreport(getJointPrecision = TRUE)`, which the fit's one production
  `sdreport()` call does not request).
- **`predict(se.fit = TRUE)`** is explicitly **conditional**: it propagates
  *only* fixed-effect (`b_fix`) uncertainty and treats every random-effect
  contribution to `eta` as fixed at its conditional mode. This is smaller
  than a full marginal fitted-value SE would be, by construction — it is not
  a claim that random-effect uncertainty is negligible, only that it is not
  included yet (see "Still missing" below).

### A documented magnitude caveat for `getREsd()`

In a near-saturated or otherwise degenerate design (e.g. `indep()` at a
grouping where every group has exactly one observation, with the residual
variance auto-fixed near a boundary), the random effect deterministically
tracks the fixed-effect residual, so its delta-method SE can be one to two
orders of magnitude larger than the block's own conditional (GMRF-only)
variance would suggest — because it inherits almost all of the fixed
effect's own uncertainty. This is correct Wald behaviour, not a bug, but a
user should treat a surprisingly large `getREsd()` value as a cue to check
whether the corresponding variance component sits at or near a boundary,
not as evidence of a defect. Documented in `getREsd()`'s roxygen
(`R/re-uncertainty.R`, "What this is, and is not" section).

## Still missing

- **`getREsd()` block coverage.** Twelve-plus other random-effect
  blocks (`s_B_slope`, `s_W_slope`, `r_c2`/diagonal cluster2, `g_phy`,
  `g_phy_diag`, the SPDE spatial fields `omega_spde*`, the dense-kernel
  blocks `g_kernel*`, every augmented random-slope block, and the
  missing-predictor latent blocks `x_mis`/`u_mi_group`/`g_x`) are, in
  principle, reachable via the identical mechanism — the underlying
  `sdreport()` call already covers their marginal variances too — but their
  point-estimate reshape convention is not established anywhere else in the
  package (so the row/column order cannot be cross-checked against existing
  code), or their dimensions are not carried as top-level fields on the fit
  object. Not attempted here; `getREsd()` errors clearly
  (`gllvmTMB_getREsd_block_absent` / `match.arg` failure) rather than
  guessing a reshape.
- **`predict(se.fit = TRUE)` random-effect uncertainty.** Only the
  fixed-effect contribution to `Var(eta)` is propagated. Adding
  random-effect uncertainty needs the joint fixed+random precision
  (`TMB::sdreport(obj, getJointPrecision = TRUE)`), which the fit's
  production `sdreport()` call does not compute. This is a real, scoped-out
  piece of work, not an oversight: it needs either a second, more expensive
  `sdreport()` call plus a new Jacobian of `eta` w.r.t. the full parameter
  vector, or `ADREPORT(eta)` in `src/gllvmTMB.cpp` (a C++ engine change,
  outside this worktree's file scope).
- **`predict(se.fit = TRUE)` for `newdata`, `multinomial()`, and `mi()`
  fits.** Each is structurally different (no training-row `X_fix`; a
  per-row softmax rather than a single inverse link; masked/imputed cells
  whose linear predictor is not simply `X_fix %*% b_fix`) and is fenced off
  with a specific error rather than attempted.
- **`predict(se.fit = TRUE)` dispersion contribution.** The response-scale
  transform for `type = "response"` uses only the mean-function derivative;
  it does not add a dispersion-parameter contribution to the response-scale
  variance (matching how `.apply_linkinv_per_row()` already treats
  dispersion as a plug-in constant elsewhere in the package).

## What has NOT been validated

- **No coverage has been measured** for any interval built from either
  `getREsd()` or `predict(se.fit = TRUE)`, in this pass or previously. Every
  claim above is a **structural/numerical correctness** claim (right index,
  right reshape, right delta-method algebra), not a coverage claim.
- All fits used to check this work were tiny, local, single-seed smoke fits
  (N <= ~90 rows, gaussian or binomial, one seed each) — sufficient to check
  that the numbers are positive, finite, in a plausible range, and match an
  independent recomputation, but this is **not** simulation evidence and
  does not generalise to a claim about typical-case accuracy across the
  parameter space. Per repo policy (D-50), no multi-seed campaign was run;
  any such campaign belongs on Totoro/DRAC, not here.
- The `getREsd()` near-saturated-design magnitude behaviour (documented
  above) was observed in one constructed toy example; it has not been
  characterised across a range of designs.

## Independent cross-checks performed (structural, not coverage)

- **`getREsd()`**: for `diag_unit`, `diag_unit_obs`, and `phylo`, the
  reported SE was checked to be `>=` a numerically independent
  conditional-only SE obtained by inverting the raw Laplace GMRF Hessian
  (`obj$env$spHess(random = TRUE)`) — a different TMB code path from
  `sd_report$diag.cov.random`, since it omits fixed-effect-uncertainty
  propagation. This direction must always hold and would not hold if
  `getREsd()` were reading a plausible-looking wrong index.
- **`getREsd()` `"equalto"`**: checked against the known per-row sampling SD
  `sqrt(V)`; the returned SE sits below it everywhere, the expected Wald
  shrinkage direction for a known-covariance term with an estimated
  residual on top.
- **`predict(se.fit = TRUE)`**: on an intercept-only-per-trait design (no
  fixed-effect interaction, so each row's `X_fix` is an exact one-hot
  vector), `se.fit` was checked to be an **exact** (tolerance `1e-10`) match
  to `.gllvmTMB_b_fix_se()` — the pre-existing, independently coded
  accessor `summary.gllvmTMB_multi()` already uses in production, which
  reads through `summary(sd_report, "fixed")` rather than the manual
  `cov.fixed[idx, idx]` extraction `se.fit` uses.

## Regression / behaviour-unchanged evidence

- `getLV()`'s two call shapes (`se = FALSE` returns a bare matrix,
  `se = TRUE` returns `list(scores, se)`) are re-verified unchanged; `R/
  output-methods.R` was not edited by this work.
- `predict.gllvmTMB_multi()`'s pre-existing four arguments
  (`object, newdata, type, re_form`) are unchanged in position and default;
  `se.fit` is appended as a new argument defaulting to `FALSE`, and
  `identical(predict(fit), predict(fit, se.fit = FALSE))` is asserted in
  `tests/testthat/test-predict-se.R`.
- `NAMESPACE` diff is exactly one line, `export(getREsd)`; no other export
  changed.

## Defects found and fixed in this integration pass

1. **REML fits fell through to a misleading generic error.**
   `predict(fit_reml, se.fit = TRUE)` used to raise the generic
   `gllvmTMB_predict_se_block_mismatch` ("stale sd_report; refit and
   retry") instead of naming the real, deterministic cause (REML integrates
   `b_fix` into TMB's random vector, so it never appears in
   `sd_report$par.fixed`). Fixed: `.gllvmTMB_predict_se_guard()` now checks
   `object$REML` explicitly and raises
   `gllvmTMB_predict_se_reml_unsupported` with an accurate message and
   remedy.
2. **Three of six `getREsd()` blocks (`diag_unit_obs`, `phylo`, `equalto`)
   shipped with no committed regression test** — only smoke-tested in
   throwaway scripts, not in `tests/testthat/`. Fixed: added a `test_that()`
   block per block, each asserting positive/finite/plausibly-scaled output
   plus the independent cross-check described above.
3. **`getREsd()`'s roxygen did not warn about the near-saturated-design
   magnitude inflation** documented above. Fixed: added a paragraph to the
   "What this is, and is not" section.

Nothing was removed; both gaps' capabilities as built survived this pass,
with the fixes above.
