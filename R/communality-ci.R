## Wald (delta-method) and parametric-bootstrap confidence intervals for
## per-trait communality
##
##   c^2_t = (Lambda Lambda^T)_{tt} / Sigma_{tt}
##
## at one tier (B / unit, W / unit_obs, or phy). Profile-likelihood CIs are
## already provided by [profile_ci_communality()]; the helpers here add
## the two remaining methods so that the `confint(parm, method)` surface
## is programmatically complete (Phase B-INF Lane 1, A1).
##
## The Wald path is a delta-method on the non-linear scalar
##   g(theta) = c^2_t(theta)
## obtained by a numerical Jacobian of `tmb_obj$report()` -- the same
## pattern used by `.lambda_se_at_mle()` for per-entry Lambda SEs. To
## handle the (0, 1) support honestly we transform to logit-c^2 space,
## build the symmetric Wald there, then back-transform via plogis().
##
## The bootstrap path wraps `bootstrap_Sigma(what = "communality")` and
## returns the per-trait percentile bounds at the requested confidence
## level.

#' Wald (delta-method) confidence interval for per-trait communality
#'
#' Computes `c^2_t = (Lambda Lambda^T)_{tt} / Sigma_{tt}` for the
#' requested tier and trait by reading `Lambda_<tier>` and
#' `sd_<tier>` from `tmb_obj$report()`, then propagates the asymptotic
#' covariance of the fixed parameters through a numerical Jacobian to
#' obtain an SE on the logit-c^2 scale. The symmetric Wald CI on logit-c^2
#' is back-transformed with `plogis()` so that the returned interval is
#' bounded in (0, 1).
#'
#' @param fit A multivariate `gllvmTMB()` fit with a `latent()` term at
#'   the requested tier.
#' @param tier `"unit"`, `"unit_obs"`, `"phy"`, or the legacy aliases
#'   `"B"` / `"W"`.
#' @param trait_idx Integer index of the trait (1-based).
#' @param level Confidence level. Default 0.95.
#'
#' @return Length-3 numeric vector with names `estimate`, `lower`,
#'   `upper`. Entries are NA when the fit cannot supply the required
#'   `sdreport` or Lambda/Psi report items.
#'
#' @keywords internal
#' @noRd
.communality_wald_ci <- function(
  fit,
  tier,
  trait_idx,
  level = 0.95,
  link_residual = c("auto", "none")
) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  if (!is.numeric(level) || length(level) != 1L ||
      level <= 0 || level >= 1)
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  if (!is.numeric(trait_idx) || length(trait_idx) != 1L)
    cli::cli_abort("{.arg trait_idx} must be a single integer.")
  trait_idx <- as.integer(trait_idx)
  link_residual <- match.arg(link_residual)

  tier_in <- tier
  tier <- .normalise_level(tier, arg_name = "tier")
  if (!tier %in% c("B", "W", "phy"))
    cli::cli_abort(
      "Communality is defined for tiers {.val unit}, {.val unit_obs}, or {.val phy}; got {.val {tier_in}}."
    )

  rr_used <- switch(
    tier,
    B = isTRUE(fit$use$rr_B),
    W = isTRUE(fit$use$rr_W),
    phy = isTRUE(fit$use$phylo_rr)
  )
  diag_used <- switch(
    tier,
    B = isTRUE(fit$use$diag_B),
    W = isTRUE(fit$use$diag_W),
    phy = isTRUE(fit$use$phylo_diag)
  )
  if (!rr_used)
    cli::cli_abort(
      "Communality at tier {.val {tier_in}} requires a {.code latent()} term."
    )
  if (!diag_used)
    cli::cli_abort(
      "Communality Wald CI at tier {.val {tier_in}} requires a diagonal Psi component (per-trait unique variance). Use the default {.fn latent} fit for ordinary tiers; for the phylogenetic tier, use the folded {.code phylo_latent(..., unique = TRUE)} contract."
    )

  trait_names <- levels(fit$data[[fit$trait_col]])
  T_n <- length(trait_names)
  if (trait_idx < 1L || trait_idx > T_n)
    cli::cli_abort(
      "{.arg trait_idx} must be in 1:{T_n}; got {trait_idx}."
    )

  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      i = "Refit so {.code fit$sd_report} is populated."
    ))

  lam_name <- switch(
    tier,
    B = "Lambda_B",
    W = "Lambda_W",
    phy = "Lambda_phy"
  )
  sd_name <- switch(
    tier,
    B = "sd_B",
    W = "sd_W",
    phy = "sd_phy_diag"
  )
  rep0 <- fit$report
  if (is.null(rep0[[lam_name]]) || is.null(rep0[[sd_name]]))
    cli::cli_abort(
      "Fit report is missing {.code {lam_name}} or {.code {sd_name}}."
    )

  ## Per-trait link-implicit residual variance added to the denominator
  ## (matches `extract_communality(link_residual = "auto")` and the
  ## bootstrap path). Treated as a constant in the delta method: for
  ## probit binary this is exactly 1; for families whose residual
  ## variance depends on parameters (e.g. lognormal-Poisson) we are
  ## ignoring the second-order contribution, consistent with how
  ## `bootstrap_Sigma()` summarises its draws.
  link_resid_vec <- if (tier == "phy" || identical(link_residual, "none")) {
    rep(0, T_n)
  } else {
    tryCatch(
      link_residual_per_trait(fit),
      error = function(e) rep(0, T_n)
    )
  }
  link_resid_t <- if (length(link_resid_vec) >= trait_idx)
    unname(link_resid_vec[trait_idx]) else 0
  if (!is.finite(link_resid_t)) link_resid_t <- 0

  ## Scalar communality at one trait given a report list.
  c2_from_report <- function(rep_x) {
    Lam <- as.matrix(rep_x[[lam_name]])
    sdv <- as.numeric(rep_x[[sd_name]])
    shared <- sum(Lam[trait_idx, ]^2)
    sigma2 <- sdv[trait_idx]^2
    total  <- shared + sigma2 + link_resid_t
    if (!is.finite(total) || total <= 0) return(NA_real_)
    shared / total
  }

  c2_hat <- unname(c2_from_report(rep0))
  if (!is.finite(c2_hat) || c2_hat <= 0 || c2_hat >= 1)
    return(c(estimate = c2_hat, lower = NA_real_, upper = NA_real_))

  ## Numerical Jacobian of c^2_t with respect to the FIXED parameters,
  ## via `tmb_obj$report()` evaluations -- mirrors `.lambda_se_at_mle()`.
  obj <- fit$tmb_obj
  par_best <- obj$env$last.par.best
  random_idx <- if (length(obj$env$random) > 0L)
    obj$env$random else integer(0)
  fixed_idx <- setdiff(seq_along(par_best), random_idx)
  n_fix <- length(fixed_idx)
  if (n_fix == 0L)
    return(c(estimate = c2_hat, lower = NA_real_, upper = NA_real_))

  eps <- 1e-6
  grad_c2 <- numeric(n_fix)
  for (p in seq_len(n_fix)) {
    par_plus <- par_best
    par_plus[fixed_idx[p]] <- par_plus[fixed_idx[p]] + eps
    rep_plus <- obj$report(par_plus)
    c2_plus <- c2_from_report(rep_plus)
    if (!is.finite(c2_plus)) {
      grad_c2[p] <- 0
    } else {
      grad_c2[p] <- (c2_plus - c2_hat) / eps
    }
  }

  V_fixed <- fit$sd_report$cov.fixed
  if (is.null(V_fixed) || !is.matrix(V_fixed) ||
      nrow(V_fixed) != n_fix || ncol(V_fixed) != n_fix)
    return(c(estimate = c2_hat, lower = NA_real_, upper = NA_real_))

  var_c2 <- as.numeric(t(grad_c2) %*% V_fixed %*% grad_c2)
  if (!is.finite(var_c2) || var_c2 < 0)
    return(c(estimate = c2_hat, lower = NA_real_, upper = NA_real_))
  se_c2 <- sqrt(var_c2)

  ## Transform to logit-c^2 to respect the (0, 1) support. The delta
  ## method on g(c^2) = log(c^2 / (1 - c^2)) gives
  ##   SE(g) = SE(c^2) / [c^2 (1 - c^2)].
  ## Symmetric Wald on g, back-transform via plogis().
  z <- stats::qnorm(0.5 + level / 2)
  g_hat <- stats::qlogis(c2_hat)
  jacobian_g <- 1 / (c2_hat * (1 - c2_hat))
  se_g <- se_c2 * jacobian_g
  if (!is.finite(se_g) || se_g <= 0)
    return(c(estimate = c2_hat, lower = NA_real_, upper = NA_real_))
  lo_g <- g_hat - z * se_g
  hi_g <- g_hat + z * se_g
  lo <- unname(stats::plogis(lo_g))
  hi <- unname(stats::plogis(hi_g))

  c(estimate = c2_hat, lower = lo, upper = hi)
}


