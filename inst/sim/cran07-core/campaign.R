# Deterministic scientific machinery for the frozen CRAN 0.7 campaigns.
# This is campaign-only code: it is not sourced by the package.

CRAN07_CORE_SHA256 <- "7182e91afa9f4c580add932f10bae753709c0525e259994cd7eacefdff7d9c5e"
CRAN07_SILENT_FAILURE_SHA256 <- "c571e804b1041e6e79a553d7a17bf7ae1f6fd9d2d6e6e667788a25693f2d6ebc"
CRAN07_ROBUSTNESS_SHA256 <- "679c043ea53a9ee47ee8ac951ed941482ad9d77448ef329a4c4b1337bc74663d"
CRAN07_CAMPAIGNS <- data.frame(
  campaign_id = c("cran07-core-recovery-v2", "cran07-silent-failure-v2",
                  "cran07-robustness-v2"),
  registry_relpath = c(
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-core-recovery/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-silent-failure/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-robustness/registry.csv"
  ),
  registry_sha256 = c(CRAN07_CORE_SHA256, CRAN07_SILENT_FAILURE_SHA256,
                      CRAN07_ROBUSTNESS_SHA256),
  seed_offset = c(270800000L, 270810000L, 270820000L),
  stringsAsFactors = FALSE
)
CRAN07_BOUNDARY_VARIANCE <- 1e-8
CRAN07_BOUNDARY_CORRELATION <- 0.9999
CRAN07_CATASTROPHIC_RELATIVE_FROBENIUS <- 2
CRAN07_CATASTROPHIC_EIGEN_RATIO <- 10
CRAN07_GEOMETRY_CONDITION_NUMBER <- 1e12
CRAN07_BINOMIAL_N_TRIALS <- 10L

cran07_sha256 <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  if (nzchar(Sys.which("sha256sum"))) {
    ans <- system2("sha256sum", shQuote(path), stdout = TRUE, stderr = TRUE)
  } else if (nzchar(Sys.which("shasum"))) {
    ans <- system2("shasum", c("-a", "256", shQuote(path)),
                   stdout = TRUE, stderr = TRUE)
  } else {
    stop("Neither sha256sum nor shasum is available; registry identity cannot be verified.",
         call. = FALSE)
  }
  hash <- strsplit(ans[[1L]], "[[:space:]]+")[[1L]][[1L]]
  if (!grepl("^[0-9a-f]{64}$", hash)) {
    stop("Could not parse a SHA-256 digest for ", path, call. = FALSE)
  }
  hash
}

