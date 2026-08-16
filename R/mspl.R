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

.gllvmTMB_mspl_abort <- function(
  message,
  ...,
  class = "gllvmTMB_mspl_unsupported"
) {
  cli::cli_abort(c(message, ...), class = class, .envir = parent.frame())
}

.gllvmTMB_mspl_inference_abort <- function(what) {
  cli::cli_abort(
    c(
      "{.fn {what}} is not available for an {.code estimator = \"mspl\"} fit.",
      "i" = "LA-MSPL is an experimental point estimator; repeated-sampling inference is not yet calibrated.",
      ">" = "Use {.fn coef}, {.fn predict}, or the covariance extractors for point estimates, and fit {.code estimator = \"ml\"} when likelihood-based inference is required."
    ),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
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
    .gllvmTMB_mspl_abort(
      c(
        "The resolved LA-MSPL fixed-effect design is rank deficient.",
        "x" = "Numerical rank is {rank_x}; {p_beta} free coefficient{?s} remain after maps and ties.",
        ">" = "Remove aliased fixed effects or pin a redundant coefficient with {.arg Xcoef_fixed} before fitting."
      ),
      class = "gllvmTMB_mspl_rank_deficient"
    )
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
  if (is.null(tau_map)) {
    return(as.integer(seq_len(n_tau) - 1L))
  }

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
  if (
    !is.numeric(locations) ||
      ncol(locations) != 2L ||
      nrow(locations) < 2L ||
      any(!is.finite(locations))
  ) {
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
  X_fix,
  b_map,
  y,
  n_trials,
  is_y_observed,
  family_id_vec,
  link_id_vec,
  offset_vec,
  random,
  use_rr_B,
  use_lv_B,
  use_rr_B_slope,
  use_diag_B,
  diag_B_all_skipped,
  d_B,
  theta_rr_B,
  theta_diag_B = NULL,
  lambda_constraint,
  use_spde,
  is_spatial_indep,
  is_spatial_scalar,
  is_spatial_latent,
  is_spatial_dep,
  use_spde_latent_diag,
  use_spde_slope,
  use_spde_latent_slope,
  d_spde_lv,
  theta_rr_spde_lv,
  log_tau_spde,
  log_tau_spde_map,
  mesh,
  use_mi_predictor,
  integration,
  engine,
  REML,
  ridge_explicit,
  unit_id = NULL,
  trait_id = NULL,
  sigma_eps_mapped = FALSE
) {
  if (isTRUE(REML)) {
    .gllvmTMB_mspl_abort(
      "{.code estimator = \"mspl\"} cannot be combined with {.code REML = TRUE}."
    )
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

  fam_ids <- unique(as.integer(family_id_vec))
  if (length(fam_ids) != 1L || !fam_ids %in% c(0L, 1L, 2L, 5L, 15L)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL supports a single gaussian, bernoulli, Poisson, nbinom1, or nbinom2 response family only.",
      "i" = "Beta, Tweedie, and mixed-family MSPL remain deferred at the public door."
    ))
  }
  is_gaussian <- identical(fam_ids, 0L)
  is_bernoulli <- identical(fam_ids, 1L)
  is_poisson <- identical(fam_ids, 2L)
  is_nbinom2 <- identical(fam_ids, 5L)
  is_nbinom1 <- identical(fam_ids, 15L)
  is_nbinom <- is_nbinom1 || is_nbinom2
  is_tweedie <- identical(fam_ids, 6L)
  is_beta <- identical(fam_ids, 7L)
  is_planned_glm <- is_poisson || is_nbinom || is_tweedie || is_beta

  if (is_bernoulli) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec %in% 0:2)) {
      .gllvmTMB_mspl_abort(c(
        "LA-MSPL requires one common supported binary link.",
        "i" = "Use {.code binomial(link = \"logit\")}, {.code \"probit\"}, or {.code \"cloglog\"}."
      ))
    }
    if (!all(n_trials == 1) || !all(y %in% c(0, 1))) {
      .gllvmTMB_mspl_abort(c(
        "LA-MSPL requires single-trial Bernoulli observations.",
        "i" = "Grouped and weighted binomial MSPL is deferred."
      ))
    }
  } else if (is_gaussian) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires the identity link.",
        "i" = "Use {.code gaussian(link = \"identity\")}."
      ))
    }
    if (any(!is.finite(y))) {
      .gllvmTMB_mspl_abort("Gaussian LA-MSPL requires finite responses.")
    }
  } else if (is_poisson) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Poisson LA-MSPL requires the log link.",
        "i" = "Use {.code poisson(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "Poisson LA-MSPL requires finite non-negative counts."
      )
    }
  } else if (is_nbinom) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "nbinom1/nbinom2 LA-MSPL requires the log link.",
        "i" = "Use {.code nbinom1(link = \"log\")} or {.code nbinom2(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "nbinom1/nbinom2 LA-MSPL requires finite non-negative counts."
      )
    }
  } else if (is_tweedie) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Tweedie LA-MSPL requires the log link.",
        "i" = "Use {.code tweedie(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "Tweedie LA-MSPL requires finite non-negative responses."
      )
    }
  } else if (is_beta) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Beta LA-MSPL requires the logit link.",
        "i" = "Use {.code Beta(link = \"logit\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y <= 0) || any(y >= 1)) {
      .gllvmTMB_mspl_abort(
        "Beta LA-MSPL requires finite responses strictly inside (0, 1)."
      )
    }
  }
  if (!all(is_y_observed == 1L)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires complete responses.",
      "i" = "FIML-MSPL and retained response masks are deferred."
    ))
  }
  if (any(!is.finite(offset_vec))) {
    .gllvmTMB_mspl_abort("LA-MSPL requires finite known offsets.")
  }
  if (any(offset_vec != 0)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires an all-zero offset vector.",
      "i" = "Nonzero offsets remain outside the frozen validation campaign."
    ))
  }
  ordinary <- isTRUE(use_rr_B) && !isTRUE(use_spde)
  spatial_indep <- !isTRUE(use_rr_B) &&
    isTRUE(use_spde) &&
    isTRUE(is_spatial_indep) &&
    !isTRUE(is_spatial_scalar) &&
    !isTRUE(is_spatial_latent) &&
    !isTRUE(is_spatial_dep)
  spatial_latent <- !isTRUE(use_rr_B) &&
    isTRUE(use_spde) &&
    isTRUE(is_spatial_latent) &&
    !isTRUE(is_spatial_dep)

  if (is_gaussian) {
    if (!isTRUE(ordinary) || isTRUE(spatial_indep) || isTRUE(spatial_latent)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL admits only ordinary {.fn latent} with {.arg unique = TRUE}.",
        "i" = "Spatial and other structures are deferred."
      ))
    }
  } else if (is_planned_glm) {
    if (!isTRUE(ordinary) || isTRUE(spatial_indep) || isTRUE(spatial_latent)) {
      .gllvmTMB_mspl_abort(c(
        if (is_poisson) {
          "Poisson LA-MSPL admits only ordinary {.fn latent}."
        } else if (is_nbinom) {
          "nbinom1/nbinom2 LA-MSPL admits only ordinary {.fn latent}."
        } else if (is_tweedie) {
          "Tweedie LA-MSPL admits only ordinary {.fn latent}."
        } else {
          "Beta LA-MSPL admits only ordinary {.fn latent}."
        },
        "i" = "Spatial and other structures are deferred."
      ))
    }
  } else if (sum(c(ordinary, spatial_indep, spatial_latent)) != 1L) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires exactly one admitted covariance structure.",
      "i" = "Use ordinary {.fn latent}, standalone {.fn spatial_indep}, or standalone {.fn spatial_latent} with rank 1 or 2."
    ))
  }

  if (
    ordinary &&
      (!d_B %in% c(1L, 2L) || isTRUE(use_lv_B) || isTRUE(use_rr_B_slope))
  ) {
    .gllvmTMB_mspl_abort(c(
      "Ordinary LA-MSPL supports one intercept-only {.fn latent} block with {.arg d} equal to 1 or 2.",
      "i" = "Predictor-informed latent means, latent slopes, and q > 2 are deferred."
    ))
  }
  if (
    spatial_latent &&
      (!d_spde_lv %in% c(1L, 2L) ||
        isTRUE(use_spde_latent_diag))
  ) {
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
  if (
    is_bernoulli &&
      ordinary &&
      isTRUE(use_diag_B) &&
      !isTRUE(diag_B_all_skipped)
  ) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL does not estimate a Bernoulli Psi companion.",
      "i" = "The automatic Bernoulli Psi may remain in the parsed formula only when every coordinate is mapped off."
    ))
  }
  if (is_gaussian) {
    if (!isTRUE(use_diag_B) || isTRUE(diag_B_all_skipped)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires free unique Psi.",
        "i" = "Use {.code latent(..., unique = TRUE)} on ordinary complete data so Q7 pins {.code sigma_eps}."
      ))
    }
    if (!isTRUE(sigma_eps_mapped)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires {.code sigma_eps} mapped off (pick C / Q7).",
        "i" = "The Hirose atom targets {.code sd_B^2} only when residual SD is not a free share."
      ))
    }
  }
  expected_random <- if (is_gaussian) {
    c("z_B", "s_B")
  } else if (ordinary) {
    "z_B"
  } else if (spatial_indep) {
    "omega_spde"
  } else {
    "omega_spde_lv"
  }
  if (!identical(as.character(random), expected_random)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL admits exactly one structure-specific Laplace-random block.",
      "x" = "Expected {.val {expected_random}}; resolved {.val {random}}.",
      "i" = "Additional random effects and structured covariance tiers are deferred."
    ))
  }
  if (isTRUE(use_mi_predictor)) {
    .gllvmTMB_mspl_abort(
      "Modelled missing predictors are outside the current LA-MSPL contract."
    )
  }
  if (
    !is.null(lambda_constraint) &&
      length(Filter(Negate(is.null), lambda_constraint))
  ) {
    .gllvmTMB_mspl_abort(c(
      "Confirmatory loading constraints are outside the current LA-MSPL contract.",
      "i" = "Fit the exploratory lower-triangular ordinary latent model without {.arg lambda_constraint}."
    ))
  }

  fixed <- .gllvmTMB_mspl_fixed_design(X_fix, b_map)
  structure <- if (ordinary) {
    "ordinary"
  } else if (spatial_indep) {
    "spatial_indep"
  } else {
    "spatial_latent"
  }
  tau_representative <- as.integer(-1L)
  spde_r0 <- 1
  p_psi <- 0L
  mspl_S_diag <- 0
  mspl_N_units <- 0L
  if (ordinary) {
    p_loading <- length(theta_rr_B)
    p_covariance <- 0L
    expected_outer <- c("b_fix", "theta_rr_B")
    if (is_gaussian) {
      p_psi <- length(theta_diag_B)
      if (!is.finite(p_psi) || p_psi < 1L) {
        .gllvmTMB_mspl_abort(
          "Gaussian LA-MSPL requires a free {.code theta_diag_B} Psi block."
        )
      }
      expected_outer <- c(expected_outer, "theta_diag_B")
      if (is.null(unit_id) || is.null(trait_id)) {
        .gllvmTMB_mspl_abort(
          "Internal Gaussian LA-MSPL missing unit/trait ids for S."
        )
      }
      mspl_S_diag <- .gllvmTMB_mspl_S_diag(y, trait_id, unit_id)
      mspl_N_units <- length(unique(as.integer(unit_id)))
    } else if (is_nbinom2) {
      ## Free per-trait phi is an outer block. C++ p_free still excludes it
      ## (Jeffreys rate is unpinned c=1, same as the planned nbinom door).
      expected_outer <- c(expected_outer, "log_phi_nbinom2")
    } else if (is_nbinom1) {
      expected_outer <- c(expected_outer, "log_phi_nbinom1")
    } else if (is_tweedie) {
      ## Free per-trait phi and power. C++ p_free still excludes them
      ## (Jeffreys rate is unpinned c=1, same as the planned nbinom door).
      expected_outer <- c(expected_outer, "log_phi_tweedie", "logit_p_tweedie")
    } else if (is_beta) {
      expected_outer <- c(expected_outer, "log_phi_beta")
    }
  } else if (spatial_indep) {
    tau_representative <- .gllvmTMB_mspl_tau_representatives(
      log_tau_spde,
      log_tau_spde_map
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
  p_free <- fixed$p_beta + p_loading + p_covariance + p_psi
  N_eff <- if (is_bernoulli) {
    sum(n_trials)
  } else {
    length(y)
  }
  if (!is.finite(N_eff) || N_eff <= 0) {
    .gllvmTMB_mspl_abort("LA-MSPL requires a positive effective sample size.")
  }

  family_name <- if (is_gaussian) {
    "gaussian"
  } else if (is_poisson) {
    "poisson"
  } else if (is_nbinom2) {
    "nbinom2"
  } else if (is_nbinom1) {
    "nbinom1"
  } else if (is_tweedie) {
    "tweedie"
  } else if (is_beta) {
    "Beta"
  } else {
    "binomial"
  }
  link_name <- .gllvmTMB_mspl_family_link_name(fam_ids, unique(link_id_vec))
  if (is.na(link_name)) {
    .gllvmTMB_mspl_abort("LA-MSPL could not resolve the family/link cell.")
  }
  q_cell <- if (identical(structure, "ordinary")) {
    as.integer(d_B)
  } else if (identical(structure, "spatial_latent")) {
    as.integer(d_spde_lv)
  } else {
    NA_integer_
  }
  registry_row <- .gllvmTMB_mspl_registry_lookup(
    family = family_name,
    link = link_name,
    structure = structure,
    q = q_cell
  )
  if (is.null(registry_row)) {
    .gllvmTMB_mspl_abort(
      c(
        "LA-MSPL resolved a surface that is not a registry cell.",
        "x" = "family {.val {family_name}}, link {.val {link_name}}, structure {.val {structure}}, q {.val {q_cell}}."
      ),
      class = "gllvmTMB_mspl_registry_miss"
    )
  }
  ## Bernoulli: admitted only. Gaussian ordinary: planned allowed during
  ## implement smoke; flip to admitted after se=FALSE smoke (point only —
  ## SE/intervals remain PROTECTED on codex/lane-b-mspl-interval-feasibility).
  ok_status <- if (is_gaussian || is_planned_glm) {
    registry_row$status %in% c("admitted", "planned")
  } else {
    identical(registry_row$status, "admitted")
  }
  if (!isTRUE(ok_status)) {
    .gllvmTMB_mspl_abort(
      c(
        "LA-MSPL resolved a surface that is not an admitted registry cell.",
        "x" = "family {.val {family_name}}, link {.val {link_name}}, structure {.val {structure}}, q {.val {q_cell}}, status {.val {registry_row$status}}."
      ),
      class = "gllvmTMB_mspl_registry_miss"
    )
  }

  ## Poisson c_P uses event count, not N_rows or N_units, and not c = 1.
  rate <- if (is_gaussian) {
    sqrt(2 / mspl_N_units)
  } else if (is_poisson) {
    .gllvmTMB_mspl_poisson_rate(
      p_free,
      .gllvmTMB_mspl_poisson_event_count(y)
    )
  } else if (is_nbinom || is_tweedie || is_beta) {
    1
  } else {
    2 * sqrt(p_free / N_eff)
  }

  list(
    estimator_id = 1L,
    family = family_name,
    X_mspl = fixed$X,
    N_eff = as.numeric(N_eff),
    p_beta = fixed$p_beta,
    p_loading = as.integer(p_loading),
    p_covariance = as.integer(p_covariance),
    p_psi = as.integer(p_psi),
    p_free = as.integer(p_free),
    rate = rate,
    mspl_S_diag = as.numeric(mspl_S_diag),
    mspl_N_units = as.integer(mspl_N_units),
    fixed_design = fixed,
    structure = structure,
    expected_outer = expected_outer,
    expected_random = expected_random,
    spde_r0 = spde_r0,
    tau_representative = tau_representative,
    registry_cell = registry_row$cell_id,
    registry_status = registry_row$status,
    registry_evidence = registry_row$evidence,
    scope = if (is_gaussian) {
      paste0(
        "complete gaussian identity; ordinary latent(unique=TRUE) q=",
        d_B,
        "; Hirose pick C; Laplace"
      )
    } else if (is_poisson) {
      paste0(
        "complete poisson log; ordinary latent q=",
        d_B,
        "; GLM-outer W=diag(mu) candidate (not I_LA(beta)); ",
        "c_P=2*sqrt(p_free/max(sum(y),1)); event-weighted loading atom; ",
        "planned tape, not admitted; Laplace"
      )
    } else if (is_nbinom2) {
      paste0(
        "complete nbinom2 log; ordinary latent q=",
        d_B,
        "; GLM-outer W=mu*phi/(phi+mu) candidate (not I_LA(beta)); ",
        "unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else if (is_nbinom1) {
      paste0(
        "complete nbinom1 log; ordinary latent q=",
        d_B,
        "; GLM-outer PMF-summed exact I (not quasi W=mu/(1+phi)); ",
        "unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else if (is_tweedie) {
      paste0(
        "complete tweedie log; ordinary latent q=",
        d_B,
        "; GLM-outer W=mu^{2-p}/phi (rewards phi->0; not I_LA(beta)); ",
        "unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else if (is_beta) {
      paste0(
        "complete Beta logit; ordinary latent q=",
        d_B,
        "; GLM-outer Jeffreys I_mu (not coercive at 0/1; not I_LA(beta)); ",
        "unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else {
      paste0(
        "complete Bernoulli; ",
        structure,
        if (structure == "spatial_latent") {
          paste0("(q=", d_spde_lv, ")")
        } else if (structure == "ordinary") {
          paste0("(q=", d_B, ")")
        } else {
          ""
        },
        "; Laplace; one common logit/probit/cloglog link"
      )
    }
  )
}
