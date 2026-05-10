## Profile-likelihood confidence intervals for gllvmTMB_multi fits.
##
## This file implements the "direct" profile path: a parameter that exists
## in opt$par (or a linear combination of such parameters) is profiled via
## TMB::tmbprofile(), then a chi-square root-finding step locates the
## CI bounds where 2*(L_max - L_profile) = qchisq(level, 1).
##
## Companion file R/profile-derived.R handles the "derived" path: ICC,
## communality, repeatability, cross-trait correlation, and phylogenetic
## signal H^2 -- non-linear functions of opt$par that need a Lagrange-style
## fix-and-refit (mirrors Nakagawa's `coxme_icc_ci(model, vfixed = ...)`
## pattern but on TMB's C++ inner optim, warm-started from the joint MLE).
##
## References (cited throughout the docstrings):
##   * Pawitan (2001) In All Likelihood, Oxford UP, ch. 9 ("Profile likelihood").
##   * Venzon & Moolgavkar (1988) Appl. Stat. 37:87-94 (uniroot-style profile).
##   * lme4 source -- profile.merMod() (a chi-square-on-deviance pattern).
##   * metafor source -- confint.rma.uni() (uniroot + optim refit pattern).
##   * McCune & Nakagawa coxme_icc_ci()
##     (https://github.com/kelseybmccune/Time-to-Event_Repeatability)
##     Conceptual prior: fix-the-target-and-refit, then root-find on the
##     deviance crossing.

#' @keywords internal
#' @noRd
.qchisq_threshold <- function(level) {
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1)
    cli::cli_abort("{.arg level} must be a single value in (0, 1); got {level}.")
  stats::qchisq(level, df = 1L) / 2
}

## ---- Identify a non-random parameter index --------------------------------
## tmbprofile() expects an integer index into the *non-random* parameter
## vector (= opt$par; what TMB calls `obj$par`), or a name (matched to
## that vector's names). We resolve both forms here so callers can use
## either. When the name occurs more than once (TMB params are vectors
## that can repeat the same name across positions), `which` selects the
## i-th occurrence.

#' @keywords internal
#' @noRd
.resolve_param_index <- function(fit, name = NULL, which = 1L) {
  par_names <- names(fit$opt$par)
  if (is.numeric(name)) {
    idx <- as.integer(name)
    if (idx < 1L || idx > length(par_names))
      cli::cli_abort("Parameter index {.val {idx}} out of range [1, {length(par_names)}].")
    return(idx)
  }
  if (!is.character(name) || length(name) != 1L)
    cli::cli_abort("{.arg name} must be a single character or integer.")
  hits <- which(par_names == name)
  if (length(hits) == 0L)
    cli::cli_abort(c(
      "Parameter {.val {name}} not found in {.code opt$par}.",
      "i" = "Available names: {.val {unique(par_names)}}."
    ))
  which <- as.integer(which)
  if (which < 1L || which > length(hits))
    cli::cli_abort(c(
      "{.arg which} = {which} out of range for {.val {name}}.",
      "i" = "There are {length(hits)} entries named {.val {name}}."
    ))
  hits[which]
}

## ---- Find CI bounds from a profile object via uniroot ---------------------
## Given a tmbprofile() data.frame (cols: name, value), find the parameter
## values at which `value` crosses `crit`. The profile is monotone away
## from the MLE in the well-behaved case; we sort by parameter and find
## the smallest (lower bound) and largest (upper bound) crossing. If no
## crossing is found on a side, that bound is NA (boundary case: variance
## pinned at zero, etc.).

#' @keywords internal
#' @noRd
.profile_bounds <- function(prof, mle_val, mle_par, crit) {
  ## Sort by parameter
  prof <- prof[order(prof[[1L]]), , drop = FALSE]
  pars <- prof[[1L]]
  vals <- prof[[2L]]
  thresh <- mle_val + crit
  ## Excess over threshold: < 0 means inside the CI, > 0 outside
  excess <- vals - thresh
  ## Lower bound: largest par < mle_par with excess > 0 ... transitioning
  ## to the smallest par >= mle_par with excess <= 0. Use uniroot on a
  ## linear interpolation.
  lo_idx <- which(pars < mle_par)
  hi_idx <- which(pars > mle_par)

  find_cross <- function(idx, side = c("lower", "upper")) {
    side <- match.arg(side)
    if (length(idx) < 2L) return(NA_real_)
    p_sub <- pars[idx]
    v_sub <- vals[idx]
    e_sub <- v_sub - thresh
    pos <- which(e_sub > 0)   # outside CI
    neg <- which(e_sub <= 0)  # inside CI
    ## Boundary case: tmbprofile() returned points on this side but the
    ## profile never reached the chi-square threshold. The variance is
    ## pinned at the natural boundary or weakly identified. Return the
    ## parameter limit (+/- Inf) so that downstream transforms map to
    ## the natural CI boundary (plogis: R -> 0/1; tanh: rho -> -1/1;
    ## exp: sigma2 -> 0/Inf; identity: -Inf/Inf for unbounded params).
    ## NA is reserved for genuine profile failure.
    if (length(pos) == 0L) return(if (side == "lower") -Inf else Inf)
    if (length(neg) == 0L) return(NA_real_)
    ## Standard case: find sign-change closest to MLE and linear-interpolate.
    transitions <- which(diff(sign(e_sub)) != 0)
    if (length(transitions) == 0L) return(NA_real_)
    i <- if (side == "lower") max(transitions) else min(transitions)
    p1 <- p_sub[i];     p2 <- p_sub[i + 1L]
    e1 <- e_sub[i];     e2 <- e_sub[i + 1L]
    if (e2 == e1) return(NA_real_)
    p1 + (0 - e1) * (p2 - p1) / (e2 - e1)
  }

  lo <- find_cross(lo_idx, "lower")
  hi <- find_cross(hi_idx, "upper")
  list(lower = lo, upper = hi)
}