cran07_read_registry <- function(path, expected_sha256 = NULL) {
  actual <- cran07_sha256(path)
  if (!is.null(expected_sha256) && !identical(actual, expected_sha256)) {
    stop("Frozen registry SHA-256 mismatch: expected ", expected_sha256,
         ", got ", actual, call. = FALSE)
  }
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("cell_number", "cell_id", "family", "mode", "n_unit",
                "n_traits", "rank", "truth_profile", "smoke_reps",
                "production_reps")
  absent <- setdiff(required, names(x))
  if (length(absent)) {
    stop("Registry is missing columns: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(x$cell_id) || anyDuplicated(x$cell_number)) {
    stop("Registry cell identifiers and numbers must be unique.", call. = FALSE)
  }
  attr(x, "sha256") <- actual
  x
}

cran07_campaign_spec <- function(campaign_id) {
  hit <- which(CRAN07_CAMPAIGNS$campaign_id == campaign_id)
  if (length(hit) != 1L) {
    stop("Unknown or non-frozen campaign ID: ", campaign_id, call. = FALSE)
  }
  CRAN07_CAMPAIGNS[hit, , drop = FALSE]
}

cran07_read_campaign_registry <- function(campaign_id, repo, registry_path = NULL) {
  spec <- cran07_campaign_spec(campaign_id)
  canonical <- normalizePath(file.path(repo, spec$registry_relpath), mustWork = TRUE)
  supplied <- if (is.null(registry_path)) canonical else
    normalizePath(registry_path, mustWork = TRUE)
  if (!identical(supplied, canonical)) {
    stop("Campaign ID is cross-wired to a non-canonical registry path.", call. = FALSE)
  }
  registry <- cran07_read_registry(canonical, spec$registry_sha256)
  attr(registry, "campaign_id") <- campaign_id
  registry
}

cran07_campaign_seed_offset <- function(campaign_id) {
  as.integer(cran07_campaign_spec(campaign_id)$seed_offset)
}

cran07_seed <- function(cell_number, replicate, campaign_offset = 270800000L) {
  seed <- as.double(campaign_offset) + as.double(cell_number) * 100000 + replicate
  if (!is.finite(seed) || seed < 1 || seed > .Machine$integer.max) {
    stop("Derived seed is outside the R integer seed range.", call. = FALSE)
  }
  as.integer(seed)
}

cran07_family <- function(name) {
  switch(name,
    gaussian = stats::gaussian(),
    poisson = stats::poisson(),
    nbinom2 = gllvmTMB::nbinom2(),
    binomial = stats::binomial(),
    stop("Unsupported frozen family: ", name, call. = FALSE)
  )
}

cran07_loading_truth <- function(profile, rank, n_traits, loading_sd = NA_real_) {
  if (n_traits != 3L) stop("Frozen DGP currently requires exactly three traits.", call. = FALSE)
  if (!is.na(loading_sd)) {
    if (rank != 1L) stop("loading_sd design requires rank one.", call. = FALSE)
    return(matrix(loading_sd * c(1, -0.75, 0.60), n_traits, 1L))
  }
  if (rank == 1L) return(matrix(c(0.55, -0.40, 0.35), n_traits, 1L))
  if (rank != 2L) stop("Frozen latent DGP supports rank one or two.", call. = FALSE)
  second <- function(rho) c(0.70 * rho, 0.70 * sqrt(max(0, 1 - rho^2)))
  rbind(
    c(0.70, 0),
    switch(profile,
      rho0 = second(0),
      rho_pos08 = second(0.8),
      rho_neg08 = second(-0.8),
      rho_boundary98 = second(0.98),
      c(0.35, 0.55)
    ),
    c(-0.20, 0.50)
  )
}

cran07_make_fixture <- function(cell, seed) {
  set.seed(seed)
  family_name <- as.character(cell$family)
  mode <- as.character(cell$mode)
  n_unit <- as.integer(cell$n_unit)
  n_traits <- as.integer(cell$n_traits)
  rank <- as.integer(cell$rank)
  profile <- as.character(cell$truth_profile)
  scenario <- if ("scenario" %in% names(cell)) as.character(cell$scenario) else "ordinary"
  loading_sd <- if ("loading_sd" %in% names(cell)) as.numeric(cell$loading_sd) else NA_real_
  missing_rate <- if ("missing_rate" %in% names(cell)) as.numeric(cell$missing_rate) else 0

  n_rep <- if (family_name == "binomial") 4L else 2L
  beta0 <- switch(family_name,
    gaussian = c(0.2, -0.1, 0.35),
    poisson = c(1.0, 0.8, 1.15),
    nbinom2 = c(1.0, 0.8, 1.15),
    binomial = c(-0.3, 0.1, 0.35),
    stop("Unsupported family in fixture.", call. = FALSE)
  )
  beta1 <- c(0.25, -0.20, 0.15)
  x_unit <- as.numeric(scale(seq_len(n_unit)))
  psi <- if (profile == "psi_small") rep(0.01, n_traits) else
    if (profile == "psi_large") rep(100, n_traits) else c(0.14, 0.10, 0.12)
  Sigma_dep <- matrix(c(0.42, 0.18, -0.08,
                        0.18, 0.35, 0.10,
                        -0.08, 0.10, 0.30), n_traits, n_traits, byrow = TRUE)
  Lambda <- if (mode == "latent")
    cran07_loading_truth(profile, rank, n_traits, loading_sd) else NULL
  Sigma_shared <- switch(mode,
    indep = matrix(0, n_traits, n_traits),
    dep = Sigma_dep,
    latent = tcrossprod(Lambda),
    stop("Unsupported covariance mode: ", mode, call. = FALSE)
  )
  Psi <- if (mode == "dep") matrix(0, n_traits, n_traits) else diag(psi)
  Sigma_total <- Sigma_shared + Psi
  B <- matrix(stats::rnorm(n_unit * n_traits), n_unit, n_traits) %*% chol(Sigma_total)

  dat <- expand.grid(rep = seq_len(n_rep), trait_idx = seq_len(n_traits),
                     unit_idx = seq_len(n_unit), KEEP.OUT.ATTRS = FALSE)
  dat$unit <- factor(dat$unit_idx)
  dat$trait <- factor(paste0("t", dat$trait_idx), levels = paste0("t", seq_len(n_traits)))
  dat$x <- x_unit[dat$unit_idx]
  if (identical(scenario, "rare_level")) {
    n_rare <- max(1L, round(0.05 * n_unit))
    habitat_unit <- rep(c("common_a", "common_b"), length.out = n_unit)
    habitat_unit[seq_len(n_rare)] <- "rare"
    habitat_unit <- sample(habitat_unit, n_unit, replace = FALSE)
    dat$habitat <- factor(habitat_unit[dat$unit_idx],
                          levels = c("common_a", "common_b", "rare"))
    formula <- value ~ 0 + trait + trait:x + trait:habitat + latent(0 + trait | unit, d = rank)
    fixed_formula <- ~ 0 + trait + trait:x + trait:habitat
  } else {
    formula <- switch(mode,
      indep = value ~ 0 + trait + trait:x + indep(0 + trait | unit),
      dep = value ~ 0 + trait + trait:x + dep(0 + trait | unit),
      latent = value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = rank)
    )
    fixed_formula <- ~ 0 + trait + trait:x
  }
  X <- stats::model.matrix(fixed_formula, dat)
  if (qr(X)$rank != ncol(X)) stop("Frozen fixed-effect design is rank deficient.", call. = FALSE)
  beta <- stats::setNames(rep(0, ncol(X)), colnames(X))
  for (t in seq_len(n_traits)) {
    beta[paste0("traitt", t)] <- beta0[t]
    slope_name <- paste0("traitt", t, ":x")
    if (!slope_name %in% names(beta)) slope_name <- paste0("x:traitt", t)
    beta[slope_name] <- beta1[t]
  }
  if (identical(scenario, "rare_level")) {
    rare_names <- grep("habitatrare", names(beta), value = TRUE)
    beta[rare_names] <- rep(c(0.45, -0.35, 0.30), length.out = length(rare_names))
    common_names <- grep("habitatcommon_b", names(beta), value = TRUE)
    beta[common_names] <- rep(c(0.10, -0.05, 0.08), length.out = length(common_names))
  }
  if (anyNA(beta)) stop("Fixed-effect truth could not be aligned to model-matrix columns.", call. = FALSE)
  eta <- drop(X %*% beta) + B[cbind(dat$unit_idx, dat$trait_idx)]
  n_trials <- if (family_name == "binomial")
    rep.int(CRAN07_BINOMIAL_N_TRIALS, nrow(dat)) else NULL
  dat$value <- switch(family_name,
    gaussian = eta + stats::rnorm(nrow(dat), sd = 0.45),
    poisson = stats::rpois(nrow(dat), exp(eta)),
    nbinom2 = stats::rnbinom(nrow(dat), mu = exp(eta), size = 5),
    binomial = stats::rbinom(nrow(dat), n_trials, stats::plogis(eta))
  )
  if (missing_rate > 0 || identical(scenario, "missing_response")) {
    rate <- if (missing_rate > 0) missing_rate else 0.20
    miss <- sample.int(nrow(dat), max(1L, floor(rate * nrow(dat))), replace = FALSE)
    dat$value[miss] <- NA
  }
  list(data = dat, formula = formula, family = cran07_family(family_name),
       missing_include = anyNA(dat$value), weights = n_trials, beta = beta,
       Sigma_shared = Sigma_shared, Psi = diag(Psi), Sigma_total = Sigma_total,
       dispersion = if (family_name == "nbinom2") 5 else NA_real_)
}

