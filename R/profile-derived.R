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
#' @param fit A fit returned by [gllvmTMB()].
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
#' applies symmetrically for R close to 0 -> lower bound **0**. `NA` is
#' reserved for genuine profile failure (e.g. tmbprofile() error or too
#' few points to bracket the threshold).
#'
#' @keywords internal
#' @noRd
profile_ci_repeatability <- function(fit, trait_idx = NULL, level = 0.95) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  ix_B <- .par_indices(fit, "theta_diag_B")
  ix_W <- .par_indices(fit, "theta_diag_W")
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
  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    if (t < 1L || t > T) {
      cli::cli_abort("{.arg trait_idx} = {t} out of range [1, {T}].")
    }
    lc <- .zero_lincomb(fit)
    lc[ix_B[t]] <- 2
    lc[ix_W[t]] <- -2
    ## Transform: log(sigma2_B/sigma2_W) -> R = plogis(L)
    ci_log <- tmbprofile_wrapper(
      fit,
      lincomb = lc,
      level = level,
      transform = stats::plogis
    )
    out_list[[k]] <- data.frame(
      trait = trait_names[t],
      R = unname(ci_log["estimate"]),
      lower = unname(ci_log["lower"]),
      upper = unname(ci_log["upper"]),
      method = "profile",
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
#' For fits with `phylo_indep(species)` and `indep(0 + trait | species)`
#' but no species-level `latent()` term, `H^2 = sigma2_phy / (sigma2_phy +
#' sigma2_non)` is a 2-component ratio profileable via a single linear
#' contrast (`log_sd_phy_diag[t] - theta_diag_species[t]`).
#'
#' For richer 3-component decompositions (PGLLVM with `phylo_latent()` plus
#' a species-level latent decomposition with Psi), full profile requires
#' fix-and-refit on the multi-component constraint and remains planned. The
#' current `method = "profile"` entry point returns the existing numerical
#' delta-method Wald bounds with a clear `method = "wald(numeric)"` label
#' rather than returning empty bounds.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param trait_idx Integer index of the trait, or `NULL` for all.
#' @param level Confidence level. Default 0.95.
#' @return A data frame with columns `trait`, `H2`, `lower`, `upper`,
#'   `method`.
#'
#' @keywords internal
#' @export
profile_ci_phylo_signal <- function(fit, trait_idx = NULL, level = 0.95) {
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
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }

  ## Two-component ratio: phy_diag (log_sd_phy_diag) vs non-phy unique
  ## (diag_species, theta_diag_species). Available when:
  ##   use$phylo_diag = TRUE  AND  use$diag_species = TRUE
  ##   AND no species-level rr_B / diag_B (else 3-component)
  has_simple_2comp <-
    isTRUE(fit$use$phylo_diag) &&
    isTRUE(fit$use$diag_species) &&
    !isTRUE(fit$use$rr_B) &&
    !isTRUE(fit$use$diag_B)

  if (has_simple_2comp) {
    ix_phy <- .par_indices(fit, "log_sd_phy_diag")
    ix_non <- .par_indices(fit, "theta_diag_species")
    if (length(ix_phy) != T || length(ix_non) != T) {
      cli::cli_inform(
        "Per-trait dimensions mismatch; falling back to point estimate only."
      )
      ## Point estimate only (no CIs)
      ps <- extract_phylo_signal(fit)
      return(data.frame(
        trait = trait_names[trait_idx],
        H2 = ps$H2[trait_idx],
        lower = NA_real_,
        upper = NA_real_,
        method = "(unavailable)",
        stringsAsFactors = FALSE
      ))
    }
    out_list <- vector("list", length(trait_idx))
    for (k in seq_along(trait_idx)) {
      t <- trait_idx[k]
      lc <- .zero_lincomb(fit)
      lc[ix_phy[t]] <- 2
      lc[ix_non[t]] <- -2
      ci <- tmbprofile_wrapper(
        fit,
        lincomb = lc,
        level = level,
        transform = stats::plogis
      )
      out_list[[k]] <- data.frame(
        trait = trait_names[t],
        H2 = unname(ci["estimate"]),
        lower = unname(ci["lower"]),
        upper = unname(ci["upper"]),
        method = "profile",
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    }
    return(do.call(rbind, out_list))
  }

  cli::cli_inform(
    "Multi-component (3+) phylogenetic signal profile CIs require fix-and-refit and are not implemented yet. Returning numerical delta-method Wald bounds with method = {.val wald(numeric)}."
  )
  .phylo_signal_wald_ci(fit, trait_idx = trait_idx, level = level)
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
.fix_and_refit_nll <- function(
  fit,
  target_fn,
  q_0,
  lambda = 1e6,
  target_grad = NULL,
  control = list(eval.max = 100, iter.max = 100, rel.tol = 1e-7)
) {
  obj <- fit$tmb_obj
  par0 <- fit$opt$par
  ## Penalised NLL
  fn_pen <- function(par) {
    val <- tryCatch(obj$fn(par), error = function(e) NA_real_)
    if (is.na(val) || !is.finite(val)) {
      return(.Machine$double.xmax / 1e3)
    }
    q <- as.numeric(target_fn(par, fit))
    if (is.na(q) || !is.finite(q)) {
      return(.Machine$double.xmax / 1e3)
    }
    val + lambda * (q - q_0)^2
  }
  ## When the caller supplies an analytic gradient of the target quantity, drive
  ## nlminb with the exact penalised gradient (TMB's own gradient + the penalty
  ## term) instead of finite-differencing the whole objective -- an order-of-
  ## magnitude speedup for derived-quantity profiles. Falls back to finite
  ## differences when target_grad is NULL (existing behaviour for other profiles).
  gr_pen <- if (is.null(target_grad)) {
    NULL
  } else {
    function(par) {
      g <- tryCatch(as.numeric(obj$gr(par)), error = function(e) NULL)
      q <- as.numeric(target_fn(par, fit))
      dq <- tryCatch(as.numeric(target_grad(par, fit)), error = function(e) NULL)
      if (is.null(g) || is.null(dq) || anyNA(g) || anyNA(dq) ||
            is.na(q) || !is.finite(q)) {
        return(rep(0, length(par)))
      }
      g + 2 * lambda * (q - q_0) * dq
    }
  }
  opt_pen <- tryCatch(
    stats::nlminb(
      start = par0, objective = fn_pen, gradient = gr_pen, control = control
    ),
    error = function(e) {
      NULL
    }
  )
  if (is.null(opt_pen) || !is.finite(opt_pen$objective)) {
    return(NA_real_)
  }
  ## Pull the underlying NLL at the constrained optimum (sans penalty)
  par_hat <- opt_pen$par
  q_hat_ach <- as.numeric(target_fn(par_hat, fit))
  ## If the constraint wasn't met to reasonable precision, the penalty
  ## was too small or the optimum was elsewhere; flag and return NA.
  if (is.na(q_hat_ach) || abs(q_hat_ach - q_0) > 0.05) {
    return(NA_real_)
  }
  nll_at_constraint <- tryCatch(obj$fn(par_hat), error = function(e) NA_real_)
  if (is.na(nll_at_constraint) || !is.finite(nll_at_constraint)) {
    return(NA_real_)
  }
  nll_at_constraint
}

## ---- Generic profile CI via fix-and-refit + uniroot ----------------------
## Run the penalty-based refit at a small grid + uniroot, returning the
## CI bounds where 2*(L_max - L_constrained) = qchisq(level, 1).

#' @keywords internal
#' @noRd
.profile_ci_via_refit <- function(
  fit,
  target_fn,
  q_hat,
  level = 0.95,
  crit = NULL,
  target_grad = NULL,
  q_lo_hint = NULL,
  q_hi_hint = NULL,
  q_lo_floor = -Inf,
  q_hi_ceiling = Inf,
  lambda = 1e6,
  max_expand = 8L,
  root_tol = 0.005,
  root_maxiter = 25L
) {
  ## Default reference is chi-square_1 (on the L_max - L_c scale). The internal
  ## B_lv prototype can pass an explicit t-sensitivity cutoff, but that route is
  ## not exported or taught.
  if (is.null(crit)) crit <- .qchisq_threshold(level)
  mle_val <- as.numeric(fit$opt$objective)
  ## Build a fast deviance-excess function for uniroot
  excess <- function(q_0) {
    nll <- .fix_and_refit_nll(
      fit, target_fn, q_0, lambda = lambda, target_grad = target_grad
    )
    if (is.na(nll)) {
      return(NA_real_)
    }
    (nll - mle_val) - crit
  }
  ## Default search ranges: spread out from q_hat
  if (is.null(q_lo_hint)) {
    q_lo_hint <- q_hat - 0.3
  }
  if (is.null(q_hi_hint)) {
    q_hi_hint <- q_hat + 0.3
  }

  interp_root <- function(q_in, e_in, q_out, e_out) {
    vals <- c(q_in, e_in, q_out, e_out)
    if (!all(is.finite(vals)) || e_out == e_in) {
      return(q_out)
    }
    q_in + (0 - e_in) * (q_out - q_in) / (e_out - e_in)
  }

  root_between <- function(q_in, q_out, e_in, e_out) {
    bound <- tryCatch(
      stats::uniroot(
        excess,
        interval = sort(c(q_in, q_out)),
        extendInt = "no",
        tol = root_tol,
        maxiter = root_maxiter
      )$root,
      error = function(e) NA_real_
    )
    if (is.finite(bound)) {
      return(bound)
    }
    ## Rough non-Gaussian surfaces can contain isolated failed constrained
    ## refits inside an otherwise valid bracket. Keep the bound finite by
    ## interpolating between the two finite endpoints, mirroring the profile
    ## curve inverter's finite-point rule.
    interp_root(q_in, e_in, q_out, e_out)
  }

  ## Bracket on each side with a finite probe ledger. Isolated constrained
  ## refit failures are skipped rather than allowed to erase a later valid
  ## crossing. If finite probes reach the parameter floor/ceiling and the
  ## profile still has not crossed the chi-square threshold, the bound IS the
  ## parameter boundary (matches `.profile_bounds()` boundary semantics).
  find_bound <- function(direction) {
    if (direction == "lower") {
      step <- (q_hat - q_lo_hint)
      sign <- -1
      lim <- q_lo_floor
    } else {
      step <- (q_hi_hint - q_hat)
      sign <- 1
      lim <- q_hi_ceiling
    }
    step <- abs(step)
    if (!is.finite(step) || step <= 0) {
      step <- 0.3
    }

    max_expand <- as.integer(max_expand)
    if (is.na(max_expand) || max_expand < 1L) {
      max_expand <- 1L
    }
    trials <- q_hat + sign * step * (1.6 ^ seq.int(0L, max_expand - 1L))
    if (direction == "lower") {
      if (is.finite(lim)) {
        trials <- pmax(trials, lim)
        trials <- c(trials, lim)
      }
    } else if (is.finite(lim)) {
      trials <- pmin(trials, lim)
      trials <- c(trials, lim)
    }
    trials <- unique(trials)

    q_inside <- q_hat
    e_inside <- -crit
    finite_probe_seen <- FALSE

    for (trial in trials) {
      e_trial <- excess(trial)
      if (is.na(e_trial) || !is.finite(e_trial)) {
        next
      }
      finite_probe_seen <- TRUE
      if (e_trial >= 0) {
        return(root_between(q_inside, trial, e_inside, e_trial))
      }
      q_inside <- trial
      e_inside <- e_trial
    }

    ## Iterations exhausted or the finite boundary was reached. If at least
    ## one constrained refit on this side was valid, report the natural
    ## boundary for a flat/one-sided profile. With no finite probe beyond the
    ## MLE, report NA because the side genuinely failed.
    if (finite_probe_seen && is.finite(lim)) {
      return(lim)
    }
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
#' @param fit A fit returned by [gllvmTMB()].
#' @param level Confidence level. Default 0.95.
#' @param tier `"unit"`, `"unit_obs"`, or `"phy"`. Legacy aliases `"B"` and
#'   `"W"` are accepted.
#' @param trait_idx Integer index of trait, or `NULL` for all.
#' @return A data frame with columns `trait`, `tier`, `c2`, `lower`,
#'   `upper`, `method`.
#'
#' @keywords internal
#' @noRd
profile_ci_communality <- function(
  fit,
  tier = c("unit", "unit_obs", "phy", "B", "W"),
  trait_idx = NULL,
  level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  tier <- match.arg(tier)
  tier <- .normalise_level(tier, arg_name = "tier")
  rr_used <- switch(
    tier,
    B = isTRUE(fit$use$rr_B),
    W = isTRUE(fit$use$rr_W),
    phy = isTRUE(fit$use$phylo_rr),
    FALSE
  )
  diag_used <- switch(
    tier,
    B = isTRUE(fit$use$diag_B),
    W = isTRUE(fit$use$diag_W),
    phy = isTRUE(fit$use$phylo_diag),
    FALSE
  )
  if (!rr_used) {
    cli::cli_abort(
      "Communality at tier {.val {tier}} requires a shared latent term in the fit."
    )
  }
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }

  ## Point estimate
  c2_pt <- extract_communality(fit, level = tier)
  if (is.null(c2_pt)) {
    cli::cli_abort(
      "Could not compute communality point estimate at tier {.val {tier}}."
    )
  }

  ## Per-trait target function: re-build Lambda from theta_rr_<tier> and
  ## sigma2_t from theta_diag_<tier>; return c2_t.
  par_names <- names(fit$opt$par)
  rr_name <- switch(
    tier,
    B = "theta_rr_B",
    W = "theta_rr_W",
    phy = "theta_rr_phy"
  )
  diag_name <- switch(
    tier,
    B = "theta_diag_B",
    W = "theta_diag_W",
    phy = "log_sd_phy_diag"
  )
  ix_rr <- which(par_names == rr_name)
  ix_diag <- which(par_names == diag_name)
  if (length(ix_rr) == 0L || length(ix_diag) == 0L) {
    cli::cli_abort(c(
      "Communality profiling requires a shared latent tier with an explicit diagonal Psi component at tier {.val {tier}}.",
      "i" = "Ordinary {.code latent()} includes {.code Psi} by default. For phylogenetic communality, use the folded {.code phylo_latent(..., unique = TRUE)} contract."
    ))
  }
  d_tier <- switch(
    tier,
    B = fit$d_B,
    W = fit$d_W,
    phy = fit$d_phy
  )
  n_traits <- length(ix_diag)
  ## Length expected for theta_rr: n_traits * d - d*(d-1)/2 (lower-tri packed)
  expected_nt <- n_traits * d_tier - d_tier * (d_tier - 1) / 2
  if (length(ix_rr) != expected_nt) {
    cli::cli_abort(
      "theta_rr_{tier} has length {length(ix_rr)} but expected {expected_nt}."
    )
  }

  build_Lambda <- function(theta_rr, p, rank) {
    L <- matrix(0, p, rank)
    if (length(theta_rr) == 0L || rank == 0L) {
      return(L)
    }
    lam_diag <- theta_rr[seq_len(rank)]
    lam_lower <- theta_rr[-seq_len(rank)]
    ## Diagonal entries
    for (j in seq_len(rank)) {
      L[j, j] <- lam_diag[j]
    }
    ## Strict-lower entries packed column by column (column j has p-j
    ## entries at rows j+1, ..., p), matching the engine's TMB packing.
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
      if (total <= 0) {
        return(NA_real_)
      }
      shared / total
    }
    q_hat <- c2_pt[t]
    bounds <- .profile_ci_via_refit(
      fit,
      target_fn,
      q_hat,
      level = level,
      q_lo_hint = max(q_hat - 0.3, 0.001),
      q_hi_hint = min(q_hat + 0.3, 0.999),
      q_lo_floor = 0.001,
      q_hi_ceiling = 0.999
    )
    out_list[[k]] <- data.frame(
      trait = trait_names[t],
      tier = tier,
      c2 = q_hat,
      lower = bounds$lower,
      upper = bounds$upper,
      method = "profile",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  do.call(rbind, out_list)
}

## ---- Total unit variance: shared builder + profile + delta-Wald -----------
## V_t = (Lambda Lambda^T)_tt + psi_t = diag(Sigma_unit)_t, the per-trait total
## variance at a covariance tier -- the rotation-INVARIANT, bounded, right-
## skewed location-axis variance component whose percentile-bootstrap interval
## under-covers (misses are "truth above upper"). `.total_variance_spec()` is the
## SINGLE source of truth for V_t and its exact gradient, so the profile route
## (`.profile_ci_total_variance`, the certificate candidate) and the delta-method
## log-SD Wald (`.wald_ci_total_variance_logsd`, a diagnostic companion) target
## the IDENTICAL functional. psi is reconstructed through `.expand_mapped_diag`
## so mapped-off single-trial-binary psi (issue #717) is handled, not misindexed;
## the theta_rr -> Lambda packing is LINEAR, so d vec(Lambda)/d theta_rr is a
## constant 0/1 map obtained once via build_Lambda on basis vectors (no hand-
## derived packing-index arithmetic).
#' @keywords internal
#' @noRd
.total_variance_spec <- function(
  fit,
  tier = c("unit", "unit_obs", "phy", "B", "W")
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  tier <- match.arg(tier)
  tier <- .normalise_level(tier, arg_name = "tier")

  par_names <- names(fit$opt$par)
  rr_name <- switch(tier, B = "theta_rr_B", W = "theta_rr_W", phy = "theta_rr_phy")
  diag_name <- switch(
    tier,
    B = "theta_diag_B",
    W = "theta_diag_W",
    phy = "log_sd_phy_diag"
  )
  d_tier <- switch(tier, B = fit$d_B, W = fit$d_W, phy = fit$d_phy)

  ix_rr <- which(par_names == rr_name)
  ix_diag <- which(par_names == diag_name)
  if (length(ix_rr) == 0L && length(ix_diag) == 0L) {
    cli::cli_abort(
      "Total-variance intervals at tier {.val {tier}} need a latent and/or diagonal component in the fit."
    )
  }

  trait_names <- levels(fit$data[[fit$trait_col]])
  n_traits <- length(trait_names)
  if (n_traits == 0L) {
    n_traits <- length(ix_diag)
  }

  has_rr <- length(ix_rr) > 0L
  rank <- if (has_rr) as.integer(d_tier) else 0L

  build_Lambda <- function(theta_rr, p, rank) {
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

  ## Constant linear map d vec(Lambda)/d theta_rr as 0/1 basis matrices.
  basis_L <- if (has_rr) {
    lapply(seq_along(ix_rr), function(m) {
      e <- numeric(length(ix_rr))
      e[m] <- 1
      build_Lambda(e, p = n_traits, rank = rank)
    })
  } else {
    list()
  }

  ## trait -> free theta_diag par index (for the psi gradient term); NA if the
  ## trait's psi is mapped off / pinned (no free parameter to differentiate).
  diag_map <- fit$tmb_map[[diag_name]]
  diag_free_for_trait <- function(t) {
    if (length(ix_diag) == 0L) {
      return(NA_integer_)
    }
    if (is.null(diag_map)) {
      if (length(ix_diag) == n_traits) {
        return(ix_diag[t])
      }
      if (length(ix_diag) == 1L) {
        return(ix_diag[1L])
      }
      return(NA_integer_)
    }
    lvl <- as.integer(diag_map)
    if (
      t > length(lvl) || is.na(lvl[t]) || lvl[t] < 1L || lvl[t] > length(ix_diag)
    ) {
      return(NA_integer_)
    }
    ix_diag[lvl[t]]
  }

  psi_full <- function(par) {
    if (length(ix_diag) == 0L) {
      return(rep(0, n_traits))
    }
    exp(2 * .expand_mapped_diag(fit, diag_name, par[ix_diag], n_traits))
  }

  V_of_par <- function(par, t) {
    llt <- if (has_rr) {
      sum(build_Lambda(par[ix_rr], p = n_traits, rank = rank)[t, ]^2)
    } else {
      0
    }
    psi_t <- if (length(ix_diag) > 0L) psi_full(par)[t] else 0
    llt + psi_t
  }

  ## Exact natural-scale gradient dV_t/dpar over the fit$opt$par vector.
  dV_dpar <- function(par, t) {
    g <- numeric(length(par))
    if (has_rr) {
      Lt <- build_Lambda(par[ix_rr], p = n_traits, rank = rank)[t, ]
      for (m in seq_along(ix_rr)) {
        contrib <- 2 * sum(Lt * basis_L[[m]][t, ])
        if (contrib != 0) {
          g[ix_rr[m]] <- contrib
        }
      }
    }
    di <- diag_free_for_trait(t)
    if (!is.na(di)) {
      g[di] <- g[di] + 2 * psi_full(par)[t]
    }
    g
  }

  list(
    tier = tier,
    n_traits = n_traits,
    trait_names = trait_names,
    ix_rr = ix_rr,
    ix_diag = ix_diag,
    has_rr = has_rr,
    V_of_par = V_of_par,
    dV_dpar = dV_dpar
  )
}

## Route A -- CERTIFICATE CANDIDATE. Genuine per-trait profile on log(V_t).
## Profiled on the LOG scale (transformation-invariant, so an identical interval
## to profiling V_t directly) which makes the fixed `.fix_and_refit_nll`
## constraint tolerance act as a relative tolerance and maps V_t -> 0 to
## q -> -Inf cleanly. `crit` is chi-square_1 (NOT the `.qt_threshold` sensitivity
## cutoff). The analytic `target_grad` (mandatory for the fix-and-refit speedup)
## is dV/dpar / V from the shared spec.
#' @keywords internal
#' @noRd
.profile_ci_total_variance <- function(
  fit,
  tier = c("unit", "unit_obs", "phy", "B", "W"),
  trait_idx = NULL,
  level = 0.95
) {
  spec <- .total_variance_spec(fit, tier)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(spec$n_traits)
  }
  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    target_fn <- function(par, fit) {
      V <- spec$V_of_par(par, t)
      if (is.na(V) || V <= 0) {
        return(NA_real_)
      }
      log(V)
    }
    target_grad <- function(par, fit) {
      V <- spec$V_of_par(par, t)
      if (is.na(V) || V <= 0) {
        return(numeric(length(par)))
      }
      spec$dV_dpar(par, t) / V
    }
    V_hat <- spec$V_of_par(fit$opt$par, t)
    if (is.na(V_hat) || V_hat <= 0) {
      out_list[[k]] <- data.frame(
        trait = spec$trait_names[t], tier = spec$tier, estimate = NA_real_,
        lower = NA_real_, upper = NA_real_, method = "profile",
        stringsAsFactors = FALSE, row.names = NULL
      )
      next
    }
    q_hat <- log(V_hat)
    bounds <- .profile_ci_via_refit(
      fit, target_fn, q_hat, level = level, target_grad = target_grad,
      q_lo_hint = q_hat - 0.35, q_hi_hint = q_hat + 0.35,
      q_lo_floor = q_hat - 15, q_hi_ceiling = q_hat + 15
    )
    out_list[[k]] <- data.frame(
      trait = spec$trait_names[t], tier = spec$tier, estimate = V_hat,
      lower = if (is.na(bounds$lower)) NA_real_ else exp(bounds$lower),
      upper = if (is.na(bounds$upper)) NA_real_ else exp(bounds$upper),
      method = "profile", stringsAsFactors = FALSE, row.names = NULL
    )
  }
  do.call(rbind, out_list)
}

## Route B -- DIAGNOSTIC COMPANION (never a certificate). Delta-method Wald on
## the log-SD scale g_t = 0.5*log(V_t): SE(V_t) = sqrt(J' cov.fixed J) with the
## EXACT analytic Jacobian J = dV_t/dpar from the shared spec (so it targets the
## identical estimand and inherits the mapped-off-psi handling), then
## SE(g)=SE(V)/(2V) and interval g +/- z*SE(g) back-transformed. z (not t): df =
## n_unit-1 makes the t-quantile cosmetic. Structurally symmetric on log-SD, so
## it under-corrects the generalized-chi-square right-skew -- expect under-
## coverage on small-loading (esp. binomial, loadings-only) traits. Gates on
## pdHess; NA-guards V_t -> 0.
#' @keywords internal
#' @noRd
.wald_ci_total_variance_logsd <- function(
  fit,
  tier = c("unit", "unit_obs", "phy", "B", "W"),
  trait_idx = NULL,
  level = 0.95
) {
  spec <- .total_variance_spec(fit, tier)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(spec$n_traits)
  }
  has_sd <- !is.null(fit$sd_report) && inherits(fit$sd_report, "sdreport")
  pd_ok <- has_sd && isTRUE(fit$sd_report$pdHess)
  cov_fixed <- if (has_sd) fit$sd_report$cov.fixed else NULL
  dim_ok <- !is.null(cov_fixed) && nrow(cov_fixed) == length(fit$opt$par)
  z <- stats::qnorm(0.5 + level / 2)

  na_row <- function(t, V, status) {
    data.frame(
      trait = spec$trait_names[t], tier = spec$tier, estimate = V,
      lower = NA_real_, upper = NA_real_, se_logsd = NA_real_,
      method = "wald_logsd", pd_hessian = pd_ok, ci_status = status,
      stringsAsFactors = FALSE, row.names = NULL
    )
  }

  out_list <- lapply(trait_idx, function(t) {
    V <- spec$V_of_par(fit$opt$par, t)
    if (!pd_ok || !dim_ok) {
      status <- if (!has_sd) {
        "no_sdreport"
      } else if (!dim_ok) {
        "cov_dim_mismatch"
      } else {
        "pdHess_false"
      }
      return(na_row(t, V, status))
    }
    ## NA-guard the small-V boundary: SE(g)=SE(V)/(2V) is non-normal as V -> 0.
    if (is.na(V) || V <= 1e-8) {
      return(na_row(t, V, "boundary_na"))
    }
    J <- spec$dV_dpar(fit$opt$par, t)
    varV <- as.numeric(t(J) %*% cov_fixed %*% J)
    seV <- sqrt(max(varV, 0))
    if (!is.finite(seV)) {
      return(na_row(t, V, "se_nonfinite"))
    }
    se_g <- seV / (2 * V)
    ## The log-SD delta method is a first-order approximation valid only when V
    ## is well-separated from the zero boundary relative to its SE. se_g =
    ## SE(V)/(2V) is half the coefficient of variation of V; when it is large the
    ## component is barely identified (e.g. a collapsed binomial loading) and the
    ## interval spans many orders of magnitude -- uninformative, and it would
    ## spuriously "cover" everything. Emit NA rather than a garbage-wide bound;
    ## the NA rate is itself a diagnostic. (Route B is never the certificate.)
    if (se_g > 2.5) {
      return(na_row(t, V, "wide_na"))
    }
    g <- 0.5 * log(V)
    data.frame(
      trait = spec$trait_names[t], tier = spec$tier, estimate = V,
      lower = exp(2 * (g - z * se_g)), upper = exp(2 * (g + z * se_g)),
      se_logsd = se_g, method = "wald_logsd", pd_hessian = TRUE,
      ci_status = "ok", stringsAsFactors = FALSE, row.names = NULL
    )
  })
  do.call(rbind, out_list)
}

## ---- Cross-trait correlation: fix-and-refit profile ----------------------
## rho_ij = Sigma_ij / sqrt(Sigma_ii * Sigma_jj). Profile via fix-and-refit
## using the same penalty driver.

## Expand a mapped diagonal (Psi) parameter block back to one value per trait.
## A TMB `map` can collapse or fix entries: the common-diagonal case maps every
## trait to one shared level, and the mixed-family auto-Psi skip pins
## `theta_diag_B[t] = log(1e-6)` and maps single-trial binary traits off
## (R/fit-multi.R). In the skip case the free vector in `fit$opt$par` is shorter
## than `n_traits` and neither scalar nor full length, so scattering it back by
## position recycles and mis-assembles Sigma (issue #717). Reconstruct the full
## per-trait vector: free traits take their estimated value via the map level;
## mapped-off traits keep the engine's pinned start value (negligible Psi).
.expand_mapped_diag <- function(fit, name, free_vals, n_traits) {
  map <- fit$tmb_map[[name]]
  if (is.null(map)) {
    ## No map: the free block is already one value per trait, or a single
    ## shared value to recycle across traits.
    if (length(free_vals) == 1L) {
      return(rep(free_vals, n_traits))
    }
    return(free_vals)
  }
  lvl <- as.integer(map) # length n_traits; NA marks a fixed / mapped-off trait
  fixed <- tryCatch(
    as.numeric(fit$tmb_obj$env$parameters[[name]]),
    error = function(e) NULL
  )
  full <- if (!is.null(fixed) && length(fixed) == n_traits) {
    fixed
  } else {
    rep(log(1e-6), n_traits)
  }
  ok <- !is.na(lvl) & lvl >= 1L & lvl <= length(free_vals)
  full[ok] <- free_vals[lvl[ok]]
  full
}

#' Profile-likelihood CI for one cross-trait correlation
#'
#' For a fit returned by [gllvmTMB()], computes the profile-likelihood
#' confidence interval for one cross-trait correlation
#' \eqn{\rho_{ij} = \Sigma_{ij} / \sqrt{\Sigma_{ii}\Sigma_{jj}}} at one
#' covariance level. Cross-trait correlations are first-class outputs of the
#' factor-analytic decomposition and need accurate CIs at scale (a 6-trait
#' fit has 60 of them across four covariance levels).
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param tier `"unit"`, `"unit_slope"`, `"unit_obs"`, `"cluster"`,
#'   `"cluster2"`, `"phy"`, or `"spatial"`. Legacy aliases `"B"`, `"W"`,
#'   and `"spde"` are accepted. `"cluster"` and `"cluster2"` fail loud as
#'   diagonal-only structural-zero point routes; they are not profile targets.
#'   `"unit_slope"` is a selected-entry Gaussian canary for augmented
#'   ordinary random-regression coefficients.
#' @param i,j Trait indices (1-based, `i < j`). For `tier = "unit_slope"`,
#'   these are augmented coefficient indices on the interleaved `2T` vector.
#' @param level Confidence level. Default 0.95.
#' @return Length-3 numeric vector (`estimate`, `lower`, `upper`).
#'
#' @keywords internal
#' @noRd
profile_ci_correlation <- function(
  fit,
  tier = c(
    "unit", "unit_slope", "unit_obs", "cluster", "cluster2",
    "phy", "spatial", "B", "W", "spde"
  ),
  i,
  j,
  level = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  tier <- match.arg(tier)
  tier <- .normalise_level(tier, arg_name = "tier")
  if (tier %in% c("cluster", "cluster2")) {
    .profile_abort_point_only_rho(tier)
  }
  if (i >= j) {
    cli::cli_abort("Provide {.arg i} < {.arg j}.")
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
  n_dim <- nrow(Sigma_pt$R)
  if (i < 1L || j < 1L || i > n_dim || j > n_dim) {
    cli::cli_abort(c(
      "Correlation indices {.val {paste0(i, ',', j)}} out of range for tier {.val {tier}}.",
      "i" = "Valid indices for this tier are 1:{n_dim}."
    ))
  }
  rho_hat <- Sigma_pt$R[i, j]

  ## Build target function from the tier's parameter blocks
  par_names <- names(fit$opt$par)
  if (tier == "B_slope") {
    fids <- fit$tmb_data$family_id_vec %||% 0L
    if (any(fids != 0L)) {
      cli::cli_abort(c(
        "{.code rho:unit_slope} profile intervals are currently a Gaussian-only canary.",
        "i" = "Non-Gaussian augmented ordinary random-regression profiles need a separate calibration gate."
      ))
    }
    ix_rr <- which(par_names == "theta_rr_B_slope")
    ix_diag <- which(par_names == "theta_diag_B_slope")
    rank <- fit$d_B_slope
    use_rr <- isTRUE(fit$use$rr_B_slope)
    use_diag <- isTRUE(fit$use$diag_B_slope)
  } else if (tier == "B") {
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
    # spde
    ix_rr <- which(par_names == "theta_rr_spde_lv")
    ix_diag <- which(par_names == "log_tau_spde")
    rank <- fit$d_spde_lv
    use_rr <- isTRUE(fit$use$spatial_latent)
    use_diag <- isTRUE(fit$use$spatial_latent_unique)
  }
  if (!use_rr) {
    cli::cli_abort(
      "Tier {.val {tier}} has no {.code latent()} term; correlation profile not available."
    )
  }
  n_traits <- n_dim
  ## Name of the diagonal (Psi) parameter block for this tier, used to reconcile
  ## a TMB-mapped free vector back to one value per trait (#717).
  diag_name <- switch(
    tier,
    B_slope = "theta_diag_B_slope",
    B = "theta_diag_B",
    W = "theta_diag_W",
    phy = "log_sd_phy_diag",
    "log_tau_spde"
  )

  build_Lambda <- function(theta_rr, p, rank) {
    L <- matrix(0, p, rank)
    if (length(theta_rr) == 0L || rank == 0L) {
      return(L)
    }
    lam_diag <- theta_rr[seq_len(rank)]
    lam_lower <- theta_rr[-seq_len(rank)]
    ## Diagonal entries
    for (jj in seq_len(rank)) {
      L[jj, jj] <- lam_diag[jj]
    }
    ## Strict-lower entries packed column by column (column j has p-j
    ## entries at rows j+1, ..., p), matching the engine's TMB packing.
    idx <- 1L
    for (jj in seq_len(rank)) {
      if (jj < p) {
        for (ii in (jj + 1L):p) {
          if (idx <= length(lam_lower)) {
            L[ii, jj] <- lam_lower[idx]
          }
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
      ## Reconcile the (possibly TMB-mapped) free diagonal block back to one
      ## value per trait before adding it to diag(Sigma); a mixed-family fit
      ## carries fewer free theta_diag_B entries than traits (#717).
      th_diag <- .expand_mapped_diag(fit, diag_name, par[ix_diag], n_traits)
      if (tier == "spde") {
        diag(Sigma) <- diag(Sigma) + exp(-2 * th_diag)
      } else {
        diag(Sigma) <- diag(Sigma) + exp(2 * th_diag)
      }
    }
    if (Sigma[i, i] <= 0 || Sigma[j, j] <= 0) {
      return(NA_real_)
    }
    Sigma[i, j] / sqrt(Sigma[i, i] * Sigma[j, j])
  }

  bounds <- .profile_ci_via_refit(
    fit,
    target_fn,
    q_hat = rho_hat,
    level = level,
    q_lo_hint = max(rho_hat - 0.3, -0.999),
    q_hi_hint = min(rho_hat + 0.3, 0.999),
    q_lo_floor = -0.999,
    q_hi_ceiling = 0.999
  )
  ## Boundary guarantee: a confidence interval must contain its own point
  ## estimate. When the latent-scale correlation MLE sits at the natural
  ## boundary (|rho_hat| = 1 -- e.g. a rank-1 latent block where
  ## Sigma = Lambda Lambda^T is rank-deficient), the refit grid is floored /
  ## ceiled just inside +/-0.999 and cannot represent the MLE, so the
  ## boundary-side bound can be returned on the wrong side of rho_hat
  ## (lower > estimate, or upper < estimate). Clamp finite bounds so
  ## lower <= estimate <= upper always holds: the boundary side collapses to
  ## rho_hat = +/-1, which is the standard pinned-parameter CI semantic (the
  ## data are consistent with the correlation right up to the boundary).
  lower <- bounds$lower
  upper <- bounds$upper
  if (is.finite(lower)) lower <- min(lower, rho_hat)
  if (is.finite(upper)) upper <- max(upper, rho_hat)
  c(estimate = rho_hat, lower = lower, upper = upper)
}

## ---- Variance proportions: fix-and-refit profile -------------------------
## extract_proportions(fit) returns per-trait variance partitions across all
## components (shared_unit, unique_unit, shared_unit_obs, unique_unit_obs,
## unique_cluster, unique_cluster2, shared_phy, unique_phy, link_residual).
## profile_ci_proportions() supplies profile-likelihood CIs for each
## (trait, component) by Lagrange-style fix-and-refit on the proportion itself
## (not the raw numerator).
##
## The constraint is on `p_c,t(theta) = component_c,t(theta) / sum_c' component_c',t(theta)`,
## with the denominator floated across all tiers and the link-residual
## term (constant in family-aware terms for the families we currently
## support) added when present in the point-estimate decomposition.

## Internal: build a single per-(trait, component) target function that
## returns the proportion `p_c,t(theta)`. The denominator floats across
## all parameter blocks present in the fit (i.e. variance from all tiers
## the user has fitted, plus link_residual when non-zero).
##
## Returns NULL if the requested component is not present in the fit
## (caller should skip / omit, not error).
#' @keywords internal
#' @noRd
.proportion_target_fn <- function(fit, component, trait_idx) {
  par_names <- names(fit$opt$par)
  T <- fit$n_traits %||% length(levels(fit$data[[fit$trait_col]]))

  ## Per-tier index blocks (NULL if tier absent).
  ix_rr_B    <- which(par_names == "theta_rr_B")
  ix_diag_B  <- which(par_names == "theta_diag_B")
  ix_rr_W    <- which(par_names == "theta_rr_W")
  ix_diag_W  <- which(par_names == "theta_diag_W")
  ix_diag_cluster <- which(par_names == "theta_diag_species")
  ix_diag_cluster2 <- which(par_names == "theta_diag_cluster2")
  ix_rr_phy  <- which(par_names == "theta_rr_phy")
  ix_diag_phy <- which(par_names == "log_sd_phy_diag")

  d_B   <- fit$d_B %||% 0L
  d_W   <- fit$d_W %||% 0L
  d_phy <- fit$d_phy %||% 0L

  use_rr_B   <- isTRUE(fit$use$rr_B)
  use_diag_B <- isTRUE(fit$use$diag_B)
  use_rr_W   <- isTRUE(fit$use$rr_W)
  use_diag_W <- isTRUE(fit$use$diag_W)
  use_diag_cluster <- isTRUE(fit$use$diag_species)
  use_diag_cluster2 <- isTRUE(fit$use$diag_cluster2)
  use_rr_phy <- isTRUE(fit$use$phylo_rr)
  use_diag_phy <- isTRUE(fit$use$phylo_diag)

  ## Per-trait link-residual is constant w.r.t. fitted parameters for the
  ## families this stage supports (Gaussian -> 0, binomial -> pi^2/3,
  ## cloglog -> pi^2/6, probit -> 1). It enters the denominator as a
  ## fixed offset; for mean-dependent families (Poisson, Gamma, etc.)
  ## extract_proportions() uses the point-estimate fitted mean -- we
  ## reuse the same point-estimate offset here so the denominator
  ## representation matches the extractor at theta = theta_hat.
  link_resid_vec <- tryCatch(
    as.numeric(link_residual_per_trait(fit)),
    error = function(e) rep(0, T)
  )
  if (length(link_resid_vec) != T) link_resid_vec <- rep(0, T)

  ## Local Lambda builder (mirror of the engine packing, copy of the
  ## ones inside profile_ci_communality / profile_ci_correlation).
  build_Lambda <- function(theta_rr, p, rank) {
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

  ## Per-component numerator builder (function of par). NULL when the
  ## component is structurally absent.
  num_fn <- switch(
    component,
    shared_unit = if (use_rr_B && length(ix_rr_B) > 0L) {
      function(par) {
        L <- build_Lambda(par[ix_rr_B], p = T, rank = d_B)
        diag(L %*% t(L))[trait_idx]
      }
    } else NULL,
    unique_unit = if (use_diag_B && length(ix_diag_B) > 0L) {
      function(par) exp(2 * par[ix_diag_B][trait_idx])
    } else NULL,
    shared_unit_obs = if (use_rr_W && length(ix_rr_W) > 0L) {
      function(par) {
        L <- build_Lambda(par[ix_rr_W], p = T, rank = d_W)
        diag(L %*% t(L))[trait_idx]
      }
    } else NULL,
    unique_unit_obs = if (use_diag_W && length(ix_diag_W) > 0L) {
      function(par) exp(2 * par[ix_diag_W][trait_idx])
    } else NULL,
    unique_cluster = if (
      use_diag_cluster && length(ix_diag_cluster) > 0L
    ) {
      function(par) exp(2 * par[ix_diag_cluster][trait_idx])
    } else NULL,
    unique_cluster2 = if (
      use_diag_cluster2 && length(ix_diag_cluster2) > 0L
    ) {
      function(par) exp(2 * par[ix_diag_cluster2][trait_idx])
    } else NULL,
    shared_phy = if (use_rr_phy && length(ix_rr_phy) > 0L) {
      function(par) {
        L <- build_Lambda(par[ix_rr_phy], p = T, rank = d_phy)
        diag(L %*% t(L))[trait_idx]
      }
    } else NULL,
    unique_phy = if (use_diag_phy && length(ix_diag_phy) > 0L) {
      function(par) exp(2 * par[ix_diag_phy][trait_idx])
    } else NULL,
    link_residual = NULL,
    NULL
  )
  if (is.null(num_fn)) {
    return(NULL)
  }

  ## Full denominator: sum of all component variances at trait t,
  ## across whatever tiers the fit uses, plus the link-residual offset.
  total_fn <- function(par) {
    s <- rep(0, length(trait_idx))
    if (use_rr_B && length(ix_rr_B) > 0L) {
      L <- build_Lambda(par[ix_rr_B], p = T, rank = d_B)
      s <- s + diag(L %*% t(L))[trait_idx]
    }
    if (use_diag_B && length(ix_diag_B) > 0L) {
      s <- s + exp(2 * par[ix_diag_B][trait_idx])
    }
    if (use_rr_W && length(ix_rr_W) > 0L) {
      L <- build_Lambda(par[ix_rr_W], p = T, rank = d_W)
      s <- s + diag(L %*% t(L))[trait_idx]
    }
    if (use_diag_W && length(ix_diag_W) > 0L) {
      s <- s + exp(2 * par[ix_diag_W][trait_idx])
    }
    if (use_diag_cluster && length(ix_diag_cluster) > 0L) {
      s <- s + exp(2 * par[ix_diag_cluster][trait_idx])
    }
    if (use_diag_cluster2 && length(ix_diag_cluster2) > 0L) {
      s <- s + exp(2 * par[ix_diag_cluster2][trait_idx])
    }
    if (use_rr_phy && length(ix_rr_phy) > 0L) {
      L <- build_Lambda(par[ix_rr_phy], p = T, rank = d_phy)
      s <- s + diag(L %*% t(L))[trait_idx]
    }
    if (use_diag_phy && length(ix_diag_phy) > 0L) {
      s <- s + exp(2 * par[ix_diag_phy][trait_idx])
    }
    s + link_resid_vec[trait_idx]
  }

  function(par, fit) {
    num <- num_fn(par)
    den <- total_fn(par)
    if (any(!is.finite(num)) || any(!is.finite(den)) || any(den <= 0)) {
      return(NA_real_)
    }
    as.numeric(num / den)
  }
}

#' Profile-likelihood CIs for per-trait variance proportions
#'
#' For each `(trait, component)` returned by [extract_proportions()],
#' computes a profile-likelihood CI for the proportion of total trait
#' variance attributable to that component. The constraint is applied
#' to the proportion itself (Lagrange-style fix-and-refit), so the
#' denominator floats across all parameter blocks during the
#' constrained refit (i.e. the CI on `p_c,t = sigma2_c,t / sum_{c'}
#' sigma2_c',t` correctly accounts for the fact that fixing the
#' numerator shifts the denominator as nuisance parameters re-optimise).
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param components Character vector of component names to include
#'   (e.g. `c("shared_unit", "unique_unit")`). `NULL` (default) uses all
#'   components present in `extract_proportions(fit)`.
#' @param trait_idx Integer vector of 1-based trait indices, or `NULL`
#'   (default) for all traits.
#' @param level Confidence level. Default `0.95`.
#' @return A data frame with one row per `(trait, component)`:
#'   * `trait`: trait name (character).
#'   * `component`: component name (character).
#'   * `proportion`: point estimate (matches [extract_proportions()]).
#'   * `lower`, `upper`: profile-likelihood bounds.
#'   * `method`: `"profile"` for successful inversions; `"(unavailable)"`
#'     when the component is structurally pinned (e.g. `link_residual`
#'     for fixed-scale families like Gaussian / binomial; the bounds
#'     collapse to the point estimate); `NA` when uniroot could not
#'     bracket.
#'
#' @section Implementation notes:
#' `shared_*` and `unique_*` components are profiled via the shared
#' internal `profile_ci_communality()` driver `.profile_ci_via_refit()` applied
#' to a custom target function that returns the (trait, component)
#' proportion as a function of all model parameters. For
#' `link_residual`, fixed-scale families (Gaussian, binomial with any
#' standard link, probit) give a constant-in-theta numerator and a
#' point-estimate denominator: bounds collapse to the point with
#' `method = "(unavailable)"`. Mean-dependent residuals (Poisson,
#' Gamma, Tweedie, ...) are not yet profiled and return `NA` bounds
#' with `method = "(unavailable)"`.
#'
#' @seealso [extract_proportions()].
#'
#' @keywords internal
#' @noRd
profile_ci_proportions <- function(
  fit,
  components = NULL,
  trait_idx  = NULL,
  level      = 0.95
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  pt <- suppressMessages(extract_proportions(fit, format = "long"))
  ## Sanity: extract_proportions() may add link_residual conditionally.
  comps_present <- as.character(unique(pt$component))
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  if (!is.numeric(trait_idx) || any(trait_idx < 1L) || any(trait_idx > T)) {
    cli::cli_abort(
      "{.arg trait_idx} must be integers in 1:{T}; got {.val {trait_idx}}."
    )
  }
  trait_idx <- as.integer(trait_idx)

  ## Component filter.
  if (is.null(components)) {
    components <- comps_present
  } else {
    components <- as.character(components)
    bad <- setdiff(components, comps_present)
    if (length(bad) > 0L) {
      cli::cli_abort(c(
        "{cli::qty(length(bad))} component name{?s} not present in this fit: {.val {bad}}.",
        i = "Available components: {.val {comps_present}}."
      ))
    }
  }

  ## Build a (trait x component) matrix of point-estimate PROPORTIONS
  ## from the long-format extractor (the wide format returns absolute
  ## variances, not proportions).
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

  ## Helper: which families is `link_residual` constant in theta for?
  ## Gaussian / binomial(any standard link) / Bernoulli-like all give a
  ## numerator that does not depend on the fitted theta. Mean-dependent
  ## families (Poisson, Gamma, Tweedie, ...) DO depend on theta via the
  ## fitted mu_t -- those are reported as method="(unavailable)" with NA
  ## bounds until a dedicated profile path lands.
  is_link_resid_fixed <- function() {
    fids <- fit$tmb_data$family_id_vec
    if (is.null(fids)) return(TRUE)
    fid_set <- unique(fids)
    ## family ids: 0 = gaussian, 1 = binomial. Anything else may be
    ## mean-dependent; mark as not-fixed to flag the issue.
    all(fid_set %in% c(0L, 1L))
  }

  out_rows <- list()
  for (comp in components) {
    for (t in trait_idx) {
      p_hat <- pt_mat[t, comp]
      base_row <- data.frame(
        trait = trait_names[t],
        component = comp,
        proportion = p_hat,
        lower = NA_real_,
        upper = NA_real_,
        method = NA_character_,
        stringsAsFactors = FALSE,
        row.names = NULL
      )

      if (identical(comp, "link_residual")) {
        ## Structurally fixed numerator for the families currently
        ## supported. Collapse bounds to the point with method =
        ## "(unavailable)" rather than producing a noisy NA.
        if (is_link_resid_fixed()) {
          base_row$lower <- p_hat
          base_row$upper <- p_hat
          base_row$method <- "(unavailable)"
        } else {
          base_row$method <- "(unavailable)"
        }
        out_rows[[length(out_rows) + 1L]] <- base_row
        next
      }

      target_fn <- .proportion_target_fn(fit, component = comp, trait_idx = t)
      if (is.null(target_fn)) {
        ## Component absent at the model-state level (shouldn't happen
        ## here because we filtered against extract_proportions() which
        ## also gates on fit$use$*, but defensive).
        base_row$method <- "(unavailable)"
        out_rows[[length(out_rows) + 1L]] <- base_row
        next
      }

      ## Adapt the search floor / ceiling to p_hat: if the point
      ## estimate is itself near 0 or 1, the default safety floor (0.001)
      ## would sit ABOVE p_hat and the lower-bound search would report
      ## the floor as the bound, breaking lower <= p_hat. Set the floor
      ## strictly below p_hat in those cases.
      q_floor <- min(0.001, max(p_hat / 10, .Machine$double.eps))
      q_ceil <- max(0.999, min(1 - (1 - p_hat) / 10, 1 - .Machine$double.eps))
      bounds <- tryCatch(
        .profile_ci_via_refit(
          fit,
          target_fn,
          q_hat = p_hat,
          level = level,
          q_lo_hint = max(p_hat - 0.3, q_floor),
          q_hi_hint = min(p_hat + 0.3, q_ceil),
          q_lo_floor = q_floor,
          q_hi_ceiling = q_ceil
        ),
        error = function(e) list(lower = NA_real_, upper = NA_real_)
      )
      base_row$lower <- bounds$lower
      base_row$upper <- bounds$upper
      base_row$method <- "profile"
      out_rows[[length(out_rows) + 1L]] <- base_row
    }
  }
  do.call(rbind, out_rows)
}

## ---- Profile CI for predictor-informed latent-score effects B_lv ----------

#' Profile confidence intervals for predictor-informed latent-score effects
#'
#' Likelihood-profile confidence intervals for the trait-scale effects
#' \eqn{B_{lv} = \Lambda_B \alpha^\top} of a predictor-informed latent term
#' (\code{latent(..., lv = ~ x)}), obtained by inverting the likelihood-ratio
#' test for each selected entry via constrained refit. Unlike a delta-method
#' Wald interval, this route follows the fitted likelihood away from the point
#' estimate and does not use the target's local Hessian approximation. The
#' constrained refits must still be numerically stable, and a computed interval
#' is not evidence of repeated-sampling calibration. The default reference is
#' the standard asymptotic \eqn{\chi^2_1} likelihood-ratio cutoff.
#'
#' `B_lv` is rotation-invariant, so it is a valid recovery/inference target for
#' any latent rank; the raw loadings and raw \eqn{\alpha} are not.
#'
#' `r lifecycle::badge("experimental")`
#'
#' @section Interval calibration:
#' Software tests exercise the profile route, but broad empirical interval
#' coverage has not been established. Treat the returned bounds as experimental,
#' especially for small samples, boundary targets, non-Gaussian likelihoods, and
#' mixed-family fits. A finite interval only shows that the constrained numerical
#' profile crossed the requested cutoff.
#'
#' @param fit A fitted \code{gllvmTMB} model with a predictor-informed latent
#'   term.
#' @param trait,predictor Optional integer indices selecting entries of
#'   \eqn{B_{lv}} (traits x predictors); default is every entry.
#' @param level Confidence level (default \code{0.95}).
#' @param reference \code{"chisq"} (default) for the standard asymptotic
#'   likelihood-ratio cutoff, or \code{"t"} for an explicit sensitivity
#'   analysis using \code{qt((1 + level) / 2, df)^2}. The t-based option is not
#'   a calibrated finite-sample correction for this model.
#' @param df Degrees of freedom supplied by the user when
#'   \code{reference = "t"}. There is no generally justified automatic rule for
#'   this target, so the function does not infer \code{df} from the number of
#'   units or latent dimensions.
#'
#' @return A data frame with one row per selected entry: \code{trait},
#'   \code{predictor}, \code{estimate}, \code{lower}, \code{upper},
#'   \code{level}, \code{method}, \code{reference}, \code{df}.
#'
#' @keywords internal
#' @noRd
profile_ci_lv_effects <- function(fit,
                                  trait = NULL,
                                  predictor = NULL,
                                  level = 0.95,
                                  reference = c("chisq", "t"),
                                  df = NULL) {
  reference <- match.arg(reference)
  B_hat <- fit$report[["B_lv_unit"]]
  if (is.null(B_hat)) {
    cli::cli_abort(c(
      "{.fn profile_ci_lv_effects} needs a predictor-informed latent term.",
      "i" = "Fit with {.code latent(0 + trait | unit, d = K, lv = ~ x)}."
    ))
  }
  B_hat <- as.matrix(B_hat)
  n_tr <- nrow(B_hat)
  n_pr <- ncol(B_hat)
  d_B <- tryCatch(ncol(as.matrix(fit$report[["Lambda_B"]])), error = function(e) 1L)

  if (identical(reference, "t") && is.null(df)) {
    cli::cli_abort(c(
      "The t-based sensitivity analysis requires an explicit {.arg df}.",
      "i" = "There is no generally justified automatic degrees-of-freedom rule for {.code B_lv}.",
      ">" = "Use the default {.code reference = \"chisq\"}, or supply a scientifically justified {.arg df} and report it as a sensitivity analysis."
    ))
  }
  crit <- if (identical(reference, "t")) {
    .qt_threshold(level, df)
  } else {
    .qchisq_threshold(level)
  }

  ## B_lv = Lambda_B alpha^T is a pure function of the FIXED params. For rank 1
  ## it is theta_rr_B[t] * alpha_lv_B[j] (fast, no inner solve); for higher rank
  ## fall back to the engine report at the constrained par (exact, slower).
  nm <- names(fit$opt$par)
  idx_th <- which(nm == "theta_rr_B")
  idx_al <- which(nm == "alpha_lv_B")
  fast_rank1 <- d_B == 1L && length(idx_th) == n_tr && length(idx_al) >= n_pr
  make_target <- function(ti, pj) {
    force(ti); force(pj)
    if (fast_rank1) {
      function(par, fit) par[idx_th[ti]] * par[idx_al[pj]]
    } else {
      function(par, fit) {
        fit$tmb_obj$fn(par)
        as.numeric(as.matrix(fit$tmb_obj$report()[["B_lv_unit"]])[ti, pj])
      }
    }
  }
  ## Analytic gradient of B_lv[ti, pj] = theta_rr_B[ti] * alpha_lv_B[pj] w.r.t.
  ## the fixed parameter vector (rank 1). Drives the constrained refit far faster
  ## than finite differences; NULL (finite-diff) for the higher-rank fallback.
  make_grad <- function(ti, pj) {
    force(ti); force(pj)
    if (!fast_rank1) {
      return(NULL)
    }
    function(par, fit) {
      g <- numeric(length(par))
      g[idx_th[ti]] <- par[idx_al[pj]]
      g[idx_al[pj]] <- par[idx_th[ti]]
      g
    }
  }

  trait_ids <- if (is.null(trait)) seq_len(n_tr) else as.integer(trait)
  pred_ids <- if (is.null(predictor)) seq_len(n_pr) else as.integer(predictor)
  tr_names <- rownames(B_hat) %||% paste0("trait", seq_len(n_tr))
  pr_names <- colnames(B_hat) %||% paste0("lv", seq_len(n_pr))

  rows <- list()
  for (ti in trait_ids) {
    for (pj in pred_ids) {
      bounds <- .profile_ci_via_refit(
        fit,
        make_target(ti, pj),
        q_hat = B_hat[ti, pj],
        level = level,
        crit = crit,
        target_grad = make_grad(ti, pj)
      )
      rows[[length(rows) + 1L]] <- data.frame(
        trait = tr_names[ti],
        predictor = pr_names[pj],
        estimate = B_hat[ti, pj],
        lower = bounds$lower,
        upper = bounds$upper,
        level = level,
        method = "profile",
        reference = reference,
        df = if (identical(reference, "t")) df else NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}
