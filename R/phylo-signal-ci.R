## Wald (delta-method) and parametric-bootstrap CIs for per-trait
## phylogenetic signal H^2 = sigma2_phy / (sigma2_phy + sigma2_non).
##
## Companion to `profile_ci_phylo_signal()` in R/profile-derived.R, which
## provides the profile path. The three CI methods together (profile +
## wald + bootstrap) complete Lane 1 / A3 of Phase B-INF (Design 58).
##
## Policy (mirrors `profile_ci_phylo_signal`):
##
## * 2-component case -- `use$phylo_diag && use$diag_species &&
##   !use$rr_B && !use$diag_B`: H^2 is a closed-form ratio of two
##   exponentiated log-SDs and reduces to plogis() of a linear contrast.
##   Wald path uses the lincomb `2 * log_sd_phy_diag[t] -
##   2 * theta_diag_species[t]` directly: SE on the lincomb is
##   sqrt(lc' * cov.fixed * lc); back-transform via plogis().
##
## * Richer cases (3+ components, or `unique` at unit-tier instead of
##   species cluster): H^2 = sigma2_phy / V_eta is a nonlinear function
##   of multiple fixed parameters. Wald path builds a numerical Jacobian
##   d H^2 / d theta_fixed at the MLE (perturbing each fixed-parameter
##   index by `eps` and recomputing the per-trait variance components
##   from `obj$report(par_plus)`), then SE^2 = J * cov.fixed * J'.
##   Symmetric Wald on the H^2 scale, clipped to [0, 1] for sanity.
##
## Bootstrap: parametric simulate-refit (re-using the same machinery
## bootstrap_Sigma() uses for refit + extract). Per replicate we compute
## extract_phylo_signal(out)$H2; aggregate percentile CIs across traits.

## ---- Helpers shared with profile-derived.R (re-declared here to keep
##      this file self-contained per Lane 1 disjoint-files rule). They
##      remain `@noRd` and identical to the originals.

#' @keywords internal
#' @noRd
.phylo_signal_zero_lincomb <- function(fit) {
  numeric(length(fit$opt$par))
}

#' @keywords internal
#' @noRd
.phylo_signal_par_indices <- function(fit, name) {
  which(names(fit$opt$par) == name)
}

## ---- Reject fits with no phylogenetic component ---------------------------

#' @keywords internal
#' @noRd
.phylo_signal_check_has_phy <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  has_phy <- isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  if (!has_phy) {
    cli::cli_abort(c(
      "Phylogenetic signal requires a phylogenetic component.",
      "i" = "Refit with {.code phylo_latent()} or {.code phylo_unique()}."
    ))
  }
  invisible(TRUE)
}

## ---- Numerical Jacobian of per-trait H^2 -----------------------------------
## Used by the richer-cases Wald path. We compute H^2_t from a parameter
## vector `par` by calling `obj$report(par)` and reading off the variance
## components, then perturb each fixed parameter index by `eps` and form
## the finite-difference column.
##
## H^2_t = Sigma_phy_diag[t] / V_eta_t
## V_eta_t = Sigma_phy_diag[t] + Sigma_non_shared_diag[t] +
##           Psi_non_diag[t]
##
## Sigma_phy is `Lambda_phy %*% t(Lambda_phy) + diag(sigma2_phy_diag)`
## when `phylo_diag` is fit, or just `Lambda_phy %*% t(Lambda_phy)` when
## only `phylo_rr` is fit. Sigma_non_shared is `Lambda_B %*% t(Lambda_B)`.
## Psi_non = diag(sigma2_diag_B) when `diag_B` is fit, or
## diag(sigma2_diag_species) (`sd_q^2`) when `diag_species` is fit at
## the non-unit cluster grouping. We pull the per-trait diagonals via
## `obj$report()` keys that mirror `extract_phylo_signal()` directly.

