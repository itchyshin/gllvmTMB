## Wald (delta-method) and parametric-bootstrap CIs for per-(trait,
## component) variance proportions
##   p_c,t(theta) = Sigma_c[tt](theta) / Sigma_total[tt](theta)
## complementing the profile-likelihood path in `profile_ci_proportions`
## (R/profile-derived.R). Adds the Wald and Bootstrap branches required
## by Lane 1 / agent A2 of Design 58 (Phase B-INF).
##
## Design choices, mirroring the surrounding code:
##   * Wald: numerical Jacobian of the proportion w.r.t. the fixed
##     parameters via `fit$tmb_obj$report()` -- the same Jacobian pattern
##     used by `.lambda_se_at_mle()` and the Wald path in
##     `extract_repeatability()`. CI built on the logit-p scale and
##     back-transformed via `plogis()` so bounds always lie in [0, 1] and
##     respect the bounded-support asymmetry near the boundaries.
##   * Bootstrap: parametric simulate-refit driven by `simulate(fit)` +
##     `gllvmTMB(...)` -- the same scaffolding as `bootstrap_Sigma()`.
##     Percentile quantiles across replicates that converged. Forwards
##     auxiliary fit arguments (`phylo_vcv`, `mesh`, `lambda_constraint`,
##     ...) so phylogenetic / spatial fits refit cleanly.
##
## `link_residual` component:
##   For fixed-scale families (Gaussian / binomial with any standard
##   link; `family_id_vec %in% {0, 1}`) the numerator is constant in
##   theta. Wald and Bootstrap collapse the bounds to the point estimate
##   and label `method = "(unavailable)"` -- matching the profile-path
##   semantics. Mean-dependent families (Poisson, Gamma, ...) return NA
##   bounds with the same label.

## ---- Component vocabulary + helpers ----------------------------------

#' @keywords internal
#' @noRd
.proportions_components_present <- function(fit) {
  pt <- suppressMessages(extract_proportions(fit, format = "long"))
  as.character(unique(pt$component))
}

#' @keywords internal
#' @noRd
.proportions_validate_inputs <- function(
  fit,
  components,
  trait_idx,
  level
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a scalar in (0, 1); got {.val {level}}.")
  }
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_len(T)
  }
  if (
    !is.numeric(trait_idx) || any(trait_idx < 1L) || any(trait_idx > T)
  ) {
    cli::cli_abort(
      "{.arg trait_idx} must be integers in 1:{T}; got {.val {trait_idx}}."
    )
  }
  trait_idx <- as.integer(trait_idx)

  comps_present <- .proportions_components_present(fit)
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

  ## Build a (trait x component) matrix of point-estimate proportions
  ## from the long-format extractor (matches profile_ci_proportions()).
  pt <- suppressMessages(extract_proportions(fit, format = "long"))
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

  list(
    trait_names = trait_names,
    T = T,
    trait_idx = trait_idx,
    components = components,
    comps_present = comps_present,
    pt_mat = pt_mat
  )
}

#' @keywords internal
#' @noRd
.proportions_link_resid_fixed <- function(fit) {
  fids <- fit$tmb_data$family_id_vec
  if (is.null(fids)) {
    return(TRUE)
  }
  ## Match the profile-path convention: only family ids 0 (gaussian) and
  ## 1 (binomial / probit / cloglog) have a numerator constant in theta.
  all(unique(fids) %in% c(0L, 1L))
}

