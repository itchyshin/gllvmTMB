# Lane B B2 ordinary, permutation-audit, and spatial simulation harness
#
# This file deliberately keeps manifest, RNG, queue, data-generation, and
# aggregation code independent of the compiled package.  Fitting is the only
# Tier-2 boundary.

`%||%` <- function(x, y) if (is.null(x)) y else x

lane_b_manifest_version <- function() "lane-b-b2-v1-2026-08-08"

lane_b_links <- function() c("logit", "probit", "cloglog")

lane_b_arms <- function() {
  data.frame(
    arm_id = c("ml", "ml_ridge", "mspl", "mspl_ridge_internal"),
    estimator = c("ml", "ml", "mspl", "mspl"),
    loading_ridge_tau = c(Inf, 2, Inf, 2),
    ridge_objective = c("none", "0.5*sum(lambda_free^2)/tau^2; tau=2",
                        "none", "0.5*sum(lambda_free^2)/tau^2; tau=2"),
    public = c(TRUE, TRUE, TRUE, FALSE),
    purpose = c("unpenalized baseline; nonexistence retained as an outcome",
                "finite Gaussian-prior MAP comparator", "candidate LA-MSPL estimator",
                "internal double-penalty ablation only"),
    stringsAsFactors = FALSE
  ) |>
    transform(arm = arm_id, loading_ridge = is.finite(loading_ridge_tau))
}

