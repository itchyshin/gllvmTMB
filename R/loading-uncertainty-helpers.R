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
##   2. Asymmetric Wald via Fisher-z transformation: transform
##      Λ → standardised loading ρ = Λ / sqrt(Λ² + σ²_d) (bounded
##      in (-1, 1)), then z = atanh(ρ), do symmetric Wald on z,
##      back-transform. Captures the bounded-support asymmetry that
##      symmetric Wald on Λ ignores; matches the shape (not the exact
##      magnitude) of profile and bootstrap CIs.
##
## See `~/.claude/memory/MEMORY.md` task group "Loading uncertainty"
## for the queued profile and bootstrap variants.

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

  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      i = "Refit so {.code fit$sd_report} is populated."
    ))

  lam_name <- paste0("Lambda_", internal_level)
  if (is.null(fit$report[[lam_name]]))
    cli::cli_abort("Fit has no {.code {lam_name}} reported.")
  Lambda <- as.matrix(fit$report[[lam_name]])

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
    J[, p] <- (as.numeric(rep_plus[[lam_name]]) - Lambda_vec) / eps
  }

  cov_lambda <- J %*% fit$sd_report$cov.fixed %*% t(J)
  list(
    Lambda         = Lambda,
    cov_vec_lambda = cov_lambda,
    se_lambda      = matrix(sqrt(pmax(diag(cov_lambda), 0)),
                            nrow = nrow(Lambda), ncol = ncol(Lambda))
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


#' Asymmetric Wald CI on Λ via Fisher-z on the standardised loading
#'
#' Pipeline: Λ → ρ = Λ / sqrt(Λ² + σ²_d) → z = atanh(ρ) → symmetric
#' Wald on z → back-transform to ρ via tanh → back-transform to Λ via
#' Λ = ρ √(σ²_d) / √(1 - ρ²). Captures the bounded-support asymmetry
#' (the dominant source for loadings); does NOT capture higher-order
#' log-likelihood curvature (which profile would) or joint structure
#' across parameters (which bootstrap would).
#'
#' Vectorised over entries.
#'
#' @param est numeric vector of Λ̂ estimates.
#' @param se  numeric vector of SE(Λ̂) at the same entries.
#' @param sigma_d2 link-implicit residual variance (scalar or vector,
#'   length 1 or `length(est)`).
#' @param conf_level confidence level (scalar in (0, 1)).
#'
#' @return list with `lower`, `upper` (asymmetric Λ-CI), and
#'   `rho_hat`, `z_hat`, `se_z` for diagnostics.
#'
#' @keywords internal
#' @noRd
.lambda_ci_asym <- function(est, se, sigma_d2 = 1, conf_level = 0.95) {

  ## Pinned entries (se = 0) stay pinned in the CI.
  pinned <- se == 0
  rho_hat <- est / sqrt(est^2 + sigma_d2)
  se_rho  <- se * sigma_d2 / (est^2 + sigma_d2)^(3/2)
  z_hat   <- atanh(rho_hat)
  se_z    <- se_rho / pmax(1 - rho_hat^2, .Machine$double.eps)
  zcrit   <- stats::qnorm(0.5 + conf_level / 2)

  z_lo <- z_hat - zcrit * se_z
  z_hi <- z_hat + zcrit * se_z
  rho_lo <- tanh(z_lo); rho_hi <- tanh(z_hi)
  ## Back-transform ρ → Λ: Λ = ρ √(σ²_d) / √(1 - ρ²); preserves sign.
  Lambda_lo <- rho_lo * sqrt(sigma_d2) / sqrt(pmax(1 - rho_lo^2, .Machine$double.eps))
  Lambda_hi <- rho_hi * sqrt(sigma_d2) / sqrt(pmax(1 - rho_hi^2, .Machine$double.eps))

  ## Pinned entries: CI collapses to the point estimate.
  Lambda_lo[pinned] <- est[pinned]
  Lambda_hi[pinned] <- est[pinned]

  list(
    lower   = Lambda_lo, upper = Lambda_hi,
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
    ## Skip pinned (se = 0) or degenerate entries; their hollow point is
    ## handled by geom_point.
    if (is.na(lo) || is.na(hi) || is.na(se) || se <= 0 ||
        (hi - lo) < .Machine$double.eps * 10)
      next
    y_seq <- seq(lo, hi, length.out = n)
    ## Gaussian density width (truncated to the CI). Peak = width_max at
    ## y = est; ~14.6% of peak at the 95% CI bound; sharp lens taper.
    w_at <- width_max * exp(-((y_seq - est)^2) / (2 * se^2))
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


#' Asymmetric Wald retention probability  P(|Λ_{i,k}| > threshold_rho)
#'
#' The retention question lives naturally on the standardised loading
#' scale (Comrey-Lee 0.30 / 0.40 / 0.50 thresholds are ρ-scale
#' conventions). On the z = atanh(ρ) scale the sampling distribution
#' is approximately Normal, so the probability is a closed-form pnorm
#' calculation.
#'
#' @param est,se,sigma_d2 see `.lambda_ci_asym()`.
#' @param threshold_rho threshold on the standardised loading scale
#'   (e.g. 0.30 for Comrey-Lee). Scalar.
#'
#' @return numeric vector of retention probabilities in [0, 1].
#'
#' @keywords internal
#' @noRd
.salience_prob_asym <- function(est, se, threshold_rho, sigma_d2 = 1) {
  rho_hat <- est / sqrt(est^2 + sigma_d2)
  se_rho  <- se * sigma_d2 / (est^2 + sigma_d2)^(3/2)
  z_hat   <- atanh(rho_hat)
  se_z    <- se_rho / pmax(1 - rho_hat^2, .Machine$double.eps)
  z_c     <- atanh(threshold_rho)

  ## Pinned entries (se = 0): salience probability is 1 if |est| >
  ## threshold_lambda, else 0. We use the lambda-scale threshold here
  ## because for pinned entries the z-scale would be degenerate.
  pinned <- se == 0
  thr_lambda <- threshold_rho * sqrt(sigma_d2) /
                sqrt(pmax(1 - threshold_rho^2, .Machine$double.eps))
  prob <- numeric(length(est))
  prob[!pinned] <-
    1 - stats::pnorm((z_c - z_hat[!pinned]) / se_z[!pinned]) +
        stats::pnorm((-z_c - z_hat[!pinned]) / se_z[!pinned])
  prob[pinned] <- as.numeric(abs(est[pinned]) > thr_lambda)
  prob
}
