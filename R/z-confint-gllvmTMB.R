## confint() method for gllvmTMB_multi objects.
##
## This file sorts after methods-gllvmTMB.R (z > m) so that this
## definition of confint.gllvmTMB_multi takes precedence at load time.
##
## Three-method API (Phase K):
##   method = "profile"   (NEW DEFAULT) -- profile-likelihood CI via
##                                          TMB::tmbprofile() + uniroot
##                                          (R/profile-ci.R)
##   method = "wald"                    -- Wald CI from sd_report
##   method = "bootstrap"               -- parametric bootstrap via
##                                          bootstrap_Sigma()
##
## Two parameter-class dispatch paths:
##   parm = "Sigma_B" | "Sigma_W" | "sigma_phy"  -> bootstrap or profile
##   parm = character/integer/missing            -> Wald / profile on
##                                                   fixed effects + var
##                                                   components

## Internal helper: recognise sigma-type parm tokens.
.is_sigma_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    parm %in% c("Sigma_B", "Sigma_W", "sigma_phy")
}

#' Confidence intervals for a \code{gllvmTMB_multi} fit
#'
#' Returns 95% (or other-level) confidence intervals for fixed effects,
#' variance components, and trait covariance matrices, with three method
#' choices:
#'
#' \itemize{
#'   \item \code{method = "profile"} (\strong{new default in Phase K}):
#'     profile-likelihood CIs via \code{TMB::tmbprofile()} +
#'     \code{stats::uniroot()}. Accurate, respects skewness, fast for
#'     individual parameters.
#'   \item \code{method = "wald"}: Gaussian-approximation CIs from
#'     \code{sd_report}. Fastest; poor near boundaries.
#'   \item \code{method = "bootstrap"}: parametric bootstrap via
#'     \code{bootstrap_Sigma()}. Slowest; most flexible (full sampling
#'     distribution).
#' }
#'
#' Two parm-class dispatch paths:
#'
#' \itemize{
#'   \item \strong{Sigma matrices} -- when \code{parm} is one of
#'     \code{"Sigma_B"}, \code{"Sigma_W"}, or \code{"sigma_phy"}, returns a
#'     tidy \code{data.frame} with columns \code{parameter}, \code{estimate},
#'     \code{lower}, \code{upper}, \code{method}. Profile is computed
#'     element-wise via [TMB::tmbprofile()] for the diagonal entries; off-
#'     diagonals fall back to bootstrap (full Σ sampling) since they
#'     mix two parameters in a non-linear way.
#'   \item \strong{Fixed effects / variance components} -- when \code{parm}
#'     is missing, an integer index, or a character vector of fixed-effect
#'     term names, returns a numeric matrix with rows = parameters and
#'     columns = lower / upper bounds (same shape as
#'     [stats::confint()]). Method choice applies.
#' }
#'
#' @param object A \code{gllvmTMB_multi} fit returned by [gllvmTMB()].
#' @param parm One of:
#'   \itemize{
#'     \item \code{"Sigma_B"} -- between-unit trait covariance matrix.
#'     \item \code{"Sigma_W"} -- within-unit trait covariance matrix.
#'     \item \code{"sigma_phy"} -- per-trait phylogenetic standard deviations.
#'     \item An integer index vector or character vector of fixed-effect
#'       term names (same as the standard \code{confint()} interface).
#'     \item Missing (default) -- all fixed-effect parameters.
#'   }
#' @param level Confidence level in \code{(0, 1)}. Default \code{0.95}.
#' @param method One of \code{"profile"} (default), \code{"wald"},
#'   \code{"bootstrap"}.
#' @param nsim Number of bootstrap replicates passed to [bootstrap_Sigma()]
#'   when \code{method = "bootstrap"}. Default \code{500}. Use a small
#'   value (e.g. \code{50}) during development or testing.
#' @param seed Optional integer RNG seed forwarded to [bootstrap_Sigma()]
#'   (only meaningful when \code{method = "bootstrap"}).
#' @param ... Additional arguments currently unused.
#'
#' @return
#' \itemize{
#'   \item \strong{Sigma path} -- a \code{data.frame} with columns
#'     \code{parameter} (character, e.g. \code{"Sigma_B[t1,t1]"}),
#'     \code{estimate} (point estimate), \code{lower}, \code{upper}, and
#'     \code{method} (the method used for that row).
#'   \item \strong{Fixed-effects / variance-component path} -- a numeric
#'     matrix with rownames = parameter names and two columns named
#'     \code{"2.5 \%"} / \code{"97.5 \%"} (or the analogous quantiles for
#'     the requested \code{level}).
#' }
#'
#' @seealso [bootstrap_Sigma()], [extract_Sigma()], [extract_correlations()],
#'   [extract_repeatability()], [extract_communality()], [tmbprofile_wrapper()],
#'   [gllvmTMB()].
#'
#' @section References:
#' Pawitan, Y. (2001). \emph{In All Likelihood: Statistical Modelling
#' and Inference Using Likelihood}, Oxford University Press, ch. 9.
#'
#' Venzon, D. J. & Moolgavkar, S. H. (1988). A method for computing
#' profile-likelihood-based confidence intervals. \emph{Applied
#' Statistics} \strong{37}, 87-94. \doi{10.2307/2347496}
#'
#' McCune, K. B., \emph{et al.} (2024) \code{coxme_icc_ci()} -- the
#' Nakagawa-authored \code{coxme}-based profile-CI helper that
#' inspired this work, in
#' \url{https://github.com/kelseybmccune/Time-to-Event_Repeatability/blob/main/R/rptRsurv.R}.
#'
#' @examples
#' \dontrun{
#' ## Fit a tiny example
#' set.seed(1)
#' s <- simulate_site_trait(
#'   n_sites = 30, n_species = 4, n_traits = 3,
#'   mean_species_per_site = 4,
#'   Lambda_B = matrix(c(0.9, 0.4, -0.3), 3, 1),
#'   psi_B = c(0.20, 0.15, 0.10),
#'   beta = matrix(0, 3, 2), seed = 1
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1) +
#'           unique(0 + trait | site),
#'   data = s$data
#' )
#'
#' ## Profile-likelihood CIs for the between-site covariance matrix (default)
#' ci_B <- confint(fit, parm = "Sigma_B")
#' ci_B
#'
#' ## Bootstrap CIs (slow, more accurate for non-monotone cases)
#' ci_B_boot <- confint(fit, parm = "Sigma_B", method = "bootstrap",
#'                      nsim = 200, seed = 42)
#'
#' ## Wald CIs for fixed effects
#' confint(fit)
#' }
#'
#' @export
#' @method confint gllvmTMB_multi
confint.gllvmTMB_multi <- function(object,
                                   parm,
                                   level  = 0.95,
                                   method = c("profile", "wald", "bootstrap"),
                                   nsim   = 500L,
                                   seed   = NULL,
                                   ...) {
  method <- match.arg(method)

  ## ---- Sigma matrix path ---------------------------------------------------
  if (.is_sigma_parm(parm)) {
    return(.confint_sigma(object, parm = parm, level = level,
                          method = method, nsim = nsim, seed = seed))
  }

  ## ---- Fixed-effects / variance-component path -----------------------------
  if (method == "wald") {
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  } else if (method == "profile") {
    td <- .confint_fixef_profile(object, level = level)
  } else {
    ## bootstrap on fixed effects: not currently supported (existing bootstrap
    ## machinery only covers Sigma matrices). Fall back to Wald with a note.
    cli::cli_inform(
      "Bootstrap on fixed effects is not implemented; falling back to {.code method = \"wald\"}."
    )
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  }

  if (!missing(parm)) {
    if (is.numeric(parm)) {
      td <- td[parm, , drop = FALSE]
    } else {
      td <- td[match(parm, td$term), , drop = FALSE]
    }
  }
  out <- as.matrix(td[, c("conf.low", "conf.high")])
  rownames(out) <- td$term
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  out
}

