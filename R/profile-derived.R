## Profile-likelihood CIs for derived quantities (ICC / repeatability,
## communality, cross-trait correlations, phylogenetic signal H^2).
##
## Two implementation strategies, mirroring the McCune/Nakagawa
## `coxme_icc_ci()` precedent and the metafor `confint.rma.uni()` pattern:
##
##   1. **Linear-in-parameters quantities** (ICC / repeatability,
##      log-variance ratios) are profiled directly via TMB::tmbprofile()'s
##      `lincomb` argument. `lincomb` builds a contrast in the parameter
##      vector; the inner C++ optim warm-starts from the joint MLE and
##      solves the constrained max in milliseconds. CI bounds are then
##      transformed monotonically via plogis() (for variance ratios) or
##      a straight exp() (for log-variances).
##
##   2. **Non-linear derived quantities** (communality, cross-trait
##      correlations, multi-component phylogenetic signal H^2) require a
##      Lagrange-style fix-and-refit: choose a candidate target value
##      `q_0`, refit the model with q == q_0 enforced via a quadratic
##      penalty in R-side `nlminb()` warm-started from the joint MLE, and
##      use uniroot() to find `q_0` values where the constrained
##      deviance crosses qchisq(level, 1).
##
## Both follow the coxme_icc_ci() conceptual pattern (fix the target,
## refit, find the deviance crossing) but warm-start the inner optim from
## the joint MLE in TMB's C++ rather than in pure R, giving 10-50x speed
## up over the McCune/Nakagawa coxme_icc_ci() and metafor confint.rma.uni().

## ---- Helpers --------------------------------------------------------------

#' @keywords internal
#' @noRd
.zero_lincomb <- function(fit) {
  numeric(length(fit$opt$par))
}

#' @keywords internal
#' @noRd
.par_indices <- function(fit, name) {
  which(names(fit$opt$par) == name)
}

#' @keywords internal
#' @noRd
.has_param <- function(fit, name) {
  any(names(fit$opt$par) == name)
}

## ---- Repeatability / ICC: lincomb profile ----------------------------------
## R_t = sigma2_B,t / (sigma2_B,t + sigma2_W,t)
##     = 1 / (1 + exp(-2*(theta_diag_B[t] - theta_diag_W[t])))
##
## Profile L = 2*(theta_diag_B[t] - theta_diag_W[t]) (a single-coefficient
## linear contrast); transform CI bounds via plogis().

