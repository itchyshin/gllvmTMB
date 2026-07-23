## Per-trait repeatability with confidence intervals.
## extract_repeatability() is the canonical user-facing function
## for the per-trait repeatability/ICC R_t = v_B,t / (v_B,t + v_W,t),
## with Wald (default) and bootstrap confidence intervals. The former profile
## token is accepted only to fail loudly with a typed withdrawal.
##
## Conceptual prior: McCune/Nakagawa coxme_icc_ci() in
## https://github.com/kelseybmccune/Time-to-Event_Repeatability/blob/main/R/rptRsurv.R

#' Per-trait repeatability with confidence intervals
#'
#' Returns the per-trait repeatability
#' \deqn{R_t = v_{B,t} / (v_{B,t} + v_{W,t}),}
#' where
#' \deqn{v_{B,t} = [\Lambda_B\Lambda_B^\top]_{tt} + \sigma^2_{B,t}}
#' and
#' \deqn{v_{W,t} = [\Lambda_W\Lambda_W^\top]_{tt} + \sigma^2_{W,t} + \sigma^2_{d,t}.}
#' The first two terms include the shared latent and diagonal companion variance
#' at the unit and observation tiers; \eqn{\sigma^2_{d,t}} is the
#' family-specific link residual used for non-Gaussian traits. The function is
#' intended for a fit returned by [gllvmTMB()] with the relevant ordinary unit
#' and observation-level components.
#' Also known as the intraclass correlation coefficient (ICC) at the unit
#' level.
#'
#' @section Interval calibration:
#' The point estimates are the supported claim. The Wald and bootstrap interval
#' methods here are provided for exploration: their empirical coverage is not
#' certified for this estimand, so treat intervals as exploratory rather than
#' coverage-calibrated. See `NEWS.md` for the current coverage status.
#'
#' @param fit A fit returned by \code{\link{gllvmTMB}}. A
#'   \code{bootstrap_Sigma} object is also accepted when it contains an
#'   \code{ICC_site} summary; in that case the function reuses the stored
#'   point estimates and percentile bounds rather than refitting.
#' @param level Confidence level. Default 0.95.
#' @param method One of \code{"wald"} (default), \code{"profile"}, or
#'   \code{"bootstrap"}. \code{"profile"} is accepted only for backwards
#'   compatibility and aborts because a defensible profile interval for
#'   canonical full-covariance repeatability is not available.
#' @param nsim Number of bootstrap replicates when
#'   \code{method = "bootstrap"}. Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @return A data frame with columns \code{trait}, \code{R} (point
#'   estimate), \code{lower}, \code{upper}, \code{method}.
#'
#' @section Method choice:
#' \itemize{
#'   \item \code{"wald"} (default): Gaussian-approximation CI via the delta method
#'     on \code{log(v_B) - log(v_W)}, transformed with \code{plogis()}.
#'   \item \code{"profile"}: withdrawn. It aborts rather than silently
#'     substituting a different interval method or estimand.
#'   \item \code{"bootstrap"}: parametric bootstrap via \code{bootstrap_Sigma()}.
#' }
#'
#' @seealso \code{\link{extract_communality}},
#'   \code{\link{extract_correlations}},
#'   \code{\link{extract_phylo_signal}},
#'   \code{\link{confint.gllvmTMB_multi}}.
#'
#' @section References:
#' Nakagawa, S. & Schielzeth, H. (2010) Repeatability for Gaussian and
#' non-Gaussian data: a practical guide for biologists. \emph{Biological
#' Reviews} \strong{85}, 935-956. \doi{10.1111/j.1469-185X.2010.00141.x}
#'
#' @export
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 1) +
#'           latent(0 + trait | site_species, d = 1),
#'   data     = df,
#'   trait    = "trait",
#'   unit     = "site",
#'   unit_obs = "site_species"
#' )
#' extract_repeatability(fit)
#' boot <- bootstrap_Sigma(fit, n_boot = 50, level = c("unit", "unit_obs"),
#'                         what = "ICC", progress = FALSE)
#' extract_repeatability(boot)
#' }
extract_repeatability <- function(
  fit,
  level = 0.95,
  method = c("wald", "profile", "bootstrap"),
  nsim = 500L,
  seed = NULL
) {
  method <- match.arg(method)
  if (method == "profile") {
    cli::cli_abort(c(
      "A profile interval for canonical full-covariance repeatability is not currently available.",
      "i" = "The former profile token estimated only a diagonal-companion ratio and omitted shared latent variance.",
      ">" = "Request {.code method = \"wald\"} or {.code method = \"bootstrap\"}, and report the method's limitations."
    ), class = "gllvmTMB_repeatability_profile_withdrawn")
  }
  if (inherits(fit, "bootstrap_Sigma")) {
    return(.repeatability_from_bootstrap(fit))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort(
      "Provide a fit returned by {.fun gllvmTMB} or a {.cls bootstrap_Sigma} object."
    )
  }
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  if (method == "wald") {
    ## Wald CI for FULL-Sigma R = vB[t] / (vB[t] + vW[t]), where
    ##   vB[t] = (Lambda_B Lambda_B^T)[t,t] + sd_B[t]^2
    ##   vW[t] = (Lambda_W Lambda_W^T)[t,t] + sd_W[t]^2 + sigma2_d[t]
    ## (Bell 2009; Nakagawa & Schielzeth 2010 latent-scale formula).
    ## sigma2_d[t] is the per-trait distribution-specific / observation-
    ## level latent-scale residual (0 for Gaussian, pi^2/3 for
    ## binomial-logit, log(1 + 1/mu_t) for Poisson, etc.) — see
    ## link_residual_per_trait() in R/extract-sigma.R. Added in M1.6;
    ## pre-fix code omitted this term, biasing repeatability upward
    ## (toward 1) on non-Gaussian fits.
    ## Delta method on the log-odds: log_v[t] = log(vB[t]) - log(vW[t]),
    ## R[t] = plogis(log_v[t]). SE(log_v) computed via numerical
    ## Jacobian of log_v wrt the fixed parameters, times the joint
    ## fixed-parameter covariance from sd_report.
    cov_fix <- if (!is.null(fit$sd_report)) fit$sd_report$cov.fixed else NULL
    if (is.null(cov_fix)) {
      cli::cli_abort(
        "Wald repeatability requires {.code sd_report}; check Hessian."
      )
    }
    par_full_at_mle <- fit$tmb_obj$env$last.par.best
    random_idx <- fit$tmb_obj$env$random
    fix_idx <- if (length(random_idx) > 0L) {
      setdiff(seq_along(par_full_at_mle), random_idx)
    } else {
      seq_along(par_full_at_mle)
    }
    par_fix_at_mle <- par_full_at_mle[fix_idx]

    ## M1.6 fix (2026-05-17): add the per-trait link-residual variance
    ## to vW so the latent-scale repeatability is correctly defined for
    ## non-Gaussian / mixed-family fits. For Gaussian traits the link
    ## residual is 0 and the formula reduces to the previous behaviour
    ## exactly. The link residual is evaluated once at the MLE and
    ## treated as a constant w.r.t. theta_fix in the delta-method
    ## Jacobian — exact for binomial / probit / cloglog (link-defined
    ## constants); first-order approximation for Poisson / NB / Gamma
    ## where sigma2_d depends on fitted mu / phi. Improving Jacobian
    ## accuracy on those families is M3 inference-completeness work.
    sigma2_d <- unname(link_residual_per_trait(fit))

    log_v_function <- function(theta_fix) {
      par_full <- par_full_at_mle
      par_full[fix_idx] <- theta_fix
      rep <- fit$tmb_obj$report(par_full)
      Lambda_B <- if (is.null(rep$Lambda_B)) matrix(0, T, 0) else rep$Lambda_B
      Lambda_W <- if (is.null(rep$Lambda_W)) matrix(0, T, 0) else rep$Lambda_W
      sd_B <- if (is.null(rep$sd_B)) rep(0, T) else rep$sd_B
      sd_W <- if (is.null(rep$sd_W)) rep(0, T) else rep$sd_W
      vB <- diag(Lambda_B %*% t(Lambda_B)) + sd_B^2
      vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2 + sigma2_d
      if (any(vB <= 0) || any(vW <= 0)) {
        cli::cli_abort(
          "Wald repeatability needs vB > 0 and vW > 0; refit with ordinary {.fn latent} or standalone {.fn indep} at each tier."
        )
      }
      log(vB) - log(vW)
    }

    ## Inline forward-difference Jacobian (T x length(fix_idx))
    log_v_at_mle <- log_v_function(par_fix_at_mle)
    n_par <- length(par_fix_at_mle)
    eps <- 1e-6
    J <- matrix(0, T, n_par)
    for (j in seq_len(n_par)) {
      tp <- par_fix_at_mle
      tp[j] <- tp[j] + eps
      J[, j] <- (log_v_function(tp) - log_v_at_mle) / eps
    }
    var_log_v <- diag(J %*% cov_fix %*% t(J))
    se <- sqrt(pmax(var_log_v, 0))

    z <- stats::qnorm(1 - (1 - level) / 2)
    R_hat <- stats::plogis(log_v_at_mle)
    lo <- stats::plogis(log_v_at_mle - z * se)
    hi <- stats::plogis(log_v_at_mle + z * se)

    return(data.frame(
      trait = trait_names,
      R = unname(R_hat),
      lower = unname(lo),
      upper = unname(hi),
      method = "wald",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## bootstrap
  boot <- suppressMessages(bootstrap_Sigma(
    fit,
    n_boot = as.integer(nsim),
    level = c("unit", "unit_obs"),
    what = "ICC",
    conf = level,
    seed = seed,
    progress = FALSE
  ))
  pe <- boot$point_est$ICC_site
  lo <- boot$ci_lower$ICC_site
  hi <- boot$ci_upper$ICC_site
  if (is.null(pe)) {
    cli::cli_abort("ICC bootstrap failed; need both B and W tiers in the fit.")
  }
  data.frame(
    trait = trait_names,
    R = as.numeric(pe),
    lower = as.numeric(lo),
    upper = as.numeric(hi),
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
}

.repeatability_bootstrap_bound <- function(x, trait_names, field) {
  if (is.null(x)) {
    return(rep(NA_real_, length(trait_names)))
  }
  if (!is.numeric(x)) {
    cli::cli_abort(
      "Bootstrap repeatability {.field {field}} must be numeric.",
      class = "gllvmTMB_invalid_bootstrap_Sigma"
    )
  }
  out <- as.numeric(x)
  nm <- names(x)
  if (!is.null(nm)) {
    idx <- match(trait_names, nm)
    if (anyNA(idx)) {
      cli::cli_abort(
        "Bootstrap repeatability {.field {field}} names do not cover every point-estimate trait.",
        class = "gllvmTMB_invalid_bootstrap_Sigma"
      )
    }
    out <- out[idx]
  }
  if (length(out) != length(trait_names)) {
    cli::cli_abort(
      "Bootstrap repeatability {.field {field}} does not match the point-estimate length.",
      class = "gllvmTMB_invalid_bootstrap_Sigma"
    )
  }
  out
}

.repeatability_from_bootstrap <- function(boot) {
  if (!is.list(boot)) {
    cli::cli_abort(c(
      "Malformed {.cls bootstrap_Sigma} object.",
      "i" = "The object must be a list containing the stored bootstrap summaries."
    ), class = "gllvmTMB_invalid_bootstrap_Sigma")
  }
  pe <- if (is.list(boot$point_est)) boot$point_est$ICC_site else NULL
  if (is.null(pe)) {
    cli::cli_abort(c(
      "No repeatability / ICC bootstrap summary is available.",
      "i" = "Call {.fun bootstrap_Sigma} with {.code what = \"ICC\"} and both {.code level = c(\"unit\", \"unit_obs\")}."
    ), class = "gllvmTMB_invalid_bootstrap_Sigma")
  }
  if (!is.numeric(pe) || length(pe) == 0L || any(!is.finite(pe))) {
    cli::cli_abort(c(
      "Malformed {.cls bootstrap_Sigma} repeatability summary.",
      "i" = "{.code point_est$ICC_site} must be a non-empty finite numeric vector."
    ), class = "gllvmTMB_invalid_bootstrap_Sigma")
  }
  trait_names <- names(pe)
  if (is.null(trait_names)) {
    trait_names <- paste0("trait_", seq_along(pe))
  }
  lower <- .repeatability_bootstrap_bound(
    boot$ci_lower$ICC_site,
    trait_names = trait_names,
    field = "ci_lower"
  )
  upper <- .repeatability_bootstrap_bound(
    boot$ci_upper$ICC_site,
    trait_names = trait_names,
    field = "ci_upper"
  )
  tbl <- data.frame(
    trait = trait_names,
    R = unname(as.numeric(pe)),
    lower = lower,
    upper = upper,
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
  attr(tbl, "notes") <- sprintf(
    "Bootstrap percentile intervals from bootstrap_Sigma(); n_boot = %s, n_failed = %s, conf = %s.",
    boot$n_boot,
    boot$n_failed,
    boot$conf
  )
  attr(tbl, "bootstrap") <- list(
    conf = boot$conf,
    n_boot = boot$n_boot,
    n_failed = boot$n_failed,
    ci_method = boot$ci_method,
    link_residual = boot$link_residual
  )
  tbl
}
