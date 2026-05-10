#' Plot anisotropy from a gllvmTMB model
#'
#' Anisotropy is when spatial correlation is directionally dependent.
#' These plotting functions help visualise the estimated anisotropy
#' from a `gllvmTMB()` fit that used `spatial_*()` keywords with an
#' anisotropic SPDE mesh.
#'
#' @param object A fitted `gllvmTMB` model object with an anisotropic
#'   spatial component.
#' @param return_data Logical. Return a data frame? `plot_anisotropy()` only.
#' @param model Which model if a delta model (only for `plot_anisotropy2()`;
#'   `plot_anisotropy()` always plots both).
#'
#' @return
#' `plot_anisotropy()`: One or more ellipses illustrating the estimated
#' anisotropy. The ellipses are centred at coordinates of zero in the space
#' of the X-Y coordinates being modelled. The ellipses show the spatial
#' range (distance at which correlation is effectively independent) in any
#' direction from zero. Uses \pkg{ggplot2}. If anisotropy was turned off
#' when fitting the model, `NULL` is returned instead of a \pkg{ggplot2}
#' object.
#'
#' `plot_anisotropy2()`: A plot of eigenvectors illustrating the estimated
#' anisotropy. A list of the plotted data is invisibly returned. Uses base
#' graphics. If anisotropy was turned off when fitting the model, `NULL` is
#' returned instead of a plot object.
#' @references Code adapted from VAST and TMB anisotropy examples, via
#'   sdmTMB.
#' @importFrom rlang .data
#' @export
#' @rdname plot_anisotropy
plot_anisotropy <- function(object, return_data = FALSE) {
  stopifnot(inherits(object, "gllvmTMB"))
  if (!check_for_H(object)) return(NULL)
  delta <- isTRUE(object$family$delta)

  # Calculate anisotropy components for model 1
  comp1 <- calculate_anisotropy_components(object, m = 1)
  eig <- comp1$eig
  maj1_s <- comp1$maj_s
  min1_s <- comp1$min_s
  maj1_st <- comp1$maj_st
  min1_st <- comp1$min_st

  # Calculate anisotropy components for model 2 if delta
  if (delta) {
    comp2 <- calculate_anisotropy_components(object, m = 2)
    eig2 <- comp2$eig
    maj2_s <- comp2$maj_s
    min2_s <- comp2$min_s
    maj2_st <- comp2$maj_st
    min2_st <- comp2$min_st
  }

  rss <- function(V) sqrt(sum(V[1]^2 + V[2]^2))
  get_angle <- function(m) {
    a <- -1 * (atan(m[1] / m[2]) / (2 * pi) * 360 - 90)
    a * (pi / 180)
  }

  angle1_s <- get_angle(maj1_s)
  angle1_st <- get_angle(maj1_st)

  if (delta) {
    angle2_s <- get_angle(maj2_s)
    angle2_st <- get_angle(maj2_st)
    dat <- data.frame(
      angle = c(angle1_s, angle1_st, angle2_s, angle2_st),
      a = c(rss(maj1_s), rss(maj1_st), rss(maj2_s), rss(maj2_st)),
      b = c(rss(min1_s), rss(min1_st), rss(min2_s), rss(min2_st)),
      maj1 = c(maj1_s, maj1_st, maj2_s, maj2_st),
      min1 = c(min1_s, min1_st, min2_s, min2_st),
      model = rep(object$family$family, each = 2L),
      model_num  = rep(seq(1L, 2L), each = 2L),
      random_field = rep(c("spatial", "spatiotemporal"), 2L),
      stringsAsFactors = FALSE
    )
    dat$model <- factor(dat$model, levels = object$family$family)
    for (i in seq(1L, 2L)) {
      if (object$spatiotemporal[i] == "off") {
        x <- dat$random_field == "spatiotemporal" & dat$model_num == i
        dat <- dat[!x, , drop = FALSE]
      }
    }
    for (i in seq(1L, 2L)) {
      if (object$spatial[i] == "off") {
        x <- dat$random_field == "spatial" & dat$model_num == i
        dat <- dat[!x, , drop = FALSE]
      }
    }
  } else {
    dat <- data.frame(
      angle = c(angle1_s, angle1_st),
      a = c(rss(maj1_s), rss(maj1_st)),
      b = c(rss(min1_s), rss(min1_st)),
      maj1 = c(maj1_s, maj1_st),
      min1 = c(min1_s, min1_st),
      model = object$family$family,
      random_field = rep(c("spatial", "spatiotemporal"), 1L),
      stringsAsFactors = FALSE
    )
    if (object$spatiotemporal == "off") {
      x <- dat$random_field == "spatiotemporal"
      dat <- dat[!x, , drop = FALSE]
    }
    if (object$spatial == "off") {
      x <- dat$random_field == "spatial"
      dat <- dat[!x, , drop = FALSE]
    }
  }

  if (return_data) return(dat)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli_abort("ggplot2 must be installed to use this function.")
  }
  if (!requireNamespace("ggforce", quietly = TRUE)) {
    cli_abort("ggforce must be installed to use this function.")
  }
  g <- ggplot2::ggplot(dat,
    ggplot2::aes(
      x0 = 0, y0 = 0,
      a = .data$a, b = .data$b,
      angle = .data$angle,
      colour = `if`(delta, .data$model, NULL),
      linetype = .data$random_field
    )
  ) +
    ggforce::geom_ellipse() +
    ggplot2::coord_fixed() +
    ggplot2::labs(linetype = "Random field", colour = "Model",
      x = object$spde$xy_cols[1], y = object$spde$xy_cols[2]) +
    ggplot2::scale_colour_brewer(palette = "Dark2")
  g
}