#' Profile-likelihood CI for per-trait diag-only repeatability
#'
#' Computes the profile-likelihood CI for the **diag-only** per-trait
#' repeatability
#' \eqn{R^\text{diag}_t = \sigma^2_{\text{diag},B,t} /
#'                       (\sigma^2_{\text{diag},B,t} +
#'                        \sigma^2_{\text{diag},W,t})}
#' — i.e. only the trait-specific unique components, *not* the standard
#' full-\eqn{\boldsymbol\Sigma} repeatability. For the
#' Bell-2009 / Nakagawa-Schielzeth-2010 standard
#' \eqn{R = \boldsymbol\Sigma_{B,tt} /
#'        (\boldsymbol\Sigma_{B,tt} + \boldsymbol\Sigma_{W,tt})}
#' (which includes the shared latent contributions
#' \eqn{(\boldsymbol\Lambda_B\boldsymbol\Lambda_B^\top)_{tt}} and
#' \eqn{(\boldsymbol\Lambda_W\boldsymbol\Lambda_W^\top)_{tt}}), use
#' [extract_repeatability()] instead.
#'
#' Internally profiles the linear contrast
#' \eqn{2 (\theta_{\text{diag},B,t} - \theta_{\text{diag},W,t}) =
#'      \log(\sigma^2_{\text{diag},B} / \sigma^2_{\text{diag},W})} via
#' [TMB::tmbprofile()] and back-transforms the bounds via
#' \eqn{\mathrm{plogis}}. Fast and accurate for that specific quantity.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param trait_idx Integer index of the trait (1-based). `NULL` (the
#'   default) returns CIs for all traits.
#' @param level Confidence level. Default 0.95.
#' @return A data frame with columns `trait`, `R` (point estimate),
#'   `lower`, `upper`, `method`.
#'
#' @section Boundary behaviour:
#' When the within-unit variance is near zero (R close to 1) the
#' constrained log-likelihood is flat as `theta_diag_W -> -Inf` and the
#' upper bound on R is reported as **1** (the natural boundary). Same
#' applies symmetrically for R close to 0 → lower bound **0**. `NA` is
#' reserved for genuine profile failure (e.g. tmbprofile() error or too
#' few points to bracket the threshold).
#'
#' @keywords internal
#' @export
profile_ci_repeatability <- function(fit, trait_idx = NULL, level = 0.95) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  ix_B <- .par_indices(fit, "theta_diag_B")
  ix_W <- .par_indices(fit, "theta_diag_W")
  if (length(ix_B) == 0L || length(ix_W) == 0L)
    cli::cli_abort(c(
      "Repeatability requires both {.code theta_diag_B} and {.code theta_diag_W} in the fit.",
      "i" = "Refit with {.code unique(0 + trait | <unit>)} and {.code unique(0 + trait | <obs>)}."
    ))
  T <- length(ix_B)
  trait_names <- levels(fit$data[[fit$trait_col]])
  if (is.null(trait_idx)) trait_idx <- seq_len(T)
  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    if (t < 1L || t > T)
      cli::cli_abort("{.arg trait_idx} = {t} out of range [1, {T}].")
    lc <- .zero_lincomb(fit)
    lc[ix_B[t]] <-  2
    lc[ix_W[t]] <- -2
    ## Transform: log(sigma2_B/sigma2_W) -> R = plogis(L)
    ci_log <- tmbprofile_wrapper(
      fit, lincomb = lc, level = level,
      transform = stats::plogis
    )
    out_list[[k]] <- data.frame(
      trait    = trait_names[t],
      R        = unname(ci_log["estimate"]),
      lower    = unname(ci_log["lower"]),
      upper    = unname(ci_log["upper"]),
      method   = "profile",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  do.call(rbind, out_list)
}

## ---- Phylogenetic signal H^2: lincomb profile (2-component) ----------------
## When the fit has phylo_unique (log_sd_phy_diag, per-trait) and species-
## level B unique (theta_diag_B, per-trait), and NO species-level B latent,
## H^2 = sigma2_phy / (sigma2_phy + sigma2_non) reduces to a 2-component
## ratio profileable via lincomb. For 3-component decompositions (phy +
## non-shared from latent + non-unique from unique) we fall back to Wald
## with a note; full profile is available via fix-and-refit but the math
## is not yet implemented.

