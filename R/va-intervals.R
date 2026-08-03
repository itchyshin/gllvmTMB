## VA interval routes -- internal, unexported, opt-in instruments for the
## coverage-measurement campaign (docs/design/va-interval-coverage-campaign.md).
##
## Nothing in this file is wired into `confint.gllvmTMB_va()` /
## `vcov.gllvmTMB_va()` (R/va-methods.R) and nothing here may ever be. Those
## stay hard-refused: "calibrated = FALSE: the inverse variational Hessian is
## not calibrated frequentist uncertainty, so no interval computed from it
## would have its nominal coverage." Everything below is reached only via
## `gllvmTMB:::.va_profile_ci()` / `gllvmTMB:::.va_wald_beta_ci()` /
## `gllvmTMB:::.va_wald_loadings_ci()` / `gllvmTMB:::.va_sandwich_beta_ci()` /
## `gllvmTMB:::.va_sandwich_loadings_ci()` /
## `gllvmTMB:::.va_bootstrap_beta_ci()` / `gllvmTMB:::.va_bootstrap_loadings_ci()`
## and exists so the coverage campaign has something to MEASURE, not
## something to trust in advance.

## ---------------------------------------------------------------------
## Route 2: profile-likelihood-style interval on the ELBO surface
## ---------------------------------------------------------------------
##
## MECHANICAL VERDICT: works. `TMB::tmbprofile()` is a generic profiler --
## it only calls `obj$fn()`/`obj$gr()` and reads/writes `obj$env$*`
## bookkeeping fields; it has no idea whether `obj$fn` computes a
## log-likelihood, a negative ELBO, or anything else. `fit$objective`
## (`.va_r3_fit()`'s `$objective`, or a public `gllvmTMB_va` fit's
## `$engine_result$objective`) is a genuine `TMB::MakeADFun()` object built
## with `random = NULL` (R/va-r3-proto.R ~2073-2082), so the whole joint
## parameter vector -- fixed block AND variational block together -- is
## "outer" as far as `tmbprofile()` is concerned. See
## docs/design/interval-routes-contracts.md s2 for the byte-level citations
## this comment summarises, and s0 for why `tmbprofile_wrapper()` itself
## (R/profile-ci.R) cannot just be called on a VA fit: it hard-gates on
## `inherits(fit, "gllvmTMB_multi")` and reads `fit$opt$par`/`fit$tmb_obj`,
## names a VA fit list does not have.
##
## STATISTICAL VERDICT: UNCALIBRATED, for two INDEPENDENT reasons -- either
## one alone would be enough to withhold trust:
##
##  1. The objective is the negative ELBO, a BOUND on the negative
##     log-likelihood, not the log-likelihood itself
##     (`logLik.gllvmTMB_va()` refuses for exactly this reason,
##     R/va-methods.R:173-179). `.qchisq_threshold()`'s chi-squared(1)/2
##     drop-in-deviance criterion is Wilks' theorem, a statement about
##     genuine likelihood ratios and their asymptotic curvature. Nothing
##     here establishes that a drop-in-ELBO threshold inherits that
##     distribution -- the ELBO/log-likelihood gap is exactly the quantity
##     that makes VA approximate in the first place, and the suspected
##     failure mode for every route in this campaign (see the task's
##     "UNIFYING POINT") is precisely that the ELBO's curvature need not
##     equal the log-likelihood's.
##  2. Even granting (1) away: this profile re-optimizes the ENTIRE
##     variational block (`m`, `log_L_diag`, `L_off`, ...) at every grid
##     point alongside every other fixed parameter, because `random = NULL`
##     puts them all in `tmbprofile()`'s "outer, profiled-out" set together.
##     That conflates the model's genuine nuisance parameters with the
##     variational family's own free parameters -- parameters that exist to
##     approximate a posterior, not to index the data-generating model.
##     Profile likelihood is licensed to profile out nuisance MODEL
##     parameters; there is no comparable licence here for profiling out
##     variational parameters as if they were.
##
## For these two reasons this route is built ONLY as a measurement
## instrument, never as a trusted interval. `calibrated` is hard-coded
## FALSE below -- exactly as `.va_r3_fixed_information()` hard-codes it for
## the Wald/Schur route (R/va-r3-proto.R); this is a repo-wide convention,
## not a one-off. Per the task brief's established facts: a sandwich (or a
## correctly-calibrated width, generally) fixes the VARIANCE, never the
## BIAS -- if VA's point estimate is attenuated, no amount of correctly
## calibrated interval width recentres it. This route's job is to let the
## campaign find out whether chi-squared(1)/2-on-the-ELBO happens to cover
## anyway, not to assert that it does.
##
## SCOPE RESTRICTION: `name` may only select a `"beta"` fixed-effect entry.
## `"theta_rr"` (loadings) entries are refused. Raw loadings are identified
## only up to rotation and sign (2026-06-19 FA rotation-convention
## decision; docs/design/70-missing-data-simulation-design.md), so a
## per-loading profile interval has no stable referent. The rotation-
## invariant alternative -- an entry of `Lambda %*% t(Lambda)` -- is a
## QUADRATIC function of `theta_rr`, not a linear one, and
## `TMB::tmbprofile()`'s `lincomb=` argument only supports LINEAR
## combinations of the parameter vector. That target is out of reach for
## this route as built, not merely deferred; profiling it would need a
## different mechanism entirely (e.g. a delta-method or simulation-based
## functional interval), which is out of scope here.

## Shared entry-point normaliser AND fail-closed health gate for every route
## in this file (profile, Wald/Schur, sandwich, and -- via
## .va_bootstrap_replicates()'s own call to this function -- the ORIGINAL fit
## a bootstrap resamples around). Centralising the gate here, rather than
## repeating it in each route, is deliberate: an adversarial review found
## that .va_profile_ci() and .va_bootstrap_replicates() would silently accept
## a fit whose own multi-start health gate (fit$status != "healthy", e.g.
## "failed_health_gate"/"failed_variance_domain", R/va-r3-proto.R:2388-2394)
## had NOT been cleared, and return a plausible-looking, indistinguishable
## interval. Every route funnels its `fit` argument through here first, so
## fixing it once fixes it everywhere.
##
## `fit$status` is only checked when present (a raw .va_r3_fit()/public
## gllvmTMB_va fit always carries it); a hand-built list without a $status
## field -- e.g. a test fixture -- is not refused on that basis alone, since
## absence of the field is not evidence of ill health.
.va_profile_normalize_fit <- function(fit) {
  raw <- if (!is.null(fit[["objective"]]) && !is.null(fit[["best"]])) {
    fit
  } else if (!is.null(fit[["engine_result"]][["objective"]]) &&
             !is.null(fit[["engine_result"]][["best"]])) {
    fit[["engine_result"]]
  } else {
    cli::cli_abort(
      "Not a recognised VA fit: need {.code $objective}/{.code $best} (raw
       .va_r3_fit() output) or {.code $engine_result$objective}/
       {.code $engine_result$best} (a public gllvmTMB_va fit)."
    )
  }
  if (!is.null(raw[["status"]]) && !identical(raw[["status"]], "healthy")) {
    cli::cli_abort(c(
      "{.arg fit}'s own multi-start health gate was not cleared (status:
       {.val {raw$status}}).",
      "x" = "Refusing to build an interval instrument around a fit that is
             not itself admitted -- the interval would look exactly like one
             built on a healthy fit, with nothing to flag the difference.",
      "i" = "Re-fit with a wider {.arg n_starts} (or diagnose the
             non-convergence) before requesting an interval."
    ))
  }
  raw
}

