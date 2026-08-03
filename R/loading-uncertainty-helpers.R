## Private helpers for per-entry uncertainty on the reduced-rank loading
## matrix Λ. Shared by:
##  * loading_ci()                 — public Wald CI on Λ
##  * suggest_lambda_constraint()  — data-driven constraint suggestion
##    (conventions "varimax_threshold" and "wald_retention")
##
## The maths is:
##   1. Delta-method Wald SE on the un-rotated Λ via a numerical
##      Jacobian of `tmb_obj$report()` (so works for any reported
##      quantity without a C++ template change).
##   2. Standardised-loading delta inference using
##      rho[t,k] = Lambda[t,k] / sqrt(Sigma_total[t,t]). The numerical
##      Jacobian is taken against the complete fixed-parameter vector, so
##      same-trait cross-axis covariance plus fitted Psi / link-residual
##      uncertainty enter the result.
##   3. Asymmetric Wald via Fisher-z transformation of rho, with bounds
##      returned on the standardised-loading scale.
##
## Profile loading intervals now live in loading_profile() /
## loading_ci(method = "profile"). Bootstrap retention remains a later
## extension.

#' Compute Λ̂ + cov(vec(Λ̂)) at the MLE via numerical delta method
#'
#' Returns the loading matrix at the MLE plus its asymptotic covariance
#' obtained by combining a numerical Jacobian
#' `J = ∂vec(Lambda)/∂fixed_parameters` with the TMB `sdreport`
#' covariance of fixed parameters.
#'
#' Does NOT gate on confirmatory-vs-exploratory: callers (especially
#' `loading_ci()`) are responsible for that. For exploratory fits the
#' returned SE is in the lower-triangular parameterisation — meaningful
#' only as a stepping stone to a varimax-rotated SE (see
#' `.lambda_se_after_rotation()`).
#'
#' @param fit A multivariate `gllvmTMB()` fit.
#' @param internal_level One of `"B"` or `"W"` (already normalised by
#'   the caller via `.normalise_level()`).
#'
#' @return A list with `Lambda` (the n_traits × d loading matrix),
#'   `cov_vec_lambda` (the (n_traits·d)² covariance of `vec(Lambda)`),
#'   and `se_lambda` (n_traits × d matrix of marginal SEs).
#'
#' @keywords internal
#' @noRd
.lambda_se_at_mle <- function(fit, internal_level) {

  out <- .loading_delta_at_mle(
    fit = fit,
    internal_level = internal_level,
    loading_scale = "raw"
  )
  list(
    Lambda = out$Lambda,
    cov_vec_lambda = out$cov_vec,
    se_lambda = out$se
  )
}


#' Compute loading estimates and their full delta covariance at the MLE
#'
#' For `loading_scale = "standardized"`, evaluates
#' `rho[t,k] = Lambda[t,k] / sqrt(Sigma_total[t,t])` at every numerical
#' fixed-parameter perturbation. This propagates covariance among axes and
#' uncertainty in fitted denominator components such as `Psi` and
#' parameter-dependent link residuals. An optional rotation matrix is treated
#' as fixed, matching the package's existing first-order rotated-SE contract.
#'
#' @param fit A multivariate `gllvmTMB()` fit.
#' @param internal_level Internal loading level (`"B"` or `"W"`).
#' @param loading_scale One of `"raw"` or `"standardized"`.
#' @param T_mat Optional fixed orthogonal rotation matrix.
#'
#' @return A list with `Lambda`, `cov_vec`, `se`, and `loading_scale`.
#'
#' @keywords internal
#' @noRd
.loading_delta_at_mle <- function(fit,
                                  internal_level,
                                  loading_scale = c("raw", "standardized"),
                                  T_mat = NULL) {

  loading_scale <- match.arg(loading_scale)

  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      i = "Refit so {.code fit$sd_report} is populated."
    ))

  lam_name <- paste0("Lambda_", internal_level)
  if (is.null(fit$report[[lam_name]]))
    cli::cli_abort("Fit has no {.code {lam_name}} reported.")
  Lambda_raw <- as.matrix(fit$report[[lam_name]])
  if (!is.null(T_mat) && !identical(dim(T_mat), rep(ncol(Lambda_raw), 2L)))
    cli::cli_abort("Rotation matrix dimension mismatch.")

  evaluate_loading <- function(report) {
    Lambda <- as.matrix(report[[lam_name]])
    if (!is.null(T_mat)) Lambda <- Lambda %*% T_mat
    if (identical(loading_scale, "raw")) return(Lambda)

    fit_at_par <- fit
    fit_at_par$report <- report
    .standardize_loadings_by_total_variance(
      fit_at_par,
      Lambda = Lambda,
      level = .canonical_level_name(internal_level)
    )
  }

  Lambda <- evaluate_loading(fit$report)

  obj      <- fit$tmb_obj
  par_best <- obj$env$last.par.best
  random_idx <- if (length(obj$env$random) > 0L)
    obj$env$random else integer(0)
  fixed_idx  <- setdiff(seq_along(par_best), random_idx)

  Lambda_vec <- as.numeric(Lambda)
  n_par <- length(fixed_idx)
  J <- matrix(0, length(Lambda_vec), n_par)
  eps <- 1e-6
  for (p in seq_len(n_par)) {
    par_plus <- par_best
    par_plus[fixed_idx[p]] <- par_plus[fixed_idx[p]] + eps
    rep_plus <- obj$report(par_plus)
    J[, p] <- (as.numeric(evaluate_loading(rep_plus)) - Lambda_vec) / eps
  }

  cov_lambda <- J %*% fit$sd_report$cov.fixed %*% t(J)
  list(
    Lambda = Lambda,
    cov_vec = cov_lambda,
    se = matrix(
      sqrt(pmax(diag(cov_lambda), 0)),
      nrow = nrow(Lambda),
      ncol = ncol(Lambda)
    ),
    loading_scale = loading_scale
  )
}


