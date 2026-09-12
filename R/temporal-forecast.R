#' Forecast a native temporal covariance model
#'
#' Computes a Gaussian response forecast at future occasions of already
#' observed series. The forecast conditions on the complete observed response
#' vector at fitted parameter values. `se.fit` is the corresponding
#' conditional predictive standard deviation; it excludes uncertainty in the
#' fitted parameters and is not a calibrated prediction interval.
#'
#' The base route supports an unreplicated, `temporal_indep()`, Gaussian
#' identity-link model. A separately qualified route supports a replicated AR1
#' `temporal_indep() + kernel_indep()` fit with one fixed labelled diagonal
#' kernel. A second route supports the corresponding rank-one
#' `temporal_latent(unique = FALSE) + kernel_indep()` fit. A third route supports replicated AR1
#' `temporal_dep() + phylo_indep()` with one fixed phylogenetic covariance. A
#' third route supports replicated AR1 rank-one
#' `temporal_latent(unique = FALSE) + animal_indep()` with one fixed animal
#' relationship. A fourth route supports the corresponding fixed-mesh
#' `spatial_indep()` pair. All composed routes forecast future observations
#' rather than latent state means.
#' Other temporal covariance modes, non-temporal random-effect tiers, source
#' combinations, past or observed occasions, and non-Gaussian families remain
#' outside this helper until they have their own conditioning contracts.
#'
#' @param object A fitted native temporal [gllvmTMB()] model.
#' @param newdata A complete trait panel for one or more future
#'   series--occasion pairs. Each series must occur in the fitted data and each
#'   requested time must be strictly after that series' final fitted time.
#' @param se.fit Return the fitted-parameter conditional predictive standard
#'   deviation.
#' @return `newdata`, in its input row order, with `est` on the Gaussian
#'   identity-link scale and, when requested, `se.fit`.
#' @examples
#' d <- expand.grid(series = c("a", "b"), occasion = 1:3,
#'   trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
#' d$value <- with(d, occasion + as.numeric(factor(trait)) / 10)
#' fit <- gllvmTMB(value ~ 0 + trait +
#'   temporal_indep(0 + trait | series, time = occasion),
#'   data = d, unit = "series", family = gaussian(), silent = TRUE,
#'   control = gllvmTMBcontrol(se = FALSE))
#' future <- expand.grid(series = c("a", "b"), occasion = 4,
#'   trait = c("t1", "t2", "t3"), KEEP.OUT.ATTRS = FALSE)
#' forecast_temporal(fit, future, se.fit = TRUE)
#' @export
forecast_temporal <- function(object, newdata, se.fit = FALSE) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active)) {
    .temporal_abort("{.fn forecast_temporal} requires a native temporal {.fn gllvmTMB} fit.")
  }
  if (!is.data.frame(newdata)) .temporal_abort("{.arg newdata} must be a data frame.")
  if (!is.logical(se.fit) || length(se.fit) != 1L || is.na(se.fit)) {
    .temporal_abort("{.arg se.fit} must be TRUE or FALSE.")
  }
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  kernel_pair <- .temporal_is_qualified_kernel_pair(object, active)
  latent_kernel_pair <- .temporal_is_qualified_latent_kernel_pair(object, active)
  dep_phylo_pair <- .temporal_is_qualified_dep_phylo_pair(object, active)
  latent_animal_pair <- .temporal_is_qualified_latent_animal_pair(object, active)
  latent_spatial_pair <- .temporal_is_qualified_latent_spatial_pair(object, active)
  qualified_replicated_pair <-
    (kernel_pair && identical(object$temporal$structure, "ar1")) || latent_kernel_pair || dep_phylo_pair || latent_animal_pair || latent_spatial_pair
  if (!identical(object$temporal$mode, "indep") && !latent_kernel_pair && !dep_phylo_pair && !latent_animal_pair && !latent_spatial_pair) {
    .temporal_abort(c(
      "{.fn forecast_temporal} currently supports {.fn temporal_indep} only, apart from qualified temporal-dependent phylogenetic, rank-one temporal-animal, and rank-one temporal-spatial cells.",
      ">" = "Forecasts for temporal dependent and latent trait covariance need mode- and source-specific oracle evidence."
    ), class = "gllvmTMB_temporal_forecast_mode")
  }
  td <- object$tmb_data
  if (is.null(td$family_id_vec) || any(td$family_id_vec != 0L)) {
    .temporal_abort("{.fn forecast_temporal} currently requires a Gaussian identity-link temporal fit.")
  }
  if (length(active) && !kernel_pair && !latent_kernel_pair && !dep_phylo_pair && !latent_animal_pair && !latent_spatial_pair) {
    .temporal_abort(c("{.fn forecast_temporal} currently supports the temporal source by itself.",
      "i" = "Active additional tier{?s}: {.val {active}}.",
      ">" = "Forecasts with ordinary or structured source effects need a joint conditioning contract."),
      class = "gllvmTMB_temporal_forecast_composed")
  }
  if (!is.null(object$temporal$replicate_col) &&
      !qualified_replicated_pair) {
    .temporal_abort(c(
      "{.fn forecast_temporal} currently supports replicated panels only for qualified temporal-kernel, temporal-dependent phylogenetic, rank-one temporal-animal, or rank-one temporal-spatial cells.",
      ">" = "Use replicated {.fn temporal_indep} plus one fixed labelled {.fn kernel_indep}, replicated {.fn temporal_dep} plus one fixed {.fn phylo_indep}, or replicated rank-one {.fn temporal_latent} plus one fixed {.fn animal_indep} or fixed-mesh {.fn spatial_indep}."
    ), class = "gllvmTMB_temporal_forecast_replicated")
  }

  series_col <- object$temporal$series_col
  time_col <- object$temporal$time_col
  trait_col <- object$trait_col
  replicate_col <- object$temporal$replicate_col
  required <- c(series_col, time_col, trait_col, replicate_col)
  missing <- setdiff(required, names(newdata))
  if (length(missing)) .temporal_abort("{.arg newdata} is missing required temporal column{?s}: {.val {missing}}.")
  raw_series <- as.character(newdata[[series_col]])
  raw_time <- newdata[[time_col]]
  raw_trait <- as.character(newdata[[trait_col]])
  raw_replicate <- if (is.null(replicate_col)) NULL else as.character(newdata[[replicate_col]])
  if (!nrow(newdata) || anyNA(raw_series) || anyNA(raw_time) || anyNA(raw_trait) ||
      (!is.null(raw_replicate) && anyNA(raw_replicate))) {
    .temporal_abort("{.arg newdata} needs non-missing series, time, trait, and measurement values.")
  }
  if (!is.numeric(raw_time) && !is.integer(raw_time)) .temporal_abort("The temporal forecast time column must be numeric.")
  raw_time <- as.numeric(raw_time)
  if (!all(is.finite(raw_time))) .temporal_abort("The temporal forecast time column must contain finite values.")
  if (identical(object$temporal$structure, "ar1") && any(abs(raw_time - round(raw_time)) > sqrt(.Machine$double.eps))) {
    .temporal_abort("AR1 temporal forecasts require integer occasions.")
  }
  training_series <- as.character(object$data[[series_col]])
  training_time <- as.numeric(object$data[[time_col]])
  unknown_series <- setdiff(unique(raw_series), unique(training_series))
  if (length(unknown_series)) {
    .temporal_abort(c("{.fn forecast_temporal} supports existing series only.",
      "i" = "Unknown series: {.val {unknown_series}}.",
      ">" = "New-series forecasts need a separately validated marginal prediction contract."),
      class = "gllvmTMB_temporal_forecast_new_series")
  }
  trait_levels <- levels(object$data[[trait_col]])
  unknown_trait <- setdiff(unique(raw_trait), trait_levels)
  if (length(unknown_trait)) .temporal_abort("{.arg newdata} names unknown trait{?s}: {.val {unknown_trait}}.")
  key <- paste(raw_series, format(raw_time, digits = 17), raw_replicate, raw_trait, sep = "\r")
  if (anyDuplicated(key)) .temporal_abort("{.arg newdata} has duplicate future observation rows.")
  panel_key <- paste(raw_series, format(raw_time, digits = 17), raw_replicate, sep = "\r")
  complete_panel <- vapply(split(raw_trait, panel_key), function(x) length(x) == length(trait_levels) && setequal(x, trait_levels), logical(1))
  if (!all(complete_panel)) {
    .temporal_abort(c("{.arg newdata} must contain a complete trait panel at every future observation.",
      ">" = "Supply one row for each fitted trait at each series, time, and measurement."),
      class = "gllvmTMB_temporal_forecast_panel")
  }
  latest_time <- tapply(training_time, training_series, max)
  if (!all(raw_time > unname(latest_time[raw_series]))) {
    .temporal_abort(c("Temporal forecast occasions must be strictly after each series' fitted occasions.",
      ">" = "Use {.fn predict} for fitted rows; this route forecasts future occasions only."),
      class = "gllvmTMB_temporal_forecast_not_future")
  }

  nd <- .gllvmTMB_restore_newdata_factor_levels(newdata, object$data)
  X_new <- stats::model.matrix(stats::delete.response(stats::terms(object$formula)), nd)
  eta_fixed_new <- .gllvmTMB_predict_fixed_eta(object, X_new) + .gllvmTMB_offset_newdata(object, nd)
  eta_fixed_observed <- as.numeric(td$X_fix %*% .gllvmTMB_b_fix_values(object)) + .gllvmTMB_offset_vec(object)
  response_col <- all.vars(object$formula[[2L]])
  if (length(response_col) != 1L || !response_col %in% names(object$data)) {
    .temporal_abort("The temporal fit does not retain one recoverable response column.")
  }
  residual <- object$data[[response_col]] - eta_fixed_observed

  observed_covariance <- .temporal_forecast_covariance(object, object$data)
  future_covariance <- .temporal_forecast_covariance(object, nd)
  cross_covariance <- .temporal_forecast_covariance(object, object$data, nd)
  chol_observed <- tryCatch(chol(observed_covariance), error = function(e) NULL)
  if (is.null(chol_observed)) .temporal_abort("The fitted temporal response covariance was not positive definite for forecasting.")
  solved <- backsolve(chol_observed, forwardsolve(t(chol_observed), cbind(residual, cross_covariance)))
  estimate <- as.numeric(eta_fixed_new + crossprod(cross_covariance, solved[, 1L]))
  out <- data.frame(nd, est = estimate, check.names = FALSE)
  if (isTRUE(se.fit)) {
    variance <- diag(future_covariance - crossprod(cross_covariance, solved[, -1L, drop = FALSE]))
    if (any(variance < -1e-8)) .temporal_abort("The temporal forecast produced a negative conditional variance.")
    out$se.fit <- sqrt(pmax(variance, 0))
  }
  out
}