#' @keywords internal
#' @noRd
.phylo_signal_H2_from_report <- function(rep_list, T) {
  ## Sigma_phy diagonal (T-vector). Mirrors extract_phylo_signal() in
  ## R/extract-omega.R: Lambda_phy %*% t(Lambda_phy) plus sd_phy_diag^2
  ## when present (paired phylo_latent + phylo_unique case). For the
  ## rerouted "phylo_unique only" case, the per-trait phylo variances
  ## live on the diagonal of Lambda_phy (engine rewrites the lone
  ## phylo_unique to phylo_rr with diagonal Lambda).
  Lphy <- rep_list[["Lambda_phy"]]
  Sigma_phy_diag <- if (!is.null(Lphy)) {
    Lphy <- as.matrix(Lphy)
    diag(Lphy %*% t(Lphy))
  } else {
    rep(0, T)
  }
  sd_phy_diag <- rep_list[["sd_phy_diag"]]
  if (!is.null(sd_phy_diag)) {
    Sigma_phy_diag <- Sigma_phy_diag + as.numeric(sd_phy_diag)^2
  }
  ## Non-phylo shared (Sigma_B from Lambda_B).
  L_B <- rep_list[["Lambda_B"]]
  Sigma_non_shared <- if (!is.null(L_B)) {
    L_B <- as.matrix(L_B)
    diag(L_B %*% t(L_B))
  } else {
    rep(0, T)
  }
  ## Non-phylo unique: sum sd_B^2 (diag_B at unit tier) and sd_q^2
  ## (diag_species at species cluster). Either or both may be present.
  Psi_non_diag <- rep(0, T)
  sd_B <- rep_list[["sd_B"]]
  if (!is.null(sd_B)) {
    Psi_non_diag <- Psi_non_diag + as.numeric(sd_B)^2
  }
  sd_q <- rep_list[["sd_q"]]
  if (!is.null(sd_q)) {
    Psi_non_diag <- Psi_non_diag + as.numeric(sd_q)^2
  }
  ## Pad to length T defensively (mixed missing reports).
  if (length(Sigma_phy_diag) < T) {
    Sigma_phy_diag <- c(Sigma_phy_diag, rep(0, T - length(Sigma_phy_diag)))
  }
  if (length(Sigma_non_shared) < T) {
    Sigma_non_shared <- c(
      Sigma_non_shared,
      rep(0, T - length(Sigma_non_shared))
    )
  }
  if (length(Psi_non_diag) < T) {
    Psi_non_diag <- c(Psi_non_diag, rep(0, T - length(Psi_non_diag)))
  }
  V_eta <- Sigma_phy_diag + Sigma_non_shared + Psi_non_diag
  H2 <- ifelse(V_eta > 0, Sigma_phy_diag / V_eta, NA_real_)
  H2
}

#' @keywords internal
#' @noRd
.phylo_signal_jacobian <- function(fit, T, eps = 1e-6) {
  obj <- fit$tmb_obj
  par_best <- obj$env$last.par.best
  random_idx <- if (length(obj$env$random) > 0L) obj$env$random else integer(0)
  fixed_idx <- setdiff(seq_along(par_best), random_idx)
  ## H^2 at the MLE.
  rep_base <- obj$report(par_best)
  H2_base <- .phylo_signal_H2_from_report(rep_base, T = T)
  n_par <- length(fixed_idx)
  J <- matrix(0, T, n_par)
  for (p in seq_len(n_par)) {
    par_plus <- par_best
    par_plus[fixed_idx[p]] <- par_plus[fixed_idx[p]] + eps
    rep_plus <- tryCatch(obj$report(par_plus), error = function(e) NULL)
    if (is.null(rep_plus)) {
      next
    }
    H2_plus <- .phylo_signal_H2_from_report(rep_plus, T = T)
    J[, p] <- (H2_plus - H2_base) / eps
  }
  list(H2 = H2_base, J = J)
}

## ---- Wald (delta-method) CI on H^2 -----------------------------------------

