.temporal_bootstrap_time_estimate <- function(object, par) {
  theta <- par$theta_temporal_time
  if (identical(object$temporal$structure, "ar1")) {
    (1 - 1e-6) * tanh(theta)
  } else {
    exp(theta)
  }
}

.temporal_is_qualified_kernel_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "phylo_rr")) {
    return(FALSE)
  }
  extra <- providers[[1L]]$extra
  is.list(extra) && is.character(extra$.kernel_name) &&
    length(extra$.kernel_name) == 1L && nzchar(extra$.kernel_name) &&
    identical(extra$.kernel_mode, "indep")
}

.temporal_is_qualified_dep_phylo_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "phylo_rr") ||
      !identical(object$temporal$source_pair, "phylo_indep") ||
      !identical(object$temporal$mode, "dep") ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$workflow, "replicated")) {
    return(FALSE)
  }
  provider <- providers[[1L]]
  extra <- provider$extra
  identical(provider$kind, "phylo_rr") && is.list(extra) &&
    isTRUE(extra$.indep) && isTRUE(extra$.phylo_unique) &&
    is.null(object$source_strength) &&
    (is.matrix(object$tmb_data$Ainv_phy_rr) ||
      inherits(object$tmb_data$Ainv_phy_rr, "Matrix"))
}

.temporal_is_qualified_dep_animal_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "phylo_rr") ||
      !identical(object$temporal$source_pair, "animal_indep") ||
      !identical(object$temporal$mode, "dep") ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$workflow, "replicated")) {
    return(FALSE)
  }
  provider <- providers[[1L]]
  extra <- provider$extra
  identical(provider$kind, "phylo_rr") && is.list(extra) &&
    isTRUE(extra$.indep) && isTRUE(extra$.phylo_unique) &&
    isTRUE(extra$.animal_source) && is.null(object$source_strength) &&
    (is.matrix(object$tmb_data$Ainv_phy_rr) ||
      inherits(object$tmb_data$Ainv_phy_rr, "Matrix"))
}

.temporal_is_qualified_latent_animal_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "phylo_rr") ||
      !identical(object$temporal$source_pair, "animal_indep") ||
      !identical(object$temporal$mode, "latent") ||
      !identical(object$temporal$d, 1L) || isTRUE(object$temporal$unique) ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$workflow, "replicated")) {
    return(FALSE)
  }
  provider <- providers[[1L]]
  extra <- provider$extra
  identical(provider$kind, "phylo_rr") && is.list(extra) &&
    isTRUE(extra$.indep) && isTRUE(extra$.phylo_unique) &&
    isTRUE(extra$.animal_source) && is.null(object$source_strength) &&
    (is.matrix(object$tmb_data$Ainv_phy_rr) ||
      inherits(object$tmb_data$Ainv_phy_rr, "Matrix"))
}

.temporal_is_qualified_latent_kernel_pair <- function(object, active_tiers) {
  .temporal_is_qualified_kernel_pair(object, active_tiers) &&
    identical(object$temporal$source_pair, "kernel_indep") &&
    identical(object$temporal$mode, "latent") &&
    identical(object$temporal$d, 1L) && !isTRUE(object$temporal$unique) &&
    identical(object$temporal$structure, "ar1") &&
    identical(object$temporal$workflow, "replicated")
}

.temporal_is_qualified_latent_spatial_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "spde") ||
      !identical(object$temporal$source_pair, "spatial_indep") ||
      !identical(object$temporal$mode, "latent") ||
      !identical(object$temporal$d, 1L) || isTRUE(object$temporal$unique) ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$workflow, "replicated")) return(FALSE)
  provider <- providers[[1L]]; extra <- provider$extra
  identical(provider$kind, "spde") && is.list(extra) &&
    isTRUE(extra$.spatial_indep) && identical(extra$lhs_form, "intercept_only") &&
    inherits(extra$mesh, "gllvmTMBmesh") && is.null(object$source_strength) &&
    isTRUE(object$tmb_data$use_spde == 1L)
}

