.gllvmTMB_resolve_kernel_psi_sd_prior <- function(
    priors, kernel_names, kernel_has_psi, trait_names, multi_kernel) {
  if (is.null(priors)) return(NULL)
  if (!is.data.frame(priors) ||
      !identical(sort(names(priors)), sort(c("kernel", "trait", "scale")))) {
    cli::cli_abort(c(
      "{.arg kernel_psi_sd_prior} must be a data frame with kernel, trait, and scale columns.",
      ">" = "Use one row per named-kernel and trait pair to regularise."
    ), class = "gllvmTMB_kernel_psi_prior_invalid")
  }
  if (!nrow(priors) || !is.character(priors$kernel) ||
      !is.character(priors$trait) || anyNA(priors$kernel) ||
      anyNA(priors$trait) || any(!nzchar(priors$kernel)) ||
      any(!nzchar(priors$trait)) ||
      anyDuplicated(paste(priors$kernel, priors$trait, sep = "\r"))) {
    cli::cli_abort(c(
      "Kernel Psi prior targets must be distinct, non-empty kernel and trait names.",
      ">" = "Supply each named-kernel and trait pair at most once."
    ), class = "gllvmTMB_kernel_psi_prior_invalid")
  }
  if (!is.numeric(priors$scale) || anyNA(priors$scale) ||
      any(!is.finite(priors$scale)) || any(priors$scale <= 0) ||
      any(!is.finite(1 / priors$scale^2)) ||
      any(1 / priors$scale^2 <= 0)) {
    cli::cli_abort(c(
      "Kernel Psi prior scales must be finite positive values with finite precision.",
      ">" = "Use response-scale values that are neither extremely small nor extremely large."
    ), class = "gllvmTMB_kernel_psi_prior_invalid")
  }
  if (!length(kernel_names)) {
    cli::cli_abort(c(
      "{.arg kernel_psi_sd_prior} requires at least one named kernel term.",
      ">" = "Add kernel_latent(..., name = ...) to the formula or omit this prior."
    ), class = "gllvmTMB_kernel_psi_prior_target_unknown")
  }
  if (length(kernel_names) != length(kernel_has_psi) ||
      anyDuplicated(kernel_names)) {
    cli::cli_abort("Internal kernel Psi prior registry is inconsistent.",
                   class = "gllvmTMB_kernel_psi_prior_internal")
  }
  kernel_index <- match(priors$kernel, kernel_names)
  trait_index <- match(priors$trait, trait_names)
  if (anyNA(kernel_index) || anyNA(trait_index)) {
    cli::cli_abort(c(
      "A kernel Psi prior names an unknown kernel or trait.",
      "i" = "Kernel names must match the formula's kernel_latent(name = ...) terms; trait names must match the fitted trait levels.",
      ">" = "Inspect the formula and trait column, then correct the prior table."
    ), class = "gllvmTMB_kernel_psi_prior_target_unknown")
  }
  if (any(kernel_has_psi[kernel_index] != 1L)) {
    cli::cli_abort(c(
      "A kernel Psi prior target has no fitted trait-specific Psi component.",
      "i" = "Each targeted kernel must use kernel_latent(..., unique = TRUE).",
      ">" = "Add the Psi companion to that kernel or remove its prior row."
    ), class = "gllvmTMB_kernel_psi_prior_without_psi")
  }
  prior_parameter_index <- if (isTRUE(multi_kernel)) {
    vapply(seq_len(nrow(priors)), function(i) {
      sum(kernel_has_psi[seq_len(kernel_index[i] - 1L)]) * length(trait_names) +
        trait_index[i]
    }, integer(1L))
  } else {
    trait_index
  }
  priors$kernel_index <- kernel_index
  priors$trait_index <- trait_index
  priors$parameter_name <- if (isTRUE(multi_kernel)) {
    "log_sd_kernel_diag"
  } else {
    "log_sd_phy_diag"
  }
  priors$parameter_index <- prior_parameter_index
  priors
}

.gllvmTMB_kernel_psi_sd_prior_route <- function(priors, engine, estimator,
                                                 REML, control) {
  if (is.null(priors)) return(invisible(NULL))
  if (!identical(engine, "tmb") || !identical(estimator, "ml") ||
      isTRUE(REML) ||
      !identical(control$integration %||% "laplace", "laplace") ||
      isTRUE(control$aghq)) {
    cli::cli_abort(c(
      "{.arg kernel_psi_sd_prior} currently requires native TMB ML Laplace estimation with REML = FALSE.",
      "i" = "Julia, MSPL, REML, AGHQ, and variational fits do not yet support this prior.",
      ">" = "Use engine = 'tmb', estimator = 'ml', REML = FALSE, and integration = 'laplace'."
    ), class = "gllvmTMB_kernel_psi_prior_unsupported")
  }
  if (!is.null(control$fixed_effect_priors) ||
      !is.null(control$loading_ridge) ||
      (isTRUE(control$aghq_ridge_explicit) &&
       is.numeric(control$aghq_ridge) && any(is.finite(control$aghq_ridge)))) {
    cli::cli_abort(c(
      "{.arg kernel_psi_sd_prior} is currently a separate sensitivity fit.",
      "i" = "It cannot be combined with fixed-effect priors or a loading ridge.",
      ">" = "Fit the kernel Psi prior separately from coefficient and loading penalties."
    ), class = "gllvmTMB_kernel_psi_prior_penalty_conflict")
  }
  invisible(NULL)
}

.gllvmTMB_attach_kernel_psi_sd_prior <- function(obj, priors) {
  if (is.null(priors)) return(obj)
  block_name <- unique(priors$parameter_name)
  if (length(block_name) != 1L) {
    cli::cli_abort("Kernel Psi prior targets do not share one parameter block.",
                   class = "gllvmTMB_kernel_psi_prior_internal")
  }
  block <- which(names(obj$par) == block_name)
  if (!length(block) || max(priors$parameter_index) > length(block)) {
    cli::cli_abort(c(
      "The fitted objective does not contain the requested kernel Psi SD parameters.",
      ">" = "Refit with a named kernel that has kernel_latent(..., unique = TRUE)."
    ), class = "gllvmTMB_kernel_psi_prior_parameter_missing")
  }
  idx <- block[priors$parameter_index]
  scale <- priors$scale
  base_fn <- obj$fn
  base_gr <- obj$gr
  base_he <- obj$he
  penalty <- function(p) {
    sigma <- exp(p[idx])
    -sum(stats::dnorm(sigma, mean = 0, sd = scale, log = TRUE) + log(2))
  }
  obj$fn <- function(p = obj$par, ...) base_fn(p, ...) + penalty(p)
  obj$gr <- function(p = obj$par, ...) {
    g <- base_gr(p, ...)
    sigma <- exp(p[idx])
    g[idx] <- g[idx] + sigma^2 / scale^2
    g
  }
  if (is.function(base_he)) obj$he <- function(p = obj$par, ...) {
    H <- base_he(p, ...)
    sigma <- exp(p[idx])
    H[cbind(idx, idx)] <- H[cbind(idx, idx)] + 2 * sigma^2 / scale^2
    H
  }
  obj$kernel_psi_sd_prior <- list(
    specification = priors,
    indices = idx,
    penalty = penalty,
    likelihood_fn = base_fn,
    likelihood_gr = base_gr,
    target_class = "unique_variance",
    measure = "natural_sd",
    interpretation = "local_approximate_posterior_curvature_at_map",
    calibrated_sampling_covariance = FALSE
  )
  obj
}