#' @export
#' @rdname plot_anisotropy
plot_anisotropy2 <- function(object, model = 1) {
  stopifnot(inherits(object, "gllvmTMB"))
  if (!check_for_H(object)) return(NULL)
  report <- object$tmb_obj$report(object$tmb_obj$env$last.par.best)
  if (model == 1) eig <- eigen(report$H)
  if (model == 2) eig <- eigen(report$H2)
  dat <- data.frame(
    x0 = c(0, 0),
    y0 = c(0, 0),
    x1 = eig$vectors[1, , drop = TRUE] * eig$values,
    y1 = eig$vectors[2, , drop = TRUE] * eig$values
  )
  plot(0,
    xlim = range(c(dat$x0, dat$x1)),
    ylim = range(c(dat$y0, dat$y1)),
    type = "n", asp = 1, xlab = "", ylab = ""
  )
  graphics::arrows(dat$x0, dat$y0, dat$x1, dat$y1)
  invisible(list(eig = eig, dat = dat, H = report$H))
}

# Calculate anisotropic eigenvectors and ranges for a given model
# Returns list with: eig, range_s, range_st, maj_s, min_s, maj_st, min_st
calculate_anisotropy_components <- function(x, m = 1L) {
  # Get report and extract H matrices
  report <- x$tmb_obj$report(x$tmb_obj$env$last.par.best)
  delta <- isTRUE(x$family$delta)

  # Extract range values from sd_report
  est_rep <- as.list(x$sd_report, "Estimate", report = TRUE)
  range_values <- as.numeric(est_rep$range[, m])
  range_s <- range_values[1]
  range_st <- if (length(range_values) > 1) range_values[2] else range_values[1]

  # Get eigenvalues/vectors from H matrix (or H2 for delta model 2)
  H <- if (delta && m == 2) report$H2 else report$H
  eig <- eigen(H)

  # Calculate major and minor axis vectors for spatial field
  maj_s <- eig$vectors[, 1, drop = TRUE] * eig$values[1] * range_s
  min_s <- eig$vectors[, 2, drop = TRUE] * eig$values[2] * range_s

  # Calculate major and minor axis vectors for spatiotemporal field
  maj_st <- eig$vectors[, 1, drop = TRUE] * eig$values[1] * range_st
  min_st <- eig$vectors[, 2, drop = TRUE] * eig$values[2] * range_st

  list(
    eig = eig,
    range_s = range_s,
    range_st = range_st,
    maj_s = maj_s,
    min_s = min_s,
    maj_st = maj_st,
    min_st = min_st
  )
}

check_for_H <- function(obj) {
  H <- any(grepl(
    pattern = "ln_H_input",
    x = names(obj$sd_report$par.fixed),
    ignore.case = TRUE
  ))
  if (!H) {
    cli::cli_inform("`anisotropy = FALSE` in `sdmTMB()`; no anisotropy figure is available.")
    # FIXME in the future plot the isotropic covariance instead of NULL?
  }
  H
}
