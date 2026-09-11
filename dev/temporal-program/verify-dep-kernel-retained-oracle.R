## Independent retained-fixture oracle for temporal_dep() + kernel_indep().
##
## This is a diagnostic-only evaluation of the frozen positive-AR1 recovery
## fixture.  It recreates its direct DGP, but never calls production
## simulation.  With two measurements, the orthogonal replicate average and
## contrast separate the Gaussian likelihood exactly.  The labelled kernel's
## symmetric eigendecomposition then separates the average likelihood into
## one time-by-trait block per kernel eigenvalue.  Thus the full 7,680-row
## normal likelihood is evaluated as 80 independent 48-row blocks plus the
## independent contrasts, including its normalising constants.

.temporal_dep_kernel_retained_seeds <- 2609221:2609223

.temporal_dep_kernel_retained_truth <- function() {
  loading <- rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48))
  list(
    beta = c(.2, -.3, .1),
    temporal_loading = loading,
    kernel_sd = c(.35, .28, .40),
    residual = .30
  )
}

.temporal_dep_kernel_retained_kernel <- function(n_series = 80L) {
  series <- paste0("s", seq_len(n_series))
  coords <- cbind(seq_len(n_series) / n_series, sin(seq_len(n_series) * .7))
  raw <- exp(-as.matrix(stats::dist(coords)) / .16) + diag(.08, n_series)
  K <- raw / sqrt(outer(diag(raw), diag(raw)))
  dimnames(K) <- list(series, series)
  K
}

.temporal_dep_kernel_retained_fixture <- function(seed, phi = .6,
                                                   n_series = 80L,
                                                   n_time = 16L) {
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
    stop("seed must be one finite number", call. = FALSE)
  }
  if (!identical(as.numeric(phi), .6)) {
    stop("the retained diagnostic is restricted to the frozen positive phi = 0.6 stratum", call. = FALSE)
  }
  truth <- .temporal_dep_kernel_retained_truth()
  series <- paste0("s", seq_len(n_series))
  traits <- paste0("t", 1:3)
  K <- .temporal_dep_kernel_retained_kernel(n_series)

  set.seed(as.integer(seed))
  chol_time <- t(chol(tcrossprod(truth$temporal_loading)))
  chol_kernel <- t(chol(K))
  static <- chol_kernel %*% sweep(
    matrix(stats::rnorm(n_series * 3L), n_series, 3L), 2L, truth$kernel_sd, "*"
  )
  state <- array(0, c(n_series, n_time, 3L))
  for (g in seq_len(n_series)) {
    state[g, 1L, ] <- drop(chol_time %*% stats::rnorm(3L))
    for (tt in 2:n_time) {
      state[g, tt, ] <- phi * state[g, tt - 1L, ] +
        sqrt(1 - phi^2) * drop(chol_time %*% stats::rnorm(3L))
    }
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  g <- match(data$series, series)
  tt <- data$occasion
  j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt, j)] + static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = 2L), , drop = FALSE]
  data$measurement <- rep(c("m1", "m2"), times = nrow(data) / 2L)
  data$value <- data$mean_value + stats::rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  list(data = data, K = K, truth = truth, phi = phi, seed = as.integer(seed),
    series = series, traits = traits, n_time = n_time)
}

.temporal_dep_kernel_retained_helper <- function(name) {
  namespace <- asNamespace("gllvmTMB")
  if (!exists(name, envir = namespace, inherits = FALSE)) {
    stop(sprintf("gllvmTMB namespace does not contain %s", sQuote(name)), call. = FALSE)
  }
  getFromNamespace(name, "gllvmTMB")
}

.temporal_dep_kernel_retained_fit <- function(fixture) {
  temporal_dep <- .temporal_dep_kernel_retained_helper("temporal_dep")
  kernel_indep <- .temporal_dep_kernel_retained_helper("kernel_indep")
  suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fixture$K, name = "fixed_nonproportional_K"),
    data = fixture$data, unit = "series", cluster = "series",
    family = stats::gaussian(), silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14)),
      optimizer_passes = 2L
    )
  ))
}