#' Build a row of the output frame for one (trait, component) cell.
#' @keywords internal
#' @noRd
.proportions_row <- function(
  trait_name,
  comp,
  p_hat,
  lower = NA_real_,
  upper = NA_real_,
  method = NA_character_
) {
  data.frame(
    trait = trait_name,
    component = comp,
    proportion = p_hat,
    lower = lower,
    upper = upper,
    method = method,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}


## ---- Wald (delta-method) CI ------------------------------------------

#' Reconstruct per-(trait, component) variance matrix from `fit$tmb_obj$report(par)`
#'
#' Returns a list with two T x C matrices on the canonical component
#' vocabulary used by `extract_proportions()`: `num` (per-component
#' numerator variance per trait) and `den` (total denominator variance
#' per trait, summed across present components plus the link-implicit
#' residual). `comps` is the column order. Used by the Wald path to
#' build a numerical Jacobian without re-running `extract_proportions`.
#'
#' @keywords internal
#' @noRd
.proportions_components_at <- function(fit, par_full, comps_present, T) {
  rep <- fit$tmb_obj$report(par_full)
  num <- matrix(0, nrow = T, ncol = length(comps_present),
                dimnames = list(NULL, comps_present))

  pull_LLt_diag <- function(slot) {
    L <- rep[[slot]]
    if (is.null(L)) {
      return(rep(0, T))
    }
    L <- as.matrix(L)
    if (nrow(L) != T) {
      return(rep(0, T))
    }
    diag(L %*% t(L))
  }
  pull_diag_var <- function(slot) {
    s <- rep[[slot]]
    if (is.null(s)) {
      return(rep(0, T))
    }
    s <- as.numeric(s)
    if (length(s) != T) {
      return(rep(0, T))
    }
    s^2
  }

  for (cc in comps_present) {
    v <- switch(
      cc,
      shared_unit     = pull_LLt_diag("Lambda_B"),
      unique_unit     = pull_diag_var("sd_B"),
      shared_unit_obs = pull_LLt_diag("Lambda_W"),
      unique_unit_obs = pull_diag_var("sd_W"),
      unique_cluster  = pull_diag_var("sd_q"),
      unique_cluster2 = pull_diag_var("sd_c2"),
      shared_phy      = pull_LLt_diag("Lambda_phy"),
      unique_phy      = pull_diag_var("sd_phy_diag"),
      link_residual   = rep(0, T),  ## handled separately below
      rep(0, T)
    )
    num[, cc] <- v
  }

  ## Treat the per-trait link-implicit residual as a constant in theta
  ## (point-estimate offset). This matches the profile-path convention
  ## for fixed-scale families and yields the same Wald variance for
  ## those families. For mean-dependent families the caller has already
  ## rejected the `link_residual` component above.
  link_const <- tryCatch(
    as.numeric(link_residual_per_trait(fit)),
    error = function(e) rep(0, T)
  )
  if (length(link_const) != T) link_const <- rep(0, T)

  if ("link_residual" %in% comps_present) {
    num[, "link_residual"] <- link_const
  }
  ## Denominator = sum across present components (link_residual already
  ## populated into `num` when present so it enters the rowSum). When
  ## link_residual is *not* in `comps_present` (e.g. Gaussian-only fit)
  ## the constant is zero anyway and rowSums covers it.
  den <- rowSums(num)
  list(num = num, den = den)
}

#' Wald (delta-method) CIs for per-(trait, component) variance proportions
#'
#' Numerical-Jacobian Wald CI on the logit-transformed proportion
#' `p_c,t = Sigma_c[tt] / Sigma_total[tt]`. The Jacobian is built by
#' perturbing each fixed parameter and re-reading the relevant
#' `Lambda_*` / `sd_*` slots from `fit$tmb_obj$report()`; the asymptotic
#' covariance is `J Cov(theta_fix) J^T` from
#' `fit$sd_report$cov.fixed`. Bounds are computed on `z = qlogis(p)`
#' (symmetric Wald) and back-transformed via `plogis()`, so they always
#' lie in \eqn{[0, 1]} and respect the bounded-support asymmetry.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param components Character vector of component names. `NULL`
#'   (default) uses all components present in
#'   [extract_proportions()].
#' @param trait_idx Integer indices of traits, or `NULL` for all.
#' @param level Confidence level. Default `0.95`.
#'
#' @return A data frame with columns `trait`, `component`, `proportion`,
#'   `lower`, `upper`, `method`. `method = "wald"` for delta-method
#'   rows, `"(unavailable)"` for link-residual rows (bounds collapse to
#'   point for fixed-scale families; bounds are NA for mean-dependent
#'   families).
#'
#' @keywords internal
#' @export
.proportions_wald_ci <- function(
  fit,
  components = NULL,
  trait_idx  = NULL,
  level      = 0.95
) {
  v <- .proportions_validate_inputs(fit, components, trait_idx, level)
  trait_names <- v$trait_names
  T <- v$T
  trait_idx <- v$trait_idx
  components <- v$components
  comps_present <- v$comps_present
  pt_mat <- v$pt_mat

  fixed_only_components <- setdiff(components, "link_residual")
  link_resid_fixed <- .proportions_link_resid_fixed(fit)

  ## Short-circuit if only link_residual was requested (no Jacobian
  ## needed) -- saves the sdreport check.
  if (length(fixed_only_components) == 0L) {
    out_rows <- list()
    for (t in trait_idx) {
      p_hat <- pt_mat[t, "link_residual"]
      if (link_resid_fixed) {
        out_rows[[length(out_rows) + 1L]] <- .proportions_row(
          trait_names[t], "link_residual", p_hat,
          lower = p_hat, upper = p_hat,
          method = "(unavailable)"
        )
      } else {
        out_rows[[length(out_rows) + 1L]] <- .proportions_row(
          trait_names[t], "link_residual", p_hat,
          method = "(unavailable)"
        )
      }
    }
    return(do.call(rbind, out_rows))
  }

  ## sdreport (asymptotic covariance of the fixed parameters) is
  ## required for the delta-method Jacobian. If absent, abort with the
  ## same message as `.lambda_se_at_mle()`.
  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport")) {
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      i = "Refit so {.code fit$sd_report} is populated."
    ))
  }

  cov_fix <- fit$sd_report$cov.fixed
  obj <- fit$tmb_obj
  par_full_at_mle <- obj$env$last.par.best
  random_idx <- if (length(obj$env$random) > 0L) obj$env$random else integer(0)
  fixed_idx <- setdiff(seq_along(par_full_at_mle), random_idx)
  par_fix_at_mle <- par_full_at_mle[fixed_idx]
  n_par <- length(par_fix_at_mle)

  ## Evaluate at the MLE. We always evaluate the *full* present-
  ## component set so the denominator is reconstructed correctly even
  ## when the caller subsets `components`.
  base <- .proportions_components_at(fit, par_full_at_mle, comps_present, T)
  num_hat <- base$num
  den_hat <- base$den
  if (any(!is.finite(den_hat)) || any(den_hat <= 0)) {
    cli::cli_abort(
      "Total variance denominator is non-positive at the MLE for {sum(den_hat <= 0)} trait{?s}; Wald CI undefined."
    )
  }

  ## Build per-(trait, component) p_hat from the reconstruction so the
  ## logit transform anchor lines up exactly with the Jacobian.
  p_hat_mat <- sweep(num_hat, 1, den_hat, FUN = "/")
  z_hat_mat <- stats::qlogis(pmin(pmax(p_hat_mat, .Machine$double.eps),
                                  1 - .Machine$double.eps))

  ## Forward-difference Jacobian: perturb each fixed parameter, re-read
  ## report(), compute z_c,t at the perturbed point.
  ##
  ## Storage: an array (n_par x T x length(fixed_only_components)) of
  ## partial z_c,t / partial theta_fix. We only carry the columns we
  ## need to return (fixed_only_components) into the SE step.
  C <- length(fixed_only_components)
  Jz <- array(
    0,
    dim = c(n_par, T, C),
    dimnames = list(NULL, NULL, fixed_only_components)
  )
  eps <- 1e-6
  for (j in seq_len(n_par)) {
    par_plus <- par_full_at_mle
    par_plus[fixed_idx[j]] <- par_plus[fixed_idx[j]] + eps
    pert <- .proportions_components_at(fit, par_plus, comps_present, T)
    if (any(!is.finite(pert$den)) || any(pert$den <= 0)) {
      ## Skip: derivative undefined at this perturbation -- Jz row
      ## stays zero, contribution to SE^2 is zero. (The MLE check
      ## already ruled out boundary issues at the unperturbed point.)
      next
    }
    p_pert <- sweep(pert$num[, fixed_only_components, drop = FALSE], 1,
                    pert$den, FUN = "/")
    z_pert <- stats::qlogis(pmin(pmax(p_pert, .Machine$double.eps),
                                 1 - .Machine$double.eps))
    z_base <- z_hat_mat[, fixed_only_components, drop = FALSE]
    Jz[j, , ] <- (z_pert - z_base) / eps
  }

  zcrit <- stats::qnorm(0.5 + level / 2)

  out_rows <- list()
  for (comp in components) {
    for (t in trait_idx) {
      p_hat <- pt_mat[t, comp]

      if (identical(comp, "link_residual")) {
        if (link_resid_fixed) {
          out_rows[[length(out_rows) + 1L]] <- .proportions_row(
            trait_names[t], comp, p_hat,
            lower = p_hat, upper = p_hat,
            method = "(unavailable)"
          )
        } else {
          out_rows[[length(out_rows) + 1L]] <- .proportions_row(
            trait_names[t], comp, p_hat,
            method = "(unavailable)"
          )
        }
        next
      }

      ## Wald SE on the logit scale: J^T Cov(theta_fix) J for the
      ## column of Jz indexed by (t, comp).
      jvec <- Jz[, t, comp]
      var_z <- as.numeric(t(jvec) %*% cov_fix %*% jvec)
      if (!is.finite(var_z) || var_z < 0) var_z <- 0
      se_z <- sqrt(var_z)
      z_pt <- z_hat_mat[t, comp]
      lo <- stats::plogis(z_pt - zcrit * se_z)
      hi <- stats::plogis(z_pt + zcrit * se_z)
      out_rows[[length(out_rows) + 1L]] <- .proportions_row(
        trait_names[t], comp, p_hat,
        lower = lo, upper = hi,
        method = "wald"
      )
    }
  }
  do.call(rbind, out_rows)
}


