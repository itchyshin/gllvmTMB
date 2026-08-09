## Lane B: opt-in maximum softly penalised Laplace likelihood --------------
##
## This file owns the small R-side contract shared by the public API,
## fit assembly, and S3 methods.  The numerical Jeffreys log-determinant and
## loading penalty live in the TMB template; R resolves the fixed-effect map,
## fences the admitted model surface, and labels the resulting point estimate.

.gllvmTMB_is_mspl <- function(x) {
  estimator <- tryCatch(x$estimator, error = function(e) NULL)
  inherits(x, "gllvmTMB_mspl") ||
    identical(toupper(estimator %||% ""), "MSPL")
}

.gllvmTMB_mspl_abort <- function(message, ..., class = "gllvmTMB_mspl_unsupported") {
  cli::cli_abort(c(message, ...), class = class, .envir = parent.frame())
}

.gllvmTMB_mspl_inference_abort <- function(what) {
  cli::cli_abort(c(
    "{.fn {what}} is not available for an {.code estimator = \"mspl\"} fit.",
    "i" = "LA-MSPL is an experimental point estimator; repeated-sampling inference is not yet calibrated.",
    ">" = "Use {.fn coef}, {.fn predict}, or the covariance extractors for point estimates, and fit {.code estimator = \"ml\"} when likelihood-based inference is required."
  ), class = "gllvmTMB_mspl_inference_unsupported")
}

.gllvmTMB_mspl_assert_inference <- function(x, what) {
  if (.gllvmTMB_is_mspl(x)) {
    .gllvmTMB_mspl_inference_abort(what)
  }
  invisible(x)
}

## Resolve b_fix = b_fixed + K gamma and return X_* = X_fix K.  TMB maps use
## factor levels to represent shared free parameters and NA to represent pinned
## coordinates.  The present public Xcoef_fixed surface only pins zeros, but
## handling ties here makes the derivative-design construction agree with TMB's
## general map semantics rather than relying on that temporary API restriction.
.gllvmTMB_mspl_fixed_design <- function(X_fix, b_map = NULL) {
  X_fix <- as.matrix(X_fix)
  if (!is.numeric(X_fix) || any(!is.finite(X_fix))) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires a finite numeric fixed-effect design matrix.",
      "x" = "The resolved {.field X_fix} contains a non-finite value."
    )
  }

  n_beta <- ncol(X_fix)
  if (is.null(b_map)) {
    K <- diag(n_beta)
    if (n_beta == 0L) K <- matrix(numeric(0), 0L, 0L)
  } else {
    map_code <- as.integer(b_map)
    if (length(map_code) != n_beta) {
      .gllvmTMB_mspl_abort(
        "Internal LA-MSPL map mismatch.",
        "x" = "The {.field b_fix} map has {length(map_code)} entries for {n_beta} design columns.",
        class = "gllvmTMB_mspl_internal_map"
      )
    }
    n_free <- if (all(is.na(map_code))) 0L else max(map_code, na.rm = TRUE)
    K <- matrix(0, nrow = n_beta, ncol = n_free)
    keep <- which(!is.na(map_code))
    if (length(keep)) K[cbind(keep, map_code[keep])] <- 1
  }

  X_mspl <- unname(X_fix %*% K)
  p_beta <- ncol(X_mspl)
  if (p_beta < 1L) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires at least one free fixed-effect coefficient.",
      "i" = "An interceptless or fully pinned fixed-effect model is outside the current LA-MSPL contract."
    )
  }

  singular_values <- svd(X_mspl, nu = 0L, nv = 0L)$d
  rank_tol <- max(dim(X_mspl)) * max(singular_values) * .Machine$double.eps
  rank_x <- sum(singular_values > rank_tol)
  if (rank_x != p_beta) {
    .gllvmTMB_mspl_abort(c(
      "The resolved LA-MSPL fixed-effect design is rank deficient.",
      "x" = "Numerical rank is {rank_x}; {p_beta} free coefficient{?s} remain after maps and ties.",
      ">" = "Remove aliased fixed effects or pin a redundant coefficient with {.arg Xcoef_fixed} before fitting."
    ), class = "gllvmTMB_mspl_rank_deficient")
  }

  list(
    X = X_mspl,
    K = K,
    p_beta = as.integer(p_beta),
    rank = as.integer(rank_x),
    rank_tolerance = rank_tol
  )
}

