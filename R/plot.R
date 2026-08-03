#' Plot the isotropic spatial range from a gllvmTMB model
#'
#' @description
#' `gllvmTMB` currently fits isotropic SPDE/GMRF spatial fields. Consequently,
#' these helpers draw a circle whose radius is the fitted practical range,
#' `sqrt(8) / kappa`. Equal axes describe the model assumption (`H = I`); they
#' are not evidence that anisotropy was estimated.
#' Scope: the fitted isotropic-range display is covered by focused tests; the
#' broader spatial-family evidence remains partial; directional anisotropy,
#' delta/spatiotemporal fields, and new likelihoods are rejected from this
#' plotting contract.
#'
#' @param object A fitted `gllvmTMB_multi` model containing an intercept-only or
#'   random-slope spatial field.
#' @param return_data If `TRUE`, return the range geometry instead of a plot.
#' @param model Retained for compatibility. Only `model = 1` is supported
#'   because gllvmTMB has one shared spatial range parameter.
#'
#' @return `plot_anisotropy()` returns a `ggplot2` object, or a data frame when
#'   `return_data = TRUE`. `plot_anisotropy2()` draws the same geometry with
#'   base graphics and invisibly returns a list containing `data`, `range`,
#'   `kappa`, `H = diag(2)`, and `anisotropy_estimated = FALSE`.
#'
#' @section Scope:
#' These functions do not estimate or diagnose directional anisotropy. Delta
#' and spatiotemporal spatial models are not supported by this plotting
#' contract and fail explicitly.
#'
#' @export
plot_anisotropy <- function(object, return_data = FALSE) {
  if (
    !is.logical(return_data) || length(return_data) != 1L || is.na(return_data)
  ) {
    cli::cli_abort("{.arg return_data} must be one non-missing logical value.")
  }

  range_data <- .gllvm_spatial_range_geometry(object)
  if (return_data) {
    return(range_data)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install {.pkg ggplot2} to use {.fn plot_anisotropy}.")
  }

  ggplot2::ggplot(range_data, ggplot2::aes(x = .data$x, y = .data$y)) +
    ggplot2::geom_path(linewidth = 0.8, colour = "#0072B2") +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.25, colour = "grey70") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.25, colour = "grey70") +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Isotropic spatial range",
      subtitle = "Equal axes reflect the fitted H = I model assumption; anisotropy is not estimated",
      x = range_data$axis_x[[1L]],
      y = range_data$axis_y[[1L]],
      caption = sprintf(
        "Practical range = sqrt(8) / kappa = %.4g",
        range_data$range[[1L]]
      )
    ) +
    ggplot2::theme_minimal()
}

#' @rdname plot_anisotropy
#' @export
plot_anisotropy2 <- function(object, model = 1L) {
  if (!is.numeric(model) || length(model) != 1L || is.na(model) || model != 1) {
    cli::cli_abort(
      "{.arg model} must be 1; gllvmTMB fits one shared spatial range parameter."
    )
  }
  range_data <- .gllvm_spatial_range_geometry(object)
  graphics::plot(
    range_data$x,
    range_data$y,
    type = "l",
    asp = 1,
    xlab = range_data$axis_x[[1L]],
    ylab = range_data$axis_y[[1L]],
    main = "Isotropic spatial range"
  )
  graphics::abline(h = 0, v = 0, col = "grey70", lty = 3)
  invisible(list(
    data = range_data,
    range = range_data$range[[1L]],
    kappa = range_data$kappa[[1L]],
    H = diag(2L),
    anisotropy_estimated = FALSE
  ))
}

.gllvm_spatial_range_geometry <- function(object) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort(
      "{.arg object} must be a fitted {.cls gllvmTMB_multi} model."
    )
  }
  if (.gllvm_fit_uses_delta(object)) {
    cli::cli_abort(
      "Isotropic-range plotting is not supported for delta spatial models."
    )
  }
  if (isTRUE(object$use$spatiotemporal)) {
    cli::cli_abort(
      "Isotropic-range plotting is not supported for spatiotemporal models."
    )
  }

  spatial_flags <- c(
    isTRUE(object$use$spde),
    isTRUE(object$use$spde_slope),
    isTRUE(object$use$spde_latent_slope)
  )
  if (!any(spatial_flags)) {
    cli::cli_abort(
      "{.arg object} does not contain a fitted gllvmTMB spatial field."
    )
  }

  kappa <- .gllvm_spatial_kappa(object)
  if (
    !is.numeric(kappa) || length(kappa) != 1L || !is.finite(kappa) || kappa <= 0
  ) {
    cli::cli_abort(
      "The fitted model does not contain one finite positive spatial kappa estimate."
    )
  }

  range <- sqrt(8) / as.numeric(kappa)
  theta <- seq(0, 2 * pi, length.out = 361L)
  axes <- object$mesh$xy_cols
  if (!is.character(axes) || length(axes) != 2L) {
    axes <- c("x", "y")
  }
  data.frame(
    x = range * cos(theta),
    y = range * sin(theta),
    theta = theta,
    range = range,
    kappa = as.numeric(kappa),
    axis_x = axes[[1L]],
    axis_y = axes[[2L]],
    anisotropy_estimated = FALSE,
    model_assumption = "isotropic (H = I)",
    stringsAsFactors = FALSE
  )
}

.gllvm_spatial_kappa <- function(object) {
  if (!is.null(object$report$kappa)) {
    return(object$report$kappa)
  }
  if (!is.null(object$report$kappa_s)) {
    return(object$report$kappa_s)
  }

  # The reduced-rank spatial random-slope route estimates the same shared
  # log_kappa_spde parameter but does not currently duplicate it in REPORT().
  # Read the fitted parameter through TMB's retained parList contract rather
  # than changing the likelihood or inventing an anisotropy parameter.
  parameter_list <- tryCatch(
    object$tmb_obj$env$parList(object$opt$par),
    error = function(error) NULL
  )
  if (!is.null(parameter_list$log_kappa_spde)) {
    return(exp(parameter_list$log_kappa_spde))
  }
  NULL
}

.gllvm_fit_uses_delta <- function(object) {
  family <- object$family
  if (is.null(family)) {
    return(FALSE)
  }
  if (isTRUE(family$delta)) {
    return(TRUE)
  }
  if (!is.list(family)) {
    return(FALSE)
  }
  any(vapply(
    family,
    function(entry) is.list(entry) && isTRUE(entry$delta),
    logical(1)
  ))
}