## ---- Parametric-bootstrap CI -----------------------------------------

#' Parametric-bootstrap CIs for per-(trait, component) variance proportions
#'
#' Simulate `nsim` response vectors via `simulate(fit, nsim = nsim)`,
#' refit the same formula on each, and recompute `extract_proportions()`.
#' Percentile-quantile bounds across replicates that converged. Reuses
#' the formula-reconstruction and auxiliary-args plumbing from
#' [bootstrap_Sigma()] so phylogenetic / spatial / lambda-constraint
#' fits refit cleanly.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param components Character vector of component names. `NULL`
#'   (default) uses all components present.
#' @param trait_idx Integer indices of traits, or `NULL` for all.
#' @param level Confidence level. Default `0.95`.
#' @param nsim Number of bootstrap replicates. Default `500`.
#' @param seed Optional RNG seed for reproducibility.
#'
#' @return A data frame with columns `trait`, `component`, `proportion`,
#'   `lower`, `upper`, `method`. `method = "bootstrap"` for percentile
#'   rows, `"(unavailable)"` for link-residual rows.
#'
#' @keywords internal
#' @export
.proportions_bootstrap_ci <- function(
  fit,
  components = NULL,
  trait_idx  = NULL,
  level      = 0.95,
  nsim       = 500L,
  seed       = NULL
) {
  v <- .proportions_validate_inputs(fit, components, trait_idx, level)
  trait_names <- v$trait_names
  T <- v$T
  trait_idx <- v$trait_idx
  components <- v$components
  comps_present <- v$comps_present
  pt_mat <- v$pt_mat

  if (!is.numeric(nsim) || nsim < 2L) {
    cli::cli_abort("{.arg nsim} must be an integer >= 2; got {.val {nsim}}.")
  }
  nsim <- as.integer(nsim)

  fixed_only_components <- setdiff(components, "link_residual")
  link_resid_fixed <- .proportions_link_resid_fixed(fit)

  ## --- Set up the refit closure (parallels bootstrap_Sigma()) ---------
  formula <- .reconstruct_multi_formula(fit)
  trait <- fit$trait_col
  unit <- fit$unit_col
  unit_obs <- fit$unit_obs_col
  cluster <- fit$cluster_col %||% fit$species_col
  cluster2 <- fit$cluster2_col
  family <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data <- fit$data
  resp <- all.vars(fit$formula)[1]
  if (!resp %in% names(data)) {
    cli::cli_abort(
      "Response column {.var {resp}} not found in {.code fit$data}."
    )
  }
  aux <- list(
    phylo_vcv = fit$phylo_vcv,
    phylo_tree = fit$phylo_tree,
    mesh = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  if (!is.null(seed)) {
    set.seed(seed)
  }
  Y_sim <- simulate(fit, nsim = nsim)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != nsim) {
    cli::cli_abort(
      "Internal: {.fn simulate.gllvmTMB_multi} did not return an n x nsim matrix."
    )
  }

  refit_one <- function(b) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(
        formula = formula,
        data = dat,
        trait = trait,
        unit = unit,
        unit_obs = unit_obs,
        cluster = cluster,
        cluster2 = cluster2,
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
      return(NULL)
    }
    ## extract_proportions() can change which components are present
    ## (a refit may drop a near-singular term); align replicates to the
    ## original `comps_present` ordering, NA for absent.
    pt_b <- tryCatch(
      suppressMessages(extract_proportions(out, format = "long")),
      error = function(e) NULL
    )
    if (is.null(pt_b)) {
      return(NULL)
    }
    mat <- matrix(
      NA_real_,
      nrow = T,
      ncol = length(comps_present),
      dimnames = list(trait_names, comps_present)
    )
    for (cc in comps_present) {
      rows_c <- pt_b[as.character(pt_b$component) == cc, , drop = FALSE]
      if (nrow(rows_c) == 0L) next
      row_idx <- match(as.character(rows_c$trait), trait_names)
      ok <- !is.na(row_idx)
      mat[row_idx[ok], cc] <- rows_c$proportion[ok]
    }
    mat
  }

  draws <- vector("list", nsim)
  for (b in seq_len(nsim)) {
    draws[[b]] <- refit_one(b)
  }

  ok_idx <- which(!vapply(draws, is.null, logical(1)))
  if (length(ok_idx) < 2L) {
    cli::cli_abort(
      "Bootstrap: only {length(ok_idx)} replicate{?s} converged out of {nsim}; cannot form a percentile CI."
    )
  }

  alpha <- 1 - level
  q_lo <- alpha / 2
  q_hi <- 1 - alpha / 2

  out_rows <- list()
  for (comp in components) {
    for (t in trait_idx) {
      p_hat <- pt_mat[t, comp]

      if (identical(comp, "link_residual")) {
        if (link_resid_fixed) {
          out_rows[[length(out_rows) + 1L]] <- .proportions_row(
            trait_names[t], comp, p_hat,
            lower = p_hat, upper = p_hat,
            method = "(unavailable)"
          )
        } else {
          out_rows[[length(out_rows) + 1L]] <- .proportions_row(
            trait_names[t], comp, p_hat,
            method = "(unavailable)"
          )
        }
        next
      }

      vals <- vapply(
        ok_idx,
        function(b) draws[[b]][t, comp],
        numeric(1)
      )
      vals <- vals[is.finite(vals)]
      if (length(vals) < 2L) {
        out_rows[[length(out_rows) + 1L]] <- .proportions_row(
          trait_names[t], comp, p_hat,
          method = "bootstrap"
        )
        next
      }
      lo <- stats::quantile(vals, probs = q_lo, na.rm = TRUE, names = FALSE)
      hi <- stats::quantile(vals, probs = q_hi, na.rm = TRUE, names = FALSE)
      out_rows[[length(out_rows) + 1L]] <- .proportions_row(
        trait_names[t], comp, p_hat,
        lower = lo, upper = hi,
        method = "bootstrap"
      )
    }
  }
  do.call(rbind, out_rows)
}