#' Wald (delta-method) CI for per-trait phylogenetic signal H^2
#'
#' Companion to [profile_ci_phylo_signal()]. Mirrors the same
#' 2-component-vs-richer-case policy:
#'
#' * 2-component (`phylo_diag` + `diag_species`, no species-level
#'   `latent` or `unique` at the unit tier): closed-form delta-method on
#'   the linear contrast `2 * log_sd_phy_diag[t] - 2 *
#'   theta_diag_species[t]`. SE on the lincomb is `sqrt(lc' * cov.fixed
#'   * lc)`; back-transform via [plogis()].
#'
#' * Richer cases (3+ components, lone-`phylo_unique` rerouted to
#'   `phylo_rr`, or species-level `unique` at the unit tier with
#'   `unit == species`): numerical Jacobian of H^2 on the
#'   fixed-parameter scale, then symmetric Wald on the logit-H^2 scale
#'   (with delta-method SE on logit) and back-transform via [plogis()].
#'   At H^2 near 0 or 1 the logit blows up; the path falls back to
#'   symmetric Wald on the H^2 scale clipped to [0, 1].
#'
#' @param fit A fit returned by [gllvmTMB()] with a phylogenetic
#'   component (`phylo_latent()` or `phylo_unique()`).
#' @param trait_idx Integer vector of 1-based trait indices, or `NULL`
#'   (default) for all traits.
#' @param level Confidence level. Default 0.95.
#'
#' @return A data frame with columns `trait`, `H2`, `lower`, `upper`,
#'   `method` (`"wald"` for the closed-form 2-component branch;
#'   `"wald(numeric)"` for the numerical-Jacobian branch).
#'
#' @keywords internal
#' @noRd
.phylo_signal_wald_ci <- function(fit, trait_idx = NULL, level = 0.95) {
  .phylo_signal_check_has_phy(fit)
  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport")) {
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      "i" = "Refit so {.code fit$sd_report} is populated."
    ))
  }
  cov_fixed <- fit$sd_report$cov.fixed
  if (is.null(cov_fixed) || !is.matrix(cov_fixed)) {
    cli::cli_abort(
      "Fit's {.code sd_report$cov.fixed} is missing; cannot compute Wald CI."
    )
  }
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  alpha <- 1 - level
  zcrit <- stats::qnorm(1 - alpha / 2)

  ## Decide branch: simple 2-component (mirror profile_ci_phylo_signal).
  has_simple_2comp <-
    isTRUE(fit$use$phylo_diag) &&
    isTRUE(fit$use$diag_species) &&
    !isTRUE(fit$use$rr_B) &&
    !isTRUE(fit$use$diag_B)

  ## Point estimate from the same report quantities used by the
  ## numerical-Jacobian path (so the centre lines up with the CI). For
  ## the simple 2-component case this matches plogis(lincomb) too.
  obj <- fit$tmb_obj
  par_best <- obj$env$last.par.best
  rep_base <- obj$report(par_best)
  H2_hat <- .phylo_signal_H2_from_report(rep_base, T = T)

  if (has_simple_2comp) {
    ix_phy <- .phylo_signal_par_indices(fit, "log_sd_phy_diag")
    ix_non <- .phylo_signal_par_indices(fit, "theta_diag_species")
    if (length(ix_phy) != T || length(ix_non) != T) {
      cli::cli_inform(
        "Per-trait dimensions mismatch; falling back to numeric Jacobian Wald."
      )
      return(.phylo_signal_wald_numeric(
        fit,
        trait_idx = trait_idx,
        level = level,
        H2_hat = H2_hat
      ))
    }
    out_list <- vector("list", length(trait_idx))
    par_vec <- fit$opt$par
    for (k in seq_along(trait_idx)) {
      t <- trait_idx[k]
      lc <- .phylo_signal_zero_lincomb(fit)
      lc[ix_phy[t]] <- 2
      lc[ix_non[t]] <- -2
      ## SE on the lincomb scale (logit-H^2 scale).
      var_lc <- as.numeric(crossprod(lc, cov_fixed %*% lc))
      if (!is.finite(var_lc) || var_lc < 0) {
        var_lc <- NA_real_
      }
      se_lc <- sqrt(var_lc)
      mle_lc <- as.numeric(crossprod(par_vec, lc))
      lo_lc <- mle_lc - zcrit * se_lc
      hi_lc <- mle_lc + zcrit * se_lc
      out_list[[k]] <- data.frame(
        trait = trait_names[t],
        H2 = H2_hat[t],
        lower = if (is.na(se_lc)) NA_real_ else stats::plogis(lo_lc),
        upper = if (is.na(se_lc)) NA_real_ else stats::plogis(hi_lc),
        method = "wald",
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    }
    return(do.call(rbind, out_list))
  }

  ## Richer cases: numerical Jacobian on H^2.
  .phylo_signal_wald_numeric(
    fit,
    trait_idx = trait_idx,
    level = level,
    H2_hat = H2_hat
  )
}

