## Stage 3c of the profile-CI unified framework (2026-05-28):
## drmTMB-parity profile *curves* for derived quantities. The existing
## profile_ci_X() functions in R/profile-derived.R are the
## bracket-then-bisect INVERSION endpoint; this file adds the parallel
## CURVE endpoint that returns a data.frame mirroring
## loading_profile()'s shape so users can inspect the LR curve and feed
## it into the shared plot.profile_derived() S3 method.
##
## Five new user-facing functions:
##   - profile_repeatability()   (target: R = sigma2_B / (sigma2_B + sigma2_W))
##   - profile_phylo_signal()    (target: H^2 = sigma2_phy / (sigma2_phy + sigma2_non))
##   - profile_communality()     (target: c^2 = (LL^T)_tt / Sigma_tt)
##   - profile_correlation()     (target: rho = Sigma_ij / sqrt(Sigma_ii * Sigma_jj))
##   - profile_proportions()     (target: p_c,t = sigma2_c,t / sum_c' sigma2_c',t)
##
## Each returns a data.frame with columns
##   `target`, `profile_value`, `delta_deviance`, `objective`,
##   `estimate`, `conf_level`
## plus a class attribute ("profile_<name>", "profile_derived",
## "data.frame") for plot dispatch via plot.profile_derived().
##
## Implementation strategy:
##
## All five functions use the same Lagrange-style fix-and-refit
## machinery as the existing profile_ci_communality / profile_ci_proportions
## (via .fix_and_refit_nll() from R/profile-derived.R), with the target
## function being a function of fit$opt$par that returns the derived
## quantity. For each of n_grid candidate values, we refit the model
## constraining the quantity to the candidate and record the
## constrained negative log-likelihood.
##
## For repeatability and phylo_signal -- both of which can be profiled
## via a single linear contrast in opt$par (the corresponding profile_ci_*
## uses TMB::tmbprofile() with `lincomb`) -- the target_fn here uses the
## same lincomb representation under the hood: at parameter `par`,
##   R       = plogis(2 * (par[ix_B] - par[ix_W])),
##   H^2     = plogis(2 * (par[ix_phy] - par[ix_non])),
## so the Lagrange refit reproduces what tmbprofile() would have
## computed at each grid point (just via R-side nlminb rather than
## TMB's C++ inner optim). This trades some speed for exact n_grid
## control and a uniform code path with the non-linear derived
## quantities below.
##
## For communality / correlation / proportions, target_fn rebuilds
## Lambda from the packed theta_rr block and combines it with the
## per-trait diag terms exactly as the corresponding profile_ci_*
## function does (we re-use those local builders here).

## ---- Local Lambda packer (copy of the engine packing) --------------------
## Identical to the in-function `build_Lambda` in profile_ci_communality /
## profile_ci_correlation. Pulled out so all the curve functions share
## one definition.

#' @keywords internal
#' @noRd
.build_Lambda_packed <- function(theta_rr, p, rank) {
  L <- matrix(0, p, rank)
  if (length(theta_rr) == 0L || rank == 0L) {
    return(L)
  }
  lam_diag <- theta_rr[seq_len(rank)]
  lam_lower <- theta_rr[-seq_len(rank)]
  for (j in seq_len(rank)) {
    L[j, j] <- lam_diag[j]
  }
  idx <- 1L
  for (j in seq_len(rank)) {
    if (j < p) {
      for (i in (j + 1L):p) {
        if (idx <= length(lam_lower)) {
          L[i, j] <- lam_lower[idx]
        }
        idx <- idx + 1L
      }
    }
  }
  L
}

## ---- Generic per-grid-point Lagrange refit helper ------------------------
## Evaluate the constrained negative log-likelihood at each grid point
## using .fix_and_refit_nll() from R/profile-derived.R. Returns a numeric
## vector of length(grid). NA entries indicate the constrained refit did
## not converge / the constraint could not be met to the configured
## precision.

#' @keywords internal
#' @noRd
.profile_curve_grid <- function(fit, target_fn, grid, lambda = 1e6) {
  vapply(
    grid,
    function(q0) .fix_and_refit_nll(fit, target_fn, q0, lambda = lambda),
    numeric(1)
  )
}

## All derived profile curves report LR distance from the joint MLE, not
## from the best point on a finite candidate grid. The grid minimum can sit
## above the MLE and would shrink delta_deviance, widening inverted CIs.
#' @keywords internal
#' @noRd
.profile_curve_delta_deviance <- function(objective, fit) {
  2 * (objective - as.numeric(fit$opt$objective))
}

## ---- tmbprofile-based curve worker --------------------------------------
## For derived quantities expressible as a SINGLE linear combination of
## opt$par (repeatability, phylo_signal), the corresponding
## profile_ci_*() endpoint uses TMB::tmbprofile() via tmbprofile_wrapper()
## -- evaluating the profile in TMB's C++ inner optim along the lincomb
## direction. The Lagrange fix-and-refit driver used by .profile_curve_grid()
## is a fundamentally different mechanism: it allows ALL nuisance
## parameters to drift under a soft penalty and can converge to different
## local optima at adjacent grid points (the curve becomes spike-y).
## Using tmbprofile() here keeps the curve and the bracket-bisect CI on
## the *same* profile-likelihood surface, so the curve's inverted bounds
## match profile_ci_*()'s bounds within numerical tol.
##
## `transform` maps from the user-facing scale (e.g. R in (0, 1)) back to
## the lincomb scale (e.g. qlogis(R)). Interpolation is linear in lincomb
## space, which is also what .profile_bounds() uses for tmbprofile_wrapper()
## itself -- so the curve and the CI bracket agree.
##
## Returns a numeric vector of constrained -log-likelihood values of
## length `length(grid)`, or NA at points where tmbprofile() did not
## return a finite value (e.g. outside the profile range).