#' Profile-likelihood-style interval on a VA fit's ELBO surface (uncalibrated)
#'
#' @description
#' Points `TMB::tmbprofile()` at the negative-ELBO objective of a completed
#' `.va_r3_fit()` (or public `gllvmTMB_va`) fit and locates where the
#' drop-in-objective trace crosses the chi-squared(1)/2 threshold used
#' elsewhere in this package for genuine profile likelihoods
#' (`.qchisq_threshold()`, R/profile-ci.R). Mechanically this works because
#' `tmbprofile()` is generic over what `obj$fn` computes. Statistically it
#' is NOT validated -- see the file-level comment above for the two
#' independent reasons this is uncalibrated, and
#' `docs/design/va-interval-coverage-campaign.md` for the measurement plan
#' that is supposed to settle whether it covers anyway.
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit
#'   (`gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))`).
#' @param name Character; must name a `"beta"` entry of `fit$best$par`.
#'   `"theta_rr"` (loadings) entries are refused -- see "Scope restriction"
#'   above. `"beta"` entries repeat the same name once per trait (TMB
#'   vector-parameter convention), so `which` (below) selects among them.
#' @param which Integer; which occurrence of `name` to profile when the name
#'   is not unique (`fit$best$par` typically has one `"beta"` entry per
#'   trait, all literally named `"beta"`). Defaults to the first. Mirrors
#'   `.resolve_param_index()`'s `which` in R/profile-ci.R.
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only: this is
#'   the level `.qchisq_threshold()` is asked to target, not a coverage
#'   guarantee. See the campaign doc for whether it is achieved.
#' @param ystep,ytol,parm.range,transform Passed straight through to the
#'   same-named arguments of `tmbprofile_wrapper()` / `TMB::tmbprofile()`;
#'   see R/profile-ci.R for their meaning. `ytol` defaults to
#'   `.profile_ytol(level)` when `NULL`, matching the LA-route convention.
#'
#' @return A list:
#'   \describe{
#'     \item{estimate, lower, upper}{Transformed-scale profile interval, or
#'       `lower`/`upper = NA_real_` on profile failure -- same convention as
#'       `tmbprofile_wrapper()`.}
#'     \item{level}{The requested nominal level (echoed back, not verified).}
#'     \item{calibrated}{Always `FALSE`. Read the file-level comment before
#'       ever changing this.}
#'     \item{route}{`"va_elbo_profile"`.}
#'     \item{basis}{Free-text provenance string.}
#'   }
#'
#' @keywords internal
#' @noRd
.va_profile_ci <- function(
  fit,
  name,
  which = 1L,
  level = 0.95,
  ystep = 0.5,
  ytol = NULL,
  parm.range = c(-Inf, Inf),
  transform = identity
) {
  raw <- .va_profile_normalize_fit(fit)
  obj <- raw$objective
  best_par <- raw$best$par
  best_val <- raw$best$objective

  if (is.null(obj) || is.null(obj$fn) || is.null(obj$gr)) {
    cli::cli_abort("{.arg fit} has no usable ELBO objective ({.code $objective}).")
  }
  if (is.null(best_par) || is.null(names(best_par))) {
    cli::cli_abort("{.arg fit} has no named {.code $best$par}.")
  }
  if (!is.numeric(best_val) || length(best_val) != 1L || !is.finite(best_val)) {
    cli::cli_abort("{.arg fit} has no finite {.code $best$objective}.")
  }
  if (!is.character(name) || length(name) != 1L) {
    cli::cli_abort("{.arg name} must be a single character string.")
  }
  if (.va_r3_multi_tier(obj)) {
    cli::cli_abort(
      "{.fn .va_profile_ci} refuses on a multi-tier objective (unverified
       for that layout); matches the Wald/Schur route's fail-closed
       convention ({.fn .va_r3_multi_tier}, R/va-r3-proto.R)."
    )
  }

  nm <- names(best_par)
  hits <- which(nm == name)
  if (length(hits) == 0L) {
    cli::cli_abort(c(
      "Parameter {.val {name}} not found in {.code fit$best$par}.",
      "i" = "Available names: {.val {unique(nm)}}."
    ))
  }
  which <- as.integer(which)
  if (which < 1L || which > length(hits)) {
    cli::cli_abort(c(
      "{.arg which} = {which} out of range for {.val {name}}.",
      "i" = "There are {length(hits)} entries named {.val {name}}."
    ))
  }
  idx <- hits[which]
  if (nm[idx] != "beta") {
    cli::cli_abort(c(
      "{.fn .va_profile_ci} only profiles {.val beta} (fixed-effect) entries.",
      "x" = "{.val {name}} is a {.val {nm[idx]}} entry.",
      "i" = "Raw loadings ({.val theta_rr}) are identified only up to
             rotation and sign; a per-loading profile interval has no
             stable referent. See the file-level comment in
             R/va-intervals.R."
    ))
  }

  if (is.null(ytol)) ytol <- .profile_ytol(level)
  crit <- .qchisq_threshold(level)
  mle_par <- as.numeric(best_par[idx])

  ## Anchor tmbprofile()'s starting point at the optimum WE found.
  ## tmbprofile() reads obj$env$last.par.best, which MakeADFun() updates as
  ## a side effect of $fn() calls made during optimization -- it should
  ## already equal best_par, but this call makes that an explicit
  ## precondition rather than an assumption about optimizer internals.
  obj$fn(best_par)

  prof <- tryCatch(
    TMB::tmbprofile(
      obj,
      name = idx,
      ystep = ystep,
      ytol = ytol,
      parm.range = parm.range,
      trace = FALSE
    ),
    error = function(e) {
      cli::cli_warn("tmbprofile() failed for {.val {name}}: {conditionMessage(e)}")
      NULL
    }
  )

  if (is.null(prof) || nrow(prof) < 3L) {
    return(list(
      estimate = transform(mle_par), lower = NA_real_, upper = NA_real_,
      level = level, calibrated = FALSE, route = "va_elbo_profile",
      basis = "tmbprofile() failed or returned <3 rows; see warning."
    ))
  }

  bounds <- .profile_bounds(prof, mle_val = best_val, mle_par = mle_par, crit = crit)

  list(
    estimate = transform(mle_par),
    lower = if (is.na(bounds$lower)) NA_real_ else transform(bounds$lower),
    upper = if (is.na(bounds$upper)) NA_real_ else transform(bounds$upper),
    level = level,
    calibrated = FALSE,
    route = "va_elbo_profile",
    basis = paste0(
      "drop-in-negative-ELBO profile, chi-squared(1)/2 threshold at level=",
      level, "; UNCALIBRATED (bound, not likelihood; variational block ",
      "profiled out alongside beta) -- diagnostic instrument only, see ",
      "file-level comment in R/va-intervals.R."
    )
  )
}

## ---------------------------------------------------------------------
## Route 1: Wald interval from the Schur-complement observed information
## ---------------------------------------------------------------------
##
## This is gllvmTMB's apples-to-apples arm against what gllvm ships.
## `.va_r3_fixed_information_blocked()` (R/va-r3-proto.R) computes the Schur
## complement H_ff - H_fv H_vv^-1 H_vf -- the observed information for the
## fixed block (beta, theta_rr) with the variational block profiled out --
## and gllvm::se.gllvm() computes algebraically the SAME quantity
## (`I <- A.mat - B.mat %*% solve(D.mat, t(B.mat))`). On a real fit the two
## reproduce each other's numbers to 4-6 significant figures
## (docs/design/schur-equivalence-check.md); the residual disagreement is
## fully explained by the two optimisers landing at very slightly different
## points on the same objective, not by any difference in the SE formula.
##
## STATISTICAL VERDICT: this route ASSUMES the information matrix equality --
## that the ELBO's curvature equals the log-likelihood's curvature. That is
## exactly the assumption suspected to fail for a variational bound (see the
## task brief's "UNIFYING POINT" and `docs/design/interval-routes-contracts.md`),
## and it is NOT verified here. `calibrated` is hard-coded FALSE below, the
## same repo-wide convention `.va_r3_fixed_information()` and `.va_profile_ci()`
## both follow. A Wald interval built from a correctly-scaled covariance still
## fixes only the VARIANCE, never the BIAS: VA is documented to attenuate
## point estimates on discrete data, and an interval centred on a biased
## estimate need not cover regardless of width. Nothing here corrects that.
##
## SCOPE: two targets are covered, deliberately NOT raw loadings.
##  * `.va_wald_beta_ci()` -- the fixed-effect (beta) block directly; betas
##    are ordinary regression coefficients with no identifiability ambiguity,
##    so a per-coefficient Wald interval is a sound target on its face
##    (modulo the IM-equality assumption above).
##  * `.va_wald_loadings_ci()` -- entries of the ROTATION-INVARIANT
##    Sigma = Lambda %*% t(Lambda), not raw theta_rr/Lambda entries. Raw
##    loadings are identified only up to rotation and sign (2026-06-19 FA
##    rotation-convention decision; docs/design/70-missing-data-simulation-design.md),
##    so a CI on a raw loading has no stable referent across refits, seeds,
##    or optimiser starts. Sigma is rotation invariant -- for any orthogonal
##    Q, (Lambda Q)(Lambda Q)^T = Lambda Lambda^T -- so its entries are
##    estimable functionals with a fixed referent, and are the standard
##    invariant target for factor-analytic loadings. The interval is built by
##    the delta method, propagating the theta_rr covariance sub-block through
##    the (quadratic) map theta_rr -> Sigma.

## Full (not diagonal-only) covariance matrix for the FIXED block (beta,
## theta_rr), via the same block-diagonal Schur complement as
## `.va_r3_fixed_information_blocked()` (R/va-r3-proto.R).
##
## WHY THIS DUPLICATES THAT FUNCTION'S SCHUR MATH RATHER THAN CALLING IT:
## `.va_r3_fixed_information_blocked()` deliberately returns only SEs (the
## diagonal of the inverse information) -- the right contract for
## per-parameter reporting, but the loadings' delta-method target below needs
## the OFF-diagonal covariances between theta_rr entries, which the SE-only
## function discards. This is the smallest additive way to get them without
## changing that function's contract or its existing callers/tests.
##
## Returns list(covariance =, names =, pd =, status =). `covariance` is NULL
## on any failure (multi-tier, singular variational block, non-PD
## information, ...) -- fails closed, never returns a matrix it cannot
## justify. `names` is the fixed-block parameter-name vector aligned
## positionally with `covariance`'s rows/columns (values repeat, e.g.
## "beta", "beta", ..., "theta_rr", "theta_rr", ...; index into it
## positionally -- duplicate names make name-based subsetting unsafe).
##
## @keywords internal
## @noRd
.va_r3_schur_fixed_covariance <- function(objective, par, N, q) {
  fail <- function(status) {
    list(covariance = NULL, names = NULL, pd = FALSE, status = status)
  }
  if (.va_r3_multi_tier(objective)) return(fail(.VA_R3_MULTI_TIER_SE_STATUS))
  nm <- names(par)
  if (is.null(nm)) return(fail("va_unnamed_par_no_fixed_se"))
  fixed_idx <- which(nm %in% c("beta", "theta_rr"))
  if (!length(fixed_idx)) return(fail("va_no_fixed_block_no_fixed_se"))

  index_map <- tryCatch(.va_r3_variational_index_map(nm, N, q),
                        error = function(e) NULL)
  if (is.null(index_map) || !ncol(index_map)) {
    return(fail("va_variational_layout_unrecognised"))
  }

  parts <- tryCatch(
    .va_r3_hessian_blocks(objective, par, fixed_idx, index_map),
    error = function(e) NULL
  )
  if (is.null(parts)) return(fail("va_hessian_error_no_fixed_se"))

  correction <- matrix(0, parts$n_fixed, parts$n_fixed)
  for (i in seq_len(parts$N)) {
    H_fv_i <- parts$fixed_columns[index_map[i, ], , drop = FALSE]
    solved <- tryCatch(solve(parts$blocks[, , i], H_fv_i), error = function(e) NULL)
    if (is.null(solved)) return(fail("va_singular_variational_block"))
    correction <- correction + crossprod(H_fv_i, solved)
  }
  schur <- parts$H_ff - correction
  schur <- (schur + t(schur)) / 2

  pd <- tryCatch({ chol(schur); TRUE }, error = function(e) FALSE)
  if (!pd) return(fail("va_non_pd_profile_information"))
  covariance <- tryCatch(solve(schur), error = function(e) NULL)
  if (is.null(covariance) || any(!is.finite(covariance))) {
    return(fail("va_non_pd_profile_information"))
  }
  dimnames(covariance) <- list(nm[fixed_idx], nm[fixed_idx])
  list(covariance = covariance, names = nm[fixed_idx], pd = TRUE, status = "ok")
}