cran07_matrix_rows <- function(name, estimate, truth, cell_id, replicate, seed,
                               applicable = TRUE) {
  n <- nrow(truth)
  idx <- which(lower.tri(truth, diag = TRUE), arr.ind = TRUE)
  data.frame(cell_id = cell_id, replicate = replicate, seed = seed,
             estimand = name, component = paste0("t", idx[, 1], "_t", idx[, 2]),
             trait_i = idx[, 1], trait_j = idx[, 2], applicable = applicable,
             truth = truth[idx], estimate = if (applicable) estimate[idx] else NA_real_,
             stringsAsFactors = FALSE)
}

cran07_extract_estimands <- function(fit, fixture, cell_id, replicate, seed, mode) {
  ix <- names(fit$opt$par) == "b_fix"
  beta_hat <- as.numeric(fit$opt$par[ix])
  beta_names <- fit$X_fix_names
  if (length(beta_hat) != length(beta_names) || !setequal(beta_names, names(fixture$beta))) {
    stop("Fixed-effect extractor names do not exactly match frozen DGP truth.", call. = FALSE)
  }
  beta_truth <- fixture$beta[beta_names]
  beta_rows <- data.frame(cell_id = cell_id, replicate = replicate, seed = seed,
    estimand = "beta", component = beta_names, trait_i = NA_integer_, trait_j = NA_integer_,
    applicable = TRUE, truth = as.numeric(beta_truth), estimate = beta_hat,
    stringsAsFactors = FALSE)

  shared_applicable <- mode != "indep"
  psi_applicable <- mode != "dep"
  shared_hat <- if (shared_applicable)
    gllvmTMB::extract_Sigma(fit, level = "unit", part = "shared", link_residual = "none")$Sigma else
    matrix(NA_real_, nrow(fixture$Sigma_shared), ncol(fixture$Sigma_shared))
  psi_hat <- if (psi_applicable)
    as.numeric(gllvmTMB::extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none")$s) else
    rep(NA_real_, length(fixture$Psi))
  total_hat <- gllvmTMB::extract_Sigma(fit, level = "unit", part = "total",
                                      link_residual = "none")$Sigma
  dims <- dim(fixture$Sigma_total)
  if (!identical(dim(total_hat), dims) ||
      (shared_applicable && !identical(dim(shared_hat), dims)) ||
      (psi_applicable && length(psi_hat) != dims[[1L]])) {
    stop("Sigma/Psi extractor dimensions do not match frozen truth.", call. = FALSE)
  }
  psi_matrix_hat <- diag(psi_hat, nrow = dims[[1L]])
  rows <- rbind(beta_rows,
    cran07_matrix_rows("Sigma_shared", shared_hat, fixture$Sigma_shared,
                       cell_id, replicate, seed, shared_applicable),
    cran07_matrix_rows("Psi", psi_matrix_hat, diag(fixture$Psi),
                       cell_id, replicate, seed, psi_applicable),
    cran07_matrix_rows("Sigma_total", total_hat, fixture$Sigma_total,
                       cell_id, replicate, seed, TRUE))
  pair <- which(lower.tri(fixture$Sigma_total), arr.ind = TRUE)
  truth_cor <- stats::cov2cor(fixture$Sigma_total)
  est_cor <- stats::cov2cor(total_hat)
  corr <- data.frame(cell_id = cell_id, replicate = replicate, seed = seed,
    estimand = "correlation_total", component = paste0("t", pair[, 1], "_t", pair[, 2]),
    trait_i = pair[, 1], trait_j = pair[, 2], applicable = TRUE,
    truth = truth_cor[pair], estimate = est_cor[pair], stringsAsFactors = FALSE)
  if (shared_applicable) {
    truth_shared_cor <- stats::cov2cor(fixture$Sigma_shared)
    est_shared_cor <- stats::cov2cor(shared_hat)
    shared_corr <- data.frame(cell_id = cell_id, replicate = replicate, seed = seed,
      estimand = "correlation_shared", component = paste0("t", pair[, 1], "_t", pair[, 2]),
      trait_i = pair[, 1], trait_j = pair[, 2], applicable = TRUE,
      truth = truth_shared_cor[pair], estimate = est_shared_cor[pair], stringsAsFactors = FALSE)
  } else {
    shared_corr <- data.frame(cell_id = cell_id, replicate = replicate, seed = seed,
      estimand = "correlation_shared", component = paste0("t", pair[, 1], "_t", pair[, 2]),
      trait_i = pair[, 1], trait_j = pair[, 2], applicable = FALSE,
      truth = NA_real_, estimate = NA_real_, stringsAsFactors = FALSE)
  }
  rbind(rows, corr, shared_corr)
}

cran07_rebuild_matrix <- function(z, field) {
  n <- max(z$trait_i, z$trait_j)
  ans <- matrix(0, n, n)
  ans[cbind(z$trait_i, z$trait_j)] <- z[[field]]
  ans + t(ans) - diag(diag(ans))
}

cran07_assess_estimands <- function(estimands) {
  use <- estimands$applicable
  finite <- all(is.finite(estimands$estimate[use]))
  boundary <- FALSE
  geometry_flag <- FALSE
  relative_covariance_error <- if (finite) 0 else Inf
  max_eigen_ratio <- if (finite) 0 else Inf
  if (finite) {
    variance <- estimands$estimate[use & estimands$estimand %in% c("Psi", "Sigma_total") &
                                    estimands$trait_i == estimands$trait_j]
    rho <- estimands$estimate[use & estimands$estimand == "correlation_total"]
    boundary <- any(variance < CRAN07_BOUNDARY_VARIANCE) ||
      any(abs(rho) >= CRAN07_BOUNDARY_CORRELATION)
    total <- estimands[use & estimands$estimand == "Sigma_total", ]
    total_est <- cran07_rebuild_matrix(total, "estimate")
    eig_total <- eigen(total_est, symmetric = TRUE, only.values = TRUE)$values
    largest <- max(eig_total)
    geometry_flag <- min(eig_total) < -sqrt(.Machine$double.eps) ||
      largest <= 0 || min(eig_total) <= largest / CRAN07_GEOMETRY_CONDITION_NUMBER
    for (nm in c("Sigma_shared", "Sigma_total")) {
      z <- estimands[use & estimands$estimand == nm, ]
      if (!nrow(z)) next
      est <- cran07_rebuild_matrix(z, "estimate")
      truth <- cran07_rebuild_matrix(z, "truth")
      denom <- sqrt(sum(truth^2))
      rel <- if (denom > 0) sqrt(sum((est - truth)^2)) / denom else 0
      eig_ratio <- max(eigen(est, symmetric = TRUE, only.values = TRUE)$values) /
        max(eigen(truth, symmetric = TRUE, only.values = TRUE)$values)
      relative_covariance_error <- max(relative_covariance_error, rel)
      max_eigen_ratio <- max(max_eigen_ratio, eig_ratio)
    }
  }
  catastrophic_truth_error <- !finite ||
    relative_covariance_error > CRAN07_CATASTROPHIC_RELATIVE_FROBENIUS ||
    max_eigen_ratio > CRAN07_CATASTROPHIC_EIGEN_RATIO
  list(finite = finite, boundary = boundary, geometry_flag = geometry_flag,
       catastrophic_truth_error = catastrophic_truth_error,
       relative_covariance_error = relative_covariance_error,
       max_eigen_ratio = max_eigen_ratio)
}

cran07_binomial_gate_evidence <- function(fit, fixture) {
  if (is.null(fixture$weights)) {
    return(list(n_trials_min = NA_integer_, n_trials_max = NA_integer_,
                diag_B_skip = "", diag_B_all_free = NA))
  }
  expected <- as.integer(fixture$weights)
  observed <- !is.na(fixture$data$value)
  actual <- as.integer(fit$tmb_data$n_trials)
  skip <- as.integer(fit$tmb_data$diag_B_skip)
  if (length(actual) != length(expected) ||
      any(actual[observed] != expected[observed]) ||
      any(expected[observed] != CRAN07_BINOMIAL_N_TRIALS)) {
    stop("Multi-trial binomial n_trials did not survive the weights API exactly.", call. = FALSE)
  }
  if (length(skip) != nlevels(fixture$data$trait) || any(skip != 0L)) {
    stop("Multi-trial binomial Psi was mapped off by diag_B_skip.", call. = FALSE)
  }
  list(n_trials_min = min(actual[observed]), n_trials_max = max(actual[observed]),
       diag_B_skip = paste(skip, collapse = ";"), diag_B_all_free = TRUE)
}
