#' Forecast a native temporal covariance model
#'
#' Computes a Gaussian response forecast at future occasions of already
#' observed series. The forecast conditions on the complete observed response
#' vector at fitted parameter values. `se.fit` is the corresponding
#' conditional predictive standard deviation; it excludes uncertainty in the
#' fitted parameters and is not a calibrated prediction interval.
#'
#' This route supports an unreplicated, `temporal_indep()`, Gaussian
#' identity-link model and one separately checked source-pair cell: replicated
#' AR1 `temporal_indep()` plus a fixed labelled `kernel_indep()` term. It
#' deliberately refuses new series, other temporal covariance modes, other
#' non-temporal tiers, source combinations, past or observed occasions, and
#' non-Gaussian families. The source-pair result is a fitted-parameter forecast
#' only; it does not establish interval calibration, coverage, or general
#' source-pair prediction.
#'
#' @param object A fitted native temporal [gllvmTMB()] model.
#' @param newdata A complete trait panel for one or more future
#'   series--occasion pairs. Each series must occur in the fitted data and each
#'   requested time must be strictly after that series' final fitted time. For
#'   the replicated kernel cell, include `measurement` and a complete trait
#'   panel for each series--occasion--measurement combination.
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
  indep_kernel_pair <- .temporal_is_qualified_indep_kernel_pair(object, active)
  if (!is.null(object$temporal$replicate_col) && !indep_kernel_pair) {
    .temporal_abort(c("{.fn forecast_temporal} does not yet support replicated temporal panels.",
      ">" = "Use a temporal-only unreplicated Gaussian fit for this fitted-parameter forecast route."),
      class = "gllvmTMB_temporal_forecast_replicated")
  }
  if (!identical(object$temporal$mode, "indep")) {
    .temporal_abort(c(
      "{.fn forecast_temporal} currently supports {.fn temporal_indep} only.",
      ">" = "Forecasts for temporal dependent and latent trait covariance need mode-specific oracle evidence."
    ), class = "gllvmTMB_temporal_forecast_mode")
  }
  td <- object$tmb_data
  if (is.null(td$family_id_vec) || any(td$family_id_vec != 0L)) {
    .temporal_abort("{.fn forecast_temporal} currently requires a Gaussian identity-link temporal fit.")
  }
  if (length(active) && !indep_kernel_pair) {
    .temporal_abort(c("{.fn forecast_temporal} currently supports the temporal source by itself.",
      "i" = "Active additional tier{?s}: {.val {active}}.",
      ">" = "Forecasts with ordinary or structured source effects need a joint conditioning contract."),
      class = "gllvmTMB_temporal_forecast_composed")
  }

  series_col <- object$temporal$series_col
  time_col <- object$temporal$time_col
  trait_col <- object$trait_col
  kernel_source_col <- if (indep_kernel_pair) .temporal_indep_kernel_source_column(object) else NULL
  required <- c(series_col, time_col, trait_col, object$temporal$replicate_col,
    kernel_source_col)
  missing <- setdiff(required, names(newdata))
  if (length(missing)) .temporal_abort("{.arg newdata} is missing required temporal column{?s}: {.val {missing}}.")
  raw_series <- as.character(newdata[[series_col]])
  raw_time <- newdata[[time_col]]
  raw_trait <- as.character(newdata[[trait_col]])
  if (!nrow(newdata) || anyNA(raw_series) || anyNA(raw_time) || anyNA(raw_trait)) {
    .temporal_abort("{.arg newdata} needs non-missing series, time, and trait values.")
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
  raw_replicate <- if (is.null(object$temporal$replicate_col)) NULL else
    as.character(newdata[[object$temporal$replicate_col]])
  if (!is.null(raw_replicate) && anyNA(raw_replicate)) {
    .temporal_abort("{.arg newdata} needs non-missing measurement labels.")
  }
  key <- paste(raw_series, format(raw_time, digits = 17), raw_replicate, raw_trait, sep = "\r")
  if (anyDuplicated(key)) .temporal_abort("{.arg newdata} has duplicate future observation rows.")
  panel_key <- paste(raw_series, format(raw_time, digits = 17), raw_replicate, sep = "\r")
  complete_panel <- vapply(split(raw_trait, panel_key), function(x) length(x) == length(trait_levels) && setequal(x, trait_levels), logical(1))
  if (!all(complete_panel)) {
    .temporal_abort(c("{.arg newdata} must contain a complete trait panel at every future series--occasion pair.",
      ">" = "Supply one row for each fitted trait at each requested time."),
      class = "gllvmTMB_temporal_forecast_panel")
  }
  if (indep_kernel_pair) {
    .temporal_indep_kernel_forecast_levels(object, nd = newdata,
      source_col = kernel_source_col)
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

.temporal_is_qualified_indep_kernel_pair <- function(object, active) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active) ||
      !identical(object$temporal$workflow, "replicated") ||
      !identical(object$temporal$structure, "ar1") ||
      !identical(object$temporal$mode, "indep") ||
      !identical(object$temporal$source_pair, "kernel_indep") ||
      !identical(active, "phylo_rr") || !isTRUE(object$use$phylo_rr)) {
    return(FALSE)
  }
  providers <- Filter(function(x) identical(x$kind, "phylo_rr"), object$covstructs)
  if (length(providers) != 1L) return(FALSE)
  extra <- providers[[1L]]$extra
  kernel_name <- extra$.kernel_name
  identical(extra$.kernel_mode, "indep") && isTRUE(extra$.indep) &&
    is.character(kernel_name) && length(kernel_name) == 1L && nzchar(kernel_name) &&
    !is.null(object$kernel_matrices[[kernel_name]]) &&
    is.matrix(object$kernel_matrices[[kernel_name]]) &&
    !is.null(rownames(object$kernel_matrices[[kernel_name]]))
}