#' Wald interval for the beta (fixed-effect) block from the Schur-complement
#' observed information of the negative ELBO (uncalibrated)
#'
#' @description
#' `gllvmTMB`'s apples-to-apples comparator against `gllvm::se.gllvm()`: both
#' invert the SAME Schur complement H_ff - H_fv H_vv^-1 H_vf (confirmed to
#' reproduce the same numbers to 4-6 significant figures on a real fit, see
#' `docs/design/schur-equivalence-check.md`). Statistically UNCALIBRATED --
#' see the file-level "Route 1" comment above for why -- built as a
#' measurement instrument for the coverage campaign, not a trusted interval.
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit
#'   (`gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))`).
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only.
#'
#' @return A data.frame, one row per beta coefficient, with columns `term`,
#'   `estimate`, `se`, `lower`, `upper`, `level`, `route`, `status`,
#'   `calibrated` (always `FALSE`). `route`/`status` are carried over from
#'   `.va_r3_fixed_information_blocked()` so a caller can see exactly which
#'   computation produced the number.
#'
#' @keywords internal
#' @noRd
.va_wald_beta_ci <- function(fit, level = 0.95) {
  raw <- .va_profile_normalize_fit(fit)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  par <- raw$best$par
  nm <- names(par)
  if (is.null(nm)) {
    cli::cli_abort("{.code fit$best$par} must carry TMB parameter names.")
  }
  dims <- .va_r3_infer_dims(nm)
  if (is.null(dims)) {
    cli::cli_abort(
      "Could not infer N, q from {.code fit$best$par}'s layout
       (single-tier fits only)."
    )
  }

  info <- .va_r3_fixed_information_blocked(raw$objective, par,
                                           N = dims$N, q = dims$q)
  if (is.null(info$se_profile)) {
    cli::cli_abort(
      "Schur-complement information is not usable (status:
       {.val {info$status}}); no Wald interval can be formed."
    )
  }

  beta_names <- nm[nm == "beta"]
  se <- unname(info$se_profile[names(info$se_profile) == "beta"])
  if (length(se) != length(beta_names)) {
    cli::cli_abort(
      "Recovered beta SEs do not match the beta block length; refusing to
       guess an alignment."
    )
  }
  est <- unname(par[nm == "beta"])
  z <- stats::qnorm(1 - (1 - level) / 2)

  data.frame(
    term = beta_names,
    estimate = est,
    se = se,
    lower = est - z * se,
    upper = est + z * se,
    level = level,
    route = info$route,
    status = info$status,
    calibrated = info$calibrated,
    stringsAsFactors = FALSE
  )
}

## Recover T (number of traits) from the packed length of theta_rr and q,
## using `.va_r3_theta_length(T, q) = T*q - q*(q-1)/2` inverted:
## T = (length(theta_rr) + q*(q-1)/2) / q. Errors rather than rounding if the
## result is not an exact integer -- that means q or the packed length is
## wrong, not that T is fractional.
##
## @keywords internal
## @noRd
.va_r3_infer_T_from_theta_rr <- function(theta_rr_length, q) {
  q <- as.integer(q)
  T_raw <- (theta_rr_length + q * (q - 1L) / 2L) / q
  T_int <- as.integer(round(T_raw))
  if (abs(T_int - T_raw) > 1e-8 ||
      .va_r3_theta_length(T_int, q) != theta_rr_length) {
    cli::cli_abort("Could not recover an integer T from theta_rr's length and q.")
  }
  T_int
}

#' Delta-method Wald interval for entries of Lambda %*% t(Lambda) (uncalibrated)
#'
#' @description
#' Interval for the ROTATION-INVARIANT target `Sigma = Lambda %*% t(Lambda)`,
#' propagated by the delta method from the Schur-complement covariance of
#' `theta_rr` (the packed, non-identified loadings) -- NOT an interval on raw
#' loadings, which have no stable referent (identified only up to rotation
#' and sign). See the file-level "Route 1" comment above for the full
#' rationale. Statistically UNCALIBRATED for the same reasons
#' `.va_wald_beta_ci()` is, PLUS the delta method's first-order local-
#' linearity assumption, which degrades near a rotation/reflection ambiguity
#' or a near-zero loading.
#'
#' Because `.va_r3_unpack_theta_rr()` places each element of `theta_rr` into
#' `Lambda` by pure placement (no arithmetic), the Jacobian
#' `d Lambda[t, k] / d theta_rr[i]` is 0/1: calling
#' `.va_r3_unpack_theta_rr(seq_len(length(theta_rr)), T, q)` returns exactly
#' that position map (a `0` entry marks a structural zero -- the strict upper
#' triangle, not a free parameter -- since real positions are 1-indexed), so
#' the gradient of `Sigma[t1, t2]` is closed-form: no numerical
#' differentiation beyond the delta method's own linearisation.
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit.
#' @param T Number of traits. Optional -- inferred from `theta_rr`'s length
#'   and `q` via `.va_r3_infer_T_from_theta_rr()` when `NULL`; pass it
#'   explicitly to get an error instead of a silent mismatch if your own
#'   bookkeeping disagrees.
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only.
#'
#' @return A data.frame, one row per `(row <= col)` entry of `Sigma`, with
#'   columns `row`, `col`, `estimate`, `se`, `lower`, `upper`, `level`,
#'   `route` (`"blocked_schur_delta_method"`), `calibrated` (always `FALSE`).
#'
#' @keywords internal
#' @noRd
.va_wald_loadings_ci <- function(fit, T = NULL, level = 0.95) {
  raw <- .va_profile_normalize_fit(fit)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  par <- raw$best$par
  nm <- names(par)
  if (is.null(nm)) {
    cli::cli_abort("{.code fit$best$par} must carry TMB parameter names.")
  }
  dims <- .va_r3_infer_dims(nm)
  if (is.null(dims)) {
    cli::cli_abort(
      "Could not infer N, q from {.code fit$best$par}'s layout
       (single-tier fits only)."
    )
  }
  q <- dims$q
  theta_rr <- unname(par[nm == "theta_rr"])
  if (!length(theta_rr)) {
    cli::cli_abort("{.code fit$best$par} has no {.val theta_rr} block.")
  }

  if (is.null(T)) {
    T <- .va_r3_infer_T_from_theta_rr(length(theta_rr), q)
  } else {
    T <- as.integer(T)
    if (.va_r3_theta_length(T, q) != length(theta_rr)) {
      cli::cli_abort("Supplied {.arg T} is inconsistent with theta_rr's length and q.")
    }
  }

  Lambda <- .va_r3_unpack_theta_rr(theta_rr, T, q)
  ## 0 marks a structural zero (strict upper triangle): not a free
  ## parameter, contributes no gradient.
  pos <- .va_r3_unpack_theta_rr(seq_len(length(theta_rr)), T, q)

  cov_full <- .va_r3_schur_fixed_covariance(raw$objective, par,
                                            N = dims$N, q = q)
  if (is.null(cov_full$covariance)) {
    cli::cli_abort(
      "Schur-complement covariance is not usable (status:
       {.val {cov_full$status}}); no delta-method interval can be formed."
    )
  }
  theta_idx <- which(cov_full$names == "theta_rr")
  if (length(theta_idx) != length(theta_rr)) {
    cli::cli_abort(
      "theta_rr covariance sub-block does not match theta_rr's length;
       refusing to guess an alignment."
    )
  }
  cov_theta <- cov_full$covariance[theta_idx, theta_idx, drop = FALSE]

  z <- stats::qnorm(1 - (1 - level) / 2)
  upper_incl <- upper.tri(matrix(0, T, T), diag = TRUE)
  pair_idx <- which(upper_incl, arr.ind = TRUE)

  rows_out <- vector("list", nrow(pair_idx))
  for (i in seq_len(nrow(pair_idx))) {
    t1 <- pair_idx[i, "row"]; t2 <- pair_idx[i, "col"]
    g <- numeric(length(theta_rr))
    for (k in seq_len(q)) {
      i1 <- pos[t1, k]; i2 <- pos[t2, k]
      if (i1 > 0) g[i1] <- g[i1] + Lambda[t2, k]
      if (i2 > 0) g[i2] <- g[i2] + Lambda[t1, k]
    }
    est <- sum(Lambda[t1, ] * Lambda[t2, ])
    var_est <- as.numeric(t(g) %*% cov_theta %*% g)
    se <- if (is.finite(var_est) && var_est >= 0) sqrt(var_est) else NA_real_
    rows_out[[i]] <- data.frame(
      row = t1, col = t2, estimate = est, se = se,
      lower = est - z * se, upper = est + z * se
    )
  }
  result <- do.call(rbind, rows_out)
  result$level <- level
  result$route <- "blocked_schur_delta_method"
  result$calibrated <- FALSE
  result
}

