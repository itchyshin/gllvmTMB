# Frozen targeted quasi-complete supplement for Lane B B2.

lane_b_quasi_version <- function() "lane-b-quasi-v1-2026-08-08"

lane_b_quasi_source_receipt <- function() {
  d <- lane_b_harness_dir()
  files <- c("lane-b-b2-common.R", "lane-b-b2-runner.R",
             "lane-b-quasi-supplement.R", "5_run_lane_b_quasi.R",
             "SYMBOLIC-ALIGNMENT.md", "lane-b-quasi-fir-setup-v1.sh",
             "lane-b-quasi-fir-array-v1.sh",
             "lane-b-quasi-fir-aggregate-v1.sh",
             "lane-b-quasi-fir-keeper-v1.sh")
  setNames(vapply(file.path(d, files), lane_b_sha256_file, character(1L)), files)
}

lane_b_quasi_runtime_receipt <- function() {
  if (!requireNamespace("gllvmTMB", quietly = TRUE))
    stop("gllvmTMB must be installed before freezing the quasi runtime.")
  libs <- list.files(system.file("libs", package = "gllvmTMB"),
                     pattern = paste0("\\", .Platform$dynlib.ext, "$"),
                     full.names = TRUE)
  if (!length(libs)) stop("Installed gllvmTMB shared library is missing.")
  list(
    r_version = R.version.string,
    package_version = as.character(utils::packageVersion("gllvmTMB")),
    tmb_version = as.character(utils::packageVersion("TMB")),
    detector_version = as.character(utils::packageVersion("detectseparation")),
    installed_dll_sha256 = setNames(vapply(libs, lane_b_sha256_file, character(1L)),
                                    basename(libs))
  )
}