.temporal_indep_kernel_source_column <- function(object) {
  providers <- Filter(function(x) identical(x$kind, "phylo_rr"), object$covstructs)
  source_col <- all.vars(providers[[1L]]$lhs)
  if (length(source_col) != 1L || !nzchar(source_col)) {
    .temporal_abort("The fitted temporal-kernel source grouping is unavailable for forecasting.")
  }
  source_col
}

.temporal_indep_kernel_forecast_levels <- function(object, nd, source_col) {
  kernel_name <- Filter(function(x) identical(x$kind, "phylo_rr"), object$covstructs)[[1L]]$extra$.kernel_name
  kernel <- object$kernel_matrices[[kernel_name]]
  labels <- as.character(nd[[source_col]])
  unknown <- setdiff(unique(labels), rownames(kernel))
  if (length(unknown)) {
    .temporal_abort(c(
      "{.arg newdata} names a kernel level absent from the fitted model.",
      "i" = "Unknown kernel level{?s}: {.val {unknown}}.",
      ">" = "Use existing fitted kernel labels; new-label forecasts need a separate marginal contract."
    ), class = "gllvmTMB_temporal_forecast_kernel_level")
  }
  invisible(kernel)
}

.temporal_forecast_covariance <- function(object, left, right = left) {
  par <- object$tmb_obj$env$parList(object$opt$par)
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
    lambda <- as.matrix(object$report$Lambda_temporal)
    covariance <- lambda %*% t(lambda)
    if (isTRUE(object$temporal$unique)) diag(covariance) <- diag(covariance) + exp(2 * par$theta_temporal_diag)
    covariance
  }
  out <- correlation * trait_covariance[left_trait, right_trait]
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  if (.temporal_is_qualified_indep_kernel_pair(object, active)) {
    source_col <- .temporal_indep_kernel_source_column(object)
    if (!source_col %in% names(left) || !source_col %in% names(right)) {
      .temporal_abort("The fitted temporal-kernel source grouping is unavailable in forecast data.")
    }
    kernel <- .temporal_indep_kernel_forecast_levels(object, left, source_col)
    .temporal_indep_kernel_forecast_levels(object, right, source_col)
    left_source <- as.character(left[[source_col]])
    right_source <- as.character(right[[source_col]])
    kernel_entry <- outer(left_source, right_source,
      Vectorize(function(a, b) kernel[a, b]))
    kernel_variance <- par$theta_rr_phy^2
    kernel_trait <- outer(left_trait, right_trait,
      Vectorize(function(i, j) if (i == j) kernel_variance[[i]] else 0))
    out <- out + kernel_entry * kernel_trait
  }
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}
