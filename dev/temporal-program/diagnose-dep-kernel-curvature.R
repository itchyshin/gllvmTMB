## Independent small-fixture curvature diagnostic for temporal_dep() + kernel_indep().
##
## This script deliberately does not fit a model or call package simulation.  It
## reconstructs the frozen campaign's additive Gaussian data-generating model at
## a smaller dimension, then examines the normalized dense marginal likelihood
## on the transformed coordinates used by the model.  It is a diagnostic only:
## its output establishes neither recovery, calibration, nor a numerical remedy.

.temporal_dep_kernel_curvature_truth <- function() {
  loading <- rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48))
  list(
    beta = c(.2, -.3, .1),
    temporal_loading = loading,
    kernel_sd = c(.35, .28, .40),
    residual = .30
  )
}

.temporal_dep_kernel_curvature_pack <- function(loading) {
  c(diag(loading), loading[2L, 1L], loading[3L, 1L], loading[3L, 2L])
}

.temporal_dep_kernel_curvature_unpack <- function(theta) {
  if (length(theta) != 6L) stop("temporal loading coordinate must have length six", call. = FALSE)
  loading <- matrix(0, 3L, 3L)
  diag(loading) <- theta[seq_len(3L)]
  loading[2L, 1L] <- theta[[4L]]
  loading[3L, 1L] <- theta[[5L]]
  loading[3L, 2L] <- theta[[6L]]
  loading
}

.temporal_dep_kernel_curvature_fixture <- function(seed = 2609221L,
                                                    n_series = 6L,
                                                    n_time = 5L,
                                                    n_measurement = 2L) {
  stopifnot(length(seed) == 1L, n_series >= 3L, n_time >= 3L, n_measurement >= 2L)
  truth <- .temporal_dep_kernel_curvature_truth()
  set.seed(seed)
  series <- paste0("s", seq_len(n_series))
  traits <- paste0("t", 1:3)
  coords <- cbind(seq_len(n_series) / n_series, sin(seq_len(n_series) * .7))
  K_raw <- exp(-as.matrix(stats::dist(coords)) / .16) + diag(.08, n_series)
  K <- K_raw / sqrt(outer(diag(K_raw), diag(K_raw)))
  dimnames(K) <- list(series, series)

  temporal_chol <- t(chol(tcrossprod(truth$temporal_loading)))
  kernel_chol <- t(chol(K))
  static <- kernel_chol %*% sweep(matrix(stats::rnorm(n_series * 3L), n_series, 3L),
    2L, truth$kernel_sd, "*")
  phi <- .6
  state <- array(0, c(n_series, n_time, 3L))
  for (g in seq_len(n_series)) {
    state[g, 1L, ] <- drop(temporal_chol %*% stats::rnorm(3L))
    for (tt in 2:n_time) {
      state[g, tt, ] <- phi * state[g, tt - 1L, ] +
        sqrt(1 - phi^2) * drop(temporal_chol %*% stats::rnorm(3L))
    }
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  g <- match(data$series, series)
  tt <- data$occasion
  j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt, j)] + static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = n_measurement), , drop = FALSE]
  data$measurement <- rep(paste0("m", seq_len(n_measurement)), times = nrow(data) / n_measurement)
  data$value <- data$mean_value + stats::rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  list(data = data, K = K, truth = truth, phi = phi)
}

.temporal_dep_kernel_curvature_coordinates <- function(fixture) {
  truth <- fixture$truth
  c(
    setNames(log(truth$kernel_sd^2), paste0("log_kernel_variance_", 1:3)),
    theta_temporal_time = atanh(fixture$phi / (1 - 1e-6)),
    setNames(.temporal_dep_kernel_curvature_pack(truth$temporal_loading),
      paste0("theta_temporal_rr_", 1:6))
  )
}