.gllvmTMB_mspl_tau_representatives <- function(log_tau, tau_map = NULL) {
  n_tau <- length(log_tau)
  if (n_tau < 1L) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires at least one free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  if (is.null(tau_map)) return(as.integer(seq_len(n_tau) - 1L))

  map_code <- as.integer(tau_map)
  if (length(map_code) != n_tau) {
    .gllvmTMB_mspl_abort(
      "Internal LA-MSPL spatial-scale map mismatch.",
      class = "gllvmTMB_mspl_internal_map"
    )
  }
  free_levels <- sort(unique(map_code[!is.na(map_code)]))
  if (!length(free_levels)) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires a free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  as.integer(vapply(
    free_levels,
    function(level) which(map_code == level)[1L] - 1L,
    integer(1L)
  ))
}

.gllvmTMB_mspl_spde_r0 <- function(mesh) {
  if (is.null(mesh) || is.null(mesh$loc_xy)) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires a resolved {.fn make_mesh} object.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  locations <- unique(as.matrix(mesh$loc_xy))
  if (!is.numeric(locations) || ncol(locations) != 2L ||
      nrow(locations) < 2L || any(!is.finite(locations))) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires at least two distinct finite observed locations."
    )
  }
  centred <- sweep(locations, 2L, colMeans(locations), FUN = "-")
  r0 <- sqrt(mean(rowSums(centred^2)))
  if (length(r0) != 1L || !is.finite(r0) || r0 <= 0) {
    .gllvmTMB_mspl_abort(
      "The spatial LA-MSPL reference distance is not positive and finite."
    )
  }
  unname(r0)
}