## ---- One-shot profile CI for a single parameter or lincomb ----------------

#' Profile-likelihood CI for one parameter or linear combination
#'
#' Wraps `TMB::tmbprofile()` with a chi-square root-finding step to return
#' a 95% (or other-level) confidence interval for a single parameter (or
#' a fixed linear combination of parameters) on a fitted gllvmTMB_multi
#' model. The profile is computed in TMB's C++ inner optim warm-started
#' from the joint MLE — typically order-of-magnitude faster than refitting
#' under a constraint in pure R.
#'
#' For non-linear derived quantities (ICC, communality, repeatability,
#' correlations, phylogenetic signal H^2), see the helpers in
#' `R/profile-derived.R`.
#'
#' @param fit A `gllvmTMB_multi` fit returned by [gllvmTMB()].
#' @param name Either:
#'   * A single character string giving the parameter name (matched
#'     against `names(fit$opt$par)`; for vector parameters use `which`
#'     to pick the entry), OR
#'   * a single integer giving the index into `fit$opt$par`.
#' @param which For vector-valued parameters (e.g. `theta_diag_B` is
#'   length T), the index within the named-block. Default `1`.
#' @param lincomb Optional numeric vector of length `length(fit$opt$par)`
#'   giving a linear combination of fixed-effect parameters to profile.
#'   When supplied, `name` is ignored. Used internally for total-variance
#'   contrasts (e.g. `theta_diag_B[t] + theta_diag_W[t]` for a per-trait
#'   total log-variance).
#' @param level Confidence level in (0, 1). Default 0.95.
#' @param transform Optional function applied to the profile-CI bounds
#'   before returning. Pass `exp` to convert log-SD to SD; pass
#'   `\(x) exp(2 * x)` for variance from log-SD. Default `identity`.
#' @param ystep,ytol Passed through to [TMB::tmbprofile()]. The defaults
#'   give a fast, robust profile for variance components.
#' @param parm.range Passed through to [TMB::tmbprofile()]. Default
#'   `c(-Inf, Inf)`; for log-scale parameters with a hard lower bound,
#'   constrain via e.g. `c(-15, Inf)` so the profile does not chase
#'   variance to zero.
#' @return A length-3 named numeric vector (`estimate`, `lower`, `upper`).
#'   `lower` or `upper` may be `NA` when the profile is one-sided
#'   (variance pinned at boundary).
#'
#' @section Boundary behaviour:
#' When a variance component is near zero, the profile likelihood becomes
#' one-sided: the parameter can decrease to negative infinity in log-SD
#' space (variance to zero) without an additional likelihood penalty.
#' In that case the bound is at the natural boundary of the parameter
#' space, not unknown. `tmbprofile_wrapper()` therefore returns the
#' transformed boundary (e.g. `lower = 0` for `transform = exp`,
#' `lower = 0` for `transform = plogis`, `lower = -1` for
#' `transform = tanh`, `lower = -Inf` for `transform = identity`).
#' `NA` is reserved for genuine profile failure (e.g. tmbprofile()
#' threw an error or returned too few points).
#'
#' @keywords internal
#' @export
tmbprofile_wrapper <- function(fit,
                               name       = NULL,
                               which      = 1L,
                               lincomb    = NULL,
                               level      = 0.95,
                               transform  = identity,
                               ystep      = 0.5,
                               ytol       = 2,
                               parm.range = c(-Inf, Inf)) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  crit <- .qchisq_threshold(level)
  mle_val <- as.numeric(fit$opt$objective)

  if (!is.null(lincomb)) {
    if (!is.numeric(lincomb) || length(lincomb) != length(fit$opt$par))
      cli::cli_abort(c(
        "{.arg lincomb} must be numeric of length {length(fit$opt$par)}.",
        "i" = "Got length {length(lincomb)}."
      ))
    mle_par <- as.numeric(crossprod(fit$opt$par, lincomb))
    prof <- tryCatch(
      TMB::tmbprofile(
        fit$tmb_obj,
        lincomb    = lincomb,
        ystep      = ystep,
        ytol       = ytol,
        parm.range = parm.range,
        trace      = FALSE
      ),
      error = function(e) {
        cli::cli_warn("tmbprofile() failed for lincomb: {conditionMessage(e)}")
        NULL
      }
    )
  } else {
    idx <- .resolve_param_index(fit, name = name, which = which)
    mle_par <- as.numeric(fit$opt$par[idx])
    prof <- tryCatch(
      TMB::tmbprofile(
        fit$tmb_obj,
        name       = idx,
        ystep      = ystep,
        ytol       = ytol,
        parm.range = parm.range,
        trace      = FALSE
      ),
      error = function(e) {
        cli::cli_warn("tmbprofile() failed for {.val {name}}: {conditionMessage(e)}")
        NULL
      }
    )
  }

  if (is.null(prof) || nrow(prof) < 3L) {
    return(c(estimate = transform(mle_par), lower = NA_real_, upper = NA_real_))
  }
  bounds <- .profile_bounds(prof, mle_val = mle_val, mle_par = mle_par, crit = crit)
  c(
    estimate = transform(mle_par),
    lower    = if (is.na(bounds$lower)) NA_real_ else transform(bounds$lower),
    upper    = if (is.na(bounds$upper)) NA_real_ else transform(bounds$upper)
  )
}

