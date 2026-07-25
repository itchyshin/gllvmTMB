#!/usr/bin/env Rscript

# Private Design-90 fixture and one-attempt runner.  Sourcing this file is
# non-fitting; execution requires an explicit cell and seed and writes exactly
# one non-overwrite receipt.

read_d90_config <- function(path = file.path("dev", "design90-eva-atlas", "atlas-config.json")) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Design 90.")
  jsonlite::read_json(path, simplifyVector = TRUE)
}

normal_quadrature <- function(order = 15L) {
  j <- seq_len(order - 1L)
  jacobi <- matrix(0, order, order)
  jacobi[cbind(j, j + 1L)] <- sqrt(j / 2)
  jacobi[cbind(j + 1L, j)] <- sqrt(j / 2)
  eg <- eigen(jacobi, symmetric = TRUE)
  list(nodes = sqrt(2) * eg$values, weights = eg$vectors[1, ]^2)
}

quadrature_latents <- function(rho, order = 15L) {
  q <- normal_quadrature(order)
  z <- cbind(rep(q$nodes, each = order), rep(q$nodes, times = order))
  w <- as.vector(outer(q$weights, q$weights))
  list(u = z %*% chol(matrix(c(1, rho, rho, 1), 2, 2)), w = w)
}

make_lambda <- function(T, signal) {
  if (T < 2L) stop("Design 90 requires at least two traits.")
  lam <- matrix(0, T, 2)
  lam[1L, ] <- c(signal, 0)
  lam[2L, ] <- c(0, signal)
  if (T > 2L) {
    angles <- 2 * pi * seq_len(T - 2L) / (T - 1L)
    lam[3:T, ] <- signal * cbind(cos(angles), sin(angles))
  }
  lam
}

calibrate_intercepts <- function(lambda, prevalence, rho) {
  quad <- quadrature_latents(rho)
  vapply(seq_len(nrow(lambda)), function(t) {
    shift <- as.vector(quad$u %*% lambda[t, ])
    f <- function(b) sum(quad$w * plogis(b + shift)) - prevalence
    uniroot(f, interval = c(-20, 20), tol = 1e-12)$root
  }, numeric(1))
}

make_d90_fixture <- function(cell, config = read_d90_config(), max_draws = 100L) {
  n <- as.integer(cell$n); T <- as.integer(cell$traits)
  lambda <- make_lambda(T, as.numeric(cell$loading_signal))
  intercept <- calibrate_intercepts(lambda, as.numeric(cell$marginal_prevalence),
                                    as.numeric(cell$latent_correlation))
  R <- matrix(c(1, cell$latent_correlation, cell$latent_correlation, 1), 2, 2)
  cell_index <- as.integer(cell$cell_index)
  seed0 <- as.integer(config$generator_seed_base + cell_index * 100L)
  for (draw in seq_len(max_draws)) {
    set.seed(seed0 + draw - 1L)
    u <- matrix(rnorm(n * 2L), n, 2) %*% chol(R)
    prob <- plogis(sweep(u %*% t(lambda), 2L, intercept, "+"))
    y <- matrix(rbinom(n * T, size = 1L, prob = as.vector(prob)), n, T)
    if (all(colSums(y) > 0L) && all(colSums(y) < n)) {
      colnames(y) <- sprintf("trait_%02d", seq_len(T))
      rownames(y) <- sprintf("unit_%03d", seq_len(n))
      return(list(cell = cell, generator_seed = seed0, accepted_draw = draw,
                  lambda = lambda, R = R, intercept = intercept, y = y))
    }
  }
  stop("SEPARATION_EXCLUDED: no nonseparable fixture in frozen max_draws.")
}

validate_d90_fixture <- function(fixture) {
  y <- fixture$y
  is.matrix(y) && all(y %in% c(0, 1)) && all(colSums(y) > 0L) &&
    all(colSums(y) < nrow(y)) && identical(dim(fixture$lambda), c(ncol(y), 2L))
}

make_d90_grid <- function(config = read_d90_config()) {
  g <- expand.grid(n = config$n, traits = config$traits,
                   marginal_prevalence = config$marginal_prevalence,
                   loading_signal = config$loading_signal,
                   latent_correlation = config$latent_correlation,
                   KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  g$cell_index <- seq_len(nrow(g))
  g$cell_id <- sprintf("n%03d_t%02d_p%02d_s%02d_r%02d", g$n, g$traits,
                       round(100 * g$marginal_prevalence), round(100 * g$loading_signal),
                       round(100 * g$latent_correlation))
  g
}

run_d90_attempt <- function(cell, fit_seed, result_dir, config = read_d90_config()) {
  if (!dir.exists(result_dir)) stop("Result root must exist before an attempt.")
  if (!nzchar(Sys.getenv("D90_GLLVM_LIB", unset = ""))) stop("Set D90_GLLVM_LIB.")
  .libPaths(c(Sys.getenv("D90_GLLVM_LIB"), .libPaths()))
  if (!requireNamespace("gllvm", quietly = TRUE) ||
      as.character(utils::packageVersion("gllvm")) != "2.0.13") stop("Locked gllvm 2.0.13 required.")
  fixture <- make_d90_fixture(cell, config)
  if (!validate_d90_fixture(fixture)) stop("PRECHECK_FAIL: fixture validation failed.")
  stem <- file.path(result_dir, paste0(cell$cell_id, "-seed", fit_seed))
  if (file.exists(paste0(stem, ".rds")) || file.exists(paste0(stem, ".json"))) stop("Non-overwrite receipt exists.")
  warnings <- messages <- character(); err <- NULL
  started <- Sys.time()
  fit <- withCallingHandlers(tryCatch({
    set.seed(fit_seed)
    gllvm::gllvm(fixture$y, family = config$fit$family, link = config$fit$link,
                 method = config$fit$method, num.lv = config$fit$num_lv,
                 num.lv.c = config$fit$num_lv_c, Lambda.struc = config$fit$lambda_structure,
                 seed = fit_seed, sd.errors = config$fit$sd_errors,
                 starting.val = config$fit$starting_value)
  }, error = function(e) { err <<- conditionMessage(e); NULL }),
  warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") },
  message = function(m) { messages <<- c(messages, conditionMessage(m)); invokeRestart("muffleMessage") })
  grad <- if (!is.null(fit)) tryCatch(fit$TMBfn$gr(fit$TMBfn$par), error = function(e) numeric()) else numeric()
  finite <- function(x) is.numeric(x) && length(x) > 0L && all(is.finite(x))
  convergence <- if (is.null(fit)) NA else fit$convergence
  max_grad <- if (finite(grad)) max(abs(grad)) else NA_real_
  healthy <- !is.null(fit) && isTRUE(convergence) && finite(fit$logL) &&
    finite(unlist(fit$params, recursive = TRUE, use.names = FALSE)) && finite(grad) &&
    is.finite(max_grad) && max_grad <= config$health$max_abs_gradient && !length(warnings)
  out <- list(cell = cell, fit_seed = fit_seed, fixture = fixture,
              telemetry = list(error = err, warnings = warnings, messages = messages,
                convergence_value = convergence, convergence_type = typeof(convergence),
                log_likelihood = if (is.null(fit)) NA_real_ else fit$logL,
                max_abs_gradient = max_grad, healthy = healthy,
                elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))))
  saveRDS(out, paste0(stem, ".rds"))
  jsonlite::write_json(out$telemetry, paste0(stem, ".json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
  out
}
