#!/usr/bin/env Rscript

# Private, non-running Design-91 producer and paired EVA/VA receipt writer.
# Sourcing this file does not generate a fixture or fit a model.

read_d91_config <- function(path = file.path("dev", "design91-eva-va-envelope", "design91-config.json")) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Design 91.")
  jsonlite::read_json(path, simplifyVector = TRUE)
}

d91_normal_quadrature <- function(order = 15L) {
  j <- seq_len(order - 1L)
  jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2)
  jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eigen_result <- eigen(jacobi, symmetric = TRUE)
  list(nodes = sqrt(2) * eigen_result$values, weights = eigen_result$vectors[1, ]^2)
}

d91_latent_quadrature <- function(rho, order = 15L) {
  quad <- d91_normal_quadrature(order)
  z <- cbind(rep(quad$nodes, each = order), rep(quad$nodes, times = order))
  weights <- as.vector(outer(quad$weights, quad$weights))
  list(u = z %*% chol(matrix(c(1, rho, rho, 1), 2L, 2L)), weights = weights)
}

d91_lambda <- function(traits, signal) {
  if (traits < 2L) stop("Design 91 requires at least two traits.")
  lambda <- matrix(0, traits, 2L)
  lambda[1L, ] <- c(signal, 0)
  lambda[2L, ] <- c(0, signal)
  if (traits > 2L) {
    angles <- 2 * pi * seq_len(traits - 2L) / (traits - 1L)
    lambda[3:traits, ] <- signal * cbind(cos(angles), sin(angles))
  }
  lambda
}

d91_intercepts <- function(lambda, prevalence, rho) {
  quad <- d91_latent_quadrature(rho)
  vapply(seq_len(nrow(lambda)), function(trait) {
    shift <- as.vector(quad$u %*% lambda[trait, ])
    uniroot(function(intercept) sum(quad$weights * plogis(intercept + shift)) - prevalence,
            interval = c(-20, 20), tol = 1e-12)$root
  }, numeric(1))
}

d91_support <- function(y) {
  list(
    trait_support = all(colSums(y) > 0L & colSums(y) < nrow(y)),
    row_support = all(rowSums(y) > 0L & rowSums(y) < ncol(y))
  )
}