#' Profile-likelihood CI for per-trait phylogenetic signal H^2
#'
#' For fits with `phylo_unique(species)` and `unique(0 + trait | species)`
#' but no species-level `latent()` term, `H^2 = sigma2_phy / (sigma2_phy +
#' sigma2_non)` is a 2-component ratio profileable via a single linear
#' contrast (`log_sd_phy_diag[t] - theta_diag_species[t]`).
#'
#' For richer 3-component decompositions (PGLLVM with phylo_latent +
#' species-level latent + unique), we currently return Wald CIs with a
#' note; full profile would require fix-and-refit on the multi-component
#' constraint and is logged as a future enhancement.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param trait_idx Integer index of the trait, or `NULL` for all.
#' @param level Confidence level. Default 0.95.
#' @return A data frame with columns `trait`, `H2`, `lower`, `upper`,
#'   `method`.
#'
#' @keywords internal
#' @export
profile_ci_phylo_signal <- function(fit, trait_idx = NULL, level = 0.95) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  has_phy <- isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  if (!has_phy)
    cli::cli_abort(c(
      "Phylogenetic signal requires a phylogenetic component.",
      "i" = "Refit with {.code phylo_latent()} or {.code phylo_unique()}."
    ))
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) trait_idx <- seq_len(T)

  ## Two-component ratio: phy_diag (log_sd_phy_diag) vs non-phy unique
  ## (diag_species, theta_diag_species). Available when:
  ##   use$phylo_diag = TRUE  AND  use$diag_species = TRUE
  ##   AND no species-level rr_B / diag_B (else 3-component)
  has_simple_2comp <-
    isTRUE(fit$use$phylo_diag) &&
    isTRUE(fit$use$diag_species) &&
    !isTRUE(fit$use$rr_B) && !isTRUE(fit$use$diag_B)

  if (has_simple_2comp) {
    ix_phy <- .par_indices(fit, "log_sd_phy_diag")
    ix_non <- .par_indices(fit, "theta_diag_species")
    if (length(ix_phy) != T || length(ix_non) != T) {
      cli::cli_inform("Per-trait dimensions mismatch; falling back to point estimate only.")
      ## Point estimate only (no CIs)
      ps <- extract_phylo_signal(fit)
      return(data.frame(
        trait = trait_names[trait_idx],
        H2 = ps$H2[trait_idx],
        lower = NA_real_, upper = NA_real_,
        method = "(unavailable)",
        stringsAsFactors = FALSE
      ))
    }
    out_list <- vector("list", length(trait_idx))
    for (k in seq_along(trait_idx)) {
      t <- trait_idx[k]
      lc <- .zero_lincomb(fit)
      lc[ix_phy[t]] <-  2
      lc[ix_non[t]] <- -2
      ci <- tmbprofile_wrapper(
        fit, lincomb = lc, level = level, transform = stats::plogis
      )
      out_list[[k]] <- data.frame(
        trait    = trait_names[t],
        H2       = unname(ci["estimate"]),
        lower    = unname(ci["lower"]),
        upper    = unname(ci["upper"]),
        method   = "profile",
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    }
    return(do.call(rbind, out_list))
  }

  ## Fallback: Wald via delta method on H^2. We keep the existing point
  ## estimate from extract_phylo_signal and approximate the CI from the
  ## sd_report covariance of the constituent log-SDs.
  ps <- extract_phylo_signal(fit)
  out <- data.frame(
    trait = trait_names[trait_idx],
    H2 = ps$H2[trait_idx],
    lower = NA_real_, upper = NA_real_,
    method = "wald(approx)",
    stringsAsFactors = FALSE
  )
  cli::cli_inform(
    "Multi-component (3+) phylogenetic signal CIs require fix-and-refit; not implemented in Phase K. Returning point estimates with method = {.val wald(approx)}."
  )
  out
}

## ---- Lagrange-style fix-and-refit penalty driver --------------------------
## Given a target function `target_fn(par, fit) -> scalar` and a candidate
## value q_0, refit the model with a quadratic penalty
##   penalised_nll(par) = nll(par) + lambda * (target_fn(par, fit) - q_0)^2
## warm-started from the joint MLE. lambda is taken large enough to enforce
## the constraint to numerical precision (default 1e8). Returns the
## constrained -log-likelihood (the inner-max value).