.temporal_is_qualified_dep_spatial_pair <- function(object, active_tiers) {
  providers <- object$covstructs
  if (!is.list(providers) || length(providers) != 1L ||
      !identical(as.character(active_tiers), "spde") ||
      !identical(object$temporal$source_pair, "spatial_indep") ||
      !identical(object$temporal$mode, "dep") ||
      !identical(object$temporal$d, 0L) || isTRUE(object$temporal$unique) ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$workflow, "replicated")) return(FALSE)
  provider <- providers[[1L]]; extra <- provider$extra
  identical(provider$kind, "spde") && is.list(extra) &&
    isTRUE(extra$.spatial_indep) && identical(extra$lhs_form, "intercept_only") &&
    inherits(extra$mesh, "gllvmTMBmesh") && is.null(object$source_strength) &&
    isTRUE(object$tmb_data$use_spde == 1L)
}

.temporal_bootstrap_refit_data <- function(object, draw, response) {
  is_wide <- identical(object$traits_meta$input_shape, "wide_data_frame")
  if (!is_wide) {
    dat <- object$data
    dat[[response]] <- draw
    return(dat)
  }

  dat <- object$wide_data_original
  trait_cols <- object$traits_meta$trait_cols
  source_row <- as.integer(object$traits_meta$source_row)
  trait <- as.character(object$data[[object$trait_col]])
  response_col <- match(trait, trait_cols)
  if (!is.data.frame(dat) || !length(trait_cols) ||
      !all(trait_cols %in% names(dat)) || length(source_row) != nrow(object$data) ||
      length(response_col) != nrow(object$data) || anyNA(source_row) ||
      anyNA(response_col) || any(source_row < 1L | source_row > nrow(dat)) ||
      !is.matrix(draw) || nrow(draw) != nrow(object$data)) {
    .temporal_abort(c(
      "This wide temporal fit does not retain a reversible response mapping for bootstrap refits.",
      ">" = "Refit the model from its public wide data before using {.fn bootstrap_temporal}."
    ), class = "gllvmTMB_temporal_bootstrap_wide_mapping")
  }
  dat[cbind(source_row, match(trait_cols[response_col], names(dat)))] <- draw[, 1L]
  dat
}