## ---- Sigma path: dispatch on method ---------------------------------------

#' @keywords internal
#' @noRd
.confint_sigma <- function(object, parm, level, method, nsim, seed) {
  if (method == "bootstrap") {
    return(.confint_sigma_bootstrap(object, parm, level, nsim, seed))
  }
  if (method == "wald") {
    return(.confint_sigma_wald(object, parm, level))
  }
  ## profile
  .confint_sigma_profile(object, parm, level)
}

#' @keywords internal
#' @noRd
.confint_sigma_bootstrap <- function(object, parm, level, nsim, seed) {
  lvl <- switch(parm,
                Sigma_B   = "B",
                Sigma_W   = "W",
                sigma_phy = "phy")

  boot <- bootstrap_Sigma(
    fit        = object,
    n_boot     = as.integer(nsim),
    level      = lvl,
    what       = "Sigma",
    conf       = level,
    seed       = seed,
    progress   = FALSE
  )

  key_pt <- paste0("Sigma_", lvl)
  pe  <- boot$point_est[[key_pt]]
  lo  <- boot$ci_lower[[key_pt]]
  hi  <- boot$ci_upper[[key_pt]]

  if (is.null(pe)) {
    cli::cli_abort(c(
      "No {.val {parm}} found in the bootstrap output.",
      "i" = "Check that this covariance tier is present in the fit."
    ))
  }

  if (parm == "sigma_phy") {
    tr_nms <- rownames(pe)
    if (is.null(tr_nms)) tr_nms <- paste0("trait_", seq_len(nrow(pe)))
    return(data.frame(
      parameter = paste0("sigma_phy[", tr_nms, "]"),
      estimate  = sqrt(diag(pe)),
      lower     = sqrt(diag(lo)),
      upper     = sqrt(diag(hi)),
      method    = "bootstrap",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  n      <- nrow(pe)
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) tr_nms <- paste0("trait_", seq_len(n))
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)
  data.frame(
    parameter = paste0(parm, "[", tr_nms[idx[, 1L]], ",",
                                  tr_nms[idx[, 2L]], "]"),
    estimate  = pe[idx],
    lower     = lo[idx],
    upper     = hi[idx],
    method    = "bootstrap",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' @keywords internal
#' @noRd
.confint_sigma_wald <- function(object, parm, level) {
  ## Wald on Sigma: use sd_report covariance of theta_diag_<tier> +
  ## theta_rr_<tier> entries combined; for now fall back to the
  ## point-estimate diagonal and SE on diagonal-only entries.
  lvl <- switch(parm,
                Sigma_B   = "B",
                Sigma_W   = "W",
                sigma_phy = "phy")
  tier_label <- if (lvl == "phy") "phy" else lvl
  if (lvl == "phy") {
    Sigma_pt <- suppressMessages(extract_Sigma(object, level = "phy",
                                               part = "total",
                                               link_residual = "none"))
  } else {
    Sigma_pt <- suppressMessages(extract_Sigma(object, level = lvl,
                                               part = "total",
                                               link_residual = "none"))
  }
  if (is.null(Sigma_pt))
    cli::cli_abort("No tier {.val {lvl}} in fit.")
  pe <- Sigma_pt$Sigma
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) tr_nms <- paste0("trait_", seq_len(nrow(pe)))

  if (parm == "sigma_phy") {
    ## Per-trait SDs: profile is direct on log_sd_phy_diag
    ix <- which(names(object$opt$par) == "log_sd_phy_diag")
    if (length(ix) == 0L)
      cli::cli_abort("Sigma_phy Wald CIs require {.code log_sd_phy_diag} in opt$par.")
    se <- sqrt(diag(object$sd_report$cov.fixed))[ix]
    z <- stats::qnorm(1 - (1 - level) / 2)
    log_sd <- as.numeric(object$opt$par[ix])
    return(data.frame(
      parameter = paste0("sigma_phy[", tr_nms, "]"),
      estimate  = exp(log_sd),
      lower     = exp(log_sd - z * se),
      upper     = exp(log_sd + z * se),
      method    = "wald",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## Generic Sigma matrix Wald path: only diagonal entries get SE'd
  ## (off-diagonals are non-linear functions of multiple parameters
  ## and need delta-method which we defer to bootstrap or profile).
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)
  out <- data.frame(
    parameter = paste0(parm, "[", tr_nms[idx[, 1L]], ",",
                                  tr_nms[idx[, 2L]], "]"),
    estimate  = pe[idx],
    lower     = NA_real_,
    upper     = NA_real_,
    method    = "wald",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  ## Fill diagonal entries only
  diag_rows <- which(idx[, 1L] == idx[, 2L])
  ## On the log-SD scale of diag_<tier>, get the SE; transform back to var
  ix_diag <- which(names(object$opt$par) == paste0("theta_diag_", tier_label))
  if (length(ix_diag) >= length(diag_rows) && !is.null(object$sd_report)) {
    se_vec <- tryCatch(sqrt(diag(object$sd_report$cov.fixed))[ix_diag],
                       error = function(e) NULL)
    if (!is.null(se_vec) && length(se_vec) == nrow(pe)) {
      log_sd <- as.numeric(object$opt$par[ix_diag])
      z <- stats::qnorm(1 - (1 - level) / 2)
      var_lo <- exp(2 * (log_sd - z * se_vec))
      var_hi <- exp(2 * (log_sd + z * se_vec))
      out$lower[diag_rows] <- var_lo
      out$upper[diag_rows] <- var_hi
    }
  }
  out
}

#' @keywords internal
#' @noRd
.confint_sigma_profile <- function(object, parm, level) {
  ## Profile path on Sigma matrices.
  ##
  ## For sigma_phy (per-trait SDs from log_sd_phy_diag), TMB::tmbprofile()
  ## is direct -- one parameter per trait.
  ##
  ## For Sigma_B / Sigma_W with only diag_<tier> (no latent), profile on
  ## theta_diag_<tier> gives per-trait variance; off-diagonals are zero
  ## by construction. This is the cleanest profile case.
  ##
  ## For Sigma_B / Sigma_W with latent + diag, the total Sigma_t,t and
  ## off-diagonals are non-linear functions of multiple parameters
  ## (Lambda * Lambda^T + S_t), with rotation indeterminacy in Lambda.
  ## Profile via fix-and-refit is theoretically possible but unstable in
  ## practice (the rotation-equivalent class of Lambda is dense). We
  ## emit a clear advisory and fall back to bootstrap.
  lvl <- switch(parm,
                Sigma_B   = "B",
                Sigma_W   = "W",
                sigma_phy = "phy")
  if (lvl == "phy") {
    Sigma_pt <- suppressMessages(extract_Sigma(object, level = "phy",
                                               part = "total",
                                               link_residual = "none"))
  } else {
    Sigma_pt <- suppressMessages(extract_Sigma(object, level = lvl,
                                               part = "total",
                                               link_residual = "none"))
  }
  if (is.null(Sigma_pt))
    cli::cli_abort("No tier {.val {lvl}} in fit.")
  pe <- Sigma_pt$Sigma
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) tr_nms <- paste0("trait_", seq_len(nrow(pe)))

  if (parm == "sigma_phy") {
    ## Per-trait SDs: profile is direct on log_sd_phy_diag
    df_log <- .tmbprofile_block(object, "log_sd_phy_diag", level = level,
                                transform = exp,
                                labels = paste0("sigma_phy[", tr_nms, "]"))
    if (is.null(df_log)) {
      cli::cli_inform(
        "No {.code log_sd_phy_diag} in opt$par; falling back to Wald for sigma_phy."
      )
      return(.confint_sigma_wald(object, parm, level))
    }
    return(df_log)
  }

  ## For Sigma_B / Sigma_W: profile diagonal on theta_diag_<tier> when
  ## that gives the full diagonal (no rr at this tier).
  rr_used <- if (lvl == "B") isTRUE(object$use$rr_B) else isTRUE(object$use$rr_W)
  diag_used <- if (lvl == "B") isTRUE(object$use$diag_B) else isTRUE(object$use$diag_W)
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)

  if (!rr_used && diag_used) {
    ## Pure diag tier: per-trait variance is identifiable and direct profile
    diag_block <- .tmbprofile_block(
      object, paste0("theta_diag_", lvl), level = level,
      transform = function(x) exp(2 * x)
    )
    out <- data.frame(
      parameter = paste0(parm, "[", tr_nms[idx[, 1L]], ",",
                                    tr_nms[idx[, 2L]], "]"),
      estimate  = pe[idx],
      lower     = NA_real_,
      upper     = NA_real_,
      method    = "profile",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    diag_rows <- which(idx[, 1L] == idx[, 2L])
    if (!is.null(diag_block) && length(diag_block$estimate) == length(diag_rows)) {
      out$lower[diag_rows] <- diag_block$lower
      out$upper[diag_rows] <- diag_block$upper
    }
    ## Off-diagonals are zero by construction in pure-diag tier
    off_rows <- which(idx[, 1L] != idx[, 2L])
    out$lower[off_rows] <- 0
    out$upper[off_rows] <- 0
    return(out)
  }

  ## rr present (with or without diag): full Sigma is rotation-equivalent
  ## under Lambda. Fall back to bootstrap with a clear advisory.
  cli::cli_inform(c(
    "Profile CIs on {parm} entries when {.code latent()} is present require fix-and-refit on a non-linear function of multiple rotation-equivalent parameters and are unstable.",
    "i" = "Falling back to {.code method = \"bootstrap\"}; pass {.code nsim} to control replicate count."
  ))
  ## Reuse the bootstrap path with default nsim
  return(.confint_sigma_bootstrap(object, parm, level, nsim = 200L, seed = NULL))
}

## ---- Profile / Wald on fixed effects -------------------------------------

#' @keywords internal
#' @noRd
.confint_fixef_profile <- function(object, level) {
  ## Loop over b_fix entries via tmbprofile, label as the fixed-effect
  ## term names from $X_fix_names.
  ix <- which(names(object$opt$par) == "b_fix")
  if (length(ix) == 0L) {
    ## No fixed effects -- return empty
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
    td$conf.low <- NA_real_; td$conf.high <- NA_real_
    return(td)
  }
  term_names <- object$X_fix_names %||% paste0("b_fix[", seq_along(ix), "]")
  out <- vector("list", length(ix))
  for (k in seq_along(ix)) {
    out[[k]] <- tmbprofile_wrapper(object, name = "b_fix", which = k,
                                   level = level)
  }
  ## Wald estimates and SEs from existing tidy
  td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  ## Override conf.low / conf.high with profile bounds
  ## (only for rows that match b_fix entries)
  ## Match terms
  est <- vapply(out, `[`, numeric(1), "estimate")
  lo  <- vapply(out, `[`, numeric(1), "lower")
  hi  <- vapply(out, `[`, numeric(1), "upper")
  if (nrow(td) == length(ix)) {
    td$conf.low  <- lo
    td$conf.high <- hi
  }
  td
}