## ---- Bulk profile for a named block (e.g. theta_diag_B[1:T]) --------------

#' @keywords internal
#' @noRd
.tmbprofile_block <- function(fit, name, level = 0.95,
                              transform = identity,
                              labels = NULL,
                              ystep = 0.5, ytol = 2) {
  par_names <- names(fit$opt$par)
  hits <- which(par_names == name)
  if (length(hits) == 0L)
    return(NULL)
  out <- vector("list", length(hits))
  for (i in seq_along(hits)) {
    out[[i]] <- tmbprofile_wrapper(
      fit, name = name, which = i, level = level,
      transform = transform,
      ystep = ystep, ytol = ytol
    )
  }
  ## Build tidy data frame
  parm <- if (!is.null(labels)) labels else paste0(name, "[", seq_along(hits), "]")
  data.frame(
    parameter = parm,
    estimate  = vapply(out, `[`, numeric(1), "estimate"),
    lower     = vapply(out, `[`, numeric(1), "lower"),
    upper     = vapply(out, `[`, numeric(1), "upper"),
    method    = "profile",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

## ---- Wald CI helper (used by method = "wald") -----------------------------
## Uses sd_report; falls back to NA when the SE is missing or the parameter
## is not in the standard error report. Mirrors the layout of the profile
## tidy frame so confint() can return a uniform shape regardless of method.

#' @keywords internal
#' @noRd
.wald_block <- function(fit, name, level = 0.95,
                        transform_estimate = identity,
                        transform_se = NULL,
                        labels = NULL) {
  par_names <- names(fit$opt$par)
  hits <- which(par_names == name)
  if (length(hits) == 0L)
    return(NULL)
  alpha <- 1 - level
  z <- stats::qnorm(1 - alpha / 2)
  ## Pull SE from sd_report if available; tmb's $par.fixed corresponds to
  ## opt$par. If the gradient is bad / sd_report is NULL, return NA SE.
  se <- rep(NA_real_, length(hits))
  if (!is.null(fit$sd_report)) {
    sds <- tryCatch(sqrt(diag(fit$sd_report$cov.fixed)), error = function(e) NULL)
    if (!is.null(sds) && length(sds) == length(par_names)) {
      se <- sds[hits]
    }
  }
  est_log <- as.numeric(fit$opt$par[hits])
  ## Transform estimate to natural scale, transform SE via delta method
  ## when transform_se is supplied; otherwise widen on the log/native scale.
  est <- vapply(est_log, transform_estimate, numeric(1))
  if (is.null(transform_se)) {
    lo_log <- est_log - z * se
    hi_log <- est_log + z * se
    lo <- vapply(lo_log, transform_estimate, numeric(1))
    hi <- vapply(hi_log, transform_estimate, numeric(1))
  } else {
    se_nat <- vapply(seq_along(est_log), function(i)
      transform_se(est_log[i], se[i]), numeric(1))
    lo <- est - z * se_nat
    hi <- est + z * se_nat
  }
  parm <- if (!is.null(labels)) labels else paste0(name, "[", seq_along(hits), "]")
  data.frame(
    parameter = parm,
    estimate  = est,
    lower     = lo,
    upper     = hi,
    method    = "wald",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
