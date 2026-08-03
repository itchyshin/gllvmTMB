# Interval-route contracts for the VA lane (recon only)

Read-only recon. No files edited besides this one. All line numbers are against
`/private/tmp/gllvmtmb-va-lane2` at the commit checked out when this was written
(branch `claude/va-lane2`).

## 0. What a completed VA fit looks like (needed by every section below)

`.va_r3_fit()` (`R/va-r3-proto.R:2098` onward) returns a plain list, NOT an S3
object. The fields the other routes need:

- `fit$objective` -- `R/va-r3-proto.R:2444`: `objects[[best_id]]`, i.e. the
  actual `TMB::MakeADFun()` return value for the winning start (built inside
  `.va_r3_make_objective()`, see s4 below). It carries `$fn`, `$gr`, `$he`,
  `$par`, `$report()`, `$env`.
- `fit$best$par` -- `R/va-r3-proto.R:1391` (warm-start path) and the equivalent
  in the main path around `fits[[k]]` -- the full parameter vector at the
  optimum, NAMED (names include `"beta"`, `"theta_rr"`, `"m"`,
  `"log_L_diag"`, `"L_off"`, `"log_sd_tier"`, etc.), variational block
  included.
- `fit$best$objective` -- the scalar negative-ELBO value at the optimum
  (`stats::nlminb`'s `$objective`, or `stats::optim`'s `$value` renamed to
  match, `R/va-r3-proto.R:1533`).

The publicly-facing class is `c("gllvmTMB_va", "gllvmTMB")`
(`R/va-methods.R:3`), deliberately NOT `"gllvmTMB_multi"`. That single fact is
the mechanical blocker for sections 2 and 3 below, both of which gate on
`inherits(fit, "gllvmTMB_multi")`.

`confint.gllvmTMB_va` (`R/va-methods.R:184-190`) and `vcov.gllvmTMB_va`
(`R/va-methods.R:195-201`) both call `.va_not_defined()` and refuse
unconditionally, citing `calibrated = FALSE`. `logLik.gllvmTMB_va`
(`R/va-methods.R:173-179`) also refuses, citing "the objective is an ELBO (a
lower bound), not a log-likelihood." This is the fence this recon must not
weaken.

## 1. `.va_r3_fixed_information_blocked()` / `.va_r3_fixed_information()`

**Blocked route** -- `R/va-r3-proto.R:1624-1696`.

- Signature: `.va_r3_fixed_information_blocked(objective, par, N, q)`.
- `objective`: needs `$gr(p)` only (never calls `$he`). Built by
  `.va_r3_hessian_blocks()` (`R/va-r3-proto.R:1584-1619`), which differences
  the analytic gradient via central finite differences (`step = 1e-5`,
  `R/va-r3-proto.R:1585`) to assemble `H_ff` (fixed-fixed block) and the
  N per-unit k x k variational blocks, WITHOUT ever forming the dense
  Hessian -- comment at `R/va-r3-proto.R:1582-1583` gives the concrete saving
  (27,002^2 dense Hessian, ~5.8 GB, replaced by ~44 gradient evals).
- `par`: the named full parameter vector (`fit$best$par`). Fixed-block
  columns are identified by `names(par) %in% c("beta", "theta_rr")`
  (`R/va-r3-proto.R:1632`); the variational layout is recovered by
  `.va_r3_variational_index_map(nm, N, q)` (`R/va-r3-proto.R:1545-1568`,
  called at `:1635`), which assumes exactly the column-major
  `m` / `log_L_diag` / `L_off` layout and a SINGLE tier.
- `N`, `q`: passed in explicitly (not re-derived) by this entry point; the
  wrapper `.va_r3_fixed_information()` derives them for you (next bullet).
- Returns a list: `se_conditional` (naive block-diagonal SE, flagged
  "expected ANTI-CONSERVATIVE" at `R/va-r3-proto.R:1466-1471`-equivalent
  comment reproduced at `:1659-1660`/`:1803-1806`), `se_profile` (the Schur
  complement `H_ff - sum_i H_fv,i B_i^-1 H_fv,i'`, the one the package
  actually uses), `pd_hessian` (logical), `calibrated` (always `FALSE`),
  `route` (`"blocked"`), `status` (one of `"ok"`,
  `"va_singular_variational_block"`, `"va_non_pd_profile_information"`,
  `"va_non_pd_fixed_information_no_fixed_se"`, or an early-fail status --
  see next bullet), `basis` (free-text provenance string). Names of
  `se_conditional`/`se_profile` are `nm[fixed_idx]`, i.e. the `"beta"` /
  `"theta_rr"` parameter names in their original order.