.temporal_forecast_covariance <- function(object, left, right = left) {
  par <- object$tmb_obj$env$parList(object$opt$par)
  td <- object$tmb_data
  trait_levels <- levels(object$data[[object$trait_col]])
  left_trait <- match(as.character(left[[object$trait_col]]), trait_levels)
  right_trait <- match(as.character(right[[object$trait_col]]), trait_levels)
  left_series <- as.character(left[[object$temporal$series_col]])
  right_series <- as.character(right[[object$temporal$series_col]])
  left_time <- as.numeric(left[[object$temporal$time_col]])
  right_time <- as.numeric(right[[object$temporal$time_col]])
  same_series <- outer(left_series, right_series, FUN = "==")
  gap <- abs(outer(left_time, right_time, "-"))
  correlation <- if (identical(object$temporal$structure, "ar1")) {
    ((1 - 1e-6) * tanh(par$theta_temporal_time))^gap
  } else exp(-exp(par$theta_temporal_time) * gap)
  correlation[!same_series] <- 0
  trait_covariance <- if (identical(object$temporal$mode, "indep")) {
    diag(exp(2 * par$theta_temporal_diag), nrow = length(trait_levels))
  } else {
    lambda <- .temporal_forecast_unpack_loadings(
      par$theta_temporal_rr, length(trait_levels), td$temporal_rank
    )
    covariance <- lambda %*% t(lambda)
    if (isTRUE(object$temporal$unique)) diag(covariance) <- diag(covariance) + exp(2 * par$theta_temporal_diag)
    covariance
  }
  out <- correlation * trait_covariance[left_trait, right_trait]
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  if (.temporal_is_qualified_kernel_pair(object, active)) {
    provider <- object$covstructs[[1L]]
    source_col <- all.vars(provider$lhs)
    if (length(source_col) != 1L || !source_col %in% names(left) || !source_col %in% names(right)) {
      .temporal_abort("The fitted temporal-kernel source grouping is unavailable in forecast data.")
    }
    kernel_name <- object$kernel_levels$name
    K <- object$kernel_matrices[[kernel_name]]
    if (!is.matrix(K) || is.null(rownames(K)) || is.null(colnames(K))) {
      .temporal_abort("The fitted temporal-kernel model does not retain a labelled kernel matrix.")
    }
    left_source <- match(as.character(left[[source_col]]), rownames(K))
    right_source <- match(as.character(right[[source_col]]), colnames(K))
    if (anyNA(left_source) || anyNA(right_source)) {
      .temporal_abort(c(
        "{.arg newdata} names a source level absent from the fitted kernel.",
        ">" = "Use a fitted series and its corresponding kernel label."
      ), class = "gllvmTMB_temporal_forecast_kernel_level")
    }
    kernel_covariance <- diag(par$theta_rr_phy^2, nrow = length(trait_levels))
    out <- out + K[left_source, right_source] * kernel_covariance[left_trait, right_trait]
  }
  if (.temporal_is_qualified_dep_phylo_pair(object, active)) {
    provider <- object$covstructs[[1L]]
    source_col <- all.vars(provider$lhs)
    if (length(source_col) != 1L || !source_col %in% names(left) || !source_col %in% names(right)) {
      .temporal_abort("The fitted temporal-phylogenetic source grouping is unavailable in forecast data.")
    }
    source_map <- split(td$species_aug_id, as.character(object$data[[source_col]]))
    source_map <- vapply(source_map, function(x) {
      if (length(unique(x)) != 1L) NA_integer_ else unique(x)[[1L]]
    }, integer(1))
    left_source <- unname(source_map[as.character(left[[source_col]])])
    right_source <- unname(source_map[as.character(right[[source_col]])])
    if (anyNA(left_source) || anyNA(right_source)) {
      .temporal_abort(c(
        "{.arg newdata} names a phylogenetic level absent from the fitted model.",
        ">" = "Use a fitted series and its corresponding phylogenetic tip label."
      ), class = "gllvmTMB_temporal_forecast_phylo_level")
    }
    phylo_covariance <- solve(as.matrix(td$Ainv_phy_rr))
    phylo_variance <- diag(par$theta_rr_phy^2, nrow = length(trait_levels))
    out <- out + phylo_covariance[left_source + 1L, right_source + 1L] *
      phylo_variance[left_trait, right_trait]
  }
  if (.temporal_is_qualified_latent_animal_pair(object, active)) {
    provider <- object$covstructs[[1L]]
    source_col <- all.vars(provider$lhs)
    if (length(source_col) != 1L || !source_col %in% names(left) || !source_col %in% names(right)) {
      .temporal_abort("The fitted temporal-animal source grouping is unavailable in forecast data.")
    }
    source_map <- split(td$species_aug_id, as.character(object$data[[source_col]]))
    source_map <- vapply(source_map, function(x) {
      if (length(unique(x)) != 1L) NA_integer_ else unique(x)[[1L]]
    }, integer(1))
    left_source <- unname(source_map[as.character(left[[source_col]])])
    right_source <- unname(source_map[as.character(right[[source_col]])])
    if (anyNA(left_source) || anyNA(right_source)) {
      .temporal_abort(c(
        "{.arg newdata} names an animal level absent from the fitted model.",
        ">" = "Use a fitted series and its corresponding animal relationship label."
      ), class = "gllvmTMB_temporal_forecast_animal_level")
    }
    animal_covariance <- solve(as.matrix(td$Ainv_phy_rr))
    animal_variance <- diag(par$theta_rr_phy^2, nrow = length(trait_levels))
    out <- out + animal_covariance[left_source + 1L, right_source + 1L] *
      animal_variance[left_trait, right_trait]
  }
  if (.temporal_is_qualified_latent_spatial_pair(object, active)) {
    xy_cols <- object$mesh$xy_cols
    if (!is.character(xy_cols) || length(xy_cols) != 2L ||
        !all(xy_cols %in% names(left)) || !all(xy_cols %in% names(right))) {
      .temporal_abort(c(
        "The fitted temporal-spatial forecast requires both fitted coordinate columns.",
        ">" = "Supply the same coordinate names used to construct the fitted mesh."
      ), class = "gllvmTMB_temporal_forecast_spatial_coordinates")
    }
    left_coordinates <- as.matrix(left[, xy_cols, drop = FALSE])
    right_coordinates <- as.matrix(right[, xy_cols, drop = FALSE])
    if (!is.numeric(left_coordinates) || !is.numeric(right_coordinates) ||
        any(!is.finite(left_coordinates)) || any(!is.finite(right_coordinates))) {
      .temporal_abort("Temporal-spatial forecast coordinates must be finite numeric values.")
    }
    if (!requireNamespace("fmesher", quietly = TRUE)) {
      .temporal_abort("The qualified temporal-spatial forecast requires the suggested fmesher package.")
    }
    P_left <- as.matrix(fmesher::fm_basis(object$mesh$mesh, loc = left_coordinates))
    P_right <- as.matrix(fmesher::fm_basis(object$mesh$mesh, loc = right_coordinates))
    if (any(!is.finite(P_left)) || any(!is.finite(P_right)) ||
        any(rowSums(abs(P_left)) <= 0) || any(rowSums(abs(P_right)) <= 0)) {
      .temporal_abort(c(
        "Temporal-spatial forecast coordinates must project onto the fitted mesh.",
        ">" = "Use future coordinates inside the supported fitted-mesh domain."
      ), class = "gllvmTMB_temporal_forecast_spatial_projection")
    }
    kappa <- exp(par$log_kappa_spde)
    Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) + as.matrix(td$spde_M2)
    spatial_covariance <- P_left %*% solve(Q) %*% t(P_right)
    spatial_variance <- diag(exp(-2 * par$log_tau_spde), nrow = length(trait_levels))
    out <- out + spatial_covariance * spatial_variance[left_trait, right_trait]
  }
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

.temporal_forecast_unpack_loadings <- function(theta, n_traits, rank) {
  rank <- as.integer(rank)
  expected <- n_traits * rank - rank * (rank - 1L) / 2L
  if (rank < 1L || rank > n_traits || length(theta) != expected) {
    .temporal_abort("The fitted temporal loading block has an invalid shape for forecasting.")
  }
  loading <- matrix(0, n_traits, rank)
  cursor <- 1L
  for (column in seq_len(rank)) {
    loading[column, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  for (column in seq_len(rank)) {
    if (column < n_traits) {
      for (row in seq.int(column + 1L, n_traits)) {
        loading[row, column] <- theta[[cursor]]
        cursor <- cursor + 1L
      }
    }
  }
  loading
}
