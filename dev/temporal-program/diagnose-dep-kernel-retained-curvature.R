## Curvature diagnostic for the retained temporal_dep() + kernel_indep() panel.
##
## This file sources the independent retained-oracle DGP and block likelihood;
## it neither calls production simulation nor copies the production likelihood.
## It is diagnostic evidence only: finite calculations here neither alter the
## optimiser nor establish recovery, calibration, or an intervention.

.temporal_dep_kernel_retained_curvature_source <- function() {
  candidates <- c(
    file.path("dev", "temporal-program", "verify-dep-kernel-retained-oracle.R"),
    file.path("..", "dev", "temporal-program", "verify-dep-kernel-retained-oracle.R")
  )
  found <- candidates[file.exists(candidates)]
  if (!length(found)) {
    stop("cannot locate verify-dep-kernel-retained-oracle.R", call. = FALSE)
  }
  source_path <- found[[1L]]
  source(source_path, local = globalenv())
  invisible(normalizePath(source_path))
}

.temporal_dep_kernel_retained_curvature_require_oracle <- function() {
  required <- c(".temporal_dep_kernel_retained_seeds",
    ".temporal_dep_kernel_retained_fixture", ".temporal_dep_kernel_retained_fit",
    ".temporal_dep_kernel_retained_block_nll")
  missing <- required[!vapply(required, exists, logical(1), inherits = TRUE)]
  if (length(missing)) {
    stop("source the retained oracle before the curvature diagnostic: ",
      paste(missing, collapse = ", "), call. = FALSE)
  }
}

.temporal_dep_kernel_retained_curvature_seed <- function(seed) {
  .temporal_dep_kernel_retained_curvature_require_oracle()
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      as.integer(seed) != seed || !(as.integer(seed) %in% .temporal_dep_kernel_retained_seeds)) {
    stop("curvature diagnostic accepts exactly frozen seeds 2609221:2609223", call. = FALSE)
  }
  as.integer(seed)
}

.temporal_dep_kernel_retained_curvature_truth_point <- function(fit, fixture) {
  fixed <- fit$opt$par
  truth <- fixture$truth
  fixed[which(names(fixed) == "b_fix")] <- truth$beta
  fixed[which(names(fixed) == "theta_temporal_time")] <- atanh(fixture$phi / (1 - 1e-6))
  fixed[which(names(fixed) == "theta_temporal_rr")] <- c(
    diag(truth$temporal_loading), truth$temporal_loading[2L, 1L],
    truth$temporal_loading[3L, 1L], truth$temporal_loading[3L, 2L]
  )
  ## The frozen kernel model uses positive diagonal raw loading coordinates;
  ## these are the square roots of the requested variances.
  fixed[which(names(fixed) == "theta_rr_phy")] <- truth$kernel_sd
  fixed[which(names(fixed) == "log_sigma_eps")] <- log(truth$residual)
  fixed
}

.temporal_dep_kernel_retained_curvature_coordinates <- function(fit, fixed) {
  kernel <- which(names(fixed) == "theta_rr_phy")
  time <- which(names(fixed) == "theta_temporal_time")
  temporal <- which(names(fixed) == "theta_temporal_rr")
  if (length(kernel) != 3L || length(time) != 1L || length(temporal) != 6L) {
    stop("retained native vector has unexpected curvature-coordinate blocks", call. = FALSE)
  }
  values <- numeric(10L)
  names(values) <- c(paste0("kernel_", seq_along(kernel)), "theta_temporal_time",
    paste0("theta_temporal_rr_", seq_along(temporal)))
  kind <- rep("raw", length(values))
  native_index <- c(kernel, time, temporal)
  for (j in seq_along(kernel)) {
    q <- fixed[[kernel[[j]]]]
    if (identical(q, 0)) {
      values[[j]] <- q
      kind[[j]] <- "raw_q_at_zero"
    } else {
      values[[j]] <- log(q^2)
      kind[[j]] <- "log_variance"
    }
  }
  values[[4L]] <- fixed[[time]]
  values[5:10] <- fixed[temporal]
  list(values = values, kind = stats::setNames(kind, names(values)),
    native_index = stats::setNames(native_index, names(values)),
    kernel_index = kernel)
}