## ---------------------------------------------------------------------
## Route 3: parametric bootstrap (simulate-then-refit)
## ---------------------------------------------------------------------
##
## The other routes all start from the negative-ELBO objective's curvature at
## the fitted optimum (or, for the sandwich route, an empirical variant of
## it), so they inherit some version of the same open question: does the
## ELBO's curvature stand in for the log-likelihood's (the information-matrix
## equality)? This route asks neither question -- it never differentiates the
## objective at all. Instead it (1) draws fresh unit-level latent scores from
## the fitted model's assumed N(0, I_q) prior, (2) forms a new response
## vector through the FITTED beta/Lambda and the ORIGINAL, fixed design (X,
## unit_id, trait_id, n_trials), (3) refits the whole `.va_r3_fit()`
## objective from scratch on that simulated response, and (4) repeats
## `n_boot` times to build percentile intervals. Its assumption is the
## ordinary parametric-bootstrap one -- that the fitted generative model is a
## correctly specified stand-in for the true data-generating process -- which
## is a DIFFERENT thing to get wrong than the information-matrix equality,
## not a weaker or stronger version of the same worry.
##
## `bootstrap_Sigma()` (R/bootstrap-sigma.R) is the Laplace-route precedent
## for exactly this design; it cannot be reused directly here for two
## independent reasons: (a) it hard-gates on `inherits(fit, "gllvmTMB_multi")`,
## which no VA fit satisfies (VA fits are `c("gllvmTMB_va", "gllvmTMB")`,
## Design 85 s10), and (b) its `refit_one()` is hardwired to
## `do.call(gllvmTMB, ...)` -- the ordinary Laplace/GH formula entry point --
## and there is no `simulate.gllvmTMB_va()` method anywhere in the package
## (confirmed absent by grep) for it to draw from even if the class gate were
## lifted. Building a VA-native simulator (`.va_bootstrap_simulate_one()`
## below) is therefore the actual first step, not a detail.
##
## COST, NOT A SHORTCUT: the task brief is explicit that bootstrap's
## advantage over the curvature-based routes is that it "costs compute
## instead" of making a curvature/calibration assumption. Every replicate
## here is a FULL `.va_r3_fit()` refit. `n_boot` therefore stays a small
## default (49) and `n_starts` per replicate defaults to a single start (see
## caveats below) -- this file builds the instrument the coverage campaign is
## meant to run at scale on Totoro/DRAC, not something to run large locally.
##
## SCOPE, same restriction as Route 1: rotation-invariant `Sigma = Lambda %*%
## t(Lambda)` entries, not raw `theta_rr`/loadings entries. Unlike Route 1's
## delta method, the bootstrap does not even need Sigma's invariance argued
## through a Jacobian -- Sigma is invariant to any orthogonal rotation Q of
## the latent scores ((Lambda Q)(Lambda Q)^T = Lambda Lambda^T) by
## construction, so every replicate's Sigma is directly comparable to every
## other's with no alignment step, however differently its optimiser happened
## to rotate that replicate's Lambda. A raw loading entry has no such
## guarantee and is not bootstrapped here.
##
## WHAT THIS DOES NOT GUARANTEE (read before trusting a number this returns):
##  * Not calibrated. `calibrated` is hard-coded FALSE below, the same
##    repo-wide convention every other route in this file follows. Nothing
##    here has been measured against a known truth; it is an instrument for
##    the coverage campaign to MEASURE, not a certified interval.
##  * Does not fix bias. A bootstrap resamples variability AROUND the fitted
##    point estimate. If VA's point estimate is attenuated -- the documented
##    weakness for discrete-response families named in the task brief -- the
##    interval is centred on that attenuation and will not cover the true
##    parameter at nominal frequency however well its WIDTH is calibrated.
##  * Correct-model assumption. Each replicate response is drawn under the
##    FITTED family/link/design/prior, not the true DGP. If the fitted model
##    is misspecified, the bootstrap faithfully propagates that
##    misspecification into every replicate rather than detecting it.
##  * The ORIGINAL fit's own health gate (`status == "healthy"`) IS enforced,
##    via `.va_profile_normalize_fit()` (the shared entry point every route in
##    this file funnels `fit` through) -- an earlier version of this function
##    silently bootstrapped around a fit whose multi-start health gate had
##    failed (adversarial review finding), with no field in the output to
##    flag it. What is NOT the same claim: per-replicate refits below.
##  * Per-replicate refits are cheap, not robust. The original fit's own
##    health gate requires >= 3 healthy multi-starts in mutual agreement
##    (R/va-r3-proto.R); refitting every bootstrap replicate to that standard
##    would multiply the cost `n_boot`-fold. `n_starts` here defaults to a
##    single start per replicate, so a replicate landing in a different local
##    optimum from the kind the original fit's health gate selects for is
##    caught only if the optimiser happens to report a non-zero `convergence`
##    code -- a necessary, not sufficient, check. Widen `n_starts` (and
##    re-examine `n_failed`) for anything beyond a mechanical smoke test.
##  * Percentile CIs are only first-order accurate, and B draws cannot exceed
##    `(B-1)/(B+1)` coverage whatever the data are -- the same arithmetic
##    floor `bootstrap_Sigma()` documents, reproduced below as
##    `coverage_ceiling`.
##  * Family coverage. Only binomial-logit, binomial_probit-probit, and
##    poisson-log have a simulator implemented
##    (`.va_bootstrap_simulate_one()`); any other admitted family/link aborts
##    rather than silently reusing the wrong sampling distribution.
##  * No masking. `.va_r3_fit()`'s dense-design requirement is passed through
##    unchanged -- every `(unit_id, trait_id)` cell must appear exactly once.
##    There is no `is_y_observed` channel here.

#' Simulate one replicate response vector from a fitted VA-R3 generative model
#'
#' Draws fresh unit-level latent scores from the model's assumed N(0, I_q)
#' prior, forms the linear predictor from the FITTED `beta`/`Lambda` and the
#' ORIGINAL, fixed design (`X`, `unit_id`, `trait_id` are held at their
#' observed values -- only the response is resampled, the standard
#' parametric-bootstrap design), and draws a new response through the fitted
#' family/link. See the "Route 3" file-level comment above for what this
#' assumes.
#'
#' @keywords internal
#' @noRd
.va_bootstrap_simulate_one <- function(beta, Lambda, X, unit_id, trait_id,
                                        n_trials, family, link, q) {
  N <- length(unique(unit_id))
  T_n <- nrow(Lambda)
  ## `.va_r3_fit()` itself accepts EITHER 1-based or 0-based unit_id/trait_id
  ## and sniffs which via `.va_r3_normalise_index()` (R/va-r3-proto.R) --
  ## that is the codebase-wide convention every caller relies on, and this
  ## package's own test suite constructs these 1-based
  ## (`rep(seq_len(N), each = T)`). An earlier version of this function
  ## assumed 0-based indices via a raw `+ 1L`, so calling it with the SAME
  ## 1-based inputs used to produce `fit` (as this function's own docs
  ## instruct) walked off the end of `Lambda`/`U` and every replicate failed
  ## silently (adversarial review finding). Normalising here, the same way
  ## `.va_r3_fit()` does internally, makes this function robust to whichever
  ## base the caller used -- not merely to the one the test suite happens to
  ## use.
  unit_id0 <- .va_r3_normalise_index(unit_id, N, "unit_id")
  trait_id0 <- .va_r3_normalise_index(trait_id, T_n, "trait_id")
  U <- matrix(stats::rnorm(N * q), nrow = N, ncol = q)
  eta <- as.numeric(X %*% beta) +
    rowSums(Lambda[trait_id0 + 1L, , drop = FALSE] *
              U[unit_id0 + 1L, , drop = FALSE])
  if (identical(family, "binomial") && identical(link, "logit")) {
    stats::rbinom(length(eta), size = n_trials, prob = stats::plogis(eta))
  } else if (identical(family, "binomial_probit") && identical(link, "probit")) {
    stats::rbinom(length(eta), size = n_trials, prob = stats::pnorm(eta))
  } else if (identical(family, "poisson") && identical(link, "log")) {
    stats::rpois(length(eta), lambda = exp(eta))
  } else {
    cli::cli_abort(c(
      "No bootstrap simulator is implemented for family {.val {family}} /
       link {.val {link}}.",
      "i" = "Implemented: binomial-logit, binomial_probit-probit, poisson-log."
    ))
  }
}