#' @keywords internal
#' @noRd
.phylo_signal_wald_numeric <- function(
  fit,
  trait_idx,
  level,
  H2_hat = NULL
) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  alpha <- 1 - level
  zcrit <- stats::qnorm(1 - alpha / 2)
  if (is.null(H2_hat)) {
    obj <- fit$tmb_obj
    par_best <- obj$env$last.par.best
    rep_base <- obj$report(par_best)
    H2_hat <- .phylo_signal_H2_from_report(rep_base, T = T)
  }
  jac <- tryCatch(
    .phylo_signal_jacobian(fit, T = T),
    error = function(e) NULL
  )
  cov_fixed <- fit$sd_report$cov.fixed
  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    lo <- NA_real_
    hi <- NA_real_
    if (!is.null(jac) && is.matrix(jac$J) && nrow(jac$J) >= t) {
      j_row <- jac$J[t, ]
      var_t <- as.numeric(crossprod(j_row, cov_fixed %*% j_row))
      if (is.finite(var_t) && var_t >= 0) {
        se_t <- sqrt(var_t)
        ## Apply Wald on the logit-H^2 scale and back-transform via
        ## plogis(). The logit transform stabilises the variance on the
        ## bounded support [0, 1], matching the closed-form 2-component
        ## branch (which profiles plogis(lincomb) directly). Delta-method
        ## SE on logit(H^2) is SE(H^2) / (H^2 * (1 - H^2)). At H^2 near
        ## 0 or 1 the gradient becomes singular; we fall back to clipped
        ## symmetric Wald on H^2 in that boundary case.
        h <- H2_hat[t]
        if (is.finite(h) && h > 1e-8 && h < 1 - 1e-8) {
          g_hat <- stats::qlogis(h)
          dg_dH <- 1 / (h * (1 - h))
          se_g <- se_t * dg_dH
          if (is.finite(se_g) && se_g >= 0) {
            lo <- stats::plogis(g_hat - zcrit * se_g)
            hi <- stats::plogis(g_hat + zcrit * se_g)
          } else {
            lo <- max(0, h - zcrit * se_t)
            hi <- min(1, h + zcrit * se_t)
          }
        } else {
          ## At the boundary (H^2 ~ 0 or ~ 1), the logit blows up. Fall
          ## back to symmetric Wald on H^2 clipped to [0, 1].
          lo <- max(0, h - zcrit * se_t)
          hi <- min(1, h + zcrit * se_t)
        }
      }
    }
    out_list[[k]] <- data.frame(
      trait = trait_names[t],
      H2 = H2_hat[t],
      lower = lo,
      upper = hi,
      method = "wald(numeric)",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  do.call(rbind, out_list)
}

## ---- Bootstrap CI on H^2 ---------------------------------------------------
## Parametric simulate-refit. Re-uses `.reconstruct_multi_formula()` and
## simulate.gllvmTMB_multi() (the same plumbing bootstrap_Sigma() uses).
## Each replicate refits the same formula on a simulated response vector;
## extracts H^2 via extract_phylo_signal(); percentile CIs at the
## requested level.