.temporal_dep_kernel_retained_curvature_native <- function(fixed, coordinates, x) {
  if (!identical(names(x), names(coordinates$values))) {
    stop("curvature coordinate names changed", call. = FALSE)
  }
  out <- fixed
  for (name in names(x)) {
    index <- coordinates$native_index[[name]]
    if (startsWith(name, "kernel_")) {
      kind <- coordinates$kind[[name]]
      if (identical(kind, "log_variance")) {
        q0 <- fixed[[index]]
        out[[index]] <- sign(q0) * exp(x[[name]] / 2)
      } else if (identical(kind, "raw_q_at_zero")) {
        out[[index]] <- x[[name]]
      } else {
        stop("unknown kernel curvature coordinate", call. = FALSE)
      }
    } else {
      out[[index]] <- x[[name]]
    }
  }
  out
}

.temporal_dep_kernel_retained_curvature_point <- function(fit, fixture, fixed,
                                                          point, step = 1e-4) {
  if (!is.character(point) || length(point) != 1L || !point %in% c("truth", "rehydrated")) {
    stop("point must be either truth or rehydrated", call. = FALSE)
  }
  if (!is.numeric(step) || length(step) != 1L || !is.finite(step) || step <= 0) {
    stop("step must be one finite positive number", call. = FALSE)
  }
  coordinates <- .temporal_dep_kernel_retained_curvature_coordinates(fit, fixed)
  x <- coordinates$values
  p <- length(x)
  evaluate <- function(value) {
    nll <- .temporal_dep_kernel_retained_block_nll(
      fit, .temporal_dep_kernel_retained_curvature_native(fixed, coordinates, value), fixture
    )
    if (!is.finite(nll)) stop("block likelihood is non-finite at a curvature evaluation", call. = FALSE)
    nll
  }
  value <- evaluate(x)
  h <- step * pmax(1, abs(x))
  gradient <- stats::setNames(numeric(p), names(x))
  information <- matrix(NA_real_, p, p, dimnames = list(names(x), names(x)))
  for (i in seq_len(p)) {
    plus <- minus <- x
    plus[[i]] <- plus[[i]] + h[[i]]
    minus[[i]] <- minus[[i]] - h[[i]]
    f_plus <- evaluate(plus)
    f_minus <- evaluate(minus)
    gradient[[i]] <- (f_plus - f_minus) / (2 * h[[i]])
    information[i, i] <- (f_plus - 2 * value + f_minus) / h[[i]]^2
    if (i > 1L) for (j in seq_len(i - 1L)) {
      pp <- pm <- mp <- mm <- x
      pp[[i]] <- pp[[i]] + h[[i]]; pp[[j]] <- pp[[j]] + h[[j]]
      pm[[i]] <- pm[[i]] + h[[i]]; pm[[j]] <- pm[[j]] - h[[j]]
      mp[[i]] <- mp[[i]] - h[[i]]; mp[[j]] <- mp[[j]] + h[[j]]
      mm[[i]] <- mm[[i]] - h[[i]]; mm[[j]] <- mm[[j]] - h[[j]]
      information[i, j] <- information[j, i] <-
        (evaluate(pp) - evaluate(pm) - evaluate(mp) + evaluate(mm)) /
        (4 * h[[i]] * h[[j]])
    }
  }
  if (any(!is.finite(gradient)) || any(!is.finite(information))) {
    stop("curvature gradient or information is non-finite", call. = FALSE)
  }
  singular <- svd(information, nu = 0L, nv = 0L)$d
  condition <- if (!length(singular) || min(singular) == 0) Inf else max(singular) / min(singular)
  eigenvalue <- eigen(information, symmetric = TRUE, only.values = TRUE)$values
  positive_definite <- !inherits(try(chol(information), silent = TRUE), "try-error")
  parameter_correlation <- matrix(NA_real_, p, p, dimnames = dimnames(information))
  correlation_status <- "unavailable_observed_information_not_positive_definite"
  if (positive_definite) {
    covariance <- chol2inv(chol(information))
    parameter_correlation <- covariance / sqrt(outer(diag(covariance), diag(covariance)))
    dimnames(parameter_correlation) <- dimnames(information)
    correlation_status <- "observed_information_inverse"
  }
  list(point = point, nll = value, coordinate = x, coordinate_kind = coordinates$kind,
    gradient = gradient, observed_information = information,
    curvature = stats::setNames(diag(information), names(x)),
    information_eigenvalues = eigenvalue, information_singular_values = singular,
    information_condition = condition, information_positive_definite = positive_definite,
    parameter_correlation = parameter_correlation, correlation_status = correlation_status)
}