#' Draw `n_boot` simulate-refit replicates of a VA-R3 fit (uncalibrated)
#'
#' @description
#' The workhorse for Route 3 (see the file-level comment above). Runs the
#' simulate-then-refit loop ONCE and returns the raw per-replicate draws of
#' `beta` and `Sigma = Lambda %*% t(Lambda)`, so a caller who wants both a
#' beta interval and a loadings interval (`.va_bootstrap_beta_ci()` /
#' `.va_bootstrap_loadings_ci()`) can get both from one bootstrap run rather
#' than paying for the refits twice -- each replicate here is a full
#' `.va_r3_fit()` call, so that duplication is not free the way it would be
#' for the curvature-based routes.
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit
#'   (`gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))`).
#' @param y,n_trials,X,unit_id,trait_id The SAME refit inputs originally
#'   passed to `.va_r3_fit()` to produce `fit`. A `gllvmTMB_va` object does
#'   not retain these (Design 85 s10 keeps its field vocabulary disjoint from
#'   an ordinary fit -- no `$formula`/`$data`), so the caller must supply
#'   them.
#' @param n_boot Integer, bootstrap replicate count. Default 49 -- a SMALL
#'   default on purpose (see the file-level comment): this file builds an
#'   instrument for the coverage campaign to run at scale elsewhere, not
#'   something to run large locally.
#' @param seed Optional RNG seed for the simulated responses.
#' @param n_starts Integer, multi-starts PER REPLICATE refit. Default 1L
#'   (cheap; see "does not guarantee" above).
#' @param H Quadrature order forwarded to each replicate refit. Defaults to
#'   the original fit's own `$quadrature$order` (or 15L if that is absent).
#' @param control Optimiser control forwarded to each replicate refit.
#' @param progress Logical; print a one-line status per replicate.
#'
#' @return A list of class `"va_bootstrap_replicates"`:
#'   \describe{
#'     \item{beta_hat, Sigma_hat}{Point estimates from the ORIGINAL fit.}
#'     \item{beta_draws}{`n_boot x length(beta_hat)` matrix; `NA` rows mark
#'       failed replicates.}
#'     \item{Sigma_draws}{`n_boot x T x T` array; `NA` slices mark failed
#'       replicates.}
#'     \item{T, q}{Trait count and latent rank used.}
#'     \item{n_boot, n_failed}{Requested replicate count and failure count.}
#'     \item{n_starts, seed}{Echoed configuration.}
#'   }
#'
#' @keywords internal
#' @noRd
.va_bootstrap_replicates <- function(
  fit,
  y,
  n_trials,
  X,
  unit_id,
  trait_id,
  n_boot = 49L,
  seed = NULL,
  n_starts = 1L,
  H = NULL,
  control = list(eval.max = 800L, iter.max = 400L),
  progress = TRUE
) {
  raw <- .va_profile_normalize_fit(fit)
  par0 <- raw$best$par
  nm <- names(par0)
  if (is.null(nm)) {
    cli::cli_abort("{.code fit$best$par} must carry TMB parameter names.")
  }
  q <- as.integer(raw$q %||% .va_r3_infer_dims(nm)$q)
  if (!length(q) || is.na(q)) {
    cli::cli_abort("Could not determine {.arg q} (latent rank) from {.arg fit}.")
  }
  family <- raw$family
  link <- raw$link
  eval_method <- raw$eval_method
  if (is.null(family) || is.null(link) || is.null(eval_method)) {
    cli::cli_abort(
      "{.arg fit} is missing {.code family}/{.code link}/{.code eval_method};
       pass the raw {.fn .va_r3_fit} output or a public {.cls gllvmTMB_va} fit."
    )
  }
  Hq <- H %||% (raw$quadrature$order %||% 15L)

  n_boot <- as.integer(n_boot)
  if (n_boot < 1L) cli::cli_abort("{.arg n_boot} must be a positive integer.")

  theta_rr_hat <- unname(par0[nm == "theta_rr"])
  T_n <- .va_r3_infer_T_from_theta_rr(length(theta_rr_hat), q)
  beta_hat <- unname(par0[nm == "beta"])
  Lambda_hat <- .va_r3_unpack_theta_rr(theta_rr_hat, T_n, q)
  Sigma_hat <- Lambda_hat %*% t(Lambda_hat)

  if (!is.null(seed)) set.seed(seed)

  beta_draws <- matrix(NA_real_, n_boot, length(beta_hat))
  Sigma_draws <- array(NA_real_, dim = c(n_boot, T_n, T_n))
  ## Kept only for diagnostics if every replicate fails (see the abort
  ## below): an earlier version of this loop swallowed the real per-replicate
  ## error entirely, so a genuine bug (e.g. the indexing-convention mismatch
  ## fixed in .va_bootstrap_simulate_one()) surfaced only as the generic
  ## "every replicate failed" message with no clue why.
  first_error <- NULL
  note_error <- function(e) {
    if (is.null(first_error)) first_error <<- conditionMessage(e)
    NULL
  }

  for (b in seq_len(n_boot)) {
    if (isTRUE(progress)) {
      cli::cli_inform("  VA bootstrap rep {b}/{n_boot}")
    }
    y_b <- tryCatch(
      .va_bootstrap_simulate_one(beta_hat, Lambda_hat, X, unit_id, trait_id,
                                 n_trials, family, link, q),
      error = note_error
    )
    if (is.null(y_b)) next
    fit_b <- tryCatch(
      .va_r3_fit(
        y = y_b, n_trials = n_trials, X = X, unit_id = unit_id,
        trait_id = trait_id, q = q, family = family, link = link,
        eval_method = eval_method, n_starts = n_starts, H = Hq,
        control = control, silent = TRUE
      ),
      error = note_error
    )
    par_b <- fit_b$best$par
    ok <- !is.null(fit_b) && !is.null(par_b) &&
      isTRUE(fit_b$best$convergence == 0L) && all(is.finite(par_b))
    if (!ok) next
    nm_b <- names(par_b)
    beta_b <- unname(par_b[nm_b == "beta"])
    theta_b <- unname(par_b[nm_b == "theta_rr"])
    if (length(beta_b) != length(beta_hat) ||
        length(theta_b) != length(theta_rr_hat)) {
      next
    }
    Lambda_b <- .va_r3_unpack_theta_rr(theta_b, T_n, q)
    beta_draws[b, ] <- beta_b
    Sigma_draws[b, , ] <- Lambda_b %*% t(Lambda_b)
  }

  n_failed <- sum(!stats::complete.cases(beta_draws))
  if (n_failed == n_boot) {
    cli::cli_abort(c(
      "Every bootstrap replicate failed to refit; no interval can be constructed.",
      "i" = if (!is.null(first_error)) {
        "First replicate's error: {first_error}"
      } else {
        "No replicate raised an R error; check convergence/finiteness instead."
      }
    ))
  }

  structure(
    list(
      beta_hat = beta_hat, Sigma_hat = Sigma_hat,
      beta_draws = beta_draws, Sigma_draws = Sigma_draws,
      T = T_n, q = q, n_boot = n_boot, n_failed = n_failed,
      n_starts = n_starts, seed = seed
    ),
    class = "va_bootstrap_replicates"
  )
}

## Shared percentile-CI + arithmetic-floor step, factored out of the two
## public formatters below so the (B-1)/(B+1) ceiling logic exists in exactly
## one place. Mirrors bootstrap_Sigma()'s own floor (R/bootstrap-sigma.R) --
## see that file's comment for the derivation.
##
## @keywords internal
## @noRd
.va_bootstrap_ceiling <- function(n_boot, conf) {
  min_boot <- as.integer(ceiling(2 / (1 - conf)) - 1)
  ceiling_val <- (n_boot - 1) / (n_boot + 1)
  if (n_boot < min_boot) {
    cli::cli_warn(c(
      "{.arg n_boot} = {n_boot} cannot deliver a {conf * 100}% percentile interval.",
      "x" = "The widest interval {n_boot} draws can produce has coverage at
             most {round(ceiling_val, 3)}, below the requested {conf}. This is
             arithmetic, not a property of the data.",
      "i" = "Use {.arg n_boot} >= {min_boot} for a {conf * 100}% interval;
             returned as {.code $coverage_ceiling} either way."
    ))
  }
  ceiling_val
}

#' Percentile bootstrap interval for `beta` from a VA-R3 fit (uncalibrated)
#'
#' See the file-level "Route 3" comment above for the method and its caveats.
#' Runs `.va_bootstrap_replicates()` internally unless `fit` is already that
#' function's output (class `"va_bootstrap_replicates"`), in which case the
#' expensive refit loop is skipped and this call only forms percentile bounds
#' -- pass a saved replicate object here (and to
#' `.va_bootstrap_loadings_ci()`) to get both a beta and a loadings interval
#' from one bootstrap run.
#'
#' @param fit A `.va_r3_fit()` result, a public `gllvmTMB_va` fit, or the
#'   output of `.va_bootstrap_replicates()`.
#' @param ... When `fit` is not already a `"va_bootstrap_replicates"` object,
#'   forwarded to `.va_bootstrap_replicates()` (`y`, `n_trials`, `X`,
#'   `unit_id`, `trait_id`, `n_boot`, `seed`, `n_starts`, `H`, `control`,
#'   `progress`).
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only -- see
#'   caveats above.
#'
#' @return A data.frame, one row per beta coefficient: `term`, `estimate`,
#'   `lower`, `upper`, `level`, `route` (`"parametric_bootstrap"`), `n_boot`,
#'   `n_failed`, `coverage_ceiling`, `calibrated` (always `FALSE`).
#'
#' @keywords internal
#' @noRd
.va_bootstrap_beta_ci <- function(fit, ..., level = 0.95) {
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  boot <- if (inherits(fit, "va_bootstrap_replicates")) {
    fit
  } else {
    .va_bootstrap_replicates(fit, ...)
  }
  ceiling_val <- .va_bootstrap_ceiling(boot$n_boot, level)

  alpha <- 1 - level
  lo <- apply(boot$beta_draws, 2L, stats::quantile, probs = alpha / 2,
             na.rm = TRUE, names = FALSE)
  hi <- apply(boot$beta_draws, 2L, stats::quantile, probs = 1 - alpha / 2,
             na.rm = TRUE, names = FALSE)

  data.frame(
    term = rep("beta", length(boot$beta_hat)),
    estimate = boot$beta_hat,
    lower = lo,
    upper = hi,
    level = level,
    route = "parametric_bootstrap",
    n_boot = boot$n_boot,
    n_failed = boot$n_failed,
    coverage_ceiling = ceiling_val,
    calibrated = FALSE,
    stringsAsFactors = FALSE
  )
}