#' Parametric-bootstrap CI for per-trait phylogenetic signal H^2
#'
#' @param fit A fit returned by [gllvmTMB()] with a phylogenetic
#'   component.
#' @param trait_idx Integer vector of 1-based trait indices, or `NULL`
#'   (default) for all traits.
#' @param level Confidence level. Default 0.95.
#' @param nsim Integer; number of bootstrap replicates. Default 200.
#' @param seed Optional RNG seed for reproducibility.
#'
#' @return A data frame with columns `trait`, `H2`, `lower`, `upper`,
#'   `method` (`"bootstrap"`), and `n_failed` as an attribute.
#'
#' @keywords internal
#' @noRd
.phylo_signal_bootstrap_ci <- function(
  fit,
  trait_idx = NULL,
  level = 0.95,
  nsim = 200L,
  seed = NULL
) {
  .phylo_signal_check_has_phy(fit)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a scalar in (0, 1); got {level}.")
  }
  if (!is.numeric(nsim) || nsim < 1L) {
    cli::cli_abort("{.arg nsim} must be a positive integer; got {nsim}.")
  }
  nsim <- as.integer(nsim)
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  ## Point estimate via report (matches Wald + handles unit != species).
  obj_pe <- fit$tmb_obj
  rep_pe <- obj_pe$report(obj_pe$env$last.par.best)
  H2_hat <- .phylo_signal_H2_from_report(rep_pe, T = T)

  ## Reconstruct the original formula (via the same helper bootstrap_Sigma
  ## uses; lives in R/bootstrap-sigma.R).
  formula <- .reconstruct_multi_formula(fit)
  trait <- fit$trait_col
  site <- fit$unit_col
  species <- fit$species_col
  family <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data <- fit$data
  resp <- all.vars(fit$formula)[1]
  if (!resp %in% names(data)) {
    cli::cli_abort(
      "Response column {.var {resp}} not found in {.code fit$data}."
    )
  }
  ## `phylo_unique()` auto-populates `lambda_constraint$phy` to make
  ## Lambda_phy diagonal; passing that back to gllvmTMB() during refit
  ## triggers a guard ("phylo_unique() supplies its own diagonal
  ## lambda_constraint..."). Strip the phy slot so the refit re-derives
  ## it from the formula on its own.
  lc <- fit$lambda_constraint
  if (!is.null(lc) && "phy" %in% names(lc) && isTRUE(fit$use$phylo_unique)) {
    lc <- lc[setdiff(names(lc), "phy")]
    if (length(lc) == 0L) {
      lc <- NULL
    }
  }
  aux <- list(
    phylo_vcv = fit$phylo_vcv,
    phylo_tree = fit$phylo_tree,
    mesh = fit$mesh,
    lambda_constraint = lc
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  ## Pre-draw simulated responses in the parent process for reproducibility.
  if (!is.null(seed)) {
    set.seed(seed)
  }
  Y_sim <- stats::simulate(fit, nsim = nsim)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != nsim) {
    cli::cli_abort(
      "Internal: {.fn simulate.gllvmTMB_multi} did not return an n x nsim matrix."
    )
  }

  ## Per-replicate worker.
  refit_one <- function(b) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(
        formula = formula,
        data = dat,
        trait = trait,
        site = site,
        species = species,
        family = family,
        silent = TRUE
      ),
      aux
    )
    out <- tryCatch(
      withCallingHandlers(
        suppressMessages(suppressWarnings(do.call(gllvmTMB, call_args))),
        error = function(e) NULL
      ),
      error = function(e) NULL
    )
    if (
      is.null(out) ||
        !inherits(out, "gllvmTMB_multi") ||
        !isTRUE(out$opt$convergence == 0L)
    ) {
      return(rep(NA_real_, T))
    }
    H2_b <- tryCatch(
      {
        obj_b <- out$tmb_obj
        rep_b <- obj_b$report(obj_b$env$last.par.best)
        .phylo_signal_H2_from_report(rep_b, T = T)
      },
      error = function(e) rep(NA_real_, T)
    )
    H2_b
  }

  draws_mat <- matrix(NA_real_, nrow = T, ncol = nsim)
  for (b in seq_len(nsim)) {
    draws_mat[, b] <- refit_one(b)
  }
  n_failed <- sum(apply(draws_mat, 2, function(col) all(is.na(col))))

  alpha <- 1 - level
  q_lo <- alpha / 2
  q_hi <- 1 - alpha / 2

  out_list <- vector("list", length(trait_idx))
  for (k in seq_along(trait_idx)) {
    t <- trait_idx[k]
    draws_t <- draws_mat[t, ]
    if (all(is.na(draws_t))) {
      lo <- NA_real_
      hi <- NA_real_
    } else {
      qs <- stats::quantile(
        draws_t,
        probs = c(q_lo, q_hi),
        na.rm = TRUE,
        names = FALSE
      )
      lo <- qs[1]
      hi <- qs[2]
    }
    out_list[[k]] <- data.frame(
      trait = trait_names[t],
      H2 = H2_hat[t],
      lower = lo,
      upper = hi,
      method = "bootstrap",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  out <- do.call(rbind, out_list)
  attr(out, "n_failed") <- n_failed
  attr(out, "n_boot") <- nsim
  out
}