lane_b_quasi_manifest <- function() {
  g <- expand.grid(
    link = lane_b_links(), q = c(1L, 2L), loading_sd = c(0.5, 1.5),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  g <- g[order(match(g$link, lane_b_links()), g$q, g$loading_sd), , drop = FALSE]
  rownames(g) <- NULL
  g$cell_index <- 200L + seq_len(nrow(g))
  g$cell_id <- sprintf("Q%03d", seq_len(nrow(g)))
  g$n_unit <- 200L
  g$n_trait <- 6L
  g$n_slope <- 3L
  g$dimension <- "targeted_quasi"
  g$prevalence <- "balanced"
  g$target_prevalence <- "conditional_quasi_trait1;finite_0.5_other_traits"
  g$n_rep <- 500L
  g$truth_seed_key <- 1760000000 + seq_len(nrow(g))
  g$calibration_seed_key <- 1761000000 + seq_len(nrow(g))
  g$dimension_profile <- "targeted_quasi"
  g$prevalence_profile <- "targeted_quasi"
  g$n_trait_slopes <- g$n_slope
  g$p_beta <- g$n_trait * (1L + g$n_slope)
  g$attempts <- g$n_rep
  g$truth_seed <- g$truth_seed_key
  g$calibration_seed <- g$calibration_seed_key
  g$data_seed_base <- 700000000 + g$cell_index * 2000
  g$start_seed_base <- 800000000 + g$cell_index * 2000
  g$prevalence_targets <- g$target_prevalence
  g$manifest_version <- lane_b_manifest_version()
  g$supplement_version <- lane_b_quasi_version()
  g[, c("manifest_version", "supplement_version", "cell_id", "cell_index",
        "link", "n_unit", "n_trait", "n_slope", "q", "dimension",
        "prevalence", "target_prevalence", "loading_sd", "n_rep",
        "truth_seed_key", "calibration_seed_key", "dimension_profile",
        "prevalence_profile", "n_trait_slopes", "p_beta", "attempts",
        "truth_seed", "calibration_seed", "data_seed_base", "start_seed_base",
        "prevalence_targets")]
}

lane_b_quasi_queue <- function(manifest = lane_b_quasi_manifest(), shard_size = 10L) {
  rows <- lapply(seq_len(nrow(manifest)), function(i) {
    chunks <- split(seq_len(manifest$n_rep[[i]]),
                    ceiling(seq_len(manifest$n_rep[[i]]) / shard_size))
    do.call(rbind, lapply(seq_along(chunks), function(j) data.frame(
      shard_id = sprintf("quasi-%s-%04d", manifest$cell_id[[i]], j),
      cell_id = manifest$cell_id[[i]], cell_index = manifest$cell_index[[i]],
      replicate_first = min(chunks[[j]]), replicate_last = max(chunks[[j]]),
      dataset_count = length(chunks[[j]]),
      primary_attempt_count = length(chunks[[j]]) * nrow(lane_b_arms()),
      stringsAsFactors = FALSE
    )))
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

lane_b_quasi_design <- function(n, state) {
  if (n < 16L) stop("Targeted quasi-complete design requires at least 16 units.")
  x <- lane_b_with_state(state, matrix(rnorm(n * 3L), nrow = n, ncol = 3L))
  nonboundary <- n - 8L
  n_negative <- nonboundary %/% 2L
  n_positive <- nonboundary - n_negative
  x[, 1L] <- c(rep(0, 8L), rep(-1, n_negative), rep(1, n_positive))
  boundary <- rbind(c(0, 0), c(0, 0), c(1, 0), c(1, 0),
                    c(0, 1), c(0, 1), c(1, 1), c(1, 1))
  x[seq_len(8L), 2:3] <- boundary
  colnames(x) <- paste0("x", seq_len(ncol(x)))
  if (qr(cbind(1, x))$rank != 4L) stop("Targeted quasi design lost fixed-design rank.")
  x
}

lane_b_generate_targeted_quasi <- function(cell, replicate_id,
                                            calibration_n = 200000L,
                                            integration_n = 2048L) {
  keys <- lane_b_seed_keys(cell$cell_index[[1L]], replicate_id)
  streams <- lane_b_substreams(keys[["data"]])
  truth <- lane_b_cell_truth(cell, calibration_n = calibration_n)
  n <- cell$n_unit[[1L]]
  nt <- cell$n_trait[[1L]]
  x <- lane_b_quasi_design(n, streams[[2L]])
  u <- lane_b_with_state(streams[[3L]], matrix(rnorm(n * cell$q[[1L]]), n))
  eta <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    x %*% t(truth$beta) + u %*% t(truth$lambda)
  probability <- lane_b_inv_link(eta, cell$link[[1L]])
  y <- lane_b_with_state(
    streams[[4L]], matrix(rbinom(length(probability), 1L, probability), n, nt)
  )
  nonboundary <- n - 8L
  n_negative <- nonboundary %/% 2L
  y[, 1L] <- c(rep(c(0L, 1L), 4L), rep(0L, n_negative),
                rep(1L, nonboundary - n_negative))

  test_draw <- lane_b_with_state(streams[[5L]], list(
    x = matrix(rnorm(n * cell$n_slope[[1L]]), n),
    u = matrix(rnorm(n * cell$q[[1L]]), n),
    y_uniform = matrix(runif(n * nt), n, nt)
  ))
  integration_z <- lane_b_with_state(
    streams[[6L]], matrix(rnorm(integration_n * cell$q[[1L]]), integration_n)
  )
  colnames(test_draw$x) <- colnames(x)
  eta_test <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    test_draw$x %*% t(truth$beta) + test_draw$u %*% t(truth$lambda)
  probability_test <- lane_b_inv_link(eta_test, cell$link[[1L]])
  y_test <- 1L * (test_draw$y_uniform < probability_test)
  fixed_test <- matrix(truth$intercept, n, nt, byrow = TRUE) +
    test_draw$x %*% t(truth$beta)
  latent_mc <- integration_z %*% t(truth$lambda)
  marginal <- vapply(seq_len(nt), function(t) {
    rowMeans(lane_b_inv_link(outer(fixed_test[, t], latent_mc[, t], "+"),
                              cell$link[[1L]]))
  }, numeric(n))
  train <- lane_b_long_frame(y, x, offset = 0)
  test <- lane_b_long_frame(y_test, test_draw$x, offset = 0)
  test$truth_probability <- as.numeric(t(marginal))
  list(train = train, test = test, truth = truth, cell = cell,
       replicate_id = replicate_id, seed_keys = keys,
       empirical_prevalence = colMeans(y), quasi_target_trait = "trait_01")
}

lane_b_quasi_paths <- function(root) {
  root <- lane_b_validate_campaign_root(root)
  rel <- c("frozen", "queue", "raw", "state/complete", "state/running",
           "state/failed", "summaries", "session")
  out <- file.path(root, rel)
  names(out) <- rel
  out
}

lane_b_release_lock <- function(lock) {
  if (file.exists(lock)) unlink(lock)
  !file.exists(lock)
}

lane_b_quasi_cell_metrics <- function(attempts,
                                      manifest = lane_b_quasi_manifest()) {
  th <- lane_b_thresholds()
  out <- lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    z <- attempts[attempts$cell_id == cell$cell_id &
                    attempts$arm == "mspl", , drop = FALSE]
    mspl <- z[z$start_role == "primary", , drop = FALSE]
    alternate <- z[z$start_role == "alternate", , drop = FALSE]
    first_status <- vapply(strsplit(mspl$b0_status_hash, ";", fixed = TRUE),
                           `[[`, character(1L), 1L)
    usable <- mspl$usable %in% TRUE
    rate <- if (nrow(mspl)) mean(usable) else NA_real_
    wilson <- lane_b_wilson_lower(sum(usable), nrow(mspl))
    stationary <- nrow(mspl) > 0L && any(usable) &&
      all(is.finite(mspl$scaled_gradient[usable])) &&
      all(mspl$scaled_gradient[usable] <= th$scaled_gradient)
    no_boundary <- nrow(mspl) > 0L && !any(mspl$bound_or_clamp %in% TRUE)
    paired <- merge(
      mspl[c("replicate_id", "usable")],
      alternate[c("replicate_id", "status", "optimizer_success", "usable",
                  "scaled_gradient", "sigma_rank", "expected_sigma_rank",
                  "bound_or_clamp", "objective")],
      by = "replicate_id", suffixes = c("_primary", "_alternate"),
      all.x = TRUE, sort = FALSE
    )
    paired_usable <- paired$usable_primary %in% TRUE
    alternate_health <- nrow(paired) == nrow(mspl) && any(paired_usable) &&
      all(paired$status[paired_usable] == "success") &&
      all(paired$optimizer_success[paired_usable] %in% TRUE) &&
      all(paired$usable_alternate[paired_usable] %in% TRUE) &&
      all(is.finite(paired$scaled_gradient[paired_usable])) &&
      all(paired$scaled_gradient[paired_usable] <= th$scaled_gradient) &&
      all(is.finite(paired$objective[paired_usable])) &&
      !any(paired$bound_or_clamp[paired_usable] %in% TRUE) &&
      all(!is.na(paired$sigma_rank[paired_usable])) &&
      all(paired$sigma_rank[paired_usable] ==
            paired$expected_sigma_rank[paired_usable])
    multistart <- alternate_health &&
      all(is.finite(mspl$alternate_objective_gap[usable])) &&
      all(is.finite(mspl$alternate_covariance_gap[usable])) &&
      all(abs(mspl$alternate_objective_gap[usable]) <=
            th$objective_gap_scale * (1 + abs(mspl$objective[usable]))) &&
      all(mspl$alternate_covariance_gap[usable] <= th$covariance_multistart)
    certificate <- nrow(mspl) == cell$n_rep[[1L]] &&
      !anyDuplicated(mspl$replicate_id) &&
      setequal(mspl$replicate_id, seq_len(cell$n_rep[[1L]])) &&
      length(first_status) == cell$n_rep[[1L]] &&
      all(first_status == "QUASI_COMPLETE")
    data.frame(
      cell_id = cell$cell_id, link = cell$link, q = cell$q,
      loading_sd = cell$loading_sd, attempted = nrow(mspl),
      quasi_certificate_exact = certificate, usable = sum(usable),
      usable_rate = rate, usable_mcse = if (nrow(mspl) && is.finite(rate))
        sqrt(rate * (1 - rate) / nrow(mspl)) else NA_real_,
      usable_wilson_lower = wilson, stationary = stationary,
      no_boundary_or_clamp = no_boundary, multistart_agreement = multistart,
      alternate_health = alternate_health,
      pass = certificate && is.finite(rate) && rate >= th$separated_usable &&
        wilson >= th$separated_wilson_lower && stationary && no_boundary &&
        multistart,
      stringsAsFactors = FALSE
    )
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans
}

lane_b_quasi_family_gate <- function(metrics) {
  keys <- unique(metrics[c("link", "q")])
  out <- lapply(seq_len(nrow(keys)), function(i) {
    z <- metrics[metrics$link == keys$link[[i]] & metrics$q == keys$q[[i]], ]
    data.frame(link = keys$link[[i]], q = keys$q[[i]], cells = nrow(z),
      passing_cells = sum(z$pass %in% TRUE),
      pass = nrow(z) == 2L && all(z$pass), stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

lane_b_validate_quasi_summary_tables <- function(summary,
                                                  manifest = lane_b_quasi_manifest()) {
  recomputed_metrics <- lane_b_quasi_cell_metrics(summary$attempts, manifest)
  recomputed_gate <- lane_b_quasi_family_gate(recomputed_metrics)
  recomputed_label <- if (all(recomputed_gate$pass)) "QUASI-PROMOTION-PASS" else
    "QUASI-PROMOTION-WITHHELD"
  if (!identical(summary$cell_metrics, recomputed_metrics) ||
      !identical(summary$family_gate, recomputed_gate) ||
      !identical(summary$label, recomputed_label))
    stop("Quasi summary label or metrics disagree with the retained attempts.")

  expected <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    z <- expand.grid(replicate_id = seq_len(manifest$n_rep[[i]]),
                     arm = lane_b_arms()$arm_id,
                     start_role = c("primary", "alternate"),
                     stringsAsFactors = FALSE)
    z$cell_id <- manifest$cell_id[[i]]
    z
  }))
  key <- function(x) paste(x$cell_id, x$replicate_id, x$arm, x$start_role, sep = ":")
  observed_key <- key(summary$attempts); expected_key <- key(expected)
  if (nrow(summary$attempts) != length(expected_key) || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key))
    stop("Quasi attempt ledger is not exactly manifest x four arms x two starts.")

  metrics <- summary$cell_metrics
  gate <- summary$family_gate
  expected_gate <- unique(manifest[c("link", "q")])
  if (nrow(metrics) != nrow(manifest) || anyDuplicated(metrics$cell_id) ||
      !setequal(metrics$cell_id, manifest$cell_id) ||
      !all(metrics$quasi_certificate_exact %in% TRUE) ||
      nrow(gate) != nrow(expected_gate) ||
      !setequal(paste(gate$link, gate$q), paste(expected_gate$link, expected_gate$q)))
    stop("Quasi cell or family summary is incomplete or inconsistent.")
  invisible(TRUE)
}

lane_b_validate_quasi_summary <- function(summary, root,
                                           manifest = lane_b_quasi_manifest()) {
  required <- c("label", "supplement_version", "manifest_version", "attempts",
                "cell_metrics", "family_gate", "source_sha256")
  if (!all(required %in% names(summary)) ||
      !identical(summary$supplement_version, lane_b_quasi_version()) ||
      !identical(summary$manifest_version, lane_b_manifest_version()))
    stop("Quasi summary provenance does not match the frozen supplement.")

  paths <- lane_b_quasi_paths(root)
  frozen_path <- file.path(paths[["frozen"]], "lane-b-quasi-frozen-v1.rds")
  receipt_path <- file.path(paths[["session"]], "prepare-receipt-v1.rds")
  if (!file.exists(frozen_path) || !file.exists(receipt_path))
    stop("Quasi frozen state or preparation receipt is missing.")
  frozen <- readRDS(frozen_path); receipt <- readRDS(receipt_path)
  if (!identical(frozen$source_sha256, summary$source_sha256) ||
      !identical(receipt$frozen_sha256, lane_b_sha256_file(frozen_path)) ||
      !identical(frozen$runtime_receipt, receipt$runtime_receipt) ||
      !identical(receipt$source_tarball_sha256, frozen$source_tarball_sha256) ||
      !grepl("^[0-9a-f]{64}$", frozen$source_tarball_sha256))
    stop("Quasi frozen state hash does not match its summary receipt.")

  verified <- lane_b_verify_shard_receipts(
    frozen$queue, paths[["raw"]], paths[["state/complete"]],
    hash_field = "raw_sha256", require_complete = TRUE
  )
  verified_attempts <- do.call(rbind, verified$attempts)
  if (!identical(verified_attempts, summary$attempts))
    stop("Quasi summary attempts differ from the SHA-256-verified raw shards.")

  lane_b_validate_quasi_summary_tables(summary, manifest)
}