- Status/singularity signalling (fail-closed, all at
  `R/va-r3-proto.R:1625-1645`): `.VA_R3_MULTI_TIER_SE_STATUS` if
  `attr(objective, "va_r3_tiers")$n_tiers > 1` (refuses rather than risk a
  wrong-partition Schur complement -- rationale at `:1698-1707`);
  `"va_unnamed_par_no_fixed_se"` if `par` has no names;
  `"va_no_fixed_block_no_fixed_se"` if no `beta`/`theta_rr` entries exist;
  `"va_variational_layout_unrecognised"` if the index map can't be built;
  `"va_hessian_error_no_fixed_se"` if `.va_r3_hessian_blocks()` throws.
  Mid-computation: `singular` flag set if any per-unit block solve fails
  (`R/va-r3-proto.R:1667`) -> `"va_singular_variational_block"`; non-PD
  Schur complement -> `"va_non_pd_profile_information"`.

**Dense route / single entry point** -- `.va_r3_fixed_information(objective,
par, route = c("auto","blocked","dense"), max_variational = NULL)`,
`R/va-r3-proto.R:1743-1849`.

- `route = "auto"` (default): multi-tier check first (`:1747-1758`, same
  refusal as above); else infers `N`/`q` from parameter-name COUNTS via
  `.va_r3_infer_dims(nm)` (`R/va-r3-proto.R:1722-1731`, valid for one tier
  only) and dispatches to the blocked route (`:1763-1764`).
- `route = "dense"`: skips the blocked dispatch, calls `objective$he(par)`
  directly (`R/va-r3-proto.R:1781`) to get the FULL joint Hessian, then slices
  `H_ff <- hessian[fixed_idx, fixed_idx]`, `H_fv`, `H_vv` and forms the Schur
  complement by direct `solve(H_vv, t(H_fv))` (`:1812-1814`). This is the
  comparator route only -- flagged platform-dependent in the tests (BLAS-
  sensitive Cholesky, see s1 below).