.temporal_dep_kernel_retained_curvature_one <- function(seed, n_series = 80L,
                                                        n_time = 16L, step = 1e-4,
                                                        receipt_path = file.path(
                                                          "dev", "temporal-program", "results",
                                                          "dep-kernel-recovery-20260911.csv"
                                                        )) {
  seed <- .temporal_dep_kernel_retained_curvature_seed(seed)
  started <- proc.time()[["elapsed"]]
  fixture <- .temporal_dep_kernel_retained_fixture(seed, n_series = n_series, n_time = n_time)
  fit <- .temporal_dep_kernel_retained_fit(fixture)
  rehydrated_elapsed_seconds <- proc.time()[["elapsed"]] - started
  ## Small fixtures exist solely to exercise the independently sourced block
  ## calculation.  Every retained 80 x 16 point must reproduce the frozen
  ## receipt before its curvature is retained.
  receipt <- if (n_series == 80L && n_time == 16L) {
    .temporal_dep_kernel_retained_receipt(fit, fixture, receipt_path,
      rehydrated_elapsed_seconds = rehydrated_elapsed_seconds)
  } else NULL
  truth <- .temporal_dep_kernel_retained_curvature_truth_point(fit, fixture)
  list(seed = seed, truth = .temporal_dep_kernel_retained_curvature_point(
    fit, fixture, truth, "truth", step = step
  ), rehydrated = .temporal_dep_kernel_retained_curvature_point(
    fit, fixture, fit$opt$par, "rehydrated", step = step
  ), receipt = receipt, rehydrated_elapsed_seconds = rehydrated_elapsed_seconds)
}

temporal_dep_kernel_retained_curvature <- function(seeds = .temporal_dep_kernel_retained_seeds,
                                                   n_series = 80L, n_time = 16L,
                                                   step = 1e-4,
                                                   receipt_path = file.path(
                                                     "dev", "temporal-program", "results",
                                                     "dep-kernel-recovery-20260911.csv"
                                                   )) {
  .temporal_dep_kernel_retained_curvature_require_oracle()
  if (!identical(as.integer(seeds), as.integer(.temporal_dep_kernel_retained_seeds))) {
    stop("curvature diagnostic requires exactly frozen seeds 2609221:2609223", call. = FALSE)
  }
  if (!identical(as.integer(n_series), 80L) || !identical(as.integer(n_time), 16L)) {
    stop("public retained curvature requires n_series = 80L and n_time = 16L", call. = FALSE)
  }
  reports <- lapply(as.integer(seeds), .temporal_dep_kernel_retained_curvature_one,
    n_series = n_series, n_time = n_time, step = step, receipt_path = receipt_path)
  names(reports) <- as.character(seeds)
  list(schema_version = "temporal-dep-kernel-retained-curvature-v1",
    seed = as.integer(seeds), n_series = n_series, n_time = n_time,
    reports = reports,
    contract = paste("Curvature/conditioning diagnostic only; no optimiser intervention,",
      "recovery, calibration, or numerical-remedy claim."))
}

.temporal_dep_kernel_retained_curvature_output_identity <- function(report) {
  required <- c("schema_version", "seed", "n_series", "n_time", "n_observation",
    "receipt_identity", "report")
  if (!is.list(report) || !all(required %in% names(report)) ||
      !identical(report$schema_version, "temporal-dep-kernel-retained-curvature-v1") ||
      !identical(as.integer(report$n_series), 80L) || !identical(as.integer(report$n_time), 16L) ||
      !identical(as.integer(report$n_observation), 7680L)) {
    stop("curvature output must record the exact retained 80 x 16 x 3 x 2 dimensions", call. = FALSE)
  }
  seed <- .temporal_dep_kernel_retained_curvature_seed(report$seed)
  one <- report$report
  if (!is.list(one) || !identical(as.integer(one$seed), seed) || is.null(one$receipt) ||
      !is.list(one$receipt) || is.null(one$receipt$expected) || is.null(one$receipt$observed)) {
    stop("curvature output lacks the required rehydrated receipt identity", call. = FALSE)
  }
  expected <- one$receipt$expected
  observed <- one$receipt$observed
  identity_fields <- c("seed", "phi", "terminal")
  if (!is.data.frame(expected) || !is.data.frame(observed) || nrow(expected) != 1L ||
      nrow(observed) != 1L || !all(identity_fields %in% names(expected)) ||
      !all(identity_fields %in% names(observed)) ||
      !identical(as.integer(expected$seed[[1L]]), seed) ||
      !identical(as.integer(observed$seed[[1L]]), seed) ||
      !identical(as.character(expected$phi[[1L]]), as.character(observed$phi[[1L]])) ||
      !identical(as.character(expected$terminal[[1L]]), as.character(observed$terminal[[1L]]))) {
    stop("curvature output receipt identity disagrees with its frozen seed", call. = FALSE)
  }
  identity <- list(seed = seed, frozen_seed = as.integer(expected$seed[[1L]]),
    rehydrated_seed = as.integer(observed$seed[[1L]]),
    frozen_phi = as.numeric(expected$phi[[1L]]),
    rehydrated_phi = as.numeric(observed$phi[[1L]]),
    terminal = as.character(observed$terminal[[1L]]))
  if (!identical(report$receipt_identity, identity[-1L])) {
    stop("curvature output receipt identity does not match the retained receipt", call. = FALSE)
  }
  identity
}