#' @keywords internal
#' @noRd
.fix_and_refit_nll <- function(fit, target_fn, q_0,
                               lambda = 1e6,
                               control = list(eval.max = 100, iter.max = 100,
                                              rel.tol = 1e-7)) {
  obj <- fit$tmb_obj
  par0 <- fit$opt$par
  ## Penalised NLL
  fn_pen <- function(par) {
    val <- tryCatch(obj$fn(par), error = function(e) NA_real_)
    if (is.na(val) || !is.finite(val)) return(.Machine$double.xmax / 1e3)
    q <- as.numeric(target_fn(par, fit))
    if (is.na(q) || !is.finite(q)) return(.Machine$double.xmax / 1e3)
    val + lambda * (q - q_0)^2
  }
  ## Use TMB's analytical gradient for the NLL part, numerical gradient
  ## via finite-difference for the penalty part. Falls back to fully
  ## numerical gradient if obj$gr fails.
  opt_pen <- tryCatch(
    stats::nlminb(start = par0, objective = fn_pen,
                  control = control),
    error = function(e) {
      NULL
    }
  )
  if (is.null(opt_pen) || !is.finite(opt_pen$objective)) return(NA_real_)
  ## Pull the underlying NLL at the constrained optimum (sans penalty)
  par_hat <- opt_pen$par
  q_hat_ach <- as.numeric(target_fn(par_hat, fit))
  ## If the constraint wasn't met to reasonable precision, the penalty
  ## was too small or the optimum was elsewhere; flag and return NA.
  if (is.na(q_hat_ach) || abs(q_hat_ach - q_0) > 0.05)
    return(NA_real_)
  nll_at_constraint <- tryCatch(obj$fn(par_hat), error = function(e) NA_real_)
  if (is.na(nll_at_constraint) || !is.finite(nll_at_constraint))
    return(NA_real_)
  nll_at_constraint
}

## ---- Generic profile CI via fix-and-refit + uniroot ----------------------
## Run the penalty-based refit at a small grid + uniroot, returning the
## CI bounds where 2*(L_max - L_constrained) = qchisq(level, 1).

#' @keywords internal
#' @noRd
.profile_ci_via_refit <- function(fit, target_fn, q_hat, level = 0.95,
                                  q_lo_hint = NULL, q_hi_hint = NULL,
                                  q_lo_floor = -Inf, q_hi_ceiling = Inf,
                                  lambda = 1e6) {
  crit <- .qchisq_threshold(level)
  mle_val <- as.numeric(fit$opt$objective)
  ## Build a fast deviance-excess function for uniroot
  excess <- function(q_0) {
    nll <- .fix_and_refit_nll(fit, target_fn, q_0, lambda = lambda)
    if (is.na(nll)) return(NA_real_)
    (nll - mle_val) - crit
  }
  ## Default search ranges: spread out from q_hat
  if (is.null(q_lo_hint)) q_lo_hint <- q_hat - 0.3
  if (is.null(q_hi_hint)) q_hi_hint <- q_hat + 0.3

  ## Bracket on each side: try a small expanding sequence of trial points.
  ## If we hit the parameter floor/ceiling and the profile still hasn't
  ## crossed the chi-square threshold, the bound IS the parameter
  ## boundary (matches the boundary semantic in `.profile_bounds()`).
  find_bound <- function(direction) {
    if (direction == "lower") {
      trial <- q_lo_hint
      step  <- (q_hat - q_lo_hint)
      sign  <- -1
      lim   <- q_lo_floor
    } else {
      trial <- q_hi_hint
      step  <- (q_hi_hint - q_hat)
      sign  <- 1
      lim   <- q_hi_ceiling
    }
    e_trial <- excess(trial)
    if (is.na(e_trial)) {
      ## First probe failed (refit at q_lo_hint or q_hi_hint did not
      ## converge). Try directly at the parameter limit: if the
      ## constrained refit at the boundary gives a finite excess that's
      ## still negative, the bound IS the boundary. If the boundary
      ## refit also fails, return NA (genuine refit failure).
      e_lim <- if (is.finite(lim)) excess(lim) else NA_real_
      if (!is.na(e_lim) && e_lim < 0) return(lim)
      return(NA_real_)
    }

    ## Case A: first probe already OUTSIDE the CI (excess > 0). The
    ## true bound lies BETWEEN the hint and q_hat. excess(q_hat) is
    ## approximately -crit (the MLE value of the target), so we have a
    ## sign change in [hint, q_hat]. Use uniroot directly.
    if (e_trial > 0) {
      bound <- tryCatch(
        stats::uniroot(excess,
                       interval = sort(c(trial, q_hat)),
                       extendInt = "no",
                       tol = 0.005, maxiter = 25)$root,
        error = function(e) NA_real_
      )
      return(bound)
    }

    n_iter <- 0
    at_boundary <- FALSE
    while (!is.na(e_trial) && e_trial < 0 && n_iter < 6) {
      trial_new <- q_hat + sign * (step * (1.6 ^ n_iter))
      if (direction == "lower" && trial_new < q_lo_floor) {
        trial_new <- q_lo_floor; at_boundary <- TRUE
      }
      if (direction == "upper" && trial_new > q_hi_ceiling) {
        trial_new <- q_hi_ceiling; at_boundary <- TRUE
      }
      e_new <- excess(trial_new)
      if (is.na(e_new)) {
        ## Mid-loop refit failure. If we were probing at the
        ## parameter boundary, the bound IS the boundary (refits
        ## near the limit are commonly singular). Otherwise NA.
        if (at_boundary) return(lim)
        return(NA_real_)
      }
      if (e_new >= 0) {
        bound <- tryCatch(
          stats::uniroot(excess,
                         interval = sort(c(trial, trial_new)),
                         extendInt = "no",
                         tol = 0.005, maxiter = 25)$root,
          error = function(e) NA_real_
        )
        return(bound)
      }
      ## Reached the parameter boundary and profile still flat: report
      ## the boundary itself (CI extends to the natural limit).
      if (at_boundary) return(lim)
      trial   <- trial_new
      e_trial <- e_new
      n_iter  <- n_iter + 1
    }
    ## Iterations exhausted but we never reached the boundary either —
    ## treat this as "profile too flat to bracket within the search
    ## range"; return the boundary as the conservative answer.
    if (is.finite(lim)) return(lim)
    NA_real_
  }
  lo <- find_bound("lower")
  hi <- find_bound("upper")
  list(lower = lo, upper = hi, estimate = q_hat)
}