#' Parametric-bootstrap confidence interval for per-trait communality
#'
#' Wraps [bootstrap_Sigma()] with `what = "communality"` and returns the
#' per-trait percentile bounds at the requested confidence level.
#'
#' @inheritParams .communality_wald_ci
#' @param nsim Integer; number of bootstrap replicates. Default 200.
#' @param seed Optional RNG seed for reproducibility.
#'
#' @return Length-3 numeric vector with names `estimate`, `lower`,
#'   `upper`.
#'
#' @keywords internal
#' @noRd
.communality_bootstrap_ci <- function(fit, tier, trait_idx,
                                      level = 0.95,
                                      nsim = 200L, seed = NULL) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  if (!is.numeric(level) || length(level) != 1L ||
      level <= 0 || level >= 1)
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  if (!is.numeric(nsim) || length(nsim) != 1L || nsim < 1)
    cli::cli_abort("{.arg nsim} must be a positive integer.")
  if (!is.numeric(trait_idx) || length(trait_idx) != 1L)
    cli::cli_abort("{.arg trait_idx} must be a single integer.")
  trait_idx <- as.integer(trait_idx)

  tier_in <- tier
  tier <- .normalise_level(tier, arg_name = "tier")
  if (!tier %in% c("B", "W", "phy"))
    cli::cli_abort(
      "Communality is defined for tiers {.val unit}, {.val unit_obs}, or {.val phy}; got {.val {tier_in}}."
    )

  rr_used <- switch(
    tier,
    B = isTRUE(fit$use$rr_B),
    W = isTRUE(fit$use$rr_W),
    phy = isTRUE(fit$use$phylo_rr)
  )
  if (!rr_used)
    cli::cli_abort(
      "Communality at tier {.val {tier_in}} requires a {.code latent()} term."
    )

  trait_names <- levels(fit$data[[fit$trait_col]])
  T_n <- length(trait_names)
  if (trait_idx < 1L || trait_idx > T_n)
    cli::cli_abort(
      "{.arg trait_idx} must be in 1:{T_n}; got {trait_idx}."
    )

  boot <- suppressMessages(suppressWarnings(bootstrap_Sigma(
    fit,
    n_boot = as.integer(nsim),
    level  = .canonical_level_name(tier),
    what   = "communality",
    conf   = level,
    seed   = seed,
    progress = FALSE
  )))
  key <- paste0("communality_", tier)
  pe <- boot$point_est[[key]]
  lo <- boot$ci_lower[[key]]
  hi <- boot$ci_upper[[key]]
  if (is.null(pe) || is.null(lo) || is.null(hi) ||
      length(pe) < trait_idx)
    return(c(estimate = NA_real_, lower = NA_real_, upper = NA_real_))

  c(estimate = unname(pe[trait_idx]),
    lower    = unname(lo[trait_idx]),
    upper    = unname(hi[trait_idx]))
}