.temporal_dep_kernel_retained_unpack <- function(theta, n_trait = 3L) {
  if (length(theta) != n_trait * (n_trait + 1L) / 2L) {
    stop("packed temporal loading vector has the wrong length", call. = FALSE)
  }
  loading <- matrix(0, n_trait, n_trait)
  cursor <- 1L
  for (column in seq_len(n_trait)) {
    loading[column, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) for (row in (column + 1L):n_trait) {
    loading[row, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  loading
}

.temporal_dep_kernel_retained_labels <- function(x) {
  occurrence <- ave(seq_along(x), names(x), FUN = seq_along)
  paste0(names(x), "[", occurrence, "]")
}

.temporal_dep_kernel_retained_relative_frobenius <- function(x, y) {
  sqrt(sum((x - y)^2)) / sqrt(sum(y^2))
}

.temporal_dep_kernel_retained_runtime <- function(frozen_elapsed_seconds,
                                                  rehydrated_elapsed_seconds) {
  values <- c(frozen = frozen_elapsed_seconds, rehydrated = rehydrated_elapsed_seconds)
  if (length(values) != 2L || any(!is.finite(values)) || any(values < 0)) {
    stop("frozen and rehydrated elapsed_seconds must be finite and nonnegative", call. = FALSE)
  }
  ## Runtime is retained as a receipt field, but it depends on host and process
  ## state.  It is deliberately never an equality criterion across runs.
  list(frozen_elapsed_seconds = unname(values[["frozen"]]),
    rehydrated_elapsed_seconds = unname(values[["rehydrated"]]), comparable = FALSE)
}

.temporal_dep_kernel_retained_parameter <- function(fit, fixed) {
  if (!is.numeric(fixed) || !identical(names(fixed), names(fit$opt$par))) {
    stop("fixed must be the complete named native outer parameter vector", call. = FALSE)
  }
  par <- fit$tmb_obj$env$parList(fixed)
  required <- c("b_fix", "theta_temporal_time", "theta_temporal_rr",
    "theta_rr_phy", "log_sigma_eps")
  if (!all(required %in% names(par))) {
    stop("native parameter list lacks a required retained-fixture block", call. = FALSE)
  }
  if (length(par$b_fix) != 3L || length(par$theta_temporal_time) != 1L ||
      length(par$theta_temporal_rr) != 6L || length(par$theta_rr_phy) < 3L ||
      length(par$log_sigma_eps) != 1L) {
    stop("native retained-fixture parameter blocks have unexpected dimensions", call. = FALSE)
  }
  par
}

.temporal_dep_kernel_retained_panel <- function(fixture) {
  d <- fixture$data
  required <- expand.grid(series = fixture$series, occasion = seq_len(fixture$n_time),
    trait = fixture$traits, measurement = c("m1", "m2"),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  key <- paste(d$series, d$occasion, d$trait, d$measurement, sep = "\r")
  requested <- paste(required$series, required$occasion, required$trait,
    required$measurement, sep = "\r")
  if (length(key) != length(unique(key)) || !setequal(key, requested)) {
    stop("retained fixture does not contain one complete labelled two-replicate panel", call. = FALSE)
  }
  y <- d$value[match(requested, key)]
  array(y, dim = c(length(fixture$series), fixture$n_time, length(fixture$traits), 2L),
    dimnames = list(series = fixture$series, time = as.character(seq_len(fixture$n_time)),
      trait = fixture$traits, measurement = c("m1", "m2")))
}

.temporal_dep_kernel_retained_block_nll <- function(fit, fixed, fixture,
                                                    product_control = FALSE) {
  par <- .temporal_dep_kernel_retained_parameter(fit, fixed)
  panel <- .temporal_dep_kernel_retained_panel(fixture)
  n_series <- dim(panel)[[1L]]
  n_time <- dim(panel)[[2L]]
  n_trait <- dim(panel)[[3L]]
  ## `array(series, time, trait, measurement)` is column-major: after the
  ## series coordinate, time varies before trait.  The same ordering is used
  ## in every 48-dimensional block below.
  variable_time <- rep(seq_len(n_time), times = n_trait)
  variable_trait <- rep(seq_len(n_trait), each = n_time)
  residual_sd <- exp(par$log_sigma_eps[[1L]])
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time[[1L]])
  Sigma_time <- tcrossprod(.temporal_dep_kernel_retained_unpack(
    par$theta_temporal_rr, n_trait
  ))
  ## `theta_rr_phy` retains mapped structural zeros after the three free
  ## diagonal source coordinates.  Only its leading trait-diagonal entries
  ## belong to this indep kernel cell.
  kernel_variance <- par$theta_rr_phy[seq_len(n_trait)]^2
  K <- fixture$K
  eig <- eigen(K, symmetric = TRUE)
  if (!identical(rownames(K), fixture$series) || !identical(colnames(K), fixture$series)) {
    stop("labelled kernel does not match the retained series labels", call. = FALSE)
  }

  average <- (panel[, , , 1L] + panel[, , , 2L]) / sqrt(2)
  contrast <- (panel[, , , 1L] - panel[, , , 2L]) / sqrt(2)
  ## Columns use the stated (time, trait) ordering.  Rotation by the labelled
  ## kernel eigenvectors leaves the full normalising constant unchanged.
  average_matrix <- matrix(aperm(average, c(1L, 2L, 3L)), nrow = n_series,
    ncol = n_time * n_trait)
  contrast_matrix <- matrix(aperm(contrast, c(1L, 2L, 3L)), nrow = n_series,
    ncol = n_time * n_trait)
  average_rotated <- crossprod(eig$vectors, average_matrix)
  mean_average_matrix <- matrix(
    rep(rep(sqrt(2) * par$b_fix, each = n_time), each = n_series),
    nrow = n_series, ncol = n_time * n_trait
  )
  mean_average <- crossprod(eig$vectors, mean_average_matrix)
  temporal_block <- phi^abs(outer(variable_time, variable_time, "-")) *
    Sigma_time[variable_trait, variable_trait]
  ## The labelled kernel is a static source effect.  Its trait-specific value
  ## persists across every occasion, so its block is J_time within trait, not
  ## an IID time diagonal.
  kernel_static <- outer(variable_trait, variable_trait, "==") *
    matrix(kernel_variance[variable_trait], nrow = n_time * n_trait,
      ncol = n_time * n_trait)

  nll_average <- 0
  for (block in seq_len(n_series)) {
    if (isTRUE(product_control)) {
      ## Deliberately wrong.  It suppresses the additive source field and
      ## turns the specified covariance into a source-by-time product field.
      V <- 2 * eig$values[[block]] * temporal_block + residual_sd^2 * diag(n_time * n_trait)
    } else {
      V <- 2 * temporal_block + 2 * eig$values[[block]] * kernel_static +
        residual_sd^2 * diag(n_time * n_trait)
    }
    L <- chol(V)
    z <- average_rotated[block, ] - mean_average[block, ]
    nll_average <- nll_average + .5 * (length(z) * log(2 * pi) +
      2 * sum(log(diag(L))) + sum(backsolve(L, z, transpose = TRUE)^2))
  }
  contrast_values <- as.numeric(contrast_matrix)
  nll_contrast <- .5 * (length(contrast_values) * log(2 * pi * residual_sd^2) +
    sum(contrast_values^2) / residual_sd^2)
  nll_average + nll_contrast
}

.temporal_dep_kernel_retained_literal_dense_nll <- function(fit, fixed, fixture,
                                                            product_control = FALSE) {
  ## Small-fixture implementation only.  This intentionally materialises the
  ## covariance as a separate audit of the block factorisation above.
  par <- .temporal_dep_kernel_retained_parameter(fit, fixed)
  if (nrow(fixture$data) > 600L) {
    stop("literal dense oracle is restricted to the small fixture", call. = FALSE)
  }
  d <- fixture$data
  source <- match(d$series, fixture$series)
  time <- d$occasion
  trait <- match(d$trait, fixture$traits)
  same_series <- outer(source, source, "==")
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time[[1L]])
  Sigma_time <- tcrossprod(.temporal_dep_kernel_retained_unpack(par$theta_temporal_rr))
  kernel_variance <- par$theta_rr_phy[seq_len(length(fixture$traits))]^2
  temporal <- phi^abs(outer(time, time, "-")) * same_series * Sigma_time[trait, trait]
  if (isTRUE(product_control)) {
    V <- phi^abs(outer(time, time, "-")) * fixture$K[source, source] *
      Sigma_time[trait, trait]
  } else {
    V <- temporal + fixture$K[source, source] * outer(trait, trait, "==") *
      matrix(kernel_variance[trait], nrow = length(trait), ncol = length(trait))
  }
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- d$value - par$b_fix[trait]
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_dep_kernel_retained_central_gradient <- function(fit, fixed, fixture,
                                                           step = 1e-5) {
  if (!is.numeric(step) || length(step) != 1L || !is.finite(step) || step <= 0) {
    stop("step must be one finite positive number", call. = FALSE)
  }
  out <- numeric(length(fixed))
  for (i in seq_along(fixed)) {
    h <- step * max(1, abs(fixed[[i]]))
    plus <- minus <- fixed
    plus[[i]] <- plus[[i]] + h
    minus[[i]] <- minus[[i]] - h
    out[[i]] <- (.temporal_dep_kernel_retained_block_nll(fit, plus, fixture) -
      .temporal_dep_kernel_retained_block_nll(fit, minus, fixture)) / (2 * h)
  }
  stats::setNames(out, .temporal_dep_kernel_retained_labels(fixed))
}

.temporal_dep_kernel_retained_points <- function(fit) {
  fitted <- fit$opt$par
  kernel <- which(names(fitted) == "theta_rr_phy")
  if (length(kernel) != 3L) stop("expected three free kernel coordinates", call. = FALSE)
  points <- list(fitted = fitted)
  for (j in 1:2) {
    point <- fitted
    point[[kernel[[j]]]] <- point[[kernel[[j]]]] + .075
    points[[paste0("kernel_", j, "_plus_0.075")]] <- point
  }
  points
}

.temporal_dep_kernel_retained_receipt <- function(fit, fixture, receipt_path,
                                                  rehydrated_elapsed_seconds) {
  if (!file.exists(receipt_path)) stop("frozen receipt CSV is missing", call. = FALSE)
  receipt <- utils::read.csv(receipt_path, stringsAsFactors = FALSE)
  required <- c("phi", "seed", "terminal", "convergence", "pass_1_convergence",
    "pass_2_convergence", "pass_2_accepted", "max_gradient", "objective",
    "hessian_status", "phi_estimate", "temporal_frobenius_relative_error",
    "kernel_1", "kernel_2", "kernel_3", "beta_1", "beta_2", "beta_3",
    "kernel_relative_error_1", "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error", "elapsed_seconds")
  if (!all(required %in% names(receipt))) stop("frozen receipt has an invalid schema", call. = FALSE)
  row <- receipt[receipt$phi == fixture$phi & receipt$seed == fixture$seed, required, drop = FALSE]
  if (nrow(row) != 1L) stop("frozen receipt does not contain the requested phi/seed", call. = FALSE)
  history <- fit$optimizer_pass_history
  if (!is.data.frame(history) || nrow(history) != 2L) {
    stop("native fit did not retain exactly two requested optimizer passes", call. = FALSE)
  }
  par <- .temporal_dep_kernel_retained_parameter(fit, fit$opt$par)
  temporal <- getFromNamespace("extract_temporal", "gllvmTMB")(fit)
  temporal_covariance <- tcrossprod(as.matrix(temporal$loading))
  hessian <- tryCatch(fit$tmb_obj$he(fit$opt$par), error = function(e) e)
  hessian_status <- if (inherits(hessian, "error")) "error" else if (
    all(is.finite(hessian)) && !inherits(try(chol(hessian), silent = TRUE), "try-error")
  ) "positive_definite" else "non_positive_definite"
  kernel <- par$theta_rr_phy[seq_len(3L)]^2
  beta <- as.numeric(par$b_fix)
  observed <- data.frame(
    phi = fixture$phi, seed = fixture$seed, terminal = "success",
    convergence = fit$opt$convergence, pass_1_convergence = history$convergence[[1L]],
    pass_2_convergence = history$convergence[[2L]], pass_2_accepted = history$accepted[[2L]],
    max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), objective = fit$opt$objective,
    hessian_status = hessian_status,
    phi_estimate = (1 - 1e-6) * tanh(par$theta_temporal_time[[1L]]),
    temporal_frobenius_relative_error = .temporal_dep_kernel_retained_relative_frobenius(
      temporal_covariance, fixture$truth$temporal_loading %*% t(fixture$truth$temporal_loading)
    ),
    kernel_1 = kernel[[1L]], kernel_2 = kernel[[2L]], kernel_3 = kernel[[3L]],
    beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]],
    kernel_relative_error_1 = abs(kernel[[1L]] - fixture$truth$kernel_sd[[1L]]^2) /
      fixture$truth$kernel_sd[[1L]]^2,
    kernel_relative_error_2 = abs(kernel[[2L]] - fixture$truth$kernel_sd[[2L]]^2) /
      fixture$truth$kernel_sd[[2L]]^2,
    kernel_relative_error_3 = abs(kernel[[3L]] - fixture$truth$kernel_sd[[3L]]^2) /
      fixture$truth$kernel_sd[[3L]]^2,
    phi_absolute_error = abs((1 - 1e-6) * tanh(par$theta_temporal_time[[1L]]) - fixture$phi),
    fixed_effect_mean_absolute_error = mean(abs(beta - fixture$truth$beta)),
    elapsed_seconds = rehydrated_elapsed_seconds,
    stringsAsFactors = FALSE
  )
  exact <- c("phi", "seed", "terminal", "convergence", "pass_1_convergence",
    "pass_2_convergence", "pass_2_accepted", "hessian_status")
  numeric <- setdiff(required, c(exact, "elapsed_seconds"))
  if (!identical(as.character(unlist(observed[exact], use.names = FALSE)),
      as.character(unlist(row[exact], use.names = FALSE))) ||
      any(abs(as.numeric(observed[numeric]) - as.numeric(row[numeric])) > 2e-5)) {
    stop("rehydrated native fit disagrees with the frozen receipt", call. = FALSE)
  }
  list(expected = row, observed = observed,
    runtime = .temporal_dep_kernel_retained_runtime(
      row$elapsed_seconds[[1L]], observed$elapsed_seconds[[1L]]
    ))
}