.temporal_dep_kernel_curvature_covariance <- function(theta, fixture, product = FALSE) {
  if (!identical(names(theta), names(.temporal_dep_kernel_curvature_coordinates(fixture)))) {
    stop("theta must use the documented transformed-coordinate names", call. = FALSE)
  }
  data <- fixture$data
  source <- match(data$series, rownames(fixture$K))
  trait <- match(data$trait, paste0("t", 1:3))
  same_series <- outer(data$series, data$series, `==`)
  lag <- abs(outer(data$occasion, data$occasion, `-`))
  phi <- (1 - 1e-6) * tanh(theta[["theta_temporal_time"]])
  temporal_correlation <- phi^lag
  temporal_correlation[!same_series] <- 0
  temporal_covariance <- tcrossprod(.temporal_dep_kernel_curvature_unpack(
    theta[paste0("theta_temporal_rr_", 1:6)]
  ))
  kernel_variance <- exp(theta[paste0("log_kernel_variance_", 1:3)])
  same_trait <- outer(trait, trait, `==`)
  trait_variance <- matrix(kernel_variance[trait], nrow = length(trait), ncol = length(trait))
  if (product) {
    ## Deliberately wrong: it makes time a kernel-weighted field across series
    ## instead of adding a within-series temporal field to a static kernel field.
    V <- (phi^lag) * fixture$K[source, source] * temporal_covariance[trait, trait]
  } else {
    V <- temporal_correlation * temporal_covariance[trait, trait] +
      fixture$K[source, source] * same_trait * trait_variance
  }
  diag(V) <- diag(V) + fixture$truth$residual^2
  V
}