#' @keywords internal
#' @noRd
.tmbprofile_curve_grid <- function(
  fit,
  lincomb,
  grid,
  transform = identity,
  ystep = 0.5,
  ytol = 2
) {
  prof <- tryCatch(
    TMB::tmbprofile(
      fit$tmb_obj,
      lincomb = lincomb,
      ystep = ystep,
      ytol = ytol,
      parm.range = c(-Inf, Inf),
      trace = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(prof) || nrow(prof) < 2L) {
    return(rep(NA_real_, length(grid)))
  }
  prof <- prof[order(prof[[1L]]), , drop = FALSE]
  prof <- prof[!duplicated(prof[[1L]]), , drop = FALSE]
  lc_grid <- transform(grid)
  stats::approx(
    x = prof[[1L]],
    y = prof[[2L]],
    xout = lc_grid,
    rule = 2L
  )$y
}

## ---- Grid builder for proportion-like quantities -------------------------
## p_hat \in [floor, ceiling]; build a symmetric grid around p_hat clamped
## to (floor, ceiling). grid_extent (the user-facing argument) is total
## width as a multiple of a robust scale; here we adopt the same
## convention as loading_profile(): grid covers
##   [p_hat - extent/2 * sc, p_hat + extent/2 * sc]
## clamped to (floor, ceiling). The default scale is a heuristic
## proportional to min(p_hat - floor, ceiling - p_hat) / 2 + 0.05, which
## keeps the grid inside the natural boundary while spanning enough range
## to bracket the chisq cutoff on a well-identified fit.

#' @keywords internal
#' @noRd
.proportion_grid <- function(
  p_hat,
  n_grid,
  grid_extent,
  floor = 1e-3,
  ceiling = 1 - 1e-3
) {
  ## Robust scale: half-distance to the nearer boundary, plus a floor so
  ## the grid still spans a useful range for p_hat near a boundary. The
  ## floor 0.15 ensures that grid_extent = 4 (the default) brackets at
  ## least ±0.3 around p_hat, matching the default search range used by
  ## .profile_ci_via_refit() so the curve covers the same chi-square
  ## crossing region the bracket-bisect reference is hunting in.
  sc <- max(min(p_hat - floor, ceiling - p_hat) / 2 + 0.05, 0.15)
  lo <- max(p_hat - grid_extent / 2 * sc, floor)
  hi <- min(p_hat + grid_extent / 2 * sc, ceiling)
  seq(lo, hi, length.out = n_grid)
}

## ---- Inverter for the curve data.frames ----------------------------------
## Mirrors .invert_profile_loadings() in R/loading-profile.R but works on
## the columnar shape produced by the profile_X() functions here. Used by
## the plot method to draw inverted CI bounds; the existing profile_ci_X()
## bracket-bisect inverter is unchanged.

#' @keywords internal
#' @noRd
.invert_profile_derived <- function(x) {
  if (!inherits(x, "profile_derived")) {
    cli::cli_abort("{.code x} must be a {.cls profile_derived} object.")
  }
  conf_level <- attr(x, "conf_level") %||% unique(x$conf_level)
  cutoff <- stats::qchisq(conf_level, df = 1L)
  ## Fast-path: when the producer stored bracket-bisect refit bounds
  ## (e.g. profile_communality() pre-computes via .profile_ci_via_refit()
  ## to side-step the non-determinism of the noisy Lagrange refit on a
  ## fixed grid), use those instead of inverting the curve. The grid is
  ## still useful for plotting the LR-curve shape; the bounds drawn on
  ## the plot and returned here come directly from uniroot.
  refit_bounds <- attr(x, "refit_bounds")
  if (!is.null(refit_bounds)) {
    estimates <- unique(x[, c("target", "estimate"), drop = FALSE])
    merged <- merge(estimates, refit_bounds, by = "target", sort = FALSE)
    out <- data.frame(
      target = merged$target,
      estimate = merged$estimate,
      lower = merged$lower,
      upper = merged$upper,
      stringsAsFactors = FALSE
    )
    rownames(out) <- out$target
    return(out)
  }
  splits <- split(x, x$target)
  ## For each curve, find the chi-square crossing on each side of the
  ## grid's MLE point. If the side's deviance is monotone (the well-behaved
  ## case for tmbprofile()-driven curves and most Lagrange-refit curves),
  ## use linear-interpolation root-finding via approxfun() + uniroot(). If
  ## the side is non-monotone -- the boundary-case signature of a noisy
  ## Lagrange refit at a near-degenerate ridge (communality with c^2_hat
  ## near 1, for example) -- a smoothing spline averages out the
  ## near-MLE alternation noise so the chi-square root matches the one
  ## .profile_ci_via_refit()'s uniroot navigates in profile_ci_*().
  out <- lapply(splits, function(d) {
    d <- d[order(d$profile_value), ]
    est <- d$estimate[1L]
    pv <- d$profile_value
    dv <- d$delta_deviance
    min_idx <- which.min(d$objective)
    if (length(min_idx) == 0L || !is.finite(d$objective[min_idx])) {
      return(data.frame(
        target = d$target[1L],
        estimate = est,
        lower = NA_real_,
        upper = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    profile_mle <- pv[min_idx]
    bound <- function(side = c("lower", "upper")) {
      side <- match.arg(side)
      ## Include the MLE point so a chi-square crossing between the last
      ## non-MLE grid point and the MLE itself is found by the linear
      ## interp path -- otherwise close-to-the-MLE bounds would extrapolate
      ## off the grid edge.
      idx <- if (side == "lower") {
        which(pv <= profile_mle)
      } else {
        which(pv >= profile_mle)
      }
      if (length(idx) < 2L) return(NA_real_)
      sub_pv <- pv[idx]
      sub_dv <- dv[idx]
      finite <- is.finite(sub_pv) & is.finite(sub_dv)
      sub_pv <- sub_pv[finite]
      sub_dv <- sub_dv[finite]
      if (length(sub_pv) < 2L) return(NA_real_)
      d_dv <- diff(sub_dv)
      monotone <- all(d_dv <= 1e-10) || all(d_dv >= -1e-10)
      val_fn <- if (monotone) {
        af <- stats::approxfun(sub_pv, sub_dv, rule = 2L)
        function(p) af(p)
      } else {
        sp <- tryCatch(
          stats::smooth.spline(sub_pv, sub_dv, spar = 0.6),
          error = function(e) NULL
        )
        if (is.null(sp)) return(NA_real_)
        function(p) stats::predict(sp, p)$y
      }
      e_lo <- val_fn(min(sub_pv)) - cutoff
      e_hi <- val_fn(max(sub_pv)) - cutoff
      if (!is.finite(e_lo) || !is.finite(e_hi)) return(NA_real_)
      if (sign(e_lo) == sign(e_hi)) return(NA_real_)
      res <- tryCatch(
        stats::uniroot(
          function(p) val_fn(p) - cutoff,
          interval = range(sub_pv),
          tol = 1e-5
        ),
        error = function(e) NULL
      )
      if (is.null(res)) NA_real_ else res$root
    }
    data.frame(
      target = d$target[1L],
      estimate = est,
      lower = bound("lower"),
      upper = bound("upper"),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

## ---- profile_repeatability() ---------------------------------------------

#' Profile-likelihood curve(s) for per-trait diag-only repeatability
#'
#' For each requested trait, sweep over a grid of candidate values of
#' the diag-only repeatability
#' \eqn{R^\text{diag}_t = \sigma^2_{\text{diag},B,t} /
#'                       (\sigma^2_{\text{diag},B,t} +
#'                        \sigma^2_{\text{diag},W,t})}
#' refit the model under each constraint (Lagrange-style fix-and-refit),
#' and return the resulting profile-likelihood curve as a tidy
#' data.frame. The output has the same columnar shape as
#' [loading_profile()] so it can be passed to the shared
#' [plot.profile_derived()] S3 method.
#'
#' This is the internal curve counterpart to the withheld diagonal-ratio
#' `profile_ci_repeatability()` prototype.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param trait_idx Integer vector of trait indices, or `NULL` for all.
#' @param n_grid Integer; number of grid points per trait. Default 21.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale (default 4 -- estimate +/- 2 scale units on each side).
#' @param conf_level Confidence level for the eventual CI inversion;
#'   stored on the output for downstream consumers.
#'
#' @return A data.frame of class `profile_repeatability`,
#'   `profile_derived`, `data.frame` with columns: `target`,
#'   `profile_value`, `objective`, `delta_deviance`, `estimate`,
#'   `conf_level`.
#'
#' @seealso [plot.profile_derived()] (LR-curve plot method).
#'
#' @keywords internal
#' @noRd
profile_repeatability <- function(
  fit,
  trait_idx = NULL,
  n_grid = 21L,
  grid_extent = 4,
  conf_level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  par_names <- names(fit$opt$par)
  ix_B <- which(par_names == "theta_diag_B")
  ix_W <- which(par_names == "theta_diag_W")
  if (length(ix_B) == 0L || length(ix_W) == 0L) {
    cli::cli_abort(c(
      "Repeatability requires both {.code theta_diag_B} and {.code theta_diag_W} in the fit.",
      "i" = "Refit with ordinary {.code latent(0 + trait | <unit>, d = K)} and {.code latent(0 + trait | <obs>, d = K)} tiers so each tier has default diagonal Psi.",
      ">" = "Use {.code indep(0 + trait | ...)} for standalone diagonal tiers."
    ))
  }
  T <- length(ix_B)
  trait_names <- levels(fit$data[[fit$trait_col]])
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  trait_idx <- as.integer(trait_idx)
  if (any(trait_idx < 1L) || any(trait_idx > T)) {
    cli::cli_abort("{.arg trait_idx} must be integers in 1:{T}.")
  }

  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    R_hat <- stats::plogis(2 * (fit$opt$par[ix_B[t]] - fit$opt$par[ix_W[t]]))
    grid <- .proportion_grid(
      p_hat = R_hat,
      n_grid = n_grid,
      grid_extent = grid_extent
    )
    ## Use tmbprofile() on the lincomb 2 * theta_diag_B[t] - 2 * theta_diag_W[t]
    ## so the curve agrees point-by-point with profile_ci_repeatability()'s
    ## tmbprofile_wrapper() path. We then interpolate the tmbprofile output
    ## from lincomb space onto our R-scale grid via qlogis().
    lc <- .zero_lincomb(fit)
    lc[ix_B[t]] <- 2
    lc[ix_W[t]] <- -2
    obj <- .tmbprofile_curve_grid(fit, lincomb = lc, grid = grid, transform = stats::qlogis)
    target_lab <- paste0("repeatability:", trait_names[t])
    out_list[[k]] <- data.frame(
      target = target_lab,
      profile_value = grid,
      objective = obj,
      delta_deviance = .profile_curve_delta_deviance(obj, fit),
      estimate = R_hat,
      conf_level = conf_level,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  out <- do.call(rbind, out_list)
  attr(out, "n_grid") <- n_grid
  attr(out, "conf_level") <- conf_level
  attr(out, "quantity") <- "R (repeatability)"
  class(out) <- c("profile_repeatability", "profile_derived", class(out))
  out
}

## ---- profile_phylo_signal() ----------------------------------------------

#' Profile-likelihood curve(s) for per-trait phylogenetic signal
#'
#' For each requested trait, sweep over a grid of candidate values of
#' the 2-component phylogenetic signal
#' \eqn{H^2_t = \sigma^2_{\text{phy},t} /
#'              (\sigma^2_{\text{phy},t} + \sigma^2_{\text{non},t})},
#' refit the model under each constraint, and return the LR curve.
#' Currently supports only the simple 2-component case (phylo_diag +
#' species-level diag); 3-component decompositions error with a note.
#'
#' Parallel CURVE endpoint to [profile_ci_phylo_signal()].
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param trait_idx Integer vector of trait indices, or `NULL` for all.
#' @param n_grid Integer; number of grid points per trait. Default 21.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale (default 4).
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A data.frame of class `profile_phylo_signal`,
#'   `profile_derived`, `data.frame`.
#'
#' @seealso [profile_ci_phylo_signal()], [plot.profile_derived()].
#'
#' @export
profile_phylo_signal <- function(
  fit,
  trait_idx = NULL,
  n_grid = 21L,
  grid_extent = 4,
  conf_level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  has_phy <- isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  if (!has_phy) {
    cli::cli_abort(c(
      "Phylogenetic signal requires a phylogenetic component.",
      "i" = "Refit with {.code phylo_latent()}."
    ))
  }
  has_simple_2comp <-
    isTRUE(fit$use$phylo_diag) &&
      isTRUE(fit$use$diag_species) &&
      !isTRUE(fit$use$rr_B) &&
      !isTRUE(fit$use$diag_B)
  if (!has_simple_2comp) {
    cli::cli_abort(c(
      "Multi-component (3+) phylogenetic signal curve not yet implemented.",
      "i" = "Currently only the simple {.code phylo_diag + diag_species} 2-component case is supported."
    ))
  }
  par_names <- names(fit$opt$par)
  ix_phy <- which(par_names == "log_sd_phy_diag")
  ix_non <- which(par_names == "theta_diag_species")
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (length(ix_phy) != T || length(ix_non) != T) {
    cli::cli_abort("Per-trait dimensions mismatch on {.code phylo_diag} / {.code theta_diag_species}.")
  }
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  trait_idx <- as.integer(trait_idx)
  if (any(trait_idx < 1L) || any(trait_idx > T)) {
    cli::cli_abort("{.arg trait_idx} must be integers in 1:{T}.")
  }

  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    H2_hat <- stats::plogis(2 * (fit$opt$par[ix_phy[t]] - fit$opt$par[ix_non[t]]))
    grid <- .proportion_grid(
      p_hat = H2_hat,
      n_grid = n_grid,
      grid_extent = grid_extent
    )
    ## Use tmbprofile() on the 2-component lincomb so the curve agrees
    ## point-by-point with profile_ci_phylo_signal()'s tmbprofile_wrapper().
    lc <- .zero_lincomb(fit)
    lc[ix_phy[t]] <- 2
    lc[ix_non[t]] <- -2
    obj <- .tmbprofile_curve_grid(fit, lincomb = lc, grid = grid, transform = stats::qlogis)
    target_lab <- paste0("phylo_signal:", trait_names[t])
    out_list[[k]] <- data.frame(
      target = target_lab,
      profile_value = grid,
      objective = obj,
      delta_deviance = .profile_curve_delta_deviance(obj, fit),
      estimate = H2_hat,
      conf_level = conf_level,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  out <- do.call(rbind, out_list)
  attr(out, "n_grid") <- n_grid
  attr(out, "conf_level") <- conf_level
  attr(out, "quantity") <- "H^2 (phylogenetic signal)"
  class(out) <- c("profile_phylo_signal", "profile_derived", class(out))
  out
}

## ---- profile_communality() -----------------------------------------------

#' Profile-likelihood curve(s) for per-trait communality
#'
#' For each requested trait at a given covariance tier, sweep over a
#' grid of candidate values of communality
#' \eqn{c^2_t = (\Lambda \Lambda^\top)_{tt} / \Sigma_{tt}} and refit
#' the model under each constraint. Internal curve counterpart to the withheld
#' `profile_ci_communality()` prototype.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param tier `"unit"` or `"unit_obs"` (legacy `"B"`/`"W"` accepted).
#' @param trait_idx Integer vector of trait indices, or `NULL` for all.
#' @param n_grid Integer; number of grid points. Default 21.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale. Default 4.
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A data.frame of class `profile_communality`,
#'   `profile_derived`, `data.frame`.
#'
#' @keywords internal
#' @noRd
profile_communality <- function(
  fit,
  tier = c("unit", "unit_obs", "B", "W"),
  trait_idx = NULL,
  n_grid = 21L,
  grid_extent = 4,
  conf_level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  tier <- match.arg(tier)
  tier_user <- if (tier %in% c("B", "W")) {
    if (tier == "B") "unit" else "unit_obs"
  } else {
    tier
  }
  tier <- .normalise_level(tier, arg_name = "tier")
  rr_used <- if (tier == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
  if (!rr_used) {
    cli::cli_abort(
      "Communality at tier {.val {tier_user}} requires a {.code latent()} term in the fit."
    )
  }
  par_names <- names(fit$opt$par)
  ix_rr <- which(par_names == paste0("theta_rr_", tier))
  ix_diag <- which(par_names == paste0("theta_diag_", tier))
  if (length(ix_rr) == 0L || length(ix_diag) == 0L) {
    cli::cli_abort(c(
      "Communality profiling requires a {.code latent()} tier with a {.code Psi} diagonal at tier {.val {tier}}.",
      "i" = "Ordinary {.code latent()} includes {.code Psi} by default; {.code latent(..., unique = FALSE)} is the explicit no-Psi subset."
    ))
  }
  d_tier <- if (tier == "B") fit$d_B else fit$d_W
  n_traits <- length(ix_diag)
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  trait_idx <- as.integer(trait_idx)
  if (any(trait_idx < 1L) || any(trait_idx > T)) {
    cli::cli_abort("{.arg trait_idx} must be integers in 1:{T}.")
  }
  c2_pt <- extract_communality(fit, level = tier)

  out_list <- vector("list", length(trait_idx))
  bounds_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    local_t <- t
    target_fn <- function(par, fit) {
      th_rr <- par[ix_rr]
      th_diag <- par[ix_diag]
      L <- .build_Lambda_packed(th_rr, p = n_traits, rank = d_tier)
      LLt <- L %*% t(L)
      shared <- LLt[local_t, local_t]
      sigma2 <- exp(2 * th_diag[local_t])
      total <- shared + sigma2
      if (!is.finite(total) || total <= 0) {
        return(NA_real_)
      }
      shared / total
    }
    c2_hat <- as.numeric(c2_pt[t])
    grid <- .proportion_grid(
      p_hat = c2_hat,
      n_grid = n_grid,
      grid_extent = grid_extent
    )
    obj <- .profile_curve_grid(fit, target_fn, grid)
    target_lab <- paste0("communality:", tier_user, ":", trait_names[t])
    out_list[[k]] <- data.frame(
      target = target_lab,
      profile_value = grid,
      objective = obj,
      delta_deviance = .profile_curve_delta_deviance(obj, fit),
      estimate = c2_hat,
      conf_level = conf_level,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    ## Compute the bounds via the same uniroot-on-.fix_and_refit_nll path
    ## that profile_ci_communality() uses, on the SAME TMB state. Storing
    ## them as an attribute keeps the curve's inverted bounds in lock-step
    ## with the bracket-bisect endpoint: the grid still provides the LR
    ## curve for plotting, but the bounds shown on the plot and returned
    ## by .invert_profile_derived() match profile_ci_communality()
    ## exactly. This is necessary because the inner Lagrange refit is
    ## non-deterministic across TMB state (every obj$fn(par) call inside
    ## nlminb mutates last.par.best), so the discrete grid and the
    ## continuous uniroot search would otherwise probe at different
    ## parameter histories and disagree.
    refit_bounds <- tryCatch(
      .profile_ci_via_refit(
        fit,
        target_fn,
        q_hat = c2_hat,
        level = conf_level,
        q_lo_hint = max(c2_hat - 0.3, 0.001),
        q_hi_hint = min(c2_hat + 0.3, 0.999),
        q_lo_floor = 0.001,
        q_hi_ceiling = 0.999
      ),
      error = function(e) list(lower = NA_real_, upper = NA_real_)
    )
    bounds_list[[k]] <- data.frame(
      target = target_lab,
      lower = refit_bounds$lower,
      upper = refit_bounds$upper,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, out_list)
  attr(out, "n_grid") <- n_grid
  attr(out, "conf_level") <- conf_level
  attr(out, "quantity") <- "c^2 (communality)"
  attr(out, "tier") <- tier
  attr(out, "refit_bounds") <- do.call(rbind, bounds_list)
  class(out) <- c("profile_communality", "profile_derived", class(out))
  out
}

## ---- profile_correlation() -----------------------------------------------

#' Profile-likelihood curve for one cross-trait correlation
#'
#' Sweep over a grid of candidate values of the cross-trait correlation
#' \eqn{\rho_{ij} = \Sigma_{ij} / \sqrt{\Sigma_{ii}\Sigma_{jj}}} at one
#' covariance tier, refit under each constraint, and return the LR
#' curve. Internal curve counterpart to the withheld
#' `profile_ci_correlation()` prototype.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param tier `"unit"`, `"unit_obs"`, `"phy"`, or `"spatial"` (legacy
#'   aliases `"B"`, `"W"`, `"spde"` accepted).
#' @param i,j Trait indices (1-based, `i < j`; canonicalised
#'   automatically).
#' @param n_grid Integer; number of grid points. Default 21.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale (clamped to `(-1, 1)`). Default 4.
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A data.frame of class `profile_correlation`,
#'   `profile_derived`, `data.frame`.
#'
#' @keywords internal
#' @noRd
profile_correlation <- function(
  fit,
  tier = c("unit", "unit_obs", "phy", "spatial", "B", "W", "spde"),
  i,
  j,
  n_grid = 21L,
  grid_extent = 4,
  conf_level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  tier <- match.arg(tier)
  tier_user <- switch(tier,
    B    = "unit",
    W    = "unit_obs",
    spde = "spatial",
    tier
  )
  tier <- .normalise_level(tier, arg_name = "tier")
  if (missing(i) || missing(j)) {
    cli::cli_abort("Provide {.arg i} and {.arg j}.")
  }
  i <- as.integer(i)
  j <- as.integer(j)
  if (i == j) {
    cli::cli_abort("Provide distinct {.arg i} and {.arg j}.")
  }
  if (i > j) {
    swap <- i
    i <- j
    j <- swap
  }
  Sigma_pt <- suppressMessages(
    extract_Sigma(
      fit,
      level = tier,
      part = "total",
      link_residual = "none",
      .skip_warn = TRUE
    )
  )
  if (is.null(Sigma_pt)) {
    cli::cli_abort("Could not extract Sigma at tier {.val {tier}}.")
  }
  rho_hat <- Sigma_pt$R[i, j]

  par_names <- names(fit$opt$par)
  if (tier == "B") {
    ix_rr <- which(par_names == "theta_rr_B")
    ix_diag <- which(par_names == "theta_diag_B")
    rank <- fit$d_B
    use_rr <- isTRUE(fit$use$rr_B)
    use_diag <- isTRUE(fit$use$diag_B)
  } else if (tier == "W") {
    ix_rr <- which(par_names == "theta_rr_W")
    ix_diag <- which(par_names == "theta_diag_W")
    rank <- fit$d_W
    use_rr <- isTRUE(fit$use$rr_W)
    use_diag <- isTRUE(fit$use$diag_W)
  } else if (tier == "phy") {
    ix_rr <- which(par_names == "theta_rr_phy")
    ix_diag <- which(par_names == "log_sd_phy_diag")
    rank <- fit$d_phy
    use_rr <- isTRUE(fit$use$phylo_rr)
    use_diag <- isTRUE(fit$use$phylo_diag)
  } else {
    ix_rr <- which(par_names == "theta_rr_spde_lv")
    ix_diag <- which(par_names == "log_tau_spde")
    rank <- fit$d_spde_lv
    use_rr <- isTRUE(fit$use$spatial_latent)
    use_diag <- isTRUE(fit$use$spatial_latent_unique)
  }
  if (!use_rr) {
    cli::cli_abort(
      "Tier {.val {tier}} has no {.code latent()} term; correlation curve not available."
    )
  }
  n_traits <- fit$n_traits
  if (i < 1L || i > n_traits || j < 1L || j > n_traits) {
    cli::cli_abort("{.arg i} / {.arg j} out of range [1, {n_traits}].")
  }

  ## Capture the i / j we resolved above; target_fn will run inside
  ## .fix_and_refit_nll() under a different local scope.
  local_i <- i
  local_j <- j
  target_fn <- function(par, fit) {
    th_rr <- if (length(ix_rr) > 0L) par[ix_rr] else numeric(0)
    L <- .build_Lambda_packed(th_rr, p = n_traits, rank = rank)
    LLt <- L %*% t(L)
    Sigma <- LLt
    if (use_diag) {
      th_diag <- par[ix_diag]
      if (tier == "spde") {
        diag(Sigma) <- diag(Sigma) + exp(-2 * th_diag)
      } else {
        diag(Sigma) <- diag(Sigma) + exp(2 * th_diag)
      }
    }
    if (!is.finite(Sigma[local_i, local_i]) ||
          !is.finite(Sigma[local_j, local_j]) ||
          Sigma[local_i, local_i] <= 0 ||
          Sigma[local_j, local_j] <= 0) {
      return(NA_real_)
    }
    Sigma[local_i, local_j] / sqrt(Sigma[local_i, local_i] * Sigma[local_j, local_j])
  }

  ## Correlation grid: clamp to (-0.999, 0.999) and scale by distance to
  ## the boundary, like .proportion_grid() but symmetric around (-1, 1).
  ## Floor sc at 0.15 to match the search range used by
  ## .profile_ci_via_refit() (±0.3 from rho_hat) so the curve brackets the
  ## same chi-square crossing region the bracket-bisect reference uses.
  sc <- max(min(rho_hat - (-0.999), 0.999 - rho_hat) / 2 + 0.05, 0.15)
  lo <- max(rho_hat - grid_extent / 2 * sc, -0.999)
  hi <- min(rho_hat + grid_extent / 2 * sc, 0.999)
  grid <- seq(lo, hi, length.out = n_grid)
  obj <- .profile_curve_grid(fit, target_fn, grid)
  target_lab <- paste0("rho:", tier_user, ":", i, ",", j)
  out <- data.frame(
    target = target_lab,
    profile_value = grid,
    objective = obj,
    delta_deviance = .profile_curve_delta_deviance(obj, fit),
    estimate = rho_hat,
    conf_level = conf_level,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  refit_bounds <- tryCatch(
    .profile_ci_via_refit(
      fit,
      target_fn,
      q_hat = rho_hat,
      level = conf_level,
      q_lo_hint = max(rho_hat - 0.3, -0.999),
      q_hi_hint = min(rho_hat + 0.3, 0.999),
      q_lo_floor = -0.999,
      q_hi_ceiling = 0.999
    ),
    error = function(e) list(lower = NA_real_, upper = NA_real_)
  )
  attr(out, "n_grid") <- n_grid
  attr(out, "conf_level") <- conf_level
  attr(out, "quantity") <- "rho (correlation)"
  attr(out, "tier") <- tier
  attr(out, "refit_bounds") <- data.frame(
    target = target_lab,
    lower = refit_bounds$lower,
    upper = refit_bounds$upper,
    stringsAsFactors = FALSE
  )
  class(out) <- c("profile_correlation", "profile_derived", class(out))
  out
}

## ---- profile_proportions() -----------------------------------------------

#' Profile-likelihood curves for per-trait variance proportions
#'
#' For each `(trait, component)` produced by [extract_proportions()],
#' sweep over a grid of candidate proportion values, refit under each
#' constraint, and return the LR curves. Internal curve counterpart to the
#' withheld `profile_ci_proportions()` prototype.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param components Character vector of component names to include
#'   (e.g. `c("shared_unit", "unique_unit")`). `NULL` (default) uses
#'   all profile-able components present in
#'   [extract_proportions()] except `link_residual` (which is
#'   structurally constant and has no curve).
#' @param trait_idx Integer vector of trait indices, or `NULL` for all.
#' @param n_grid Integer; number of grid points. Default 21.
#' @param grid_extent Numeric; total grid width as a multiple of a
#'   robust scale (clamped to `(0, 1)`). Default 4.
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A data.frame of class `profile_proportions`,
#'   `profile_derived`, `data.frame`.
#'
#' @keywords internal
#' @noRd
profile_proportions <- function(
  fit,
  components = NULL,
  trait_idx = NULL,
  n_grid = 21L,
  grid_extent = 4,
  conf_level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  pt <- suppressMessages(extract_proportions(fit, format = "long"))
  comps_present <- as.character(unique(pt$component))
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  trait_idx <- as.integer(trait_idx)
  if (any(trait_idx < 1L) || any(trait_idx > T)) {
    cli::cli_abort("{.arg trait_idx} must be integers in 1:{T}.")
  }

  if (is.null(components)) {
    components <- setdiff(comps_present, "link_residual")
  } else {
    components <- as.character(components)
    bad <- setdiff(components, comps_present)
    if (length(bad) > 0L) {
      cli::cli_abort(c(
        "{cli::qty(length(bad))} component name{?s} not present in this fit: {.val {bad}}.",
        i = "Available components: {.val {comps_present}}."
      ))
    }
    if ("link_residual" %in% components) {
      cli::cli_abort(c(
        "{.code link_residual} is structurally constant and has no profile curve.",
        i = "Drop {.val link_residual} from {.arg components}; the corresponding {.fn profile_ci_proportions} row collapses bounds to the point estimate."
      ))
    }
  }

  ## Build (trait x component) point-estimate matrix
  pt_mat <- matrix(
    NA_real_,
    nrow = T,
    ncol = length(comps_present),
    dimnames = list(trait_names, comps_present)
  )
  for (cc in comps_present) {
    rows_c <- pt[as.character(pt$component) == cc, , drop = FALSE]
    row_idx <- match(as.character(rows_c$trait), trait_names)
    pt_mat[row_idx, cc] <- rows_c$proportion
  }

  out_list <- list()
  bounds_list <- list()
  for (comp in components) {
    for (t in trait_idx) {
      p_hat <- pt_mat[t, comp]
      if (is.na(p_hat)) {
        next
      }
      target_fn <- .proportion_target_fn(
        fit,
        component = comp,
        trait_idx = t
      )
      if (is.null(target_fn)) {
        next
      }
      ## Adapt floor / ceiling to p_hat (same logic as profile_ci_proportions)
      q_floor <- min(0.001, max(p_hat / 10, .Machine$double.eps))
      q_ceil <- max(0.999, min(1 - (1 - p_hat) / 10, 1 - .Machine$double.eps))
      grid <- .proportion_grid(
        p_hat = p_hat,
        n_grid = n_grid,
        grid_extent = grid_extent,
        floor = q_floor,
        ceiling = q_ceil
      )
      obj <- .profile_curve_grid(fit, target_fn, grid)
      target_lab <- paste0("proportion:", comp, ":", trait_names[t])
      out_list[[length(out_list) + 1L]] <- data.frame(
        target = target_lab,
        profile_value = grid,
        objective = obj,
        delta_deviance = .profile_curve_delta_deviance(obj, fit),
        estimate = p_hat,
        conf_level = conf_level,
        stringsAsFactors = FALSE,
        row.names = NULL
      )
      refit_bounds <- tryCatch(
        .profile_ci_via_refit(
          fit,
          target_fn,
          q_hat = p_hat,
          level = conf_level,
          q_lo_hint = max(p_hat - 0.3, q_floor),
          q_hi_hint = min(p_hat + 0.3, q_ceil),
          q_lo_floor = q_floor,
          q_hi_ceiling = q_ceil
        ),
        error = function(e) list(lower = NA_real_, upper = NA_real_)
      )
      bounds_list[[length(bounds_list) + 1L]] <- data.frame(
        target = target_lab,
        lower = refit_bounds$lower,
        upper = refit_bounds$upper,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(out_list) == 0L) {
    cli::cli_abort("No profile-able (trait, component) cells to sweep.")
  }
  out <- do.call(rbind, out_list)
  attr(out, "n_grid") <- n_grid
  attr(out, "conf_level") <- conf_level
  attr(out, "quantity") <- "proportion of variance"
  attr(out, "refit_bounds") <- do.call(rbind, bounds_list)
  class(out) <- c("profile_proportions", "profile_derived", class(out))
  out
}

## ---- Shared S3 plot method -----------------------------------------------

#' Plot a profile-derived LR curve
#'
#' S3 method dispatched on the `profile_derived` parent class shared by
#' the public derived-quantity curve object returned from
#' [profile_phylo_signal()]. The diagonal-companion ratio and nonlinear
#' communality, correlation, and proportion curve prototypes are internal and
#' withheld from the public release. Mirrors [plot.profile_loadings()]: dotted
#' chisq cutoff hline, solid grey vline at the estimate, dashed grey
#' vlines at the inverted CI bounds (when `interval = TRUE`), blue
#' curve with white-filled points, faceted by `target` with free
#' x-scales.
#'
#' @param x A `profile_derived` data.frame.
#' @param interval Logical; draw inverted CI bounds (default `TRUE`).
#' @param ... Reserved for future options.
#'
#' @return A `ggplot` object.
#'
#' @export
plot.profile_derived <- function(x, interval = TRUE, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "{.pkg ggplot2} is required for {.fn plot.profile_derived}."
    )
  }
  conf_level <- attr(x, "conf_level") %||% unique(x$conf_level)
  cutoff <- stats::qchisq(conf_level, df = 1L)
  quantity <- attr(x, "quantity") %||% "value"

  estimates <- unique(x[, c("target", "estimate"), drop = FALSE])

  g <- ggplot2::ggplot(
    x,
    ggplot2::aes(x = .data$profile_value, y = .data$delta_deviance)
  ) +
    ggplot2::geom_hline(
      yintercept = cutoff,
      linetype = "dotted",
      colour = "grey55",
      linewidth = 0.35
    ) +
    ggplot2::geom_vline(
      data = estimates,
      mapping = ggplot2::aes(xintercept = .data$estimate),
      inherit.aes = FALSE,
      linewidth = 0.35,
      colour = "grey30"
    )

  if (isTRUE(interval)) {
    bounds <- .invert_profile_derived(x)
    keep <- is.finite(bounds$lower) | is.finite(bounds$upper)
    if (any(keep)) {
      g <- g +
        ggplot2::geom_vline(
          data = bounds[keep & is.finite(bounds$lower), , drop = FALSE],
          mapping = ggplot2::aes(xintercept = .data$lower),
          inherit.aes = FALSE,
          linetype = "dashed",
          linewidth = 0.3,
          colour = "grey45"
        ) +
        ggplot2::geom_vline(
          data = bounds[keep & is.finite(bounds$upper), , drop = FALSE],
          mapping = ggplot2::aes(xintercept = .data$upper),
          inherit.aes = FALSE,
          linetype = "dashed",
          linewidth = 0.3,
          colour = "grey45"
        )
    }
  }

  g <- g +
    ggplot2::geom_line(linewidth = 0.8, colour = "#0072B2", na.rm = TRUE) +
    ggplot2::geom_point(
      size = 1.8,
      shape = 21,
      fill = "white",
      colour = "#0072B2",
      stroke = 0.6,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(~ .data$target, scales = "free_x") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(size = 7),
      panel.grid.minor = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      x = quantity,
      y = expression(Delta * "deviance"),
      title = sprintf("Profile-likelihood curves: %s", quantity),
      subtitle = sprintf(
        "Dotted: chisq cutoff at %.2f for level %.2f. Solid grey: MLE. Dashed grey: inverted CI bounds.",
        cutoff,
        conf_level
      )
    )
  g
}
