## Per-trait repeatability with confidence intervals.
## Phase K: extract_repeatability() is the canonical user-facing function
## for the per-trait repeatability/ICC R_t = sigma2_B / (sigma2_B + sigma2_W),
## with three method choices: profile / Wald / bootstrap.
##
## Conceptual prior: McCune/Nakagawa coxme_icc_ci() in
## https://github.com/kelseybmccune/Time-to-Event_Repeatability/blob/main/R/rptRsurv.R

#' Per-trait repeatability with confidence intervals
#'
#' Returns the per-trait repeatability
#' \eqn{R_t = \sigma^2_{B,t} / (\sigma^2_{B,t} + \sigma^2_{W,t})} for a
#' fitted gllvmTMB_multi model with both \code{unique(0 + trait | <unit>)}
#' and \code{unique(0 + trait | <obs>)} terms. Also known as the
#' intraclass correlation coefficient (ICC) at the unit level.
#'
#' @param fit A \code{gllvmTMB_multi} fit returned by \code{\link{gllvmTMB}}.
#' @param level Confidence level. Default 0.95.
#' @param method One of \code{"profile"} (default), \code{"wald"},
#'   \code{"bootstrap"}.
#' @param nsim Number of bootstrap replicates when
#'   \code{method = "bootstrap"}. Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @return A data frame with columns \code{trait}, \code{R} (point
#'   estimate), \code{lower}, \code{upper}, \code{method}.
#'
#' @section Method choice:
#' \itemize{
#'   \item \code{"profile"}: profile-likelihood CI via the linear contrast
#'     \eqn{2(\theta_B - \theta_W)} in TMB::tmbprofile(). Fast and accurate.
#'   \item \code{"wald"}: Gaussian-approximation CI via the delta method
#'     on \code{plogis(2*(theta_B - theta_W))}.
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
#'           unique(0 + trait | site) +
#'           unique(0 + trait | site_species),
#'   data     = df,
#'   trait    = "trait",
#'   unit     = "site",
#'   unit_obs = "site_species"
#' )
#' extract_repeatability(fit)
#' }
extract_repeatability <- function(fit,
                                  level  = 0.95,
                                  method = c("profile", "wald", "bootstrap"),
                                  nsim   = 500L,
                                  seed   = NULL) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  method <- match.arg(method)

  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  if (method == "profile") {
    ## Full-Sigma R = vB[t]/(vB[t]+vW[t]) is a non-linear function of
    ## multiple parameters (Lambda_B / sd_B / Lambda_W / sd_W). Proper
    ## profile-likelihood CI requires Lagrange-style fix-and-refit on
    ## the ratio constraint -- not yet implemented. Fall back to the
    ## Wald CI on the same definition; the point estimate is the
    ## correct full-Sigma R from the MLE. We emit a one-shot info
    ## message per session so users know the CI is Wald-approximated
    ## without spamming on repeated calls.
    if (!isTRUE(getOption("gllvmTMB.repeatability_profile_note_shown"))) {
      cli::cli_inform(c(
        "!" = "{.code method = \"profile\"} for full-{.field Sigma} repeatability is not yet implemented; falling back to {.code method = \"wald\"}.",
        "i" = "The output's {.field method} column will report {.val wald} so the actual computation is honest.",
        ">" = "Proper profile-likelihood CI (Lagrange-style fix-and-refit on the ratio constraint) is a Phase K follow-up. For an empirical CI use {.code method = \"bootstrap\"}."
      ))
      options(gllvmTMB.repeatability_profile_note_shown = TRUE)
    }
    ## Honest labelling: don't overwrite method to "profile" when the
    ## actual computation is wald. Users see method = "wald" and the
    ## inform above tells them why their request was demoted.
    out <- Recall(fit, level = level, method = "wald")
    return(out)
  }

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
    if (is.null(cov_fix))
      cli::cli_abort("Wald repeatability requires {.code sd_report}; check Hessian.")
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
      sd_B     <- if (is.null(rep$sd_B))     rep(0, T)       else rep$sd_B
      sd_W     <- if (is.null(rep$sd_W))     rep(0, T)       else rep$sd_W
      vB <- diag(Lambda_B %*% t(Lambda_B)) + sd_B^2
      vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2 + sigma2_d
      if (any(vB <= 0) || any(vW <= 0))
        cli::cli_abort("Wald repeatability needs vB > 0 and vW > 0; refit with both {.code latent + unique} or {.code unique} alone at each tier.")
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
    lo    <- stats::plogis(log_v_at_mle - z * se)
    hi    <- stats::plogis(log_v_at_mle + z * se)

    return(data.frame(
      trait    = trait_names,
      R        = unname(R_hat),
      lower    = unname(lo),
      upper    = unname(hi),
      method   = "wald",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## bootstrap
  boot <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = as.integer(nsim), level = c("unit", "unit_obs"),
    what = "ICC", conf = level, seed = seed, progress = FALSE
  ))
  pe <- boot$point_est$ICC_site
  lo <- boot$ci_lower$ICC_site
  hi <- boot$ci_upper$ICC_site
  if (is.null(pe))
    cli::cli_abort("ICC bootstrap failed; need both B and W tiers in the fit.")
  data.frame(
    trait  = trait_names,
    R      = as.numeric(pe),
    lower  = as.numeric(lo),
    upper  = as.numeric(hi),
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
}