.temporal_dep_kernel_retained_curvature_write_rds <- function(report, path) {
  identity <- .temporal_dep_kernel_retained_curvature_output_identity(report)
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || file.exists(path) ||
      !dir.exists(dirname(path))) {
    stop("curvature RDS output must be a new path in an existing directory", call. = FALSE)
  }
  temporary <- tempfile(paste0(".", basename(path), ".tmp-"), tmpdir = dirname(path))
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  saveRDS(report, temporary)
  restored <- readRDS(temporary)
  restored_identity <- .temporal_dep_kernel_retained_curvature_output_identity(restored)
  if (!identical(identity, restored_identity)) {
    stop("temporary curvature RDS identity validation failed", call. = FALSE)
  }
  if (file.exists(path) || !file.rename(temporary, path)) {
    stop("could not atomically commit curvature RDS without overwrite", call. = FALSE)
  }
  invisible(path)
}

if (sys.nframe() == 0L) {
  namespace <- asNamespace("gllvmTMB")
  if (!all(vapply(c("temporal_dep", "kernel_indep"), exists, logical(1),
      envir = namespace, inherits = FALSE))) {
    pkgload::load_all(normalizePath(".", mustWork = TRUE), quiet = TRUE,
      export_all = FALSE)
  }
  .temporal_dep_kernel_retained_curvature_source()
  args <- commandArgs(trailingOnly = TRUE)
  one <- sub("^--one=", "", args[grepl("^--one=", args)])
  rds <- sub("^--rds=", "", args[grepl("^--rds=", args)])
  if (length(args) != 2L || length(one) != 1L || length(rds) != 1L ||
      !grepl("^[0-9]+$", one) || file.exists(rds)) {
    stop(paste("usage: Rscript --vanilla diagnose-dep-kernel-retained-curvature.R",
      "--one=SEED --rds=NEW-PATH"), call. = FALSE)
  }
  seed <- .temporal_dep_kernel_retained_curvature_seed(as.integer(one))
  ## The public function requires all retained seeds.  This private command
  ## path is deliberately the one-cell pre-run and never writes a campaign
  ## receipt.
  one <- .temporal_dep_kernel_retained_curvature_one(seed)
  receipt_identity <- list(frozen_seed = as.integer(one$receipt$expected$seed[[1L]]),
    rehydrated_seed = as.integer(one$receipt$observed$seed[[1L]]),
    frozen_phi = as.numeric(one$receipt$expected$phi[[1L]]),
    rehydrated_phi = as.numeric(one$receipt$observed$phi[[1L]]),
    terminal = as.character(one$receipt$observed$terminal[[1L]]))
  report <- list(schema_version = "temporal-dep-kernel-retained-curvature-v1", seed = seed,
    n_series = 80L, n_time = 16L, n_observation = 7680L, receipt_identity = receipt_identity,
    report = one,
    contract = paste("Curvature/conditioning diagnostic only; no optimiser intervention,",
      "recovery, calibration, or numerical-remedy claim."))
  .temporal_dep_kernel_retained_curvature_write_rds(report, rds)
  cat("TEMPORAL_DEP_KERNEL_RETAINED_CURVATURE_COMPLETE\n")
}