#' Percentile bootstrap interval for `Lambda %*% t(Lambda)` entries from a
#' VA-R3 fit (uncalibrated)
#'
#' See the file-level "Route 3" comment above. Rotation-invariant target,
#' NOT raw loadings -- same scope restriction as `.va_wald_loadings_ci()`,
#' but here invariance needs no delta-method argument: `Sigma` is invariant
#' to any orthogonal rotation of the latent scores by construction, so every
#' replicate's `Sigma` is directly comparable with no alignment step.
#'
#' @inheritParams .va_bootstrap_beta_ci
#'
#' @return A data.frame, one row per `(row <= col)` entry of `Sigma`: `row`,
#'   `col`, `estimate`, `lower`, `upper`, `level`, `route`
#'   (`"parametric_bootstrap"`), `n_boot`, `n_failed`, `coverage_ceiling`,
#'   `calibrated` (always `FALSE`).
#'
#' @keywords internal
#' @noRd
.va_bootstrap_loadings_ci <- function(fit, ..., level = 0.95) {
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  boot <- if (inherits(fit, "va_bootstrap_replicates")) {
    fit
  } else {
    .va_bootstrap_replicates(fit, ...)
  }
  ceiling_val <- .va_bootstrap_ceiling(boot$n_boot, level)

  alpha <- 1 - level
  T_n <- boot$T
  upper_incl <- upper.tri(matrix(0, T_n, T_n), diag = TRUE)
  pair_idx <- which(upper_incl, arr.ind = TRUE)

  rows_out <- vector("list", nrow(pair_idx))
  for (i in seq_len(nrow(pair_idx))) {
    t1 <- pair_idx[i, "row"]; t2 <- pair_idx[i, "col"]
    draws <- boot$Sigma_draws[, t1, t2]
    rows_out[[i]] <- data.frame(
      row = t1, col = t2,
      estimate = boot$Sigma_hat[t1, t2],
      lower = stats::quantile(draws, probs = alpha / 2, na.rm = TRUE, names = FALSE),
      upper = stats::quantile(draws, probs = 1 - alpha / 2, na.rm = TRUE, names = FALSE)
    )
  }
  result <- do.call(rbind, rows_out)
  result$level <- level
  result$route <- "parametric_bootstrap"
  result$n_boot <- boot$n_boot
  result$n_failed <- boot$n_failed
  result$coverage_ceiling <- ceiling_val
  result$calibrated <- FALSE
  result
}

## ---------------------------------------------------------------------
## Route 4: sandwich (robust / Huber-White) interval on the fixed block
## ---------------------------------------------------------------------
##
## MAINTAINER-REQUESTED. Aimed squarely at the same suspected defect Route 2
## documents from the profile side and Route 1 uses as-is: the VA objective
## is an ELBO -- a BOUND -- so there is no reason its curvature (what Route
## 1's Schur complement uses as if it were a variance) equals the variance
## of its score. That equality -- "the information matrix equality" -- holds
## for a correctly specified LIKELIHOOD at the truth; there is no version of
## it for a bound. A sandwich does not assume the equality: it keeps the
## curvature ("bread") but replaces the ASSUMED score variance with an
## EMPIRICAL one ("meat"), estimated from per-unit contributions. Of the
## four routes named in the task brief this is the one built to be
## diagnostic of exactly that gap: Route 1 assumes the equality and should
## fail if the hypothesis is right; this route drops it and estimates the
## meat directly. (Route 3, immediately above, drops both curvature AND the
## equality, at the cost of a full simulate-then-refit campaign per
## interval; this route keeps the curvature and buys cheapness back.)
##
## CONSTRUCTION.
##  * BREAD: recomputed here as the IDENTICAL Schur complement Route 1's
##    `.va_r3_schur_fixed_covariance()` computes (`H_ff -
##    sum_i H_fv,i B_i^{-1} H_fv,i'`, off the same `.va_r3_hessian_blocks()`
##    machinery) -- so bread is numerically the same quantity Route 1
##    certifies against gllvm's `se.gllvm()` to 4-6 significant figures
##    (`docs/design/schur-equivalence-check.md`). Not called via
##    `.va_r3_schur_fixed_covariance()` directly because that function
##    returns the INVERSE (a covariance); the sandwich needs the information
##    matrix itself, pre-inversion, so it is reproduced here rather than
##    inverting-then-re-inverting.
##  * MEAT: `sum_i s_i s_i'`, `s_i` the per-unit PROFILED score -- see
##    `.va_r3_profiled_score_by_unit()` immediately below for what
##    "profiled" means here and why the raw partial gradient turns out to
##    equal it exactly at a converged fit (an envelope-theorem argument, not
##    an approximation). Units are conditionally independent given the fixed
##    parameters in a GLLVM (the same structural fact that makes the Schur
##    complement block-diagonal in the first place), so this per-unit outer-
##    product decomposition is the natural empirical estimator, not an ad
##    hoc choice.
##
## WHAT THIS DOES NOT FIX. A sandwich corrects INTERVAL WIDTH for a mismatch
## between assumed and actual score variance. It does nothing about the
## CENTRE: VA's documented weakness on discrete-response data includes
## attenuation of the point estimate itself, and an interval built around a
## biased point estimate will not cover at the nominal rate however well its
## width is estimated. This route is plausibly NECESSARY but not SUFFICIENT
## for coverage, and must not be described as a fix until the (separate)
## coverage campaign actually measures it -- `calibrated` is hard-coded
## `FALSE` below, the same repo-wide convention every other route in this
## file follows.
##
## SCOPE: same split as Route 1, for the same reason -- `.va_sandwich_beta_ci()`
## for the beta block directly (no identifiability ambiguity),
## `.va_sandwich_loadings_ci()` for entries of the rotation-invariant
## `Sigma = Lambda %*% t(Lambda)` via the delta method off the sandwich
## covariance. Raw `theta_rr` entries never get a CI here either -- they are
## identified only up to rotation and sign (2026-06-19 FA rotation-
## convention decision), and that non-identifiability does not go away
## because the covariance estimator changed. Also identical to Route 1:
## single tier only (refuses on `n_tiers > 1`, same partition argument,
## R/va-r3-proto.R:1698-1707).

## Per-unit profiled score for the fixed block `{beta, theta_rr}`.
##
## Returns an `N x length(fixed_idx)` matrix `S` where `S[i, j]` is
## `d(unit i's contribution to the negative ELBO) / d(par[fixed_idx[j]])`,
## evaluated at `par` by central-differencing `objective$report()`.
##
## WHY THE RAW PARTIAL GRADIENT IS THE PROFILED SCORE HERE (the subtlety the
## task brief calls out explicitly -- read this before touching the sign or
## the differencing target). The score that belongs in a sandwich for the
## fixed parameters is the derivative of the PROFILE objective
## `L(theta_fix) = min_phi negative_elbo(theta_fix, phi)` with respect to
## `theta_fix` -- not the raw gradient with `phi` (the variational block)
## held fixed at an arbitrary value, which would omit however `phi`'s own
## optimum shifts as `theta_fix` moves. By the chain rule,
##
##   dL/d(theta_fix) = d(nelbo)/d(theta_fix)
##                      + [d(phi*)/d(theta_fix)]' * d(nelbo)/d(phi)
##
## and the second term vanishes IDENTICALLY at `phi = phi*(theta_fix)`,
## because `phi*(theta_fix)` is BY DEFINITION the value that zeroes
## `d(nelbo)/d(phi)` (that is what "profiled out" means). At `.va_r3_fit()`'s
## converged optimum this first-order condition holds exactly for every
## coordinate, fixed and variational alike -- that is what convergence
## means -- so the profiled score at the optimum collapses to the PARTIAL
## gradient of the negative ELBO with respect to `theta_fix`, `phi` held at
## its fitted value. No implicit-function term is needed; in particular
## nothing here needs `d(phi*)/d(theta_fix)` itself (that quantity is what
## `H_fv` in the bread already carries, for a different purpose).
##
## This simplifies further to a per-unit quantity because units are
## additively separable in the single-tier, unstructured case this route
## supports: `kl_by_unit(g)` and `expected_loglik_by_unit(i)` each depend
## only on unit `i`/`g`'s own `m`/`log_L_diag`/`L_off` block, never another
## unit's, when `n_tiers == 1` (verified against
## `inst/tmb/gllvmTMB_va_r3.cpp:670-948`, and numerically in the smoke test:
## `sum(kl_by_unit - expected_loglik_by_unit) == objective$fn(par)`
## exactly). So the per-unit profiled score is simply the per-unit partial
## derivative of `kl_by_unit(i) - expected_loglik_by_unit(i)` with respect
## to `theta_fix`, central-differenced via `objective$report()` -- the same
## differencing pattern `.va_r3_hessian_blocks()` already uses for
## `objective$gr()`, just applied to REPORT()'d per-unit vectors instead of
## the aggregate gradient.
##
## FALSIFIABLE PREDICTION this argument makes, checked in the smoke test as
## a diagnostic (not enforced as a hard gate here, since optimiser
## convergence tolerance varies): summing the per-unit profiled score over
## units should reproduce `objective$gr(par)[fixed_idx]`, which is ~0 at a
## converged fit. If that sum is NOT small, the fit was not actually
## stationary and the envelope-theorem simplification above does not apply
## -- `.va_r3_sandwich_information()` reports `max_abs_gradient` for exactly
## this reason.
##
## Cost: `2 * length(fixed_idx)` calls to `objective$report()`, each an O(1)
## forward pass (no AD, no linear solve) -- cheap even at moderate N.
##
## @keywords internal
## @noRd
.va_r3_profiled_score_by_unit <- function(objective, par, fixed_idx,
                                          step = 1e-5) {
  neg_elbo_by_unit <- function(p) {
    r <- objective$report(p)
    ## kl_by_unit(i) - expected_loglik_by_unit(i): unit i's exact additive
    ## share of the negative ELBO in the single-tier, unstructured case (see
    ## the file-level comment above for the citation and the smoke-test
    ## check that this sums to objective$fn(par)).
    as.numeric(r$kl_by_unit) - as.numeric(r$expected_loglik_by_unit)
  }
  n_fixed <- length(fixed_idx)
  N <- length(neg_elbo_by_unit(par))
  S <- matrix(0, nrow = N, ncol = n_fixed)
  for (j in seq_len(n_fixed)) {
    up <- par
    down <- par
    up[fixed_idx[j]] <- up[fixed_idx[j]] + step
    down[fixed_idx[j]] <- down[fixed_idx[j]] - step
    S[, j] <- (neg_elbo_by_unit(up) - neg_elbo_by_unit(down)) / (2 * step)
  }
  S
}