#' Propagate cov(vec(Λ̂)) through a fixed rotation matrix
#'
#' If `Λ_rot = Λ %*% T` for an orthogonal rotation `T`, then
#' `vec(Λ_rot) = (Tᵀ ⊗ I) vec(Λ)` and
#' `cov(vec(Λ_rot)) = (Tᵀ ⊗ I) cov(vec(Λ)) (T ⊗ I)`.
#'
#' This treats `T` as deterministic — a first-order approximation
#' because varimax `T` is itself a function of `Λ̂`. The approximation
#' is good when factors are well-separated.
#'
#' @keywords internal
#' @noRd
.lambda_se_after_rotation <- function(Lambda, cov_vec_lambda, T_mat) {
  n  <- nrow(Lambda)
  d  <- ncol(Lambda)
  if (!identical(dim(T_mat), c(d, d)))
    cli::cli_abort("Rotation matrix dimension mismatch.")
  Lambda_rot <- Lambda %*% T_mat
  J_rot <- t(T_mat) %x% diag(n)            # (n·d) × (n·d)
  cov_rot <- J_rot %*% cov_vec_lambda %*% t(J_rot)
  list(
    Lambda    = Lambda_rot,
    cov_vec   = cov_rot,
    se_lambda = matrix(sqrt(pmax(diag(cov_rot), 0)), nrow = n, ncol = d)
  )
}


#' Asymmetric Wald CI on a standardised loading via Fisher-z
#'
#' Pipeline: rho -> z = atanh(rho) -> symmetric Wald on z -> tanh. The
#' caller supplies SE(rho) from the complete joint delta method. The returned
#' bounds are therefore on the standardised-loading scale and lie in (-1, 1).
#'
#' Vectorised over entries.
#'
#' @param rho numeric vector of standardised-loading estimates.
#' @param se_rho numeric vector of delta-method SEs on the same scale.
#' @param conf_level confidence level (scalar in (0, 1)).
#'
#' @return list with `lower`, `upper`, `rho_hat`, `z_hat`, and `se_z`.
#'
#' @keywords internal
#' @noRd
.lambda_ci_asym <- function(rho, se_rho, conf_level = 0.95) {

  if (any(!is.finite(rho)) || any(!is.finite(se_rho)))
    cli::cli_abort("Standardised loading estimates and SEs must be finite.")
  if (any(abs(rho[se_rho > 0]) >= 1 - sqrt(.Machine$double.eps)))
    cli::cli_abort(c(
      "Fisher-z loading intervals are unavailable at the boundary {.code |rho| = 1}.",
      i = "Use {.code method = \"wald\"} with {.code loading_scale = \"standardized\"} instead."
    ))

  fixed <- se_rho == 0
  rho_hat <- pmin(pmax(rho, -1 + .Machine$double.eps),
                  1 - .Machine$double.eps)
  z_hat   <- atanh(rho_hat)
  se_z    <- se_rho / pmax(1 - rho_hat^2, .Machine$double.eps)
  zcrit   <- stats::qnorm(0.5 + conf_level / 2)

  z_lo <- z_hat - zcrit * se_z
  z_hi <- z_hat + zcrit * se_z
  rho_lo <- tanh(z_lo)
  rho_hi <- tanh(z_hi)
  rho_lo[fixed] <- rho[fixed]
  rho_hi[fixed] <- rho[fixed]

  list(
    lower   = rho_lo, upper = rho_hi,
    rho_hat = rho_hat,   z_hat = z_hat, se_z = se_z
  )
}