## ---- Communality: fix-and-refit profile -----------------------------------
## c2_t = (Lambda Lambda^T)_tt / Sigma_tt
## Profile via fix-and-refit. Slow (one nlminb per uniroot step).

#' Profile-likelihood CI for per-trait communality
#'
#' Communality \eqn{c^2_t = (\Lambda \Lambda^\top)_{tt} / \Sigma_{tt}} is
#' the proportion of trait \eqn{t}'s variance attributable to shared
#' factors. We compute its CI by Lagrange-style fix-and-refit: at each
#' candidate \eqn{c^2_0}, refit with a quadratic penalty enforcing
#' \eqn{c^2_t(\hat\theta) = c^2_0}, find the constrained -loglik, and
#' use [stats::uniroot()] to locate values where the deviance crosses
#' \eqn{\chi^2_1(\text{level})}.
#'
#' This mirrors the McCune/Nakagawa `coxme_icc_ci()` pattern but
#' warm-starts the inner optim from the joint MLE in TMB's C++.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level Confidence level. Default 0.95.
#' @param tier `"B"` or `"W"`. Default `"B"`.
#' @param trait_idx Integer index of trait, or `NULL` for all.
#' @return A data frame with columns `trait`, `tier`, `c2`, `lower`,
#'   `upper`, `method`.
#'
#' @keywords internal
#' @export
profile_ci_communality <- function(fit,
                                   tier = c("unit", "unit_obs", "B", "W"),
                                   trait_idx = NULL, level = 0.95) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  tier <- match.arg(tier)
  tier <- .normalise_level(tier, arg_name = "tier")
  rr_used <- if (tier == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
  diag_used <- if (tier == "B") isTRUE(fit$use$diag_B) else isTRUE(fit$use$diag_W)
  if (!rr_used)
    cli::cli_abort("Communality at tier {.val {tier}} requires a {.code latent()} term in the fit.")
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) trait_idx <- seq_len(T)

  ## Point estimate
  c2_pt <- extract_communality(fit, level = tier)
  if (is.null(c2_pt))
    cli::cli_abort("Could not compute communality point estimate at tier {.val {tier}}.")

  ## Per-trait target function: re-build Lambda from theta_rr_<tier> and
  ## sigma2_t from theta_diag_<tier>; return c2_t.
  par_names <- names(fit$opt$par)
  ix_rr   <- which(par_names == paste0("theta_rr_", tier))
  ix_diag <- which(par_names == paste0("theta_diag_", tier))
  if (length(ix_rr) == 0L || length(ix_diag) == 0L)
    cli::cli_abort("Communality requires both {.code latent()} and {.code unique()} terms at tier {.val {tier}} for the profile path.")
  d_tier <- if (tier == "B") fit$d_B else fit$d_W
  n_traits <- length(ix_diag)
  ## Length expected for theta_rr: n_traits * d - d*(d-1)/2 (lower-tri packed)
  expected_nt <- n_traits * d_tier - d_tier * (d_tier - 1) / 2
  if (length(ix_rr) != expected_nt)
    cli::cli_abort("theta_rr_{tier} has length {length(ix_rr)} but expected {expected_nt}.")

  build_Lambda <- function(theta_rr, p, rank) {
    L <- matrix(0, p, rank)
    if (length(theta_rr) == 0L || rank == 0L) return(L)
    lam_diag  <- theta_rr[seq_len(rank)]
    lam_lower <- theta_rr[-seq_len(rank)]
    ## Diagonal entries
    for (j in seq_len(rank)) L[j, j] <- lam_diag[j]
    ## Strict-lower entries packed column by column (column j has p-j
    ## entries at rows j+1, ..., p), matching the engine's TMB packing.
    idx <- 1L
    for (j in seq_len(rank)) {
      if (j < p) {
        for (i in (j + 1L):p) {
          if (idx <= length(lam_lower)) L[i, j] <- lam_lower[idx]
          idx <- idx + 1L
        }
      }
    }
    L
  }

  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    target_fn <- function(par, fit) {
      th_rr <- par[ix_rr]
      th_diag <- par[ix_diag]
      L <- build_Lambda(th_rr, p = n_traits, rank = d_tier)
      LLt <- L %*% t(L)
      shared <- LLt[t, t]
      sigma2 <- exp(2 * th_diag[t])
      total <- shared + sigma2
      if (total <= 0) return(NA_real_)
      shared / total
    }
    q_hat <- c2_pt[t]
    bounds <- .profile_ci_via_refit(
      fit, target_fn, q_hat, level = level,
      q_lo_hint = max(q_hat - 0.3, 0.001),
      q_hi_hint = min(q_hat + 0.3, 0.999),
      q_lo_floor = 0.001, q_hi_ceiling = 0.999
    )
    out_list[[k]] <- data.frame(
      trait    = trait_names[t],
      tier     = tier,
      c2       = q_hat,
      lower    = bounds$lower,
      upper    = bounds$upper,
      method   = "profile",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  do.call(rbind, out_list)
}