## Sandwich (robust) information for the fixed block of a VA-R3 fit: bread,
## meat, and the FULL (not diagonal-only) covariance -- the sandwich
## counterpart of Route 1's `.va_r3_schur_fixed_covariance()`, needed
## because `.va_sandwich_loadings_ci()` below requires the off-diagonal
## covariances between `theta_rr` entries, same reason Route 1 keeps its own
## full-covariance helper separate from `.va_r3_fixed_information_blocked()`.
##
## Contract
## --------
## Takes: `objective` -- the `TMB::MakeADFun()` object from a completed
##   `.va_r3_fit()` (`fit$objective`; built with `random = NULL`, so
##   `$he()`/`$gr()`/`$report()` act on the FULL joint parameter vector,
##   R/va-r3-proto.R:2073-2082); `par` -- the named optimum (`fit$best$par`);
##   `N`, `q` -- unit count and latent dimension, exactly as
##   `.va_r3_fixed_information_blocked()` takes them.
##
## Returns a list:
##   se_sandwich       -- named numeric, `sqrt(diag(vcov_sandwich))`, names
##                         `nm[fixed_idx]` (`"beta"`/`"theta_rr"`, repeated
##                         per TMB's vector-parameter convention).
##   fixed_idx         -- integer positions into `par`, IN ORDER matching
##                         `se_sandwich`/`vcov_sandwich`. `par`'s names
##                         repeat, so `par[fixed_idx]` -- POSITIONAL
##                         indexing -- is the only safe way to align an
##                         estimate with its SE; `par["beta"]` would
##                         silently return the FIRST `"beta"` entry,
##                         repeated.
##   vcov_sandwich      -- the `n_fixed x n_fixed` sandwich covariance,
##                         `bread^-1 %*% meat %*% bread^-1`, dimnamed
##                         `nm[fixed_idx]` x `nm[fixed_idx]`.
##   bread, meat        -- the two factors, kept for inspection/diagnostics.
##   max_abs_gradient   -- `max(abs(objective$gr(par)))`, a stationarity
##                         diagnostic: the profiled-score argument above is
##                         only exact at a converged (stationary) optimum.
##                         GATED, not merely reported: `status` becomes
##                         `"va_non_stationary_gradient"` (a fail-closed
##                         status like every other failure mode here) when
##                         this exceeds `grad_tol` (default `1e-2`) --
##                         adversarial review found an earlier version
##                         returned `status = "ok"` and a plausible SE for a
##                         `par` manually perturbed 4-6 orders of magnitude
##                         off the fitted optimum, with nothing in the output
##                         to flag it.
##   pd_bread, calibrated (always `FALSE`), route (`"sandwich"`), status,
##   basis.
##
## Assumes: single tier (refuses otherwise, identical partition argument to
##   the Schur route -- a second tier's variational blocks are NOT unit-
##   partitioned in general, R/va-r3-proto.R:1698-1707); units conditionally
##   independent given the fixed parameters (structural, verified against
##   the TMB template, see the per-unit-score comment above); the fit is at
##   a genuine stationary point -- ENFORCED via the `max_abs_gradient` gate
##   above, not merely diagnosed.
##
## Does NOT guarantee: nominal coverage (an empirical question, deliberately
##   left to the separate coverage campaign,
##   `docs/design/va-interval-coverage-campaign.md`); correctness of the
##   POINT ESTIMATE (a sandwich fixes variance, not bias -- see the Route-4
##   comment above); anything about individual `theta_rr` entries, which are
##   not rotation-identified (use `.va_sandwich_loadings_ci()` instead).
##
## @keywords internal
## @noRd
.va_r3_sandwich_information <- function(objective, par, N, q, step = 1e-5,
                                        grad_tol = 1e-2) {
  fail <- function(status) {
    list(se_sandwich = NULL, fixed_idx = NULL, vcov_sandwich = NULL,
         bread = NULL, meat = NULL, max_abs_gradient = NA_real_,
         pd_bread = FALSE, calibrated = FALSE, status = status,
         route = "sandwich")
  }
  if (.va_r3_multi_tier(objective)) return(fail(.VA_R3_MULTI_TIER_SE_STATUS))

  nm <- names(par)
  if (is.null(nm)) return(fail("va_unnamed_par_no_fixed_se"))
  fixed_idx <- which(nm %in% c("beta", "theta_rr"))
  if (!length(fixed_idx)) return(fail("va_no_fixed_block_no_fixed_se"))

  index_map <- tryCatch(.va_r3_variational_index_map(nm, N, q),
                        error = function(e) NULL)
  if (is.null(index_map) || !ncol(index_map)) {
    return(fail("va_variational_layout_unrecognised"))
  }

  grad0 <- tryCatch(as.numeric(objective$gr(par)), error = function(e) NULL)
  max_abs_gradient <- if (is.null(grad0)) NA_real_ else max(abs(grad0))

  ## Stationarity gate. The envelope-theorem argument that licenses treating
  ## the raw partial gradient as the profiled score (see the long comment
  ## above .va_r3_profiled_score_by_unit()) is only exact AT a stationary
  ## point -- it is not an approximation that degrades gracefully off one.
  ## Without this check the function returned status = "ok" and a plausible,
  ## barely-changed SE for a `par` manually perturbed 4-6 orders of magnitude
  ## off the fitted optimum (adversarial review finding, task brief); nothing
  ## in the returned data.frame distinguished that case from a converged fit.
  ## `grad_tol = 1e-2` is generous against known-good values (converged fits
  ## in this file's own smoke tests report max|gr| of 1e-4 to 1e-9) while
  ## well below the perturbed values that triggered the finding (0.5 to 54).
  if (is.na(max_abs_gradient) || max_abs_gradient > grad_tol) {
    out <- fail("va_non_stationary_gradient")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }

  parts <- tryCatch(
    .va_r3_hessian_blocks(objective, par, fixed_idx, index_map, step = step),
    error = function(e) NULL
  )
  if (is.null(parts)) return(fail("va_hessian_error_no_fixed_se"))

  ## Bread: the same Schur complement Route 1's
  ## .va_r3_schur_fixed_covariance() computes (pre-inversion) -- H_ff with
  ## the variational block profiled out one unit at a time,
  ## H_ff - sum_i H_fv,i B_i^{-1} H_fv,i'.
  correction <- matrix(0, parts$n_fixed, parts$n_fixed)
  singular <- FALSE
  for (i in seq_len(parts$N)) {
    H_fv_i <- parts$fixed_columns[index_map[i, ], , drop = FALSE]
    solved <- tryCatch(solve(parts$blocks[, , i], H_fv_i), error = function(e) NULL)
    if (is.null(solved)) { singular <- TRUE; break }
    correction <- correction + crossprod(H_fv_i, solved)
  }
  if (singular) {
    out <- fail("va_singular_variational_block")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }
  bread <- parts$H_ff - correction
  bread <- (bread + t(bread)) / 2

  bread_pd <- tryCatch({ chol(bread); TRUE }, error = function(e) FALSE)
  if (!bread_pd) {
    out <- fail("va_non_pd_profile_information")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }
  bread_inv <- tryCatch(solve(bread), error = function(e) NULL)
  if (is.null(bread_inv)) {
    out <- fail("va_non_pd_profile_information")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }

  ## Meat: sum_i s_i s_i' from the per-unit PROFILED score (comment above
  ## .va_r3_profiled_score_by_unit() explains why the raw partial gradient
  ## IS the profiled score at this fit's optimum).
  S <- tryCatch(.va_r3_profiled_score_by_unit(objective, par, fixed_idx,
                                              step = step),
               error = function(e) NULL)
  if (is.null(S)) {
    out <- fail("va_score_error_no_sandwich_se")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }
  meat <- crossprod(S)

  vcov_sandwich <- bread_inv %*% meat %*% bread_inv
  vcov_sandwich <- (vcov_sandwich + t(vcov_sandwich)) / 2
  d <- diag(vcov_sandwich)
  if (any(!is.finite(d)) || any(d < 0)) {
    out <- fail("va_non_finite_sandwich_variance")
    out$max_abs_gradient <- max_abs_gradient
    return(out)
  }
  dimnames(vcov_sandwich) <- list(nm[fixed_idx], nm[fixed_idx])

  list(
    se_sandwich = stats::setNames(sqrt(d), nm[fixed_idx]),
    fixed_idx = fixed_idx,
    vcov_sandwich = vcov_sandwich,
    bread = bread,
    meat = meat,
    max_abs_gradient = max_abs_gradient,
    pd_bread = TRUE,
    calibrated = FALSE,
    route = "sandwich",
    status = "ok",
    basis = paste(
      "robust/Huber-White sandwich for the fixed block of the negative ELBO;",
      "bread = Schur-complement profile information (variational block",
      "marginalised, matching .va_r3_fixed_information_blocked()/",
      "Route 1's .va_r3_schur_fixed_covariance(), cross-checked against",
      "gllvm::se.gllvm() in schur-equivalence-check.md); meat = sum_i s_i s_i'",
      "from the per-unit PROFILED score (envelope-theorem argument above --",
      "NOT the raw joint gradient held at an arbitrary phi); does not assume",
      "the information-matrix equality Route 1 assumes; does NOT correct for",
      "VA point-estimate bias -- a sandwich fixes variance, not bias"
    )
  )
}