## Preflight the deliberately narrow point-estimator surface.  This runs
## after maps and the random-effect vector have been resolved, so admission is
## based on the model TMB will actually see rather than formula spelling.
.gllvmTMB_mspl_prepare <- function(
  X_fix, b_map, y, n_trials, is_y_observed, family_id_vec, link_id_vec,
  offset_vec, random, use_rr_B, use_lv_B, use_rr_B_slope, use_diag_B,
  diag_B_all_skipped, d_B, theta_rr_B, lambda_constraint,
  use_spde, is_spatial_indep, is_spatial_scalar, is_spatial_latent,
  is_spatial_dep, use_spde_latent_diag, use_spde_slope,
  use_spde_latent_slope, d_spde_lv, theta_rr_spde_lv, log_tau_spde,
  log_tau_spde_map, mesh, use_mi_predictor, integration, engine, REML,
  ridge_explicit
) {
  if (isTRUE(REML)) {
    .gllvmTMB_mspl_abort("{.code estimator = \"mspl\"} cannot be combined with {.code REML = TRUE}.")
  }
  if (!identical(engine, "tmb") || !identical(integration, "laplace")) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL currently requires the native TMB Laplace route.",
      "x" = "Received engine {.val {engine}} and integration {.val {integration}}."
    ))
  }
  if (isTRUE(ridge_explicit)) {
    .gllvmTMB_mspl_abort(c(
      "Do not combine {.code estimator = \"mspl\"} with an explicit loading ridge.",
      "i" = "MSPL and {.arg loading_ridge} (or its compatibility spelling {.arg aghq_ridge}) are different penalties; combining them would define an unvalidated hybrid estimator."
    ))
  }
  if (length(unique(family_id_vec)) != 1L || !all(family_id_vec == 1L)) {
    .gllvmTMB_mspl_abort("LA-MSPL supports a single binomial response family only.")
  }
  if (length(unique(link_id_vec)) != 1L || !all(link_id_vec %in% 0:2)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires one common supported binary link.",
      "i" = "Use {.code binomial(link = \"logit\")}, {.code \"probit\"}, or {.code \"cloglog\"}."
    ))
  }
  if (!all(is_y_observed == 1L)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires complete responses.",
      "i" = "FIML-MSPL and retained response masks are deferred."
    ))
  }
  if (!all(n_trials == 1) || !all(y %in% c(0, 1))) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires single-trial Bernoulli observations.",
      "i" = "Grouped and weighted binomial MSPL is deferred."
    ))
  }
  if (any(!is.finite(offset_vec))) {
    .gllvmTMB_mspl_abort("LA-MSPL requires finite known offsets.")
  }
  if (any(offset_vec != 0)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires an all-zero offset vector.",
      "i" = "Nonzero binary offsets are mathematically plausible but remain outside the frozen validation campaign."
    ))
  }
  ordinary <- isTRUE(use_rr_B) && !isTRUE(use_spde)
  spatial_indep <- !isTRUE(use_rr_B) && isTRUE(use_spde) &&
    isTRUE(is_spatial_indep) && !isTRUE(is_spatial_scalar) &&
    !isTRUE(is_spatial_latent) && !isTRUE(is_spatial_dep)
  spatial_latent <- !isTRUE(use_rr_B) && isTRUE(use_spde) &&
    isTRUE(is_spatial_latent) && !isTRUE(is_spatial_dep)
  if (sum(c(ordinary, spatial_indep, spatial_latent)) != 1L) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires exactly one admitted covariance structure.",
      "i" = "Use ordinary {.fn latent}, standalone {.fn spatial_indep}, or standalone {.fn spatial_latent} with rank 1 or 2."
    ))
  }

  if (ordinary && (!d_B %in% c(1L, 2L) || isTRUE(use_lv_B) ||
                   isTRUE(use_rr_B_slope))) {
    .gllvmTMB_mspl_abort(c(
      "Ordinary LA-MSPL supports one intercept-only {.fn latent} block with {.arg d} equal to 1 or 2.",
      "i" = "Predictor-informed latent means, latent slopes, and q > 2 are deferred."
    ))
  }
  if (spatial_latent && (!d_spde_lv %in% c(1L, 2L) ||
                         isTRUE(use_spde_latent_diag))) {
    .gllvmTMB_mspl_abort(c(
      "Spatial-latent LA-MSPL supports {.fn spatial_latent} with {.arg d} equal to 1 or 2 and no unique companion.",
      "i" = "Free spatial Psi coordinates and q > 2 are deferred."
    ))
  }
  if (!ordinary && (isTRUE(use_diag_B) || isTRUE(use_rr_B_slope))) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL cannot be combined with an ordinary latent or Psi block."
    )
  }
  if (isTRUE(use_spde_slope) || isTRUE(use_spde_latent_slope)) {
    .gllvmTMB_mspl_abort(
      "Spatial random slopes are outside the current LA-MSPL contract."
    )
  }
  if (ordinary && isTRUE(use_diag_B) && !isTRUE(diag_B_all_skipped)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL does not estimate a Bernoulli Psi companion.",
      "i" = "The automatic Bernoulli Psi may remain in the parsed formula only when every coordinate is mapped off."
    ))
  }
  expected_random <- if (ordinary) {
    "z_B"
  } else if (spatial_indep) {
    "omega_spde"
  } else {
    "omega_spde_lv"
  }
  if (!identical(random, expected_random)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL admits exactly one structure-specific Laplace-random block.",
      "x" = "Expected {.val {expected_random}}; resolved {.val {random}}.",
      "i" = "Additional random effects and structured covariance tiers are deferred."
    ))
  }
  if (isTRUE(use_mi_predictor)) {
    .gllvmTMB_mspl_abort("Modelled missing predictors are outside the current LA-MSPL contract.")
  }
  if (!is.null(lambda_constraint) && length(Filter(Negate(is.null), lambda_constraint))) {
    .gllvmTMB_mspl_abort(c(
      "Confirmatory loading constraints are outside the current LA-MSPL contract.",
      "i" = "Fit the exploratory lower-triangular ordinary latent model without {.arg lambda_constraint}."
    ))
  }

  fixed <- .gllvmTMB_mspl_fixed_design(X_fix, b_map)
  structure <- if (ordinary) "ordinary" else if (spatial_indep) {
    "spatial_indep"
  } else {
    "spatial_latent"
  }
  tau_representative <- as.integer(-1L)
  spde_r0 <- 1
  if (ordinary) {
    p_loading <- length(theta_rr_B)
    p_covariance <- 0L
    expected_outer <- c("b_fix", "theta_rr_B")
  } else if (spatial_indep) {
    tau_representative <- .gllvmTMB_mspl_tau_representatives(
      log_tau_spde, log_tau_spde_map
    )
    p_loading <- 0L
    p_covariance <- length(tau_representative) + 1L
    expected_outer <- c("b_fix", "log_tau_spde", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  } else {
    p_loading <- length(theta_rr_spde_lv)
    p_covariance <- 1L
    expected_outer <- c("b_fix", "theta_rr_spde_lv", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  }
  p_free <- fixed$p_beta + p_loading + p_covariance
  N_eff <- sum(n_trials)
  if (!is.finite(N_eff) || N_eff <= 0) {
    .gllvmTMB_mspl_abort("LA-MSPL requires a positive effective Bernoulli sample size.")
  }

  list(
    estimator_id = 1L,
    X_mspl = fixed$X,
    N_eff = as.numeric(N_eff),
    p_beta = fixed$p_beta,
    p_loading = as.integer(p_loading),
    p_covariance = as.integer(p_covariance),
    p_free = as.integer(p_free),
    rate = 2 * sqrt(p_free / N_eff),
    fixed_design = fixed,
    structure = structure,
    expected_outer = expected_outer,
    expected_random = expected_random,
    spde_r0 = spde_r0,
    tau_representative = tau_representative,
    scope = paste0(
      "complete Bernoulli; ", structure,
      if (structure == "spatial_latent") paste0("(q=", d_spde_lv, ")") else
        if (structure == "ordinary") paste0("(q=", d_B, ")") else "",
      "; Laplace; one common logit/probit/cloglog link"
    )
  )
}