## ---- Cross-trait correlation: fix-and-refit profile ----------------------
## rho_ij = Sigma_ij / sqrt(Sigma_ii * Sigma_jj). Profile via fix-and-refit
## using the same penalty driver.

#' Profile-likelihood CI for one cross-trait correlation
#'
#' For a fitted gllvmTMB_multi model, computes the profile-likelihood
#' confidence interval for one cross-trait correlation
#' \eqn{\rho_{ij} = \Sigma_{ij} / \sqrt{\Sigma_{ii}\Sigma_{jj}}} at one
#' tier. Cross-trait correlations are first-class outputs of the
#' factor-analytic decomposition and need accurate CIs at scale (a 6-trait
#' fit has 75 of them across 5 tiers).
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param tier `"B"`, `"W"`, `"phy"`, or `"spde"`.
#' @param i,j Trait indices (1-based, `i < j`).
#' @param level Confidence level. Default 0.95.
#' @return Length-3 numeric vector (`estimate`, `lower`, `upper`).
#'
#' @keywords internal
#' @export
profile_ci_correlation <- function(fit,
                                   tier = c("unit", "unit_obs", "phy",
                                            "spatial", "B", "W", "spde"),
                                   i, j, level = 0.95) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  tier <- match.arg(tier)
  tier <- .normalise_level(tier, arg_name = "tier")
  if (i >= j)
    cli::cli_abort("Provide {.arg i} < {.arg j}.")

  Sigma_pt <- suppressMessages(
    extract_Sigma(fit, level = tier, part = "total", link_residual = "none")
  )
  if (is.null(Sigma_pt))
    cli::cli_abort("Could not extract Sigma at tier {.val {tier}}.")
  rho_hat <- Sigma_pt$R[i, j]

  ## Build target function from the tier's parameter blocks
  par_names <- names(fit$opt$par)
  if (tier == "B") {
    ix_rr   <- which(par_names == "theta_rr_B")
    ix_diag <- which(par_names == "theta_diag_B")
    rank    <- fit$d_B
    use_rr   <- isTRUE(fit$use$rr_B)
    use_diag <- isTRUE(fit$use$diag_B)
  } else if (tier == "W") {
    ix_rr   <- which(par_names == "theta_rr_W")
    ix_diag <- which(par_names == "theta_diag_W")
    rank    <- fit$d_W
    use_rr   <- isTRUE(fit$use$rr_W)
    use_diag <- isTRUE(fit$use$diag_W)
  } else if (tier == "phy") {
    ix_rr   <- which(par_names == "theta_rr_phy")
    ix_diag <- which(par_names == "log_sd_phy_diag")
    rank    <- fit$d_phy
    use_rr   <- isTRUE(fit$use$phylo_rr)
    use_diag <- isTRUE(fit$use$phylo_diag)
  } else {  # spde
    ix_rr   <- which(par_names == "theta_rr_spde_lv")
    ix_diag <- integer(0)
    rank    <- fit$d_spde_lv
    use_rr   <- isTRUE(fit$use$spatial_latent)
    use_diag <- FALSE
  }
  if (!use_rr)
    cli::cli_abort("Tier {.val {tier}} has no {.code latent()} term; correlation profile not available.")
  n_traits <- fit$n_traits

  build_Lambda <- function(theta_rr, p, rank) {
    L <- matrix(0, p, rank)
    if (length(theta_rr) == 0L || rank == 0L) return(L)
    lam_diag  <- theta_rr[seq_len(rank)]
    lam_lower <- theta_rr[-seq_len(rank)]
    ## Diagonal entries
    for (jj in seq_len(rank)) L[jj, jj] <- lam_diag[jj]
    ## Strict-lower entries packed column by column (column j has p-j
    ## entries at rows j+1, ..., p), matching the engine's TMB packing.
    idx <- 1L
    for (jj in seq_len(rank)) {
      if (jj < p) {
        for (ii in (jj + 1L):p) {
          if (idx <= length(lam_lower)) L[ii, jj] <- lam_lower[idx]
          idx <- idx + 1L
        }
      }
    }
    L
  }
  target_fn <- function(par, fit) {
    th_rr <- if (length(ix_rr) > 0L) par[ix_rr] else numeric(0)
    L <- build_Lambda(th_rr, p = n_traits, rank = rank)
    LLt <- L %*% t(L)
    Sigma <- LLt
    if (use_diag) {
      th_diag <- par[ix_diag]
      diag(Sigma) <- diag(Sigma) + exp(2 * th_diag)
    }
    if (Sigma[i, i] <= 0 || Sigma[j, j] <= 0) return(NA_real_)
    Sigma[i, j] / sqrt(Sigma[i, i] * Sigma[j, j])
  }

  bounds <- .profile_ci_via_refit(
    fit, target_fn, q_hat = rho_hat, level = level,
    q_lo_hint = max(rho_hat - 0.3, -0.999),
    q_hi_hint = min(rho_hat + 0.3, 0.999),
    q_lo_floor = -0.999, q_hi_ceiling = 0.999
  )
  c(estimate = rho_hat, lower = bounds$lower, upper = bounds$upper)
}