#' Wald interval for the beta (fixed-effect) block from the sandwich
#' (robust/Huber-White) covariance of the negative ELBO (uncalibrated)
#'
#' @description
#' Same target as `.va_wald_beta_ci()` (Route 1), different covariance: this
#' one does not assume the information-matrix equality, estimating the score
#' variance empirically from per-unit contributions instead (see the
#' file-level "Route 4" comment above). Statistically UNCALIBRATED -- a
#' sandwich corrects width for a curvature/score-variance mismatch, not bias
#' -- built as a measurement instrument for the coverage campaign, not a
#' trusted interval.
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit
#'   (`gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))`).
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only.
#' @param step Central-difference step used for both the bread
#'   (`.va_r3_hessian_blocks()`) and the meat
#'   (`.va_r3_profiled_score_by_unit()`). Default `1e-5`, matching
#'   `.va_r3_hessian_blocks()`'s own default.
#' @param grad_tol Stationarity gate: `.va_r3_sandwich_information()` refuses
#'   (status `"va_non_stationary_gradient"`) rather than returning a number
#'   when `max(abs(objective$gr(par))) > grad_tol`. Default `1e-2`, generous
#'   against converged fits (this file's own smoke tests report 1e-4 to
#'   1e-9) and well below the drifted values (0.5-54) that motivated adding
#'   this gate.
#'
#' @return A data.frame, one row per beta coefficient, with columns `term`,
#'   `estimate`, `se`, `lower`, `upper`, `level`, `route` (`"sandwich"`),
#'   `status`, `calibrated` (always `FALSE`), `max_abs_gradient` (the
#'   stationarity diagnostic from `.va_r3_sandwich_information()`).
#'
#' @keywords internal
#' @noRd
.va_sandwich_beta_ci <- function(fit, level = 0.95, step = 1e-5,
                                 grad_tol = 1e-2) {
  raw <- .va_profile_normalize_fit(fit)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  par <- raw$best$par
  nm <- names(par)
  if (is.null(nm)) {
    cli::cli_abort("{.code fit$best$par} must carry TMB parameter names.")
  }
  dims <- .va_r3_infer_dims(nm)
  if (is.null(dims)) {
    cli::cli_abort(
      "Could not infer N, q from {.code fit$best$par}'s layout
       (single-tier fits only)."
    )
  }

  info <- .va_r3_sandwich_information(raw$objective, par,
                                      N = dims$N, q = dims$q, step = step,
                                      grad_tol = grad_tol)
  if (!identical(info$status, "ok")) {
    cli::cli_abort(
      "Sandwich information is not usable (status: {.val {info$status}});
       no sandwich interval can be formed."
    )
  }

  beta_mask <- names(info$se_sandwich) == "beta"
  beta_names <- nm[nm == "beta"]
  se <- unname(info$se_sandwich[beta_mask])
  if (length(se) != length(beta_names)) {
    cli::cli_abort(
      "Recovered beta SEs do not match the beta block length; refusing to
       guess an alignment."
    )
  }
  est <- unname(par[nm == "beta"])
  z <- stats::qnorm(1 - (1 - level) / 2)

  data.frame(
    term = beta_names,
    estimate = est,
    se = se,
    lower = est - z * se,
    upper = est + z * se,
    level = level,
    route = info$route,
    status = info$status,
    calibrated = info$calibrated,
    max_abs_gradient = info$max_abs_gradient,
    stringsAsFactors = FALSE
  )
}

#' Delta-method sandwich interval for entries of Lambda %*% t(Lambda)
#' (uncalibrated)
#'
#' @description
#' Same target and same closed-form Jacobian construction as
#' `.va_wald_loadings_ci()` (Route 1) -- the ROTATION-INVARIANT
#' `Sigma = Lambda %*% t(Lambda)`, NOT raw loadings -- propagated instead
#' through the sandwich covariance of `theta_rr`
#' (`.va_r3_sandwich_information()$vcov_sandwich`) rather than the plain
#' Schur-complement covariance. See the file-level "Route 4" comment above
#' for why, and `.va_wald_loadings_ci()`'s docstring for the Jacobian
#' argument (unchanged here: `.va_r3_unpack_theta_rr()` places each element
#' of `theta_rr` into `Lambda` by pure placement, so the Jacobian is 0/1 and
#' obtained the same way).
#'
#' @param fit A `.va_r3_fit()` result, or a public `gllvmTMB_va` fit.
#' @param T Number of traits. Optional -- inferred from `theta_rr`'s length
#'   and `q` via `.va_r3_infer_T_from_theta_rr()` when `NULL`.
#' @param level Nominal confidence level, e.g. `0.95`. NOMINAL only.
#' @param step Central-difference step, forwarded to
#'   `.va_r3_sandwich_information()`.
#' @param grad_tol Stationarity gate, forwarded to
#'   `.va_r3_sandwich_information()`. See `.va_sandwich_beta_ci()`'s
#'   documentation for the rationale and default.
#'
#' @return A data.frame, one row per `(row <= col)` entry of `Sigma`, with
#'   columns `row`, `col`, `estimate`, `se`, `lower`, `upper`, `level`,
#'   `route` (`"sandwich_delta_method"`), `calibrated` (always `FALSE`).
#'
#' @keywords internal
#' @noRd
.va_sandwich_loadings_ci <- function(fit, T = NULL, level = 0.95, step = 1e-5,
                                     grad_tol = 1e-2) {
  raw <- .va_profile_normalize_fit(fit)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  par <- raw$best$par
  nm <- names(par)
  if (is.null(nm)) {
    cli::cli_abort("{.code fit$best$par} must carry TMB parameter names.")
  }
  dims <- .va_r3_infer_dims(nm)
  if (is.null(dims)) {
    cli::cli_abort(
      "Could not infer N, q from {.code fit$best$par}'s layout
       (single-tier fits only)."
    )
  }
  q <- dims$q
  theta_rr <- unname(par[nm == "theta_rr"])
  if (!length(theta_rr)) {
    cli::cli_abort("{.code fit$best$par} has no {.val theta_rr} block.")
  }

  if (is.null(T)) {
    T <- .va_r3_infer_T_from_theta_rr(length(theta_rr), q)
  } else {
    T <- as.integer(T)
    if (.va_r3_theta_length(T, q) != length(theta_rr)) {
      cli::cli_abort("Supplied {.arg T} is inconsistent with theta_rr's length and q.")
    }
  }

  Lambda <- .va_r3_unpack_theta_rr(theta_rr, T, q)
  ## 0 marks a structural zero (strict upper triangle): not a free
  ## parameter, contributes no gradient.
  pos <- .va_r3_unpack_theta_rr(seq_len(length(theta_rr)), T, q)

  info <- .va_r3_sandwich_information(raw$objective, par,
                                      N = dims$N, q = q, step = step,
                                      grad_tol = grad_tol)
  if (!identical(info$status, "ok")) {
    cli::cli_abort(
      "Sandwich covariance is not usable (status: {.val {info$status}}); no
       delta-method interval can be formed."
    )
  }
  theta_idx <- which(names(info$se_sandwich) == "theta_rr")
  if (length(theta_idx) != length(theta_rr)) {
    cli::cli_abort(
      "theta_rr covariance sub-block does not match theta_rr's length;
       refusing to guess an alignment."
    )
  }
  cov_theta <- info$vcov_sandwich[theta_idx, theta_idx, drop = FALSE]

  z <- stats::qnorm(1 - (1 - level) / 2)
  upper_incl <- upper.tri(matrix(0, T, T), diag = TRUE)
  pair_idx <- which(upper_incl, arr.ind = TRUE)

  rows_out <- vector("list", nrow(pair_idx))
  for (i in seq_len(nrow(pair_idx))) {
    t1 <- pair_idx[i, "row"]; t2 <- pair_idx[i, "col"]
    g <- numeric(length(theta_rr))
    for (k in seq_len(q)) {
      i1 <- pos[t1, k]; i2 <- pos[t2, k]
      if (i1 > 0) g[i1] <- g[i1] + Lambda[t2, k]
      if (i2 > 0) g[i2] <- g[i2] + Lambda[t1, k]
    }
    est <- sum(Lambda[t1, ] * Lambda[t2, ])
    var_est <- as.numeric(t(g) %*% cov_theta %*% g)
    se <- if (is.finite(var_est) && var_est >= 0) sqrt(var_est) else NA_real_
    rows_out[[i]] <- data.frame(
      row = t1, col = t2, estimate = est, se = se,
      lower = est - z * se, upper = est + z * se
    )
  }
  result <- do.call(rbind, rows_out)
  result$level <- level
  result$route <- "sandwich_delta_method"
  result$calibrated <- FALSE
  result
}