temporal_dep_kernel_retained_oracle <- function(seed = 2609221L,
                                                receipt_path = file.path(
                                                  "dev", "temporal-program", "results",
                                                  "dep-kernel-recovery-20260911.csv"
                                                ),
                                                n_series = 80L, n_time = 16L,
                                                step = 1e-5) {
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      as.integer(seed) != seed || !(as.integer(seed) %in% .temporal_dep_kernel_retained_seeds)) {
    stop("the retained oracle accepts exactly frozen seeds 2609221:2609223", call. = FALSE)
  }
  started <- proc.time()[["elapsed"]]
  fixture <- .temporal_dep_kernel_retained_fixture(seed = seed, n_series = n_series,
    n_time = n_time)
  fit <- .temporal_dep_kernel_retained_fit(fixture)
  rehydrated_elapsed_seconds <- proc.time()[["elapsed"]] - started
  receipt <- if (n_series == 80L && n_time == 16L) {
    .temporal_dep_kernel_retained_receipt(fit, fixture, receipt_path,
      rehydrated_elapsed_seconds = rehydrated_elapsed_seconds)
  } else NULL
  points <- .temporal_dep_kernel_retained_points(fit)
  records <- lapply(names(points), function(label) {
    fixed <- points[[label]]
    native_nll <- as.numeric(fit$tmb_obj$fn(fixed))
    block_nll <- .temporal_dep_kernel_retained_block_nll(fit, fixed, fixture)
    native_gradient <- fit$tmb_obj$gr(fixed)
    dense_gradient <- .temporal_dep_kernel_retained_central_gradient(fit, fixed, fixture,
      step = step)
    names(native_gradient) <- names(dense_gradient)
    list(point = label, fixed = fixed, labels = names(dense_gradient),
      native_nll = native_nll, block_nll = block_nll,
      nll_error = abs(native_nll - block_nll), native_gradient = native_gradient,
      block_gradient = dense_gradient,
      gradient_error = abs(native_gradient - dense_gradient))
  })
  names(records) <- names(points)
  list(
    schema_version = "temporal-dep-kernel-retained-oracle-v1",
    seed = as.integer(seed), phi = fixture$phi, n_series = n_series, n_time = n_time,
    n_observation = nrow(fixture$data), fit = fit, fixture = fixture,
    receipt = receipt, outer_parameter = fit$opt$par, records = records,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    contract = paste("Independent retained-fixture additive likelihood diagnostic only;",
      "no optimiser intervention, recovery, or calibration claim.")
  )
}