.temporal_dep_kernel_curvature_nll <- function(theta, fixture, product = FALSE) {
  V <- .temporal_dep_kernel_curvature_covariance(theta, fixture, product = product)
  L <- chol(V)
  trait <- match(fixture$data$trait, paste0("t", 1:3))
  residual <- fixture$data$value - fixture$truth$beta[trait]
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_dep_kernel_curvature_central <- function(theta, fixture, step = 1e-4) {
  if (!is.numeric(step) || length(step) != 1L || !is.finite(step) || step <= 0) {
    stop("step must be one finite positive number", call. = FALSE)
  }
  p <- length(theta)
  value <- .temporal_dep_kernel_curvature_nll(theta, fixture)
  gradient <- setNames(numeric(p), names(theta))
  information <- matrix(NA_real_, p, p, dimnames = list(names(theta), names(theta)))
  for (i in seq_len(p)) {
    plus <- minus <- theta
    plus[[i]] <- plus[[i]] + step
    minus[[i]] <- minus[[i]] - step
    f_plus <- .temporal_dep_kernel_curvature_nll(plus, fixture)
    f_minus <- .temporal_dep_kernel_curvature_nll(minus, fixture)
    gradient[[i]] <- (f_plus - f_minus) / (2 * step)
    information[i, i] <- (f_plus - 2 * value + f_minus) / step^2
    if (i > 1L) for (j in seq_len(i - 1L)) {
      pp <- pm <- mp <- mm <- theta
      pp[[i]] <- pp[[i]] + step; pp[[j]] <- pp[[j]] + step
      pm[[i]] <- pm[[i]] + step; pm[[j]] <- pm[[j]] - step
      mp[[i]] <- mp[[i]] - step; mp[[j]] <- mp[[j]] + step
      mm[[i]] <- mm[[i]] - step; mm[[j]] <- mm[[j]] - step
      information[i, j] <- information[j, i] <-
        (.temporal_dep_kernel_curvature_nll(pp, fixture) -
          .temporal_dep_kernel_curvature_nll(pm, fixture) -
          .temporal_dep_kernel_curvature_nll(mp, fixture) +
          .temporal_dep_kernel_curvature_nll(mm, fixture)) / (4 * step^2)
    }
  }
  list(value = value, gradient = gradient, information = information)
}

.temporal_dep_kernel_curvature_expected_information <- function(theta, fixture, step = 1e-4) {
  V <- .temporal_dep_kernel_curvature_covariance(theta, fixture)
  V_inverse <- chol2inv(chol(V))
  derivative <- lapply(seq_along(theta), function(i) {
    plus <- minus <- theta
    plus[[i]] <- plus[[i]] + step
    minus[[i]] <- minus[[i]] - step
    (.temporal_dep_kernel_curvature_covariance(plus, fixture) -
      .temporal_dep_kernel_curvature_covariance(minus, fixture)) / (2 * step)
  })
  scaled <- lapply(derivative, function(x) V_inverse %*% x)
  information <- matrix(NA_real_, length(theta), length(theta),
    dimnames = list(names(theta), names(theta)))
  for (i in seq_along(theta)) for (j in seq_len(i)) {
    information[i, j] <- information[j, i] <- .5 * sum(scaled[[i]] * t(scaled[[j]]))
  }
  information
}

.temporal_dep_kernel_curvature_summary <- function(theta, fixture, step = 1e-4) {
  central <- .temporal_dep_kernel_curvature_central(theta, fixture, step = step)
  covariance <- .temporal_dep_kernel_curvature_covariance(theta, fixture)
  expected_information <- .temporal_dep_kernel_curvature_expected_information(theta, fixture, step = step)
  covariance_values <- eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
  information_values <- eigen(central$information, symmetric = TRUE, only.values = TRUE)$values
  singular_values <- svd(central$information, nu = 0L, nv = 0L)$d
  scale <- max(singular_values)
  information_condition <- if (scale == 0) Inf else scale / min(singular_values[singular_values > scale * .Machine$double.eps])
  information_positive_definite <- min(information_values) > scale * sqrt(.Machine$double.eps)
  expected_values <- eigen(expected_information, symmetric = TRUE, only.values = TRUE)$values
  expected_singular_values <- svd(expected_information, nu = 0L, nv = 0L)$d
  expected_scale <- max(expected_singular_values)
  expected_condition <- expected_scale / min(expected_singular_values[expected_singular_values > expected_scale * .Machine$double.eps])
  inverse_expected_information <- solve(expected_information)
  ## A sampled observed Hessian can be indefinite away from an MLE.  The
  ## standardized correlation is therefore from the numerical expected
  ## information of this same dense covariance, while retaining the observed
  ## central Hessian separately above.
  standardized_correlation <- inverse_expected_information /
    sqrt(outer(diag(inverse_expected_information), diag(inverse_expected_information)))
  off_diagonal <- standardized_correlation[row(standardized_correlation) != col(standardized_correlation)]
  list(
    nll = central$value,
    gradient = central$gradient,
    observed_information = central$information,
    covariance_eigenvalues = covariance_values,
    covariance_condition = max(covariance_values) / min(covariance_values),
    information_eigenvalues = information_values,
    information_condition = information_condition,
    information_positive_definite = information_positive_definite,
    expected_information = expected_information,
    expected_information_eigenvalues = expected_values,
    expected_information_condition = expected_condition,
    standardized_parameter_correlation = standardized_correlation,
    max_abs_standardized_parameter_correlation = if (all(is.na(off_diagonal))) NA_real_ else max(abs(off_diagonal)),
    wrong_product_nll = .temporal_dep_kernel_curvature_nll(theta, fixture, product = TRUE),
    wrong_product_nll_difference = abs(central$value - .temporal_dep_kernel_curvature_nll(theta, fixture, product = TRUE))
  )
}

temporal_dep_kernel_curvature_diagnostic <- function(seeds = 2609221:2609223,
                                                      n_series = 6L,
                                                      n_time = 5L,
                                                      step = 1e-4) {
  rows <- lapply(seeds, function(seed) {
    fixture <- .temporal_dep_kernel_curvature_fixture(seed = seed, n_series = n_series, n_time = n_time)
    theta <- .temporal_dep_kernel_curvature_coordinates(fixture)
    report <- .temporal_dep_kernel_curvature_summary(theta, fixture, step = step)
    data.frame(
      seed = as.integer(seed), phi = fixture$phi, n_observation = nrow(fixture$data),
      nll = report$nll, covariance_condition = report$covariance_condition,
      information_condition = report$information_condition,
      information_positive_definite = report$information_positive_definite,
      max_abs_gradient = max(abs(report$gradient)),
      max_abs_standardized_parameter_correlation = report$max_abs_standardized_parameter_correlation,
      wrong_product_nll_difference = report$wrong_product_nll_difference,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  output <- sub("^--output=", "", args[grepl("^--output=", args)])
  if (length(output) > 1L || (length(args) > 0L && length(output) == 0L)) {
    stop("usage: Rscript --vanilla diagnose-dep-kernel-curvature.R [--output=FILE]", call. = FALSE)
  }
  report <- temporal_dep_kernel_curvature_diagnostic()
  print(report, row.names = FALSE)
  if (length(output) == 1L) utils::write.csv(report, output, row.names = FALSE)
  cat("TEMPORAL_DEP_KERNEL_CURVATURE_DIAGNOSTIC_COMPLETE\n")
}