#' Build eye-shaped polygon coordinates from the Gaussian sampling density
#'
#' For each row in `df`, generates `n` points around a lens-shaped polygon
#' centred at `(x_pos, estimate)`, with vertical extent `[lower, upper]`
#' and **horizontal width proportional to the Gaussian sampling density**
#' `exp(-((y - estimate) / se)^2 / 2)`. Peak width is `width_max` at the
#' estimate; at the 95% CI bound (≈ 1.96 SE) the width is about 14.6% of
#' peak, giving a visually clear lens taper that the earlier ellipse
#' shape (`sqrt(1 - rel^2)`) did not produce at typical panel aspect
#' ratios.
#'
#' This is the geometry of the Confidence Eye (a.k.a. "raindrop") plot:
#' the polygon's *shape* IS the sampling distribution of $\hat\Lambda$,
#' truncated to the CI bounds. The reader sees not just *where* the
#' estimate lies and *how wide* the interval is, but also that the
#' distribution is concentrated near the centre.
#'
#' Pinned entries (`se == 0`) emit no polygon — their hollow point is
#' drawn by the caller via `geom_point`.
#'
#' @param df Data frame with columns `estimate`, `se`, `lower`, `upper`.
#' @param x_pos Numeric vector, length `nrow(df)`. Where each polygon is
#'   centred on the horizontal axis.
#' @param width_max Maximum half-width at the estimate. Defaults to 0.7
#'   (i.e. 70% of one x-axis unit) — visible lens shape at typical
#'   panel densities (20 species per panel); raise/lower as needed for
#'   denser/sparser panels.
#' @param n Polygon vertex count per side. 60 gives a visually smooth
#'   eye without dominating the SVG size.
#'
#' @return A long data frame with columns `.id` (polygon group), `x`,
#'   `y`. Rows for pinned entries are absent.
#'
#' @keywords internal
#' @noRd
.eye_polygon_df <- function(df, x_pos, width_max = 0.7, n = 60L) {
  needed <- c("estimate", "se", "lower", "upper")
  if (!all(needed %in% names(df)))
    cli::cli_abort("{.code df} must have columns {.code {needed}}.")
  if (length(x_pos) != nrow(df))
    cli::cli_abort("{.code x_pos} must have length {.code nrow(df)}.")

  out_list <- vector("list", nrow(df))
  for (i in seq_len(nrow(df))) {
    est <- df$estimate[i]; se <- df$se[i]
    lo  <- df$lower[i];    hi <- df$upper[i]
    xp  <- x_pos[i]
    ## Skip pinned or degenerate entries; their hollow point is handled
    ## by geom_point. We don't require `se` to be available -- the profile
    ## path doesn't compute a delta-method SE but still produces a usable
    ## CI -- so we derive an effective SE from the CI width when `se` is
    ## missing (Gaussian back-of-the-envelope: 95% half-width / 1.96).
    if (is.na(lo) || is.na(hi) ||
        (hi - lo) < .Machine$double.eps * 10)
      next
    se_eff <- if (is.na(se) || se <= 0) (hi - lo) / (2 * 1.96) else se
    y_seq <- seq(lo, hi, length.out = n)
    ## Gaussian density width (truncated to the CI). Peak = width_max at
    ## y = est; ~14.6% of peak at the 95% CI bound; sharp lens taper.
    w_at <- width_max * exp(-((y_seq - est)^2) / (2 * se_eff^2))
    out_list[[i]] <- data.frame(
      .id = i,
      x   = c(xp - w_at / 2, xp + rev(w_at) / 2),
      y   = c(y_seq,         rev(y_seq))
    )
  }
  out_list <- out_list[!vapply(out_list, is.null, logical(1))]
  if (length(out_list) == 0L)
    return(data.frame(.id = integer(0), x = numeric(0), y = numeric(0)))
  do.call(rbind, out_list)
}


#' Asymmetric Wald retention probability P(|rho_{i,k}| > threshold_rho)
#'
#' The retention question lives naturally on the standardised loading
#' scale (Comrey-Lee 0.30 / 0.40 / 0.50 thresholds are ρ-scale
#' conventions). On the z = atanh(ρ) scale the sampling distribution
#' is approximately Normal, so the probability is a closed-form pnorm
#' calculation.
#'
#' @param rho,se_rho see `.lambda_ci_asym()`.
#' @param threshold_rho threshold on the standardised loading scale
#'   (e.g. 0.30 for Comrey-Lee). Scalar.
#'
#' @return numeric vector of retention probabilities between 0 and 1.
#'
#' @keywords internal
#' @noRd
.salience_prob_asym <- function(rho, se_rho, threshold_rho) {
  rho_hat <- pmin(pmax(rho, -1 + .Machine$double.eps),
                  1 - .Machine$double.eps)
  z_hat   <- atanh(rho_hat)
  se_z    <- se_rho / pmax(1 - rho_hat^2, .Machine$double.eps)
  z_c     <- atanh(threshold_rho)

  fixed <- se_rho == 0
  prob <- numeric(length(rho))
  prob[!fixed] <-
    1 - stats::pnorm((z_c - z_hat[!fixed]) / se_z[!fixed]) +
        stats::pnorm((-z_c - z_hat[!fixed]) / se_z[!fixed])
  prob[fixed] <- as.numeric(abs(rho[fixed]) > threshold_rho)
  prob
}