.temporal_dep_kernel_retained_oracle_table <- function(report) {
  do.call(rbind, lapply(report$records, function(x) {
    data.frame(schema_version = report$schema_version, seed = report$seed,
      phi = report$phi, point = x$point, kind = "nll", coordinate = NA_character_,
      native = x$native_nll, oracle = x$block_nll, absolute_error = x$nll_error,
      elapsed_seconds = report$elapsed_seconds, stringsAsFactors = FALSE)
  })) -> nll
  gradient <- do.call(rbind, lapply(report$records, function(x) {
    data.frame(schema_version = report$schema_version, seed = report$seed,
      phi = report$phi, point = x$point, kind = "gradient", coordinate = x$labels,
      native = unname(x$native_gradient), oracle = unname(x$block_gradient),
      absolute_error = unname(x$gradient_error), elapsed_seconds = report$elapsed_seconds,
      stringsAsFactors = FALSE)
  }))
  rbind(nll, gradient)
}

.temporal_dep_kernel_retained_cli <- function(args) {
  one <- sub("^--one=", "", args[grepl("^--one=", args)])
  csv <- sub("^--csv=", "", args[grepl("^--csv=", args)])
  rds <- sub("^--rds=", "", args[grepl("^--rds=", args)])
  known <- c(paste0("--one=", one), paste0("--csv=", csv), paste0("--rds=", rds))
  if (length(one) != 1L || length(csv) != 1L || length(rds) != 1L ||
      length(args) != length(known) || any(!args %in% known) ||
      !grepl("dep-kernel-retained-oracle-v1", basename(csv), fixed = TRUE) ||
      !grepl("dep-kernel-retained-oracle-v1", basename(rds), fixed = TRUE)) {
    stop(paste("usage: Rscript --vanilla verify-dep-kernel-retained-oracle.R",
      "--one=SEED --csv=PATH/dep-kernel-retained-oracle-v1.csv",
      "--rds=PATH/dep-kernel-retained-oracle-v1.rds"), call. = FALSE)
  }
  if (!grepl("^[0-9]+$", one) || !(as.integer(one) %in% .temporal_dep_kernel_retained_seeds) ||
      file.exists(csv) || file.exists(rds)) {
    stop("--one must be one frozen seed (2609221:2609223) and output paths must be new files", call. = FALSE)
  }
  list(seed = as.integer(one), csv = csv, rds = rds)
}