- `max_variational` is accepted and IGNORED
  (`R/va-r3-proto.R:1738-1741` comment: "kept because callers written against
  the old signature exist").
- Returns the same shape as the blocked route, PLUS a `calibration_evidence`
  string (`:1833-1839`) reporting a small empirical calibration check: "beta
  only, binomial-logit, q=2, p=8, n in {150,400}, 25 seeds ... se_profile
  covers 0.935-0.950 ... se_conditional under-covers ... Latent-score SDs are
  NOT calibrated. Nothing else is tested." -- i.e. this is evidence for ONE
  family/link/dimension combination, not a general certificate, and it is
  attached to the dense-route return value, not the blocked one.

**Existing dense-vs-blocked test**: YES.
`tests/testthat/test-va-r3-prototype.R:334-389`, "R3 blocked information
reproduces the dense Schur complement exactly". Calls both routes on the same
`fit$objective`/`fit$best$par` (binomial-logit, n=60, p=5, q=2) and asserts
agreement to 1e-8 relative -- but the comparison is GUARDED: dense route
success is BLAS-dependent (comment `:370-375`: "Observed passing on
macOS/Accelerate and failing on Linux CI at the same commit"), so the numeric
cross-check only runs `if (dense_available)`; the unconditional assertions are
about the blocked route alone. A second, simpler dense-vs-fail-closed test is
at `:292-332` ("R3 fixed-parameter information marginalises the variational
block") and a route-dispatch regression at `:1401-1409`.
`test-getlv-se.R` does NOT reference `.va_r3_fixed_information` at all
(checked via grep; only unrelated `getlv`-prefixed helpers appear there) --
NOT FOUND for that file; searched with
`grep -n "va_r3_fixed_information\|getlv" tests/testthat/test-getlv-se.R`.

## 2. `tmbprofile_wrapper()`

`R/profile-ci.R:355-431`.

- Signature: `tmbprofile_wrapper(fit, name = NULL, which = 1L, lincomb = NULL,
  level = 0.95, transform = identity, ystep = 0.5, ytol = NULL, parm.range =
  c(-Inf, Inf))`.
- Line 366-368: `if (!inherits(fit, "gllvmTMB_multi")) cli::cli_abort(...)`.
  This is an immediate, unconditional class gate.
- Needs from `fit`: `fit$opt$objective` (scalar MLE deviance/objective,
  `:372`), `fit$opt$par` (named vector, `:375/381/398`), and, critically,
  `fit$tmb_obj` (`:384`, `:401`) -- the actual TMB object passed straight into
  `TMB::tmbprofile(fit$tmb_obj, ...)`. It assumes `fit$tmb_obj$fn`/`$gr` behave
  like a NEGATIVE LOG-LIKELIHOOD: `.qchisq_threshold(level)` (`:369`) sizes a
  chi-squared(1) drop-in-deviance threshold, which is a Wilks'-theorem
  construction.
- Returns a length-3 named numeric vector `c(estimate=, lower=, upper=)` on
  the transformed scale, or `c(estimate=, lower=NA, upper=NA)` if
  `TMB::tmbprofile()` failed or returned fewer than 3 rows (`:417-419`).

**Mechanical fit (interface only).** A VA fit is a bare list, class
`c("gllvmTMB_va","gllvmTMB")` (s0 above), so:
  (a) the `inherits(fit, "gllvmTMB_multi")` guard at `:366-368` rejects it
      before anything else runs -- calling `tmbprofile_wrapper(va_fit, ...)`
      today errors immediately with "Provide a fit returned by `gllvmTMB()`.";
  (b) even past that guard, the VA fit object has no `$tmb_obj`, `$opt` -- it
      has `$objective` and `$best` instead (s0), different names entirely; a
      thin adapter (rename/repackage into the expected shape) would be
      needed, not zero-cost reuse. `TMB::tmbprofile()` itself is a generic
      TMB-object profiler and does not care what the objective represents --
      mechanically it would run against `fit$objective` (a real
      `MakeADFun()` object, s0/s4) once wrapped in a compatible shape.

**Statistical fit (separate question, NOT answered by the above).** The VA
objective is the negative ELBO, a BOUND on the negative log-likelihood, not
the log-likelihood itself (this is exactly why `logLik.gllvmTMB_va` refuses,
`R/va-methods.R:173-179`). `.qchisq_threshold`'s chi-squared(1) calibration is
derived from Wilks' theorem for genuine likelihood ratios; nothing in this
recon establishes (or refutes) that a drop-in-ELBO threshold has any
particular coverage. That is a calibration question for the measurement
campaign, not a plumbing question -- keep the two answers separate as
instructed.

## 3. `bootstrap_Sigma()`

`R/bootstrap-sigma.R:196-` (signature `:196-207`; guard `:208-210`).

- Signature: `bootstrap_Sigma(fit, n_boot = 999, level = c("unit","unit_obs",
  "phy","B","W"), what = c("Sigma","R","communality","ICC","cross_corr"),
  conf = 0.95, seed = NULL, n_cores = 1, progress = TRUE, keep_draws = FALSE,
  link_residual = c("auto","none"))`.
- `:208-210`: same `if (!inherits(fit, "gllvmTMB_multi")) cli::cli_abort(...)`
  gate as `tmbprofile_wrapper()` -- a VA fit is rejected immediately.
- What it resamples: draws `n_boot` replicate response matrices via
  `simulate.gllvmTMB_multi()` (documented `:154-158`, used around `:320-330`
  based on surrounding comments), then for EACH replicate calls
  `refit_one(b)` (`R/bootstrap-sigma.R:361-390`), which does
  `do.call(gllvmTMB, call_args)` at `:378` -- i.e. it refits through the
  PUBLIC, TOP-LEVEL `gllvmTMB()` entry point with `formula`, `data`, `trait`,
  `site`, `species`, `family`, plus forwarded auxiliary structure
  (`phylo_vcv`, `phylo_tree`, `mesh`, `lambda_constraint`, `:353-359`). There
  is no argument in `call_args` that selects a VA/tier route; the refit is
  whatever `gllvmTMB()`'s own `default_tier` resolves to, i.e. Laplace/GH per
  the standing fence (`R/integration-fence.R`, `default_tier = "gh"` --
  cited in the task, not re-verified here since this recon is scoped to the
  three routes named). A replicate is discarded (`na_fn(point_est)`,
  `:386-388`) if the refit errors, doesn't return class `"gllvmTMB_multi"`,
  or doesn't converge (`opt$convergence == 0`).
- Returns (per docstring `:140-150` and the `n_boot`/`coverage_ceiling`
  logic `:224-267`): a list carrying point estimates plus percentile CIs per
  requested `level`/`what` combination, `n_effective`/`n_failed` counts, and
  a `coverage_ceiling` field reporting the arithmetic best-case coverage
  `(n_boot - 1) / (n_boot + 1)` for the requested `n_boot`.
- Default replicate count: `n_boot = 999` (`:198`); a hard-floored minimum of
  `ceiling(2 / (1 - conf)) - 1` (39 at `conf = 0.95`, `:242`) below which it
  warns that percentile coverage cannot reach the requested level "whatever
  the data are."
- Can it operate on a VA fit? NO, on two independent grounds: (i) the class
  gate at `:208-210` rejects it outright; (ii) even bypassed, `refit_one()`
  is hardwired to `gllvmTMB()`'s standard (Laplace/GH) refit path (`:378`)
  with no VA branch -- it is Laplace-only by construction, not merely by the
  guard clause.

## 4. Obtaining the ELBO objective + Hessian for a completed VA fit

Confirmed call: `fit$objective` from a `.va_r3_fit()` result IS the
`TMB::MakeADFun()` object (assigned at `R/va-r3-proto.R:2444`:
`objective = if (!is.na(best_id)) objects[[best_id]] else NULL`, where each
`objects[[k]]` was built by `.va_r3_make_objective()`, `R/va-r3-proto.R:1891`
onward).

Inside `.va_r3_make_objective()`, the default (non-`profile_variational`)
branch (`R/va-r3-proto.R:2073-2082`) is:

```r
TMB::MakeADFun(
  data = tmb_data, parameters = parameters, map = map,
  random = NULL, DLL = dll$DLL, silent = silent
)
```

`random = NULL` is load-bearing: it means the returned object's `$he()` is
the Hessian of the FULL joint parameter vector (fixed block + variational
block together) with no Laplace marginalisation baked in -- confirmed by the
comment at `:2055-2063` ("reproduces the joint `random = NULL` objective byte
for byte") and by `.va_r3_fixed_information()`'s dense route calling
`objective$he(par)` directly and then slicing out `H_ff`/`H_fv`/`H_vv`
itself (`R/va-r3-proto.R:1781, 1800, 1812-1813`) rather than relying on any
TMB-side profiling. (The alternative `profile_variational = TRUE` branch,
`:2065-2072`, instead uses TMB's `profile=` argument to hand the variational
block to the inner Newton solver with the Laplace correction explicitly
disabled -- a different, exact-profile route not used by the fixed-
information helpers above.)

So the exact call sequence for a completed fit is:

```r
fit <- gllvmTMB:::.va_r3_fit(...)      # or gllvmTMB() with the VA tier, per fence
obj <- fit$objective                    # TMB::MakeADFun() object, random = NULL
obj$fn(fit$best$par)                    # negative ELBO value
obj$gr(fit$best$par)                    # gradient
obj$he(fit$best$par)                    # full joint Hessian of the negative ELBO
```

`.va_r3_fixed_information(fit$objective, fit$best$par)` (or the blocked
variant) is exactly this pattern, matching the calls verified in s1's tests
(`test-va-r3-prototype.R:307, 358-360`).

## 12-line summary of obstacles

1. Schur route (`.va_r3_fixed_information[_blocked]`, `R/va-r3-proto.R:1624,1743`):
   entry point already exists and is exercised on VA fits in the current
   suite (`test-va-r3-prototype.R:307,358-360`). Biggest obstacle: it is
   single-tier only (refuses on `n_tiers > 1`, `:1710-1712`) and its dense
   comparator is BLAS-dependent, not a VA-specific gap -- this route is
   closest to usable as-is.
2. Profile route (`tmbprofile_wrapper`, `R/profile-ci.R:355`): biggest
   obstacle is the hard `inherits(fit, "gllvmTMB_multi")` gate (`:366-368`)
   plus a `$tmb_obj`/`$opt` shape the VA fit list doesn't have (s0) --
   mechanically fixable with an adapter, but layered on top of the deeper,
   unresolved statistical question of whether a chi-squared(1) threshold
   calibrated for log-likelihood ratios means anything for an ELBO bound.
3. Bootstrap route (`bootstrap_Sigma`, `R/bootstrap-sigma.R:196`): biggest
   obstacle is structural, not a guard clause -- `refit_one()` is hardwired
   to call `gllvmTMB()` (`:378`), the standard Laplace/GH entry point, so
   even bypassing the `gllvmTMB_multi` class check (`:208-210`) leaves no VA
   refit path to reach; this route is Laplace-only by construction.