d91_grid <- function(config = read_d91_config()) {
  grid <- expand.grid(n = config$n, traits = config$traits,
                      marginal_prevalence = config$marginal_prevalence,
                      loading_signal = config$loading_signal,
                      latent_correlation = config$latent_correlation,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid$cell_index <- seq_len(nrow(grid))
  grid$cell_id <- sprintf("n%03d_t%02d_p%02d_s%02d_r%02d", grid$n, grid$traits,
                          round(100 * grid$marginal_prevalence),
                          round(100 * grid$loading_signal),
                          round(100 * grid$latent_correlation))
  grid
}

d91_make_fixture <- function(cell, config = read_d91_config()) {
  n <- as.integer(cell$n)
  traits <- as.integer(cell$traits)
  lambda <- d91_lambda(traits, as.numeric(cell$loading_signal))
  rho <- as.numeric(cell$latent_correlation)
  intercept <- d91_intercepts(lambda, as.numeric(cell$marginal_prevalence), rho)
  R <- matrix(c(1, rho, rho, 1), 2L, 2L)
  seed_base <- as.integer(config$generator_seed_base + as.integer(cell$cell_index) * 1000L)
  rejected <- list()
  for (draw in seq_len(as.integer(config$max_fixture_draws))) {
    seed <- seed_base + draw - 1L
    set.seed(seed)
    u <- matrix(rnorm(n * 2L), n, 2L) %*% chol(R)
    probability <- plogis(sweep(u %*% t(lambda), 2L, intercept, "+"))
    y <- matrix(rbinom(n * traits, size = 1L, prob = as.vector(probability)), n, traits)
    support <- d91_support(y)
    if (isTRUE(support$trait_support) && isTRUE(support$row_support)) {
      colnames(y) <- sprintf("trait_%02d", seq_len(traits))
      rownames(y) <- sprintf("unit_%03d", seq_len(n))
      return(list(cell = cell, generator_seed_base = seed_base, accepted_seed = seed,
                  accepted_draw = draw, rejected_draws = rejected, lambda = lambda,
                  R = R, intercept = intercept, y = y, support = support))
    }
    rejected[[length(rejected) + 1L]] <- list(seed = seed, draw = draw,
      reason = if (!support$trait_support) "TRAIT_SUPPORT_FAIL" else "ROW_SUPPORT_FAIL")
  }
  stop("SEPARATION_EXCLUDED: no row-and-trait-support-conditioned fixture within frozen draw budget.")
}

d91_validate_fixture <- function(fixture) {
  y <- fixture$y
  is.matrix(y) && all(y %in% c(0, 1)) &&
    identical(dim(fixture$lambda), c(ncol(y), 2L)) &&
    isTRUE(d91_support(y)$trait_support) && isTRUE(d91_support(y)$row_support)
}

d91_write_fixture <- function(fixture, fixture_dir) {
  if (!d91_validate_fixture(fixture)) stop("PRECHECK_FAIL: support-conditioned fixture validation failed.")
  if (!dir.exists(fixture_dir)) stop("Fixture root must exist before materialisation.")
  path <- file.path(fixture_dir, paste0(fixture$cell$cell_id, ".rds"))
  if (file.exists(path)) stop("Non-overwrite fixture already exists.")
  saveRDS(fixture, path)
  path
}

d91_finite <- function(x) is.numeric(x) && length(x) > 0L && all(is.finite(x))

d91_sha256_file <- function(path) {
  if (!file.exists(path)) stop("Cannot checksum a missing file.")
  if (nzchar(Sys.which("sha256sum"))) {
    return(strsplit(system2("sha256sum", path, stdout = TRUE), "[[:space:]]+")[[1L]][1L])
  }
  if (nzchar(Sys.which("shasum"))) {
    return(strsplit(system2("shasum", c("-a", "256", path), stdout = TRUE), "[[:space:]]+")[[1L]][1L])
  }
  stop("No SHA-256 command (sha256sum or shasum) is available.")
}

d91_hessian_telemetry <- function(fit) {
  hessian <- tryCatch(fit$TMBfn$he(fit$TMBfn$par), error = function(e) e)
  if (inherits(hessian, "error") || !is.matrix(hessian) || !all(is.finite(hessian))) {
    return(list(available = FALSE, condition_number = NA_real_))
  }
  values <- tryCatch(eigen((hessian + t(hessian)) / 2, symmetric = TRUE, only.values = TRUE)$values,
                     error = function(e) numeric())
  condition <- if (length(values) && all(is.finite(values)) && min(abs(values)) > 0) {
    max(abs(values)) / min(abs(values))
  } else NA_real_
  list(available = TRUE, condition_number = condition)
}

d91_run_method <- function(fixture_path, initialization_seed, method, result_dir,
                           config = read_d91_config()) {
  if (!method %in% config$fit$methods) stop("Unsupported Design-91 method.")
  if (!dir.exists(result_dir)) stop("Result root must exist before an attempt.")
  lib <- Sys.getenv("D91_GLLVM_LIB", unset = "")
  if (!nzchar(lib)) stop("Set D91_GLLVM_LIB to the fresh isolated library.")
  .libPaths(c(lib, .libPaths()))
  if (!requireNamespace("gllvm", quietly = TRUE) ||
      as.character(utils::packageVersion("gllvm")) != "2.0.13") stop("Locked gllvm 2.0.13 required.")
  fixture <- readRDS(fixture_path)
  if (!d91_validate_fixture(fixture)) stop("PRECHECK_FAIL: frozen fixture validation failed.")
  stem <- file.path(result_dir, sprintf("%s-%s-seed%d", fixture$cell$cell_id, tolower(method), initialization_seed))
  if (file.exists(paste0(stem, ".rds")) || file.exists(paste0(stem, ".json"))) stop("Non-overwrite receipt exists.")
  warnings <- messages <- character(); error_text <- NULL; started <- Sys.time()
  fit <- withCallingHandlers(tryCatch({
    set.seed(initialization_seed)
    gllvm::gllvm(fixture$y, family = config$fit$family, link = config$fit$link,
      method = method, num.lv = config$fit$num_lv, num.lv.c = config$fit$num_lv_c,
      Lambda.struc = config$fit$lambda_structure, seed = initialization_seed,
      n.init = config$fit$n_init, sd.errors = config$fit$sd_errors,
      starting.val = config$fit$starting_value)
  }, error = function(e) { error_text <<- conditionMessage(e); NULL }),
  warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") },
  message = function(m) { messages <<- c(messages, conditionMessage(m)); invokeRestart("muffleMessage") })
  gradient <- if (is.null(fit)) numeric() else tryCatch(fit$TMBfn$gr(fit$TMBfn$par), error = function(e) numeric())
  convergence <- if (is.null(fit)) NA else fit$convergence
  max_gradient <- if (d91_finite(gradient)) max(abs(gradient)) else NA_real_
  params <- if (is.null(fit)) numeric() else unlist(fit$params, recursive = TRUE, use.names = FALSE)
  healthy <- !is.null(fit) && isTRUE(convergence) && d91_finite(fit$logL) &&
    d91_finite(params) && d91_finite(gradient) && is.finite(max_gradient) &&
    max_gradient <= config$health$max_abs_gradient && !length(warnings)
  telemetry <- list(design = config$design, requested_method = method,
    initialization_seed = initialization_seed, fixture_path = normalizePath(fixture_path),
    fixture_sha256 = d91_sha256_file(fixture_path),
    error = error_text, warnings = warnings, messages = messages,
    convergence_value = convergence, convergence_type = typeof(convergence),
    log_likelihood = if (is.null(fit)) NA_real_ else fit$logL,
    max_abs_gradient = max_gradient, hessian = if (is.null(fit))
      list(available = FALSE, condition_number = NA_real_) else d91_hessian_telemetry(fit),
    parameter_coordinates = if (is.null(fit)) numeric() else params,
    parameter_transform = "UPSTREAM_INTERNAL_NOT_EXTRACTED",
    optimizer_counts = if (is.null(fit)) NULL else fit$iterations,
    healthy = healthy, elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))
  out <- list(fixture = fixture, telemetry = telemetry)
  saveRDS(out, paste0(stem, ".rds"))
  jsonlite::write_json(telemetry, paste0(stem, ".json"), auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  out
}