.temporal_dep_kernel_retained_write_pair <- function(table, report, csv, rds) {
  if (!is.data.frame(table) || !is.list(report) ||
      !is.character(report$schema_version) || length(report$schema_version) != 1L) {
    stop("paired output requires a data-frame table and a versioned report", call. = FALSE)
  }
  if (file.exists(csv) || file.exists(rds) || !dir.exists(dirname(csv)) ||
      !dir.exists(dirname(rds))) {
    stop("paired output paths must be new files in existing directories", call. = FALSE)
  }
  csv_tmp <- tempfile(paste0(".", basename(csv), ".tmp-"), tmpdir = dirname(csv))
  rds_tmp <- tempfile(paste0(".", basename(rds), ".tmp-"), tmpdir = dirname(rds))
  csv_committed <- FALSE
  rds_committed <- FALSE
  on.exit({
    unlink(c(csv_tmp, rds_tmp), force = TRUE)
    if (csv_committed && !rds_committed) unlink(csv, force = TRUE)
  }, add = TRUE)
  utils::write.csv(table, csv_tmp, row.names = FALSE)
  saveRDS(report, rds_tmp)
  csv_check <- utils::read.csv(csv_tmp, stringsAsFactors = FALSE)
  rds_check <- readRDS(rds_tmp)
  if (!identical(names(csv_check), names(table)) || nrow(csv_check) != nrow(table) ||
      !is.list(rds_check) || !identical(rds_check$schema_version, report$schema_version)) {
    stop("temporary paired output validation failed", call. = FALSE)
  }
  ## A two-file commit cannot be one filesystem rename.  The second failure
  ## removes the first committed file, so this helper leaves no partial pair.
  if (file.exists(csv) || file.exists(rds) || !file.rename(csv_tmp, csv)) {
    stop("could not commit CSV output without overwrite", call. = FALSE)
  }
  csv_committed <- TRUE
  if (file.exists(rds) || !file.rename(rds_tmp, rds)) {
    stop("could not commit RDS output; removed the incomplete paired output", call. = FALSE)
  }
  rds_committed <- TRUE
  invisible(c(csv = csv, rds = rds))
}

if (sys.nframe() == 0L) {
  namespace <- asNamespace("gllvmTMB")
  if (!all(vapply(c("temporal_dep", "kernel_indep"), exists, logical(1),
      envir = namespace, inherits = FALSE))) {
    pkgload::load_all(normalizePath(".", mustWork = TRUE), quiet = TRUE,
      export_all = FALSE)
  }
  options <- .temporal_dep_kernel_retained_cli(commandArgs(trailingOnly = TRUE))
  report <- temporal_dep_kernel_retained_oracle(seed = options$seed)
  table <- .temporal_dep_kernel_retained_oracle_table(report)
  .temporal_dep_kernel_retained_write_pair(table, report, options$csv, options$rds)
  print(table, row.names = FALSE)
  cat(sprintf("TEMPORAL_DEP_KERNEL_RETAINED_ORACLE_COMPLETE elapsed_seconds=%.3f\n",
    report$elapsed_seconds))
}