lane_b_ordinary_manifest <- function() {
  g <- expand.grid(
    link = lane_b_links(), n_unit = c(50L, 200L), q = c(1L, 2L),
    dimension = c("low", "high"), prevalence = c("balanced", "mixed_extreme"),
    loading_sd = c(0.5, 1.5), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  g <- g[order(match(g$link, lane_b_links()), g$n_unit, g$q,
               g$dimension, g$prevalence,
               g$loading_sd), , drop = FALSE]
  rownames(g) <- NULL
  g$cell_index <- seq_len(nrow(g))
  g$cell_id <- sprintf("O%03d", g$cell_index)
  g$n_trait <- ifelse(g$dimension == "low", 6L, 12L)
  g$n_slope <- ifelse(g$dimension == "low", 1L, 3L)
  g$n_rep <- ifelse(g$prevalence == "balanced", 500L, 1000L)
  g$target_prevalence <- ifelse(
    g$prevalence == "balanced", "0.5",
    "0.01,0.05,0.20,0.80,0.95,0.99(recycled)"
  )
  g$truth_seed_key <- 600000000L + g$cell_index
  g$calibration_seed_key <- 610000000L + g$cell_index
  g$dimension_profile <- g$dimension
  g$prevalence_profile <- ifelse(g$prevalence == "mixed_extreme", "mixed_extremes", g$prevalence)
  g$n_trait_slopes <- g$n_slope
  g$p_beta <- g$n_trait * (1L + g$n_slope)
  g$attempts <- g$n_rep
  g$truth_seed <- g$truth_seed_key
  g$calibration_seed <- g$calibration_seed_key
  g$data_seed_base <- 700000000 + g$cell_index * 2000
  g$start_seed_base <- 800000000 + g$cell_index * 2000
  g$prevalence_targets <- ifelse(g$prevalence == "balanced", "0.50",
                                 "0.01;0.05;0.20;0.80;0.95;0.99")
  g$manifest_version <- lane_b_manifest_version()
  g[, c("manifest_version", "cell_id", "cell_index", "link", "n_unit",
        "n_trait", "n_slope", "q", "dimension", "prevalence",
        "target_prevalence", "loading_sd", "n_rep", "truth_seed_key",
        "calibration_seed_key", "dimension_profile", "prevalence_profile",
        "n_trait_slopes", "p_beta", "attempts", "truth_seed", "calibration_seed",
        "data_seed_base", "start_seed_base", "prevalence_targets")]
}

lane_b_permutation_manifest <- function(ordinary = lane_b_ordinary_manifest()) {
  p <- ordinary[ordinary$n_unit == 200L & ordinary$loading_sd == 1.5,
    c("cell_id", "link", "q", "dimension_profile", "prevalence_profile",
      "n_unit", "n_trait", "n_trait_slopes", "loading_sd", "truth_seed",
      "calibration_seed"), drop = FALSE]
  rownames(p) <- NULL
  names(p)[names(p) == "cell_id"] <- "source_cell_id"
  p$audit_cell_id <- sprintf("P%02d", seq_len(nrow(p)))
  p$audit_cell_index <- seq_len(nrow(p))
  p$audit_attempts <- 200L
  p$permutation_set <- "reverse;cell_seeded_random"
  p$permutation_seed <- 640000000L + p$audit_cell_index
  p$data_seed_base <- 720000000L + p$audit_cell_index * 1000L
  p$equivalent_start <- "same_sigma_refactorized_lower_triangular"
  p$manifest_version <- lane_b_manifest_version()
  p
}

lane_b_spatial_manifest <- function() {
  structures <- c("spatial_indep", "spatial_latent_q1", "spatial_latent_q2")
  s <- expand.grid(
    link = lane_b_links(), n_unit = c(100L, 300L), structure = structures,
    prevalence_profile = c("balanced", "mixed_extremes"),
    range_fraction_domain = c(0.15, 0.60), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  s <- s[order(match(s$link, lane_b_links()), s$n_unit,
               match(s$structure, structures), s$prevalence_profile,
               s$range_fraction_domain), , drop = FALSE]
  rownames(s) <- NULL
  s$cell_id <- sprintf("S%03d", seq_len(nrow(s)))
  s$cell_index <- seq_len(nrow(s)); s$n_trait <- 6L
  s$q <- unname(c(spatial_indep = 0L, spatial_latent_q1 = 1L,
                  spatial_latent_q2 = 2L)[s$structure])
  s$marginal_spatial_sd <- 1
  s$attempts <- ifelse(s$prevalence_profile == "mixed_extremes", 1000L, 500L)
  s$truth_seed <- 620000000L + s$cell_index
  s$calibration_seed <- 630000000L + s$cell_index
  s$data_seed_base <- 710000000L + s$cell_index * 2000L
  s$start_seed_base <- 810000000L + s$cell_index * 2000L
  s$prevalence_targets <- ifelse(s$prevalence_profile == "balanced", "0.50",
                                 "0.01;0.05;0.20;0.80;0.95;0.99")
  s$manifest_version <- lane_b_manifest_version()
  s
}

lane_b_seed_keys <- function(cell_index, replicate_id) {
  stopifnot(length(cell_index) == 1L, length(replicate_id) == 1L,
            cell_index >= 1L, replicate_id >= 1L, replicate_id <= 1000L)
  base <- as.double(cell_index) * 2000 + as.double(replicate_id)
  c(
    data = 700000000 + base,
    start = 800000000 + base,
    prediction = 1300000000 + base,
    alternate = 1500000000 + base,
    paired_ci = 1700100000 + as.double(cell_index)
  )
}

lane_b_seed_registry <- function(manifest = lane_b_ordinary_manifest()) {
  out <- lapply(seq_len(nrow(manifest)), function(i) {
    reps <- seq_len(manifest$n_rep[[i]])
    base <- manifest$cell_index[[i]] * 2000 + reps
    data.frame(
      manifest_version = manifest$manifest_version[[i]],
      cell_id = manifest$cell_id[[i]], replicate_id = reps,
      truth_seed_key = manifest$truth_seed_key[[i]],
      calibration_seed_key = manifest$calibration_seed_key[[i]],
      data_seed_key = 700000000 + base,
      start_seed_key = 800000000 + base,
      prediction_seed_key = 1300000000 + base,
      alternate_seed_key = 1500000000 + base,
      paired_ci_seed_key = 1700100000 + manifest$cell_index[[i]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  key_cols <- c("data_seed_key", "start_seed_key", "prediction_seed_key",
                "alternate_seed_key")
  if (any(vapply(out[key_cols], anyDuplicated, integer(1)) != 0L)) {
    stop("Lane B seed-key collision detected.", call. = FALSE)
  }
  out
}

lane_b_seed_registry_all <- function(ordinary = lane_b_ordinary_manifest(),
                                     permutation = lane_b_permutation_manifest(ordinary),
                                     spatial = lane_b_spatial_manifest()) {
  ordinary_registry <- lane_b_seed_registry(ordinary)
  ordinary_registry$table <- "ordinary"
  empty_registry <- ordinary_registry[0, , drop = FALSE]
  spatial_registry <- if (!nrow(spatial)) empty_registry else do.call(rbind, lapply(seq_len(nrow(spatial)), function(i) {
    reps <- seq_len(spatial$attempts[[i]])
    data.frame(
      manifest_version = lane_b_manifest_version(), table = "spatial",
      cell_id = spatial$cell_id[[i]], replicate_id = reps,
      truth_seed_key = spatial$truth_seed[[i]],
      calibration_seed_key = spatial$calibration_seed[[i]],
      data_seed_key = spatial$data_seed_base[[i]] + reps,
      start_seed_key = spatial$start_seed_base[[i]] + reps,
      prediction_seed_key = 1400000000 + spatial$cell_index[[i]] * 2000 + reps,
      alternate_seed_key = 1600000000 + spatial$cell_index[[i]] * 2000 + reps,
      paired_ci_seed_key = 1700200000 + spatial$cell_index[[i]],
      stringsAsFactors = FALSE
    )
  }))
  permutation_registry <- do.call(rbind, lapply(seq_len(nrow(permutation)), function(i) {
    reps <- seq_len(permutation$audit_attempts[[i]])
    data.frame(
      manifest_version = lane_b_manifest_version(), table = "permutation",
      cell_id = permutation$audit_cell_id[[i]], replicate_id = reps,
      truth_seed_key = permutation$truth_seed[[i]],
      calibration_seed_key = permutation$calibration_seed[[i]],
      data_seed_key = permutation$data_seed_base[[i]] + reps,
      start_seed_key = 820000000 + permutation$audit_cell_index[[i]] * 1000 + reps,
      prediction_seed_key = 1450000000 + permutation$audit_cell_index[[i]] * 1000 + reps,
      alternate_seed_key = 1650000000 + permutation$audit_cell_index[[i]] * 1000 + reps,
      paired_ci_seed_key = 1700500000 + permutation$audit_cell_index[[i]],
      stringsAsFactors = FALSE
    )
  }))
  ordinary_registry <- ordinary_registry[names(spatial_registry)]
  out <- rbind(ordinary_registry, permutation_registry, spatial_registry)
  rownames(out) <- NULL
  keys <- c("data_seed_key", "start_seed_key", "prediction_seed_key", "alternate_seed_key")
  if (any(vapply(out[keys], anyDuplicated, integer(1)) != 0L))
    stop("Cross-surface Lane B seed-key collision detected.")
  out
}

lane_b_rng_state <- function(key) {
  old_kind <- RNGkind()
  old_seed <- if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (is.null(old_seed)) {
      if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old_seed, envir = .GlobalEnv)
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG")
  set.seed(as.integer(key %% .Machine$integer.max))
  get(".Random.seed", .GlobalEnv, inherits = FALSE)
}

lane_b_substreams <- function(key, n = 8L) {
  stopifnot(n >= 1L)
  out <- vector("list", n)
  out[[1L]] <- lane_b_rng_state(key)
  if (n > 1L) for (i in 2:n) out[[i]] <- parallel::nextRNGSubStream(out[[i - 1L]])
  names(out) <- c("truth_or_data", "train_covariates", "latent_scores",
                  "outcomes", "test_covariates_scores", "prediction_integration",
                  "alternate_start", "capsule")[seq_len(n)]
  out
}

lane_b_with_state <- function(state, code) {
  old <- if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
    get(".Random.seed", .GlobalEnv, inherits = FALSE) else NULL
  on.exit(if (is.null(old)) {
    if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv)
  } else assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
  assign(".Random.seed", state, envir = .GlobalEnv)
  force(code)
}

lane_b_arm_order <- function(replicate_id) {
  arms <- lane_b_arms()$arm_id
  shift <- (as.integer(replicate_id) - 1L) %% length(arms)
  arms[c(seq.int(shift + 1L, length(arms)), if (shift) seq_len(shift))]
}

lane_b_attempt_id <- function(cell_id, replicate_id, arm,
                              start_role = "primary", order_role = NULL,
                              table = "ordinary") {
  order_role <- order_role %||% sprintf("order_%d", match(arm, lane_b_arm_order(replicate_id)))
  paste(lane_b_manifest_version(), table, cell_id, replicate_id, arm,
        start_role, order_role, sep = "/")
}

lane_b_build_queue <- function(manifest = lane_b_ordinary_manifest(),
                               shard_size = 25L, smoke = FALSE) {
  stopifnot(shard_size >= 1L)
  if (isTRUE(smoke)) {
    manifest <- manifest[manifest$link == "logit" & manifest$n_unit == 50L &
                           manifest$q == 1L & manifest$dimension == "low" &
                           manifest$prevalence == "mixed_extreme" &
                           manifest$loading_sd == 0.5, , drop = FALSE]
    manifest$n_rep <- 1L
  }
  rows <- lapply(seq_len(nrow(manifest)), function(i) {
    reps <- seq_len(manifest$n_rep[[i]])
    chunks <- split(reps, ceiling(reps / shard_size))
    do.call(rbind, lapply(seq_along(chunks), function(j) data.frame(
      shard_id = sprintf("ordinary-%s-%04d", manifest$cell_id[[i]], j),
      manifest_version = manifest$manifest_version[[i]],
      table = "ordinary", cell_id = manifest$cell_id[[i]],
      cell_index = manifest$cell_index[[i]],
      replicate_first = min(chunks[[j]]), replicate_last = max(chunks[[j]]),
      dataset_count = length(chunks[[j]]),
      primary_attempt_count = length(chunks[[j]]) * nrow(lane_b_arms()),
      stringsAsFactors = FALSE
    )))
  })
  ans <- do.call(rbind, rows)
  rownames(ans) <- NULL
  ans
}

lane_b_build_surface_queue <- function(manifest, table, shard_size, smoke = FALSE) {
  if (table == "permutation") {
    if (smoke) { manifest <- manifest[1L, , drop = FALSE]; manifest$audit_attempts <- 1L }
    rows <- lapply(seq_len(nrow(manifest)), function(i) {
      reps <- seq_len(manifest$audit_attempts[[i]])
      chunks <- split(reps, ceiling(reps / shard_size))
      do.call(rbind, lapply(seq_along(chunks), function(j) data.frame(
        shard_id = sprintf("permutation-%s-%04d", manifest$audit_cell_id[[i]], j),
        manifest_version = lane_b_manifest_version(), table = table,
        cell_id = manifest$audit_cell_id[[i]], cell_index = manifest$audit_cell_index[[i]],
        replicate_first = min(chunks[[j]]), replicate_last = max(chunks[[j]]),
        dataset_count = length(chunks[[j]]),
        primary_attempt_count = length(chunks[[j]]) * 3L * 4L,
        stringsAsFactors = FALSE)))
    })
    return(do.call(rbind, rows))
  }
  if (table == "spatial") {
    if (smoke) {
      manifest <- manifest[manifest$link == "logit" & manifest$n_unit == 100L &
                             manifest$prevalence_profile == "mixed_extremes" &
                             manifest$range_fraction_domain == 0.15, , drop = FALSE]
      manifest$attempts <- 1L
    }
    rows <- lapply(seq_len(nrow(manifest)), function(i) {
      reps <- seq_len(manifest$attempts[[i]])
      chunks <- split(reps, ceiling(reps / shard_size))
      do.call(rbind, lapply(seq_along(chunks), function(j) data.frame(
        shard_id = sprintf("spatial-%s-%04d", manifest$cell_id[[i]], j),
        manifest_version = lane_b_manifest_version(), table = table,
        cell_id = manifest$cell_id[[i]], cell_index = manifest$cell_index[[i]],
        replicate_first = min(chunks[[j]]), replicate_last = max(chunks[[j]]),
        dataset_count = length(chunks[[j]]),
        primary_attempt_count = length(chunks[[j]]) * 4L,
        stringsAsFactors = FALSE)))
    })
    return(do.call(rbind, rows))
  }
  stop("Unknown Lane B surface: ", table)
}

lane_b_build_all_queue <- function(ordinary = lane_b_ordinary_manifest(),
                                   permutation = lane_b_permutation_manifest(ordinary),
                                   spatial = lane_b_spatial_manifest(), smoke = FALSE,
                                   include_spatial = TRUE) {
  pieces <- list(
    lane_b_build_queue(ordinary, shard_size = 25L, smoke = smoke),
    lane_b_build_surface_queue(permutation, "permutation", 25L, smoke)
  )
  if (isTRUE(include_spatial)) {
    pieces[[length(pieces) + 1L]] <- lane_b_build_surface_queue(
      spatial, "spatial", 10L, smoke
    )
  }
  do.call(rbind, pieces)
}

lane_b_inv_link <- function(eta, link) {
  switch(link, logit = plogis(eta), probit = pnorm(eta),
         cloglog = -expm1(-exp(pmin(eta, 35))),
         stop("Unknown Lane B link: ", link, call. = FALSE))
}

lane_b_targets <- function(cell) {
  if (cell$prevalence[[1L]] == "balanced") return(rep(0.5, cell$n_trait[[1L]]))
  rep(c(0.01, 0.05, 0.20, 0.80, 0.95, 0.99),
      length.out = cell$n_trait[[1L]])
}

lane_b_slopes <- function(n_trait, n_slope) {
  outer(seq_len(n_trait), seq_len(n_slope),
        Vectorize(function(t, j) 0.35 * (-1)^(t + j) / sqrt(j)))
}

lane_b_loadings <- function(n_trait, q, loading_sd, state) {
  z <- lane_b_with_state(state, matrix(rnorm(n_trait * q), n_trait, q))
  qr_q <- qr.Q(qr(z))[, seq_len(q), drop = FALSE]
  for (j in seq_len(q)) {
    nz <- which(abs(qr_q[, j]) > sqrt(.Machine$double.eps))[1L]
    if (qr_q[nz, j] < 0) qr_q[, j] <- -qr_q[, j]
  }
  qr_q * (loading_sd / sqrt(mean(rowSums(qr_q^2))))
}

.lane_b_truth_cache <- new.env(parent = emptyenv())

lane_b_cell_truth <- function(cell, calibration_n = 200000L) {
  stopifnot(nrow(cell) == 1L)
  cache_key <- paste(
    lane_b_manifest_version(), cell$cell_id[[1L]], calibration_n,
    sep = "::"
  )
  if (exists(cache_key, envir = .lane_b_truth_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .lane_b_truth_cache, inherits = FALSE))
  }
  truth_streams <- lane_b_substreams(cell$truth_seed_key[[1L]])
  cal_streams <- lane_b_substreams(cell$calibration_seed_key[[1L]])
  beta <- lane_b_slopes(cell$n_trait[[1L]], cell$n_slope[[1L]])
  lambda <- lane_b_loadings(cell$n_trait[[1L]], cell$q[[1L]],
                            cell$loading_sd[[1L]], truth_streams[[1L]])
  x <- lane_b_with_state(cal_streams[[2L]],
                         matrix(rnorm(calibration_n * cell$n_slope[[1L]]),
                                calibration_n, cell$n_slope[[1L]]))
  u <- lane_b_with_state(cal_streams[[3L]],
                         matrix(rnorm(calibration_n * cell$q[[1L]]),
                                calibration_n, cell$q[[1L]]))
  lin <- x %*% t(beta) + u %*% t(lambda)
  targets <- lane_b_targets(cell)
  intercept <- vapply(seq_len(cell$n_trait[[1L]]), function(t) {
    fn <- function(b0) mean(lane_b_inv_link(b0 + lin[, t], cell$link[[1L]])) - targets[t]
    uniroot(fn, c(-40, 40), tol = 1e-10)$root
  }, numeric(1))
  out <- list(intercept = intercept, beta = beta, lambda = lambda,
              Sigma = tcrossprod(lambda), target_prevalence = targets,
              offset = 0, calibration_n = calibration_n)
  assign(cache_key, out, envir = .lane_b_truth_cache)
  out
}

lane_b_standardize <- function(x) {
  center <- colMeans(x)
  scale <- apply(x, 2L, sd)
  if (any(!is.finite(scale) | scale <= 0)) stop("Degenerate simulated covariate.")
  list(x = sweep(sweep(x, 2L, center, "-"), 2L, scale, "/"),
       center = center, scale = scale)
}

lane_b_long_frame <- function(y, x, offset = 0) {
  n_unit <- nrow(y); n_trait <- ncol(y)
  data.frame(
    unit = factor(rep(seq_len(n_unit), each = n_trait)),
    trait = factor(rep(sprintf("trait_%02d", seq_len(n_trait)), times = n_unit),
                   levels = sprintf("trait_%02d", seq_len(n_trait))),
    value = as.numeric(t(y)), offset = rep(offset, n_unit * n_trait),
    x[rep(seq_len(n_unit), each = n_trait), , drop = FALSE],
    row.names = NULL, check.names = FALSE
  )
}

lane_b_generate_ordinary <- function(cell, replicate_id, calibration_n = 200000L,
                                     integration_n = 2048L, seed_override = NULL) {
  keys <- lane_b_seed_keys(cell$cell_index[[1L]], replicate_id)
  if (!is.null(seed_override)) keys[names(seed_override)] <- seed_override
  streams <- lane_b_substreams(keys[["data"]])
  truth <- lane_b_cell_truth(cell, calibration_n = calibration_n)
  n <- cell$n_unit[[1L]]; nt <- cell$n_trait[[1L]]
  x_raw <- lane_b_with_state(streams[[2L]],
                             matrix(rnorm(n * cell$n_slope[[1L]]), n))
  sx <- lane_b_standardize(x_raw)
  colnames(sx$x) <- paste0("x", seq_len(ncol(sx$x)))
  u <- lane_b_with_state(streams[[3L]], matrix(rnorm(n * cell$q[[1L]]), n))
  eta <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    sx$x %*% t(truth$beta) + u %*% t(truth$lambda)
  p <- lane_b_inv_link(eta, cell$link[[1L]])
  y <- lane_b_with_state(streams[[4L]], matrix(rbinom(length(p), 1L, p), n, nt))

  test_draw <- lane_b_with_state(streams[[5L]], {
    list(x = matrix(rnorm(n * cell$n_slope[[1L]]), n),
         u = matrix(rnorm(n * cell$q[[1L]]), n),
         y_uniform = matrix(runif(n * nt), n, nt))
  })
  integration_z <- lane_b_with_state(streams[[6L]],
    matrix(rnorm(integration_n * cell$q[[1L]]), integration_n))
  x_test <- sweep(sweep(test_draw$x, 2L, sx$center, "-"), 2L, sx$scale, "/")
  colnames(x_test) <- colnames(sx$x)
  eta_test <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    x_test %*% t(truth$beta) + test_draw$u %*% t(truth$lambda)
  p_test_cond <- lane_b_inv_link(eta_test, cell$link[[1L]])
  y_test <- 1L * (test_draw$y_uniform < p_test_cond)
  fixed_test <- matrix(truth$intercept, n, nt, byrow = TRUE) + x_test %*% t(truth$beta)
  latent_mc <- integration_z %*% t(truth$lambda)
  p_test_marginal <- vapply(seq_len(nt), function(t) {
    rowMeans(lane_b_inv_link(outer(fixed_test[, t], latent_mc[, t], "+"),
                              cell$link[[1L]]))
  }, numeric(n))
  if (nt == 1L) p_test_marginal <- matrix(p_test_marginal, ncol = 1L)
  train <- lane_b_long_frame(y, sx$x, offset = 0)
  test <- lane_b_long_frame(y_test, x_test, offset = 0)
  test$truth_probability <- as.numeric(t(p_test_marginal))
  if (any(!is.finite(train$offset)) || any(train$offset != 0))
    stop("Ordinary Bernoulli offset contract violated.")
  list(train = train, test = test, truth = truth, cell = cell,
       replicate_id = replicate_id, seed_keys = keys,
       empirical_prevalence = colMeans(y))
}

## Reproduce only the training rows needed for the exact B0 registry.  This is
## intentionally a second implementation of the first half of
## `lane_b_generate_ordinary()`: the contract test requires byte-identical
## training frames, while avoiding held-out prediction draws during the
## post-fit B0 supplement.
lane_b_generate_ordinary_b0 <- function(cell, replicate_id,
                                        calibration_n = 200000L,
                                        seed_override = NULL) {
  keys <- lane_b_seed_keys(cell$cell_index[[1L]], replicate_id)
  if (!is.null(seed_override)) keys[names(seed_override)] <- seed_override
  streams <- lane_b_substreams(keys[["data"]])
  truth <- lane_b_cell_truth(cell, calibration_n = calibration_n)
  n <- cell$n_unit[[1L]]
  nt <- cell$n_trait[[1L]]
  x_raw <- lane_b_with_state(
    streams[[2L]],
    matrix(rnorm(n * cell$n_slope[[1L]]), n)
  )
  x <- lane_b_standardize(x_raw)$x
  colnames(x) <- paste0("x", seq_len(ncol(x)))
  u <- lane_b_with_state(
    streams[[3L]],
    matrix(rnorm(n * cell$q[[1L]]), n)
  )
  eta <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    x %*% t(truth$beta) + u %*% t(truth$lambda)
  probability <- lane_b_inv_link(eta, cell$link[[1L]])
  y <- lane_b_with_state(
    streams[[4L]],
    matrix(rbinom(length(probability), 1L, probability), n, nt)
  )
  list(
    train = lane_b_long_frame(y, x, offset = 0),
    cell = cell,
    replicate_id = replicate_id,
    seed_keys = keys
  )
}

lane_b_b0_registry_rows <- function(cell, replicate_ids,
                                    calibration_n = 200000L) {
  rows <- lapply(replicate_ids, function(replicate_id) {
    dat <- lane_b_generate_ordinary_b0(
      cell, replicate_id, calibration_n = calibration_n
    )
    status <- lane_b_b0_status_by_trait(dat)
    data.frame(
      manifest_version = lane_b_manifest_version(),
      cell_id = cell$cell_id[[1L]],
      replicate_id = as.integer(replicate_id),
      b0_status_hash_exact = paste(status, collapse = ";"),
      b0_has_complete = any(status == "COMPLETE"),
      b0_has_quasi_complete = any(status == "QUASI_COMPLETE"),
      b0_has_constant = any(status == "CONSTANT"),
      b0_all_overlap = all(status == "OVERLAP"),
      b0_not_checked = any(status %in% c("NOT_CHECKED", "RANK_DEFICIENT")),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

lane_b_permute_ordinary <- function(dat, permutation, order_role) {
  nt <- dat$cell$n_trait[[1L]]
  stopifnot(setequal(permutation, seq_len(nt)))
  reorder_frame <- function(frame) {
    unit_split <- split(seq_len(nrow(frame)), frame$unit)
    idx <- unlist(lapply(unit_split, function(ii) ii[permutation]), use.names = FALSE)
    out <- frame[idx, , drop = FALSE]
    out$trait <- factor(rep(sprintf("trait_%02d", seq_len(nt)), times = length(unit_split)),
                        levels = sprintf("trait_%02d", seq_len(nt)))
    rownames(out) <- NULL
    out
  }
  dat$train <- reorder_frame(dat$train); dat$test <- reorder_frame(dat$test)
  dat$truth$intercept <- dat$truth$intercept[permutation]
  dat$truth$beta <- dat$truth$beta[permutation, , drop = FALSE]
  dat$truth$lambda <- dat$truth$lambda[permutation, , drop = FALSE]
  dat$truth$Sigma <- dat$truth$Sigma[permutation, permutation, drop = FALSE]
  dat$order_role <- order_role; dat$trait_permutation <- permutation
  dat$trait_permutation_hash <- paste(permutation, collapse = "-")
  dat
}

lane_b_generate_permutation <- function(audit_cell, replicate_id,
                                        ordinary = lane_b_ordinary_manifest(),
                                        calibration_n = 200000L,
                                        integration_n = 2048L) {
  source <- ordinary[ordinary$cell_id == audit_cell$source_cell_id[[1L]], , drop = FALSE]
  override <- c(
    data = audit_cell$data_seed_base[[1L]] + replicate_id,
    start = 820000000 + audit_cell$audit_cell_index[[1L]] * 1000 + replicate_id,
    prediction = 1450000000 + audit_cell$audit_cell_index[[1L]] * 1000 + replicate_id,
    alternate = 1650000000 + audit_cell$audit_cell_index[[1L]] * 1000 + replicate_id)
  base <- lane_b_generate_ordinary(source, replicate_id, calibration_n, integration_n,
                                   seed_override = override)
  nt <- source$n_trait[[1L]]
  random <- lane_b_with_state(lane_b_rng_state(audit_cell$permutation_seed[[1L]]),
                              sample.int(nt))
  list(
    original = lane_b_permute_ordinary(base, seq_len(nt), "original"),
    reverse = lane_b_permute_ordinary(base, rev(seq_len(nt)), "reverse"),
    random = lane_b_permute_ordinary(base, random, "random")
  )
}

lane_b_matern_nu1 <- function(coords, effective_range) {
  d <- as.matrix(dist(coords))
  a <- sqrt(8) * d / effective_range
  out <- a * besselK(a, nu = 1)
  out[a == 0] <- 1
  out[!is.finite(out)] <- 0
  (out + t(out)) / 2
}

lane_b_spatial_truth <- function(cell, calibration_n = 200000L) {
  n_field <- if (cell$structure[[1L]] == "spatial_indep") 6L else cell$q[[1L]]
  streams <- lane_b_substreams(cell$truth_seed[[1L]])
  lambda <- if (cell$structure[[1L]] == "spatial_indep") diag(6L) else
    lane_b_loadings(6L, cell$q[[1L]], 1, streams[[1L]])
  beta <- lane_b_slopes(6L, 1L)
  cal <- lane_b_substreams(cell$calibration_seed[[1L]])
  x <- lane_b_with_state(cal[[2L]], rnorm(calibration_n))
  field <- lane_b_with_state(cal[[3L]], matrix(rnorm(calibration_n * n_field), calibration_n))
  lin <- x %o% beta[, 1L] + field %*% t(lambda)
  targets <- if (cell$prevalence_profile[[1L]] == "balanced") rep(0.5, 6L) else
    c(0.01, 0.05, 0.20, 0.80, 0.95, 0.99)
  intercept <- vapply(seq_len(6L), function(t) uniroot(function(b0)
    mean(lane_b_inv_link(b0 + lin[, t], cell$link[[1L]])) - targets[t],
    c(-40, 40), tol = 1e-10)$root, numeric(1))
  list(intercept = intercept, beta = beta, lambda = lambda,
       Sigma = tcrossprod(lambda), target_prevalence = targets,
       effective_range = cell$range_fraction_domain[[1L]] * sqrt(2),
       marginal_spatial_sd = 1, calibration_n = calibration_n, offset = 0)
}

lane_b_generate_spatial <- function(cell, replicate_id, calibration_n = 200000L) {
  data_key <- cell$data_seed_base[[1L]] + replicate_id
  prediction_key <- 1400000000 + cell$cell_index[[1L]] * 2000 + replicate_id
  start_key <- cell$start_seed_base[[1L]] + replicate_id
  alternate_key <- 1600000000 + cell$cell_index[[1L]] * 2000 + replicate_id
  streams <- lane_b_substreams(data_key); pred_streams <- lane_b_substreams(prediction_key)
  n <- cell$n_unit[[1L]]
  train_draw <- lane_b_with_state(streams[[2L]], {
    side <- rbinom(n, 1L, 0.5)
    train_x <- ifelse(side == 0L, runif(n, 0, 0.4), runif(n, 0.6, 1))
    list(coords = cbind(lon = train_x, lat = runif(n)), x = rnorm(n))
  })
  test_draw <- lane_b_with_state(pred_streams[[5L]],
    list(coords = cbind(lon = runif(n, 0.4, 0.6), lat = runif(n)), x = rnorm(n)))
  loc <- rbind(train_draw$coords, test_draw$coords)
  truth <- lane_b_spatial_truth(cell, calibration_n)
  corr <- lane_b_matern_nu1(loc, truth$effective_range)
  chol_corr <- chol(corr + diag(1e-10, 2L * n))
  n_field <- ncol(truth$lambda)
  fields <- lane_b_with_state(streams[[3L]],
    t(chol_corr) %*% matrix(rnorm(2L * n * n_field), 2L * n, n_field))
  sx <- lane_b_standardize(matrix(train_draw$x, ncol = 1L)); colnames(sx$x) <- "x1"
  x_test <- matrix((test_draw$x - sx$center) / sx$scale, ncol = 1L); colnames(x_test) <- "x1"
  fixed_train <- matrix(truth$intercept, n, 6L, byrow = TRUE) + sx$x %*% t(truth$beta)
  fixed_test <- matrix(truth$intercept, n, 6L, byrow = TRUE) + x_test %*% t(truth$beta)
  eta_train <- fixed_train + fields[seq_len(n), , drop = FALSE] %*% t(truth$lambda)
  eta_test <- fixed_test + fields[n + seq_len(n), , drop = FALSE] %*% t(truth$lambda)
  p_train <- lane_b_inv_link(eta_train, cell$link[[1L]])
  p_test <- lane_b_inv_link(eta_test, cell$link[[1L]])
  y_train <- lane_b_with_state(streams[[4L]], matrix(rbinom(length(p_train), 1L, p_train), n))
  y_test <- lane_b_with_state(pred_streams[[4L]],
                              matrix(rbinom(length(p_test), 1L, p_test), n))
  train <- lane_b_long_frame(y_train, sx$x, 0); test <- lane_b_long_frame(y_test, x_test, 0)
  train$lon <- rep(loc[seq_len(n), "lon"], each = 6L)
  train$lat <- rep(loc[seq_len(n), "lat"], each = 6L)
  test$lon <- rep(loc[n + seq_len(n), "lon"], each = 6L)
  test$lat <- rep(loc[n + seq_len(n), "lat"], each = 6L)
  test$truth_probability <- as.numeric(t(p_test))
  list(train = train, test = test, truth = truth, cell = cell,
       replicate_id = replicate_id,
       seed_keys = c(data = data_key, start = start_key, prediction = prediction_key,
                     alternate = alternate_key),
       empirical_prevalence = colMeans(y_train), spatial_coordinates = loc)
}

lane_b_formula <- function(n_slope, q) {
  slopes <- paste(sprintf("(0 + trait):x%d", seq_len(n_slope)), collapse = " + ")
  stats::as.formula(sprintf(
    "value ~ 0 + trait + %s + offset(offset) + latent(0 + trait | unit, d = %d, unique = FALSE)",
    slopes, q
  ))
}

lane_b_spatial_formula <- function(structure) {
  term <- switch(structure,
    spatial_indep = "spatial_indep(0 + trait | unit)",
    spatial_latent_q1 = "spatial_latent(0 + trait | unit, d = 1, unique = FALSE)",
    spatial_latent_q2 = "spatial_latent(0 + trait | unit, d = 2, unique = FALSE)")
  as.formula(paste("value ~ 0 + trait + (0 + trait):x1 + offset(offset) +", term))
}

lane_b_mspl_capabilities <- function() {
  ns <- if (requireNamespace("gllvmTMB", quietly = TRUE)) asNamespace("gllvmTMB") else NULL
  public <- !is.null(ns) && "estimator" %in% names(formals(get("gllvmTMB", ns)))
  c(public_mspl = public, harness_private_mspl_ridge = public)
}

lane_b_private_reoptimize <- function(fit, tau = Inf, start = NULL,
                                      label = "alternate") {
  obj <- fit$tmb_obj %||% fit$obj
  par <- start %||% fit$opt$par
  use_ridge <- is.finite(tau) && tau > 0
  loading <- if (use_ridge) {
    which(names(par) %in% c("theta_rr_B", "theta_rr_spde_lv"))
  } else integer()
  fn <- function(x) obj$fn(x) + 0.5 * sum(x[loading]^2) / tau^2
  gr <- function(x) {
    g <- obj$gr(x); g[loading] <- g[loading] + x[loading] / tau^2; g
  }
  opt <- nlminb(par, fn, gr, control = list(eval.max = 2000L, iter.max = 1500L))
  opt$objective <- fn(opt$par)
  hybrid_gradient <- gr(opt$par)
  invisible(obj$fn(opt$par))
  if (!is.null(obj$env$last.par)) obj$env$last.par.best <- obj$env$last.par
  fit$opt <- opt
  fit$report <- obj$report()
  ridge_nll <- 0.5 * sum(opt$par[loading]^2) / tau^2
  if (!is.null(fit$mspl)) fit$report$mspl_private_ridge_nll <- ridge_nll
  unpenalized_nll <- if (!is.null(fit$mspl)) {
    tryCatch(fit$mspl$unpenalized_tmb_obj$fn(opt$par),
             error = function(e) NA_real_)
  } else NA_real_
  if (!is.null(fit$mspl)) {
    fit$mspl$objective <- if (use_ridge) {
      "harness-private MSPL plus loading ridge"
    } else {
      "harness-private alternate-start MSPL"
    }
    fit$mspl$penalized_nll <- opt$objective
    fit$mspl$unpenalized_nll_at_estimate <- unpenalized_nll
    fit$mspl$unpenalized_loglik_at_estimate <- -unpenalized_nll
    fit$mspl$total_penalty_nll <- opt$objective - unpenalized_nll
    fit$mspl$penalty$jeffreys_nll <- as.numeric(fit$report$mspl_jeffreys_nll %||% NA_real_)
    fit$mspl$penalty$loading_nll <- as.numeric(fit$report$mspl_loading_nll %||% NA_real_)
    fit$mspl$penalty$covariance_nll <- as.numeric(fit$report$mspl_covariance_nll %||% 0)
    fit$mspl$penalty$private_ridge_nll <- ridge_nll
    fit$mspl$decomposition_residual <- opt$objective - unpenalized_nll -
      sum(unlist(fit$mspl$penalty[c("jeffreys_nll", "loading_nll",
                                    "covariance_nll", "private_ridge_nll")]), na.rm = TRUE)
  }
  fit$lane_b_private_reoptimization <- list(
    label = label, tau = tau, loading_indices = loading,
    base_estimator = tolower(fit$estimator %||% "ml"),
    objective = opt$objective, gradient = hybrid_gradient,
    loading_ridge_nll = ridge_nll
  )
  if (!is.null(fit$mspl) && use_ridge) {
    fit$lane_b_private_hybrid <- fit$lane_b_private_reoptimization
  }
  if (is.null(fit$fit_health)) fit$fit_health <- list()
  fit$fit_health$objective <- opt$objective
  fit$fit_health$max_gradient <- max(abs(hybrid_gradient))
  fit$fit_health$scaled_gradient <- lane_b_scaled_gradient(opt$par, hybrid_gradient,
                                                           opt$objective)
  fit$fit_health$optimizer_converged <- isTRUE(opt$convergence == 0L)
  fit$fit_health$converged <- isTRUE(opt$convergence == 0L) &&
    is.finite(opt$objective) && max(abs(hybrid_gradient)) < 1e-2
  fit
}

lane_b_private_ridge_reoptimize <- function(fit, tau = 2, start = NULL) {
  lane_b_private_reoptimize(
    fit, tau = tau, start = start, label = "mspl_plus_loading_ridge"
  )
}

lane_b_private_mspl_ridge_fit <- function(args, tau = 2) {
  args$estimator <- "mspl"
  fit <- do.call(gllvmTMB::gllvmTMB, args)
  lane_b_private_ridge_reoptimize(fit, tau)
}

lane_b_assert_capabilities <- function(allow_missing_mspl = FALSE) {
  cap <- lane_b_mspl_capabilities()
  if (!all(cap) && !isTRUE(allow_missing_mspl)) {
    missing <- paste(names(cap)[!cap], collapse = ", ")
    stop("Lane B B2 four-arm preflight failed; missing capability: ", missing,
         ". No shard was started. Use --allow-missing-mspl only for a diagnostic smoke run.",
         call. = FALSE)
  }
  invisible(cap)
}

lane_b_scaled_gradient <- function(par, gradient, objective) {
  if (!length(par) || length(par) != length(gradient) ||
      any(!is.finite(c(par, gradient, objective)))) return(Inf)
  max(abs(gradient) * pmax(1, abs(par))) / max(1, abs(objective))
}

lane_b_matrix_rank <- function(x, relative_tolerance = sqrt(.Machine$double.eps)) {
  if (!is.matrix(x) || length(x) == 0L || any(dim(x) == 0L) ||
      any(!is.finite(x))) return(NA_integer_)
  ev <- eigen((x + t(x)) / 2, symmetric = TRUE, only.values = TRUE)$values
  if (!length(ev) || max(abs(ev)) == 0) return(0L)
  sum(ev > max(abs(ev)) * relative_tolerance)
}

lane_b_fit_arm <- function(dat, arm, start_role = "primary", seed_state = NULL) {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) stop("gllvmTMB is unavailable.")
  cap <- lane_b_mspl_capabilities()
  if (arm == "mspl" && !cap[["public_mspl"]]) stop("capability_missing: public MSPL")
  if (arm == "mspl_ridge_internal" && !cap[["harness_private_mspl_ridge"]])
    stop("capability_missing: harness-private MSPL+ridge adapter")
  cell <- dat$cell
  control_args <- list(se = FALSE, warn_runaway = FALSE)
  if (arm == "ml_ridge") control_args$loading_ridge <- 2
  is_spatial <- "structure" %in% names(cell)
  args <- list(
    formula = if (is_spatial) lane_b_spatial_formula(cell$structure[[1L]]) else
      lane_b_formula(cell$n_slope[[1L]], cell$q[[1L]]),
    data = dat$train,
    trait = "trait",
    unit = "unit",
    family = stats::binomial(link = cell$link[[1L]]),
    control = do.call(gllvmTMB::gllvmTMBcontrol, control_args)
  )
  if (is_spatial) {
    if (!"make_mesh" %in% getNamespaceExports("gllvmTMB"))
      stop("capability_missing: spatial mesh constructor")
    args$mesh <- gllvmTMB::make_mesh(dat$train, c("lon", "lat"), cutoff = 0.05)
  }
  if (arm %in% c("mspl", "mspl_ridge_internal")) args$estimator <- "mspl"
  fit_call <- function() {
    fit <- do.call(gllvmTMB::gllvmTMB, args)
    if (identical(start_role, "alternate")) {
      alternate_start <- fit$tmb_obj$par +
        stats::rnorm(length(fit$tmb_obj$par), sd = 0.2)
      tau <- if (arm %in% c("ml_ridge", "mspl_ridge_internal")) 2 else Inf
      fit <- lane_b_private_reoptimize(
        fit, tau = tau, start = alternate_start,
        label = paste0(arm, "_alternate_start")
      )
    } else if (arm == "mspl_ridge_internal") {
      fit <- lane_b_private_ridge_reoptimize(fit, tau = 2)
    }
    fit
  }
  if (is.null(seed_state)) fit_call() else lane_b_with_state(seed_state, fit_call())
}

lane_b_extract_bfix <- function(fit) {
  n <- length(fit$X_fix_names %||% character())
  if (!n) return(setNames(numeric(), character()))
  value <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  if (length(value) < n) {
    value <- tryCatch(fit$tmb_obj$env$parList(fit$opt$par)$b_fix,
                      error = function(e) numeric())
  }
  if (length(value) < n) return(setNames(rep(NA_real_, n), fit$X_fix_names))
  setNames(as.numeric(value[seq_len(n)]), fit$X_fix_names)
}

lane_b_fixed_matrix <- function(frame, n_slope, columns = NULL) {
  rhs <- paste(c("0 + trait", sprintf("(0 + trait):x%d", seq_len(n_slope))),
               collapse = " + ")
  x <- model.matrix(as.formula(paste("~", rhs)), data = frame)
  if (is.null(columns)) return(x)
  missing <- setdiff(columns, colnames(x))
  if (length(missing)) stop("Prediction design lacks fitted column(s): ", paste(missing, collapse = ", "))
  x[, columns, drop = FALSE]
}

lane_b_truth_bfix <- function(dat, columns) {
  n_slope <- dat$cell$n_slope[[1L]] %||% dat$cell$n_trait_slopes[[1L]] %||% 1L
  x <- lane_b_fixed_matrix(dat$train, n_slope, columns)
  covariates <- as.matrix(dat$train[paste0("x", seq_len(n_slope))])
  trait_id <- as.integer(dat$train$trait)
  eta_fixed <- dat$truth$intercept[trait_id] +
    rowSums(covariates * dat$truth$beta[trait_id, , drop = FALSE])
  setNames(as.numeric(qr.solve(x, eta_fixed)), columns)
}

lane_b_bfix_matrix <- function(dat, bfix) {
  nt <- dat$cell$n_trait[[1L]]
  ns <- dat$cell$n_slope[[1L]] %||% dat$cell$n_trait_slopes[[1L]] %||% 1L
  frame <- expand.grid(trait = levels(dat$train$trait), basis = 0:ns,
                       KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  frame$trait <- factor(frame$trait, levels = levels(dat$train$trait))
  for (j in seq_len(ns)) frame[[paste0("x", j)]] <- 1L * (frame$basis == j)
  x <- lane_b_fixed_matrix(frame, ns, names(bfix))
  eta <- as.numeric(x %*% bfix)
  mat <- matrix(NA_real_, nt, ns + 1L)
  for (t in seq_len(nt)) {
    z <- eta[frame$trait == levels(frame$trait)[t]]
    mat[t, 1L] <- z[frame$basis[frame$trait == levels(frame$trait)[t]] == 0L]
    for (j in seq_len(ns))
      mat[t, j + 1L] <- z[frame$basis[frame$trait == levels(frame$trait)[t]] == j] - mat[t, 1L]
  }
  mat
}

lane_b_unpermute_matrix <- function(x, permutation, covariance = FALSE) {
  if (is.null(x)) return(NULL)
  if (is.null(permutation)) return(x)
  if (covariance) {
    out <- matrix(NA_real_, nrow(x), ncol(x)); out[permutation, permutation] <- x
  } else {
    out <- matrix(NA_real_, nrow(x), ncol(x)); out[permutation, ] <- x
  }
  out
}

lane_b_pack_numeric <- function(x) paste(format(as.numeric(x), digits = 17, scientific = TRUE),
                                          collapse = ";")
lane_b_unpack_numeric <- function(x) as.numeric(strsplit(x, ";", fixed = TRUE)[[1L]])

lane_b_b0_status_by_trait <- function(dat) {
  nt <- dat$cell$n_trait[[1L]]
  if (!requireNamespace("detectseparation", quietly = TRUE))
    return(stats::setNames(rep("NOT_CHECKED", nt), levels(dat$train$trait)))
  control <- detectseparation::detect_separation_control(
    separation_type = TRUE
  )
  vapply(levels(dat$train$trait), function(tr) {
    z <- dat$train[dat$train$trait == tr, , drop = FALSE]
    if (length(unique(z$value)) < 2L) return("CONSTANT")
    xnames <- grep("^x[0-9]+$", names(z), value = TRUE)
    x <- cbind(`(Intercept)` = 1, as.matrix(z[xnames]))
    if (qr(x, tol = sqrt(.Machine$double.eps))$rank < ncol(x))
      return("RANK_DEFICIENT")
    ans <- tryCatch(detectseparation::detect_separation(
      x = x, y = z$value, family = binomial(link = dat$cell$link[[1L]]),
      control = control, intercept = FALSE, singular.ok = FALSE),
      error = identity)
    if (inherits(ans, "condition")) return("NOT_CHECKED")
    if (!isTRUE(ans$outcome)) return("OVERLAP")
    if (isTRUE(ans$complete)) "COMPLETE" else "QUASI_COMPLETE"
  }, character(1), USE.NAMES = TRUE)
}

lane_b_b0_status_hash <- function(dat) {
  nt <- dat$cell$n_trait[[1L]]
  status <- lane_b_b0_status_by_trait(dat)
  if (!is.null(dat$trait_permutation)) {
    unpermuted <- character(nt); unpermuted[dat$trait_permutation] <- status
    status <- unpermuted
  }
  paste(status, collapse = ";")
}

lane_b_predict_whole_unit <- function(fit, dat, sigma, integration_n = 2048L) {
  b <- lane_b_extract_bfix(fit)
  if (any(!is.finite(b)) || !length(b)) stop("Cannot extract finite fixed effects.")
  x <- lane_b_fixed_matrix(dat$test, dat$cell$n_slope[[1L]], names(b))
  fixed <- matrix(as.numeric(x %*% b), nrow = dat$cell$n_unit[[1L]], byrow = TRUE)
  eig <- eigen((sigma + t(sigma)) / 2, symmetric = TRUE)
  keep <- eig$values > max(abs(eig$values)) * sqrt(.Machine$double.eps)
  if (!any(keep)) stop("Fitted covariance has zero effective rank.")
  root <- sweep(eig$vectors[, keep, drop = FALSE], 2L,
                sqrt(pmax(eig$values[keep], 0)), "*")
  streams <- lane_b_substreams(dat$seed_keys[["prediction"]])
  z <- lane_b_with_state(streams[[6L]],
    matrix(rnorm(integration_n * sum(keep)), integration_n, sum(keep)))
  latent <- z %*% t(root)
  pred <- vapply(seq_len(ncol(fixed)), function(t)
    rowMeans(lane_b_inv_link(outer(fixed[, t], latent[, t], "+"),
                              dat$cell$link[[1L]])), numeric(nrow(fixed)))
  as.numeric(t(if (is.null(dim(pred))) matrix(pred, ncol = 1L) else pred))
}

lane_b_log_loss <- function(y, probability) {
  probability <- pmin(pmax(probability, 1e-12), 1 - 1e-12)
  -mean(y * log(probability) + (1 - y) * log1p(-probability))
}

lane_b_extract_shared_sigma <- function(fit, spatial = FALSE) {
  if (!isTRUE(spatial)) {
    return(suppressMessages(gllvmTMB::extract_Sigma(
      fit, level = "unit", part = "shared", link_residual = "none"
    )$Sigma))
  }
  report <- fit$report %||% list()
  kappa <- as.numeric(report$kappa %||% NA_real_)
  if (length(kappa) != 1L || !is.finite(kappa) || kappa <= 0) {
    stop("The fitted spatial precision did not report one finite positive kappa.")
  }
  marginal_scale <- sqrt(4 * pi) * kappa
  if (isTRUE(fit$use$spatial_indep)) {
    log_tau <- as.numeric(report$log_tau_spde %||% numeric())
    if (!length(log_tau) || any(!is.finite(log_tau))) {
      stop("The spatial_indep fit did not report finite log_tau_spde values.")
    }
    marginal_sd <- exp(-log_tau) / marginal_scale
    return(diag(marginal_sd^2, nrow = length(marginal_sd)))
  }
  if (isTRUE(fit$use$spatial_latent)) {
    loading <- as.matrix(report$Lambda_spde %||% matrix(NA_real_, 0L, 0L))
    if (!length(loading) || any(!is.finite(loading))) {
      stop("The spatial_latent fit did not report finite Lambda_spde values.")
    }
    loading <- loading / marginal_scale
    return(tcrossprod(loading))
  }
  stop("The fit has no admitted Lane B spatial covariance structure.")
}

lane_b_extract_fit_diagnostics <- function(fit, q, spatial = FALSE) {
  obj <- fit$tmb_obj %||% fit$obj
  par <- fit$opt$par %||% numeric()
  objective <- fit$opt$objective %||% fit$opt$value %||% NA_real_
  gradient <- fit$lane_b_private_reoptimization$gradient %||%
    fit$lane_b_private_hybrid$gradient %||%
    tryCatch(obj$gr(par), error = function(e) rep(NA_real_, length(par)))
  sigma <- tryCatch(lane_b_extract_shared_sigma(fit, spatial = spatial),
                    error = function(e) matrix(NA_real_, 0L, 0L))
  h <- tryCatch(obj$he(par), error = function(e) matrix(NA_real_, 0L, 0L))
  scaled <- lane_b_scaled_gradient(par, gradient, objective)
  boundary_flags <- unlist(fit$fit_health$boundary_flags %||% FALSE, use.names = FALSE)
  bound_or_clamp <- any(boundary_flags %in% TRUE)
  runaway <- length(par) > 0L && is.finite(max(abs(par))) && max(abs(par)) > 50
  outward_improvement <- FALSE
  if (runaway && is.finite(objective)) {
    j <- which.max(abs(par)); probe <- par; probe[j] <- probe[j] + sign(par[j]) * 1e-3
    outward_improvement <- isTRUE(tryCatch(obj$fn(probe) < objective,
                                           error = function(e) FALSE))
    invisible(tryCatch(obj$fn(par), error = function(e) NULL))
  }
  sigma_rank <- lane_b_matrix_rank(sigma)
  expected_sigma_rank <- if (spatial && q == 0L) nrow(sigma) else q
  rank_matches <- length(sigma_rank) == 1L && !is.na(sigma_rank) &&
    length(expected_sigma_rank) == 1L && !is.na(expected_sigma_rank) &&
    sigma_rank == expected_sigma_rank
  list(
    optimizer_success = isTRUE(fit$opt$convergence == 0L), objective = objective,
    scaled_gradient = scaled, max_abs_parameter = if (length(par)) max(abs(par)) else NA_real_,
    hessian_rank = lane_b_matrix_rank(h), sigma_rank = sigma_rank,
    expected_sigma_rank = expected_sigma_rank,
    sigma = sigma, bfix = lane_b_extract_bfix(fit),
    bound_or_clamp = bound_or_clamp, runaway = runaway,
    outward_improvement = outward_improvement,
    usable = isTRUE(fit$opt$convergence == 0L) && is.finite(scaled) && scaled <= 1e-4 &&
      length(sigma) > 0L && all(is.finite(sigma)) && !bound_or_clamp &&
      rank_matches && !runaway && !outward_improvement
  )
}

lane_b_empty_attempts <- function() {
  data.frame(
    attempt_id = character(), manifest_version = character(), table = character(),
    cell_id = character(), replicate_id = integer(), arm = character(),
    start_role = character(), order_role = character(), status = character(),
    failure_class = character(), failure_message = character(), elapsed_seconds = double(),
    optimizer_success = logical(), usable = logical(), objective = double(),
    scaled_gradient = double(), max_abs_parameter = double(), hessian_rank = integer(),
    sigma_rank = integer(), expected_sigma_rank = integer(), bound_or_clamp = logical(),
    beta_squared_error = double(), covariance_squared_error = double(), log_loss = double(),
    alternate_objective_gap = double(), alternate_covariance_gap = double(),
    prediction_n_unit = integer(), stringsAsFactors = FALSE
  )
}

lane_b_failure_row <- function(cell, replicate_id, arm, order_role, condition, elapsed,
                               start_role = "primary", table = "ordinary") {
  x <- lane_b_empty_attempts()[NA_integer_, ]
  x[1, ] <- list(
    lane_b_attempt_id(cell$cell_id[[1L]], replicate_id, arm, start_role, order_role, table),
    lane_b_manifest_version(), table, cell$cell_id[[1L]], replicate_id, arm,
    start_role, order_role, "failure", class(condition)[[1L]], conditionMessage(condition),
    elapsed, FALSE, FALSE, NA_real_, Inf, NA_real_, NA_integer_, NA_integer_,
    cell$q[[1L]], FALSE, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_,
    cell$n_unit[[1L]]
  )
  x
}

lane_b_wilson_lower <- function(success, total, level = 0.95) {
  if (total <= 0L) return(NA_real_)
  z <- qnorm(level); p <- success / total
  (p + z^2 / (2 * total) - z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2))) /
    (1 + z^2 / total)
}

lane_b_thresholds <- function() list(
  separated_usable = 0.99, separated_wilson_lower = 0.98,
  overlap_usable = 0.95,
  scaled_gradient = 1e-4, objective_gap_scale = 1e-6,
  covariance_multistart = 1e-4, overlap_usable_difference = -0.02,
  rmse_ratio = 1.10, log_loss_difference = 0.01,
  ridge_failure_difference = 0.02, material_benefit = 0.05,
  paired_bootstrap_repetitions = 9999L
)

lane_b_attempt_summary <- function(attempts) {
  required <- c("cell_id", "arm", "status", "usable", "scaled_gradient")
  if (!all(required %in% names(attempts))) stop("Attempt table lacks frozen columns.")
  if ("start_role" %in% names(attempts)) attempts <- attempts[attempts$start_role == "primary", ]
  key <- interaction(attempts$cell_id, attempts$arm, drop = TRUE, lex.order = TRUE)
  pieces <- lapply(split(attempts, key), function(x) data.frame(
    cell_id = x$cell_id[[1L]], arm = x$arm[[1L]], attempted = nrow(x),
    retained_failures = sum(x$status != "success"), usable = sum(x$usable %in% TRUE),
    usable_fraction = mean(x$usable %in% TRUE),
    usable_wilson_lower = lane_b_wilson_lower(sum(x$usable %in% TRUE), nrow(x)),
    max_scaled_gradient = if (any(is.finite(x$scaled_gradient)))
      max(x$scaled_gradient[is.finite(x$scaled_gradient)]) else Inf,
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, pieces); rownames(out) <- NULL; out
}

lane_b_paired_bootstrap <- function(x, statistic = mean, B = 9999L, seed_key = 1700100001) {
  x <- x[is.finite(x)]
  if (!length(x)) return(c(estimate = NA, lower = NA, upper = NA))
  streams <- lane_b_substreams(seed_key)
  boot <- lane_b_with_state(streams[[1L]], replicate(B, statistic(sample(x, replace = TRUE))))
  c(estimate = statistic(x), lower = unname(quantile(boot, 0.025)),
    upper = unname(quantile(boot, 0.975)))
}

lane_b_pair_metric <- function(attempts, arm_a, arm_b, column, transform = `-`, B = 9999L) {
  a <- attempts[attempts$arm == arm_a, c("cell_id", "replicate_id", column), drop = FALSE]
  b <- attempts[attempts$arm == arm_b, c("cell_id", "replicate_id", column), drop = FALSE]
  names(a)[3L] <- "a"; names(b)[3L] <- "b"
  m <- merge(a, b, by = c("cell_id", "replicate_id"), all = FALSE)
  split_m <- split(m, m$cell_id)
  do.call(rbind, lapply(split_m, function(z) {
    ci <- lane_b_paired_bootstrap(transform(z$a, z$b), B = B,
      seed_key = 1700100000 + 100000 + match(z$cell_id[[1L]],
        lane_b_ordinary_manifest()$cell_id))
    data.frame(cell_id = z$cell_id[[1L]], arm_a = arm_a, arm_b = arm_b,
               metric = column, estimate = ci[[1L]], lower = ci[[2L]], upper = ci[[3L]])
  }))
}

lane_b_boot_pair_stat <- function(x, statistic, B, seed_key) {
  if (!nrow(x)) return(c(estimate = NA, lower = NA, upper = NA))
  streams <- lane_b_substreams(seed_key)
  estimate <- statistic(x)
  if (!is.finite(estimate)) return(c(estimate = estimate, lower = NA, upper = NA))
  boot <- lane_b_with_state(streams[[1L]], replicate(B, {
    statistic(x[sample.int(nrow(x), replace = TRUE), , drop = FALSE])
  }))
  boot <- boot[is.finite(boot)]
  if (!length(boot)) return(c(estimate = estimate, lower = NA, upper = NA))
  c(estimate = estimate, lower = unname(quantile(boot, 0.025)),
    upper = unname(quantile(boot, 0.975)))
}

lane_b_promotion_metrics <- function(attempts,
                                     manifest = lane_b_ordinary_manifest(),
                                     B = lane_b_thresholds()$paired_bootstrap_repetitions) {
  th <- lane_b_thresholds()
  if ("start_role" %in% names(attempts))
    attempts <- attempts[attempts$start_role == "primary", , drop = FALSE]
  required <- c("cell_id", "replicate_id", "arm", "usable", "scaled_gradient",
                "bound_or_clamp", "objective", "beta_squared_error", "covariance_squared_error",
                "log_loss", "alternate_objective_gap", "alternate_covariance_gap")
  if (!all(required %in% names(attempts)))
    stop("Attempt table lacks columns required by the frozen promotion metrics.")
  out <- vector("list", nrow(manifest))
  for (i in seq_len(nrow(manifest))) {
    cell <- manifest[i, , drop = FALSE]
    z <- attempts[attempts$cell_id == cell$cell_id, , drop = FALSE]
    mspl <- z[z$arm == "mspl", , drop = FALSE]
    separated <- cell$prevalence[[1L]] == "mixed_extreme"
    success <- sum(mspl$usable %in% TRUE)
    usable_fraction <- if (nrow(mspl)) success / nrow(mspl) else NA_real_
    wilson <- lane_b_wilson_lower(success, nrow(mspl))
    stationary <- nrow(mspl) > 0L && all(mspl$scaled_gradient[mspl$usable %in% TRUE] <= th$scaled_gradient)
    no_boundary <- nrow(mspl) > 0L && !any(mspl$bound_or_clamp %in% TRUE)
    usable_rows <- mspl$usable %in% TRUE
    multistart <- any(usable_rows) &&
      all(is.finite(mspl$alternate_objective_gap[usable_rows])) &&
      all(is.finite(mspl$alternate_covariance_gap[usable_rows])) &&
      all(abs(mspl$alternate_objective_gap[usable_rows]) <=
            th$objective_gap_scale * (1 + abs(mspl$objective[usable_rows]))) &&
      all(mspl$alternate_covariance_gap[usable_rows] <= th$covariance_multistart)
    separated_pass <- !separated || (is.finite(usable_fraction) &&
      usable_fraction >= th$separated_usable && wilson >= th$separated_wilson_lower &&
      stationary && no_boundary && multistart)

    pair <- function(a, b) {
      aa <- z[z$arm == a, c("replicate_id", "usable", "beta_squared_error",
                            "covariance_squared_error", "log_loss"), drop = FALSE]
      bb <- z[z$arm == b, c("replicate_id", "usable", "beta_squared_error",
                            "covariance_squared_error", "log_loss"), drop = FALSE]
      names(aa)[-1L] <- paste0(names(aa)[-1L], "_a")
      names(bb)[-1L] <- paste0(names(bb)[-1L], "_b")
      merge(aa, bb, by = "replicate_id", all = FALSE)
    }
    overlap_pair <- pair("mspl", "ml")
    seed <- 1700100000 + 100000 + cell$cell_index[[1L]]
    usable_ci <- lane_b_boot_pair_stat(overlap_pair,
      function(d) mean((d$usable_a %in% TRUE) - (d$usable_b %in% TRUE)), B, seed)
    beta_ci <- lane_b_boot_pair_stat(overlap_pair,
      function(d) sqrt(mean(d$beta_squared_error_a, na.rm = TRUE) /
                         mean(d$beta_squared_error_b, na.rm = TRUE)), B, seed + 1)
    covariance_ci <- lane_b_boot_pair_stat(overlap_pair,
      function(d) sqrt(mean(d$covariance_squared_error_a, na.rm = TRUE) /
                         mean(d$covariance_squared_error_b, na.rm = TRUE)), B, seed + 2)
    logloss_ci <- lane_b_boot_pair_stat(overlap_pair,
      function(d) mean(d$log_loss_a - d$log_loss_b, na.rm = TRUE), B, seed + 3)
    overlap_absolute_pass <- separated || (
      is.finite(usable_fraction) && usable_fraction >= th$overlap_usable
    )
    overlap_pass <- separated || (overlap_absolute_pass && nrow(overlap_pair) > 0L &&
      usable_ci[["lower"]] >= th$overlap_usable_difference &&
      beta_ci[["upper"]] <= th$rmse_ratio && covariance_ci[["upper"]] <= th$rmse_ratio &&
      logloss_ci[["upper"]] <= th$log_loss_difference)

    ridge_pair <- pair("mspl_ridge_internal", "mspl")
    ridge_usable <- lane_b_boot_pair_stat(ridge_pair,
      function(d) mean((d$usable_a %in% TRUE) - (d$usable_b %in% TRUE)), B, seed + 4)
    ridge_beta <- lane_b_boot_pair_stat(ridge_pair,
      function(d) sqrt(mean(d$beta_squared_error_a, na.rm = TRUE) /
                         mean(d$beta_squared_error_b, na.rm = TRUE)), B, seed + 5)
    ridge_cov <- lane_b_boot_pair_stat(ridge_pair,
      function(d) sqrt(mean(d$covariance_squared_error_a, na.rm = TRUE) /
                         mean(d$covariance_squared_error_b, na.rm = TRUE)), B, seed + 6)
    ridge_logloss <- lane_b_boot_pair_stat(ridge_pair,
      function(d) mean(d$log_loss_a - d$log_loss_b, na.rm = TRUE), B, seed + 7)
    ridge_no_harm <- nrow(ridge_pair) > 0L &&
      ridge_usable[["lower"]] >= -th$ridge_failure_difference &&
      ridge_beta[["upper"]] <= th$rmse_ratio && ridge_cov[["upper"]] <= th$rmse_ratio &&
      ridge_logloss[["upper"]] <= th$log_loss_difference
    ridge_material_benefit <- nrow(ridge_pair) > 0L &&
      (ridge_usable[["lower"]] > th$material_benefit ||
       ridge_beta[["upper"]] < 1 - th$material_benefit ||
       ridge_cov[["upper"]] < 1 - th$material_benefit ||
       ridge_logloss[["upper"]] < -th$material_benefit)
    out[[i]] <- data.frame(
      cell_id = cell$cell_id, prevalence = cell$prevalence,
      mspl_attempted = nrow(mspl), usable_fraction = usable_fraction,
      usable_wilson_lower = wilson, stationary = stationary,
      no_boundary_or_clamp = no_boundary, multistart_agreement = multistart,
      separated_pass = separated_pass,
      overlap_usable_difference_lower = usable_ci[["lower"]],
      overlap_beta_rmse_ratio_upper = beta_ci[["upper"]],
      overlap_covariance_rmse_ratio_upper = covariance_ci[["upper"]],
      overlap_log_loss_difference_upper = logloss_ci[["upper"]],
      overlap_absolute_pass = overlap_absolute_pass,
      overlap_pass = overlap_pass, ridge_no_harm = ridge_no_harm,
      ridge_material_benefit = ridge_material_benefit,
      promotion_pass = separated_pass && overlap_pass,
      stringsAsFactors = FALSE
    )
  }
  ans <- do.call(rbind, out); rownames(ans) <- NULL; ans
}

lane_b_permutation_metrics <- function(attempts) {
  z <- attempts[attempts$table == "permutation" & attempts$arm == "mspl" &
                  attempts$start_role == "primary", , drop = FALSE]
  if (!nrow(z)) return(data.frame())
  keys <- unique(z[c("cell_id", "replicate_id")])
  out <- lapply(seq_len(nrow(keys)), function(i) {
    d <- z[z$cell_id == keys$cell_id[[i]] & z$replicate_id == keys$replicate_id[[i]], ]
    ref <- d[d$order_role == "original", , drop = FALSE]
    cmp <- d[d$order_role != "original", , drop = FALSE]
    if (nrow(ref) != 1L || nrow(cmp) != 2L) return(NULL)
    beta0 <- lane_b_unpack_numeric(ref$beta_vector[[1L]])
    sigma0 <- lane_b_unpack_numeric(ref$sigma_vector[[1L]])
    rows <- lapply(seq_len(nrow(cmp)), function(j) {
      beta <- lane_b_unpack_numeric(cmp$beta_vector[[j]])
      sigma <- lane_b_unpack_numeric(cmp$sigma_vector[[j]])
      objective_difference <- if (is.finite(cmp$objective[[j]]) &&
          is.finite(ref$objective[[1L]])) {
        abs(cmp$objective[[j]] - ref$objective[[1L]])
      } else Inf
      beta_difference <- if (length(beta) == length(beta0) &&
          length(beta) && all(is.finite(c(beta, beta0)))) {
        sqrt(sum((beta - beta0)^2)) / max(1, sqrt(sum(beta0^2)))
      } else Inf
      sigma_difference <- if (length(sigma) == length(sigma0) &&
          length(sigma) && all(is.finite(c(sigma, sigma0)))) {
        sqrt(sum((sigma - sigma0)^2)) / max(1, sqrt(sum(sigma0^2)))
      } else Inf
      rank_agreement <- !is.na(cmp$sigma_rank[[j]]) &&
        !is.na(ref$sigma_rank[[1L]]) &&
        identical(cmp$sigma_rank[[j]], ref$sigma_rank[[1L]]) &&
        cmp$sigma_rank[[j]] == cmp$expected_sigma_rank[[j]] &&
        ref$sigma_rank[[1L]] == ref$expected_sigma_rank[[1L]]
      stationary_agreement <- isTRUE(cmp$usable[[j]]) &&
        isTRUE(ref$usable[[1L]])
      data.frame(cell_id = keys$cell_id[[i]], replicate_id = keys$replicate_id[[i]],
        comparison = cmp$order_role[[j]], objective_difference = objective_difference,
        beta_relative_difference = beta_difference,
        sigma_relative_difference = sigma_difference,
        b0_status_agreement = identical(cmp$b0_status_hash[[j]], ref$b0_status_hash[[1L]]),
        rank_agreement = rank_agreement,
        stationary_agreement = stationary_agreement,
        pass = objective_difference <= 1e-6 * (1 + abs(ref$objective[[1L]])) &&
          beta_difference < 1e-6 && sigma_difference < 1e-6 &&
          identical(cmp$b0_status_hash[[j]], ref$b0_status_hash[[1L]]) &&
          rank_agreement && stationary_agreement, stringsAsFactors = FALSE)
    })
    do.call(rbind, rows)
  })
  out <- Filter(Negate(is.null), out)
  if (!length(out)) data.frame() else do.call(rbind, out)
}

lane_b_spatial_promotion_metrics <- function(attempts) {
  z <- attempts[attempts$table == "spatial" & attempts$arm == "mspl" &
                  attempts$start_role == "primary", , drop = FALSE]
  if (!nrow(z)) return(data.frame())
  out <- lapply(split(z, z$cell_id), function(d) {
    usable <- d[d$usable %in% TRUE, , drop = FALSE]
    rate <- nrow(usable) / nrow(d)
    sd_bias <- if (nrow(usable)) median(usable$spatial_sd_relative_error, na.rm = TRUE) else NA_real_
    sd_rmse <- if (nrow(usable)) sqrt(mean(usable$spatial_sd_relative_error^2, na.rm = TRUE)) else NA_real_
    range_bias <- if (nrow(usable)) median(usable$spatial_log_range_error, na.rm = TRUE) else NA_real_
    range_rmse <- if (nrow(usable)) sqrt(mean(usable$spatial_log_range_error^2, na.rm = TRUE)) else NA_real_
    covfun <- if (nrow(usable)) sqrt(mean(usable$spatial_covfun_frob_error^2, na.rm = TRUE)) else NA_real_
    boundary <- any(d$spatial_boundary_contact %in% TRUE)
    data.frame(cell_id = d$cell_id[[1L]], attempted = nrow(d), usable_rate = rate,
      usable_wilson_lower = lane_b_wilson_lower(nrow(usable), nrow(d)),
      spatial_sd_median_relative_bias = sd_bias, spatial_sd_relative_rmse = sd_rmse,
      spatial_log_range_median_bias = range_bias, spatial_log_range_rmse = range_rmse,
      spatial_covfun_frob_error = covfun, spatial_boundary_contact = boundary,
      pass = rate >= 0.99 && lane_b_wilson_lower(nrow(usable), nrow(d)) >= 0.98 &&
        !boundary && is.finite(sd_bias) && abs(sd_bias) <= 0.10 && sd_rmse <= 0.30 &&
        is.finite(range_bias) && abs(range_bias) <= 0.15 && range_rmse <= 0.35 &&
        is.finite(covfun) && covfun <= 0.30, stringsAsFactors = FALSE)
  })
  ans <- do.call(rbind, out); rownames(ans) <- NULL; ans
}

lane_b_sha256_file <- function(path) {
  if (!file.exists(path)) stop("Cannot hash missing file: ", path)
  shasum <- Sys.which("shasum")
  sha256sum <- Sys.which("sha256sum")
  if (nzchar(shasum)) {
    out <- system2(shasum, c("-a", "256", shQuote(path)), stdout = TRUE)
  } else if (nzchar(sha256sum)) {
    out <- system2(sha256sum, shQuote(path), stdout = TRUE)
  } else stop("A SHA-256 utility (shasum or sha256sum) is required.")
  strsplit(out[[1L]], "[[:space:]]+")[[1L]][[1L]]
}

lane_b_verify_shard_receipts <- function(queue, raw_dir, complete_dir,
                                         hash_field = "sha256",
                                         require_complete = TRUE) {
  if (!"shard_id" %in% names(queue) || anyNA(queue$shard_id) ||
      anyDuplicated(queue$shard_id)) {
    stop("Shard receipt verification requires unique frozen shard IDs.")
  }
  expected <- as.character(queue$shard_id)
  ids_in <- function(path) {
    sub("\\.rds$", "", list.files(path, pattern = "\\.rds$",
                                     full.names = FALSE))
  }
  raw_ids <- ids_in(raw_dir)
  receipt_ids <- ids_in(complete_dir)
  unexpected <- union(setdiff(raw_ids, expected), setdiff(receipt_ids, expected))
  if (length(unexpected)) {
    stop("Shard directories contain unexpected IDs: ",
         paste(sort(unexpected), collapse = ", "))
  }
  complete_ids <- intersect(expected, intersect(raw_ids, receipt_ids))
  missing <- setdiff(expected, complete_ids)
  if (isTRUE(require_complete) && length(missing)) {
    stop("Receipt verification requires a complete queue; missing ",
         length(missing), " shard(s).")
  }

  attempts <- lapply(complete_ids, function(id) {
    raw_path <- file.path(raw_dir, paste0(id, ".rds"))
    receipt_path <- file.path(complete_dir, paste0(id, ".rds"))
    receipt <- readRDS(receipt_path)
    if (!is.list(receipt) || !identical(receipt$shard_id, id) ||
        !identical(receipt$status, "complete") ||
        !hash_field %in% names(receipt) ||
        length(receipt[[hash_field]]) != 1L ||
        !identical(receipt[[hash_field]], lane_b_sha256_file(raw_path))) {
      stop("Shard receipt identity or SHA-256 mismatch: ", id)
    }
    object <- readRDS(raw_path)
    if (!is.data.frame(object) || length(receipt$rows) != 1L ||
        !is.numeric(receipt$rows) || !is.finite(receipt$rows) ||
        receipt$rows != as.integer(receipt$rows) ||
        receipt$rows != nrow(object)) {
      stop("Shard receipt row count mismatch: ", id)
    }
    object
  })
  list(ids = complete_ids, missing = missing, attempts = attempts)
}

lane_b_atomic_save_rds <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(path, ".partial")
  saveRDS(object, partial, version = 3)
  if (!file.rename(partial, path)) stop("Atomic rename failed: ", path)
  lane_b_sha256_file(path)
}

lane_b_validate_campaign_root <- function(root, repo_root = getwd()) {
  root <- normalizePath(root, mustWork = FALSE)
  repo <- normalizePath(repo_root, mustWork = TRUE)
  if (identical(root, repo) || startsWith(paste0(root, "/"), paste0(repo, "/")))
    stop("Campaign outputs must be outside the git checkout.", call. = FALSE)
  root
}