#' Parametric bootstrap for a temporal persistence parameter
#'
#' Draws unconditional temporal responses and refits the saved public model
#' call. Failed refits are retained in the returned table. The bounded composed
#' route accepts a replicated Gaussian AR1 or OU `temporal_indep()` fit with one
#' fixed labelled `kernel_indep()` term, a replicated Gaussian AR1
#' `temporal_dep()` fit with one fixed `phylo_indep()` or `animal_indep()`
#' source, or a replicated
#' Gaussian AR1 rank-one `temporal_latent(unique = FALSE)` fit with one fixed
#' `animal_indep()` source, or a replicated Gaussian AR1 rank-one
#' `temporal_latent(unique = FALSE)` fit with one fixed-mesh
#' `spatial_indep()` source. It redraws both sources through [stats::simulate()]
#' and replays the public model call through [update()]. For a `traits(...)`
#' fit it reconstructs the original wide response columns before replay.
#' The fixed-mesh `temporal_dep() + spatial_indep()` route is also admitted
#' under its separate AR1 Gaussian lifecycle contract.
#' @param object An unreplicated Gaussian `temporal_indep()` fit, or the
#'   qualified replicated AR1 or OU `temporal_indep() + kernel_indep()` fit, or
#'   the qualified replicated AR1 `temporal_dep() + phylo_indep()` or
#'   `temporal_dep() + animal_indep()` or fixed-mesh
#'   `temporal_dep() + spatial_indep()` fit, or the
#'   qualified rank-one `temporal_latent() + animal_indep()` fit, or the
#'   qualified rank-one `temporal_latent() + spatial_indep()` fit.
#' @param n_boot Number of refits.
#' @param seed Optional random seed.
#' @return A data frame with one row per attempted refit. `seed` records the
#'   exact unconditional response draw; failed and non-converged refits retain
#'   their convergence code and error text.
#' @export
bootstrap_temporal <- function(object, n_boot = 100L, seed = NULL) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active)) {
    .temporal_abort("{.fn bootstrap_temporal} requires a native temporal fit.")
  }
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  kernel_pair <- .temporal_is_qualified_kernel_pair(object, active)
  dep_phylo_pair <- .temporal_is_qualified_dep_phylo_pair(object, active)
  dep_animal_pair <- .temporal_is_qualified_dep_animal_pair(object, active)
  latent_animal_pair <- .temporal_is_qualified_latent_animal_pair(object, active)
  latent_spatial_pair <- .temporal_is_qualified_latent_spatial_pair(object, active)
  dep_spatial_pair <- .temporal_is_qualified_dep_spatial_pair(object, active)
  if (length(active) && !kernel_pair && !dep_phylo_pair && !dep_animal_pair && !latent_animal_pair && !latent_spatial_pair && !dep_spatial_pair) {
    .temporal_abort(c(
      "{.fn bootstrap_temporal} supports only qualified temporal-kernel, temporal-dependent phylogenetic, animal, or spatial, rank-one temporal-animal, or rank-one temporal-spatial source pairs.",
      "i" = "The fit also uses covariance tier(s): {.val {active}}.",
      ">" = "Use the replicated AR1 {.code temporal_indep() + kernel_indep()} cell with one fixed labelled kernel, the replicated AR1 {.code temporal_dep()} cell with one fixed phylogeny or animal relationship, a qualified rank-one {.code temporal_latent()} source pair, or a temporal-only fit."
    ), class = "gllvmTMB_temporal_bootstrap_composed")
  }
  if ((!identical(object$temporal$mode, "indep") && !dep_phylo_pair && !dep_animal_pair && !latent_animal_pair && !latent_spatial_pair && !dep_spatial_pair) ||
      any(object$tmb_data$family_id_vec != 0L)) {
    .temporal_abort("{.fn bootstrap_temporal} currently supports Gaussian {.fn temporal_indep} fits, qualified temporal-dependent phylogenetic, animal, or spatial pairs, and qualified rank-one temporal-animal or temporal-spatial pairs only.")
  }
  if (kernel_pair) {
    if (!object$temporal$structure %in% c("ar1", "ou") || is.null(object$temporal$replicate_col)) {
      .temporal_abort("The qualified temporal-kernel bootstrap requires a replicated AR1 or OU panel.")
    }
  } else if (!dep_phylo_pair && !dep_animal_pair && !latent_animal_pair && !latent_spatial_pair && !dep_spatial_pair && !is.null(object$temporal$replicate_col)) {
    .temporal_abort("{.fn bootstrap_temporal} currently supports replicated panels only for qualified temporal-kernel, temporal-dependent phylogenetic, animal, or spatial, or rank-one temporal-animal cells.")
  }
  if (!is.numeric(n_boot) || length(n_boot) != 1L || !is.finite(n_boot) ||
      n_boot < 1 || n_boot != as.integer(n_boot)) {
    .temporal_abort("{.arg n_boot} must be a positive integer.")
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      seed < 0L || seed > .Machine$integer.max || seed != as.integer(seed))) {
    .temporal_abort("{.arg seed} must be one non-negative whole number or {.code NULL}.")
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  if (!is.null(seed)) set.seed(as.integer(seed))
  draw_seeds <- sample.int(.Machine$integer.max, size = as.integer(n_boot))
  response <- all.vars(object$formula[[2L]])
  if (length(response) != 1L) .temporal_abort("The temporal fit lacks one recoverable response column.")
  out <- vector("list", n_boot)
  for (i in seq_len(n_boot)) {
    draw <- simulate(object, nsim = 1L, seed = draw_seeds[[i]], condition_on_RE = FALSE)
    dat <- .temporal_bootstrap_refit_data(object, draw, response)
    refit <- tryCatch(stats::update(object, data = dat), error = identity)
    if (inherits(refit, "error")) {
      out[[i]] <- data.frame(replicate = i, seed = draw_seeds[[i]], convergence = NA_integer_,
        objective = NA_real_, time_estimate = NA_real_, error = conditionMessage(refit))
    } else {
      par <- refit$tmb_obj$env$parList(refit$opt$par)
      convergence <- refit$opt$convergence
      out[[i]] <- data.frame(replicate = i, seed = draw_seeds[[i]], convergence = convergence,
        objective = refit$opt$objective, time_estimate = .temporal_bootstrap_time_estimate(refit, par),
        error = if (identical(convergence, 0L)) "" else sprintf("non-converged optimizer code %s", convergence))
    }
  }
  do.call(rbind, out)
}
