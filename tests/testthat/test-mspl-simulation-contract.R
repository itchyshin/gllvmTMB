lane_b_sim_file <- function(filename) {
  source_path <- file.path(
    testthat::test_path(), "..", "..", "inst", "sim", "lane-b", filename
  )
  if (file.exists(source_path)) {
    return(normalizePath(source_path))
  }

  installed_path <- system.file("sim", "lane-b", filename, package = "gllvmTMB")
  if (nzchar(installed_path) && file.exists(installed_path)) {
    return(normalizePath(installed_path))
  }

  stop("Cannot locate installed Lane B simulation helper: ", filename)
}

common_path <- lane_b_sim_file("lane-b-b2-common.R")
runner_path <- lane_b_sim_file("lane-b-b2-runner.R")
adjudication_path <- lane_b_sim_file("lane-b-b2-adjudication.R")
quasi_path <- lane_b_sim_file("lane-b-quasi-supplement.R")
source(common_path, local = environment())
source(runner_path, local = environment())
source(adjudication_path, local = environment())
source(quasi_path, local = environment())

test_that("frozen ordinary manifest has the exact campaign cardinality", {
  manifest <- lane_b_ordinary_manifest()
  expect_equal(nrow(manifest), 96L)
  expect_equal(sum(manifest$n_rep), 72000L)
  expect_equal(sum(manifest$n_rep) * 4L, 288000L)
  expect_equal(as.integer(table(factor(manifest$link, levels = lane_b_links()))),
               rep(32L, 3L))
  expect_equal(sum(manifest$n_rep[manifest$prevalence == "balanced"]), 24000L)
  expect_equal(sum(manifest$n_rep[manifest$prevalence == "mixed_extreme"]), 48000L)
  expect_identical(manifest$cell_id[c(1L, 7L, 96L)], c("O001", "O007", "O096"))
  expect_identical(manifest$dimension_profile[[1L]], "high")
  expect_identical(manifest$prevalence_profile[[3L]], "mixed_extremes")
  expect_equal(manifest$data_seed_base, 700000000 + manifest$cell_index * 2000)
})

test_that("targeted quasi supplement is frozen and exact for all links and ranks", {
  manifest <- lane_b_quasi_manifest()
  expect_equal(nrow(manifest), 12L)
  expect_equal(sum(manifest$n_rep), 6000L)
  expect_equal(nrow(lane_b_quasi_queue(manifest)), 600L)
  probe <- manifest[!duplicated(manifest[c("link", "q")]), , drop = FALSE]
  statuses <- vapply(seq_len(nrow(probe)), function(i) {
    dat <- lane_b_generate_targeted_quasi(probe[i, , drop = FALSE], 1L,
                                          calibration_n = 5000L,
                                          integration_n = 64L)
    expect_equal(qr(cbind(1, unique(dat$train[c("unit", "x1", "x2", "x3")])[-1L]))$rank,
                 4L)
    unname(lane_b_b0_status_by_trait(dat)[[1L]])
  }, character(1L))
  expect_equal(statuses, rep("QUASI_COMPLETE", 6L))
})

test_that("targeted quasi lock cleanup is explicit and idempotent", {
  lock <- tempfile("lane-b-quasi-lock-")
  expect_true(file.create(lock))
  expect_true(lane_b_release_lock(lock))
  expect_false(file.exists(lock))
  expect_true(lane_b_release_lock(lock))
})

test_that("deterministic seed registry is collision-free and arm order rotates", {
  manifest <- lane_b_ordinary_manifest()
  small <- manifest[c(1L, 96L), ]
  small$n_rep <- c(2L, 2L)
  a <- lane_b_seed_registry(small)
  b <- lane_b_seed_registry(small)
  expect_identical(a, b)
  expect_equal(nrow(a), 4L)
  expect_equal(unname(vapply(a[c("data_seed_key", "start_seed_key", "prediction_seed_key",
                                 "alternate_seed_key")], anyDuplicated, integer(1))),
               rep(0L, 4L))
  expect_identical(lane_b_arm_order(1L),
                   c("ml", "ml_ridge", "mspl", "mspl_ridge_internal"))
  expect_identical(lane_b_arm_order(2L),
                   c("ml_ridge", "mspl", "mspl_ridge_internal", "ml"))
  expect_identical(lane_b_substreams(700002001), lane_b_substreams(700002001))
})

test_that("queue is resumable at the frozen shard size", {
  queue <- lane_b_build_queue(shard_size = 25L)
  expect_equal(nrow(queue), 2880L)
  expect_equal(sum(queue$dataset_count), 72000L)
  expect_equal(sum(queue$primary_attempt_count), 288000L)
  expect_true(all(queue$dataset_count == 25L))
  smoke <- lane_b_build_queue(smoke = TRUE)
  expect_equal(nrow(smoke), 1L)
  expect_identical(smoke$shard_id, "ordinary-O007-0001")
  expect_equal(smoke$primary_attempt_count, 4L)
})

test_that("permutation and spatial manifests match frozen execution counts", {
  permutation <- lane_b_permutation_manifest()
  spatial <- lane_b_spatial_manifest()
  expect_equal(nrow(permutation), 24L)
  expect_equal(sum(permutation$audit_attempts), 4800L)
  expect_equal(nrow(spatial), 72L)
  expect_equal(sum(spatial$attempts), 54000L)
  expect_equal(table(spatial$structure),
               table(factor(rep(c("spatial_indep", "spatial_latent_q1",
                                  "spatial_latent_q2"), each = 24L))))
  queue <- lane_b_build_all_queue()
  expect_equal(as.integer(table(factor(queue$table,
                                       levels = c("ordinary", "permutation", "spatial")))),
               c(2880L, 192L, 5400L))
  expect_equal(sum(queue$dataset_count), 130800L)
  expect_equal(sum(queue$primary_attempt_count), 561600L)
  expect_equal(nrow(lane_b_seed_registry_all()), 130800L)
})

test_that("ordinary-only corrected campaign scope is explicit and resumable", {
  ordinary <- lane_b_ordinary_manifest()
  permutation <- lane_b_permutation_manifest(ordinary)
  empty_spatial <- lane_b_spatial_manifest()[0, , drop = FALSE]
  queue <- lane_b_build_all_queue(
    ordinary, permutation, empty_spatial, include_spatial = FALSE
  )
  expect_equal(as.integer(table(factor(queue$table,
                                       levels = c("ordinary", "permutation", "spatial")))),
               c(2880L, 192L, 0L))
  expect_equal(sum(queue$dataset_count), 76800L)
  expect_equal(sum(queue$primary_attempt_count), 345600L)
  expect_equal(nrow(lane_b_seed_registry_all(ordinary, permutation, empty_spatial)),
               76800L)

  root <- tempfile("lane-b-ordinary-only-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  receipt <- lane_b_prepare(lane_b_parse_cli(c(
    "prepare", "--root", root, "--smoke", "--ordinary-only"
  )))
  frozen <- readRDS(file.path(root, "frozen", "lane-b-b2-frozen.rds"))
  expect_identical(frozen$campaign_scope, "ordinary_only")
  expect_equal(receipt$campaign_scope, "ordinary_only")
  expect_equal(receipt$cells, 2L)
  expect_equal(receipt$datasets, 2L)
  expect_equal(receipt$primary_attempts, 16L)
  expect_equal(receipt$shards, 2L)
})

test_that("aggregation verifies exact shard receipts and raw SHA-256 values", {
  root <- tempfile("lane-b-receipts-")
  raw_dir <- file.path(root, "raw")
  complete_dir <- file.path(root, "complete")
  dir.create(raw_dir, recursive = TRUE)
  dir.create(complete_dir, recursive = TRUE)
  queue <- data.frame(shard_id = c("s1", "s2"), stringsAsFactors = FALSE)
  objects <- list(s1 = data.frame(x = 1:2), s2 = data.frame(x = 3:5))
  for (id in queue$shard_id) {
    raw_path <- file.path(raw_dir, paste0(id, ".rds"))
    hash <- lane_b_atomic_save_rds(objects[[id]], raw_path)
    lane_b_atomic_save_rds(
      list(shard_id = id, status = "complete", rows = nrow(objects[[id]]),
           sha256 = hash),
      file.path(complete_dir, paste0(id, ".rds"))
    )
  }
  verified <- lane_b_verify_shard_receipts(
    queue, raw_dir, complete_dir, hash_field = "sha256"
  )
  expect_identical(verified$ids, queue$shard_id)
  expect_identical(verified$attempts, unname(objects))

  lane_b_atomic_save_rds(data.frame(x = 99), file.path(raw_dir, "s1.rds"))
  expect_error(
    lane_b_verify_shard_receipts(queue, raw_dir, complete_dir),
    "SHA-256 mismatch"
  )

  raw_hash <- lane_b_atomic_save_rds(objects$s1, file.path(raw_dir, "s1.rds"))
  lane_b_atomic_save_rds(
    list(shard_id = "s1", status = "complete",
         rows = nrow(objects$s1) + 1L, sha256 = raw_hash),
    file.path(complete_dir, "s1.rds")
  )
  expect_error(
    lane_b_verify_shard_receipts(queue, raw_dir, complete_dir),
    "row count mismatch"
  )

  lane_b_atomic_save_rds(data.frame(x = 1), file.path(raw_dir, "unexpected.rds"))
  expect_error(
    lane_b_verify_shard_receipts(queue, raw_dir, complete_dir),
    "unexpected IDs"
  )
})

test_that("B0 provenance is bound to the immutable launch source receipt", {
  frozen <- lane_b_b0_frozen_source_receipt("v3")
  expect_true(lane_b_validate_b0_source_receipt(frozen, "v3"))

  altered <- frozen
  altered[[1L]] <- paste0(substr(altered[[1L]], 1L, 63L), "0")
  if (identical(altered[[1L]], frozen[[1L]])) altered[[1L]] <- paste0(
    substr(altered[[1L]], 1L, 63L), "1"
  )
  expect_error(
    lane_b_validate_b0_source_receipt(altered, "v3"),
    "does not match the immutable v3 launch source receipt"
  )
  expect_error(
    lane_b_b0_frozen_source_receipt("v4"),
    "No immutable B0 source receipt"
  )
})

test_that("permutation invariance is exact-ledger and headline gating evidence", {
  manifest <- lane_b_permutation_manifest()[1L, , drop = FALSE]
  manifest$audit_attempts <- 2L
  attempts <- expand.grid(
    replicate_id = seq_len(manifest$audit_attempts),
    arm = lane_b_arms()$arm_id,
    start_role = c("primary", "alternate"),
    order_role = c("original", "reverse", "random"),
    stringsAsFactors = FALSE
  )
  attempts$cell_id <- manifest$audit_cell_id
  attempts$table <- "permutation"
  attempts$objective <- 100
  attempts$beta_vector <- lane_b_pack_numeric(c(1, 2))
  attempts$sigma_vector <- lane_b_pack_numeric(diag(2L))
  attempts$b0_status_hash <- "OVERLAP"
  attempts$sigma_rank <- manifest$q
  attempts$expected_sigma_rank <- manifest$q
  attempts$usable <- TRUE

  metrics <- lane_b_adjudicate_permutation(attempts, manifest)
  gate <- lane_b_permutation_family_gate(metrics, manifest)
  expect_equal(nrow(metrics), 4L)
  expect_true(gate$pass)
  expect_true(lane_b_final_promotion_labels(
    data.frame(pass = TRUE), data.frame(pass = TRUE), gate
  )$overall_pass)

  expect_error(
    lane_b_adjudicate_permutation(attempts[-1L, ], manifest),
    "not exactly"
  )
  bad <- attempts
  idx <- bad$arm == "mspl" & bad$start_role == "primary" &
    bad$replicate_id == 1L & bad$order_role == "reverse"
  bad$objective[idx] <- 101
  bad_gate <- lane_b_permutation_family_gate(
    lane_b_adjudicate_permutation(bad, manifest), manifest
  )
  expect_false(bad_gate$pass)
  labels <- lane_b_final_promotion_labels(
    data.frame(pass = TRUE), data.frame(pass = TRUE), bad_gate
  )
  expect_false(labels$ordinary_pass)
  expect_false(labels$spatial_pass)
  expect_identical(labels$overall_label, "LANE-B-PROMOTION-WITHHELD")

  nonstationary <- attempts
  nonstationary$usable <- FALSE
  nonstationary_gate <- lane_b_permutation_family_gate(
    lane_b_adjudicate_permutation(nonstationary, manifest), manifest
  )
  expect_false(nonstationary_gate$pass)
})

test_that("ordinary simulator is deterministic, complete, and whole-unit", {
  cell <- lane_b_ordinary_manifest()
  cell <- cell[cell$cell_id == "O007", , drop = FALSE]
  a <- lane_b_generate_ordinary(cell, 1L, calibration_n = 2000L, integration_n = 64L)
  b <- lane_b_generate_ordinary(cell, 1L, calibration_n = 2000L, integration_n = 64L)
  expect_identical(a$train, b$train)
  expect_identical(a$test, b$test)
  expect_equal(nrow(a$train), cell$n_unit * cell$n_trait)
  expect_equal(nrow(a$test), cell$n_unit * cell$n_trait)
  expect_true(all(table(a$train$unit) == cell$n_trait))
  expect_true(all(table(a$test$unit) == cell$n_trait))
  expect_true(all(a$train$value %in% 0:1))
  expect_true(all(is.finite(a$train$offset)))
  expect_true(all(a$train$offset == 0))
  expect_true(all(is.finite(a$test$truth_probability)))
  expect_true(all(a$test$truth_probability > 0 & a$test$truth_probability < 1))
  expect_equal(lane_b_matrix_rank(a$truth$Sigma), cell$q)
})

test_that("permutation audit preserves data and spatial simulation withholds a block", {
  audit <- lane_b_permutation_manifest()[1L, , drop = FALSE]
  p <- lane_b_generate_permutation(audit, 1L, calibration_n = 1000L,
                                   integration_n = 32L)
  expect_identical(names(p), c("original", "reverse", "random"))
  expect_equal(sort(p$original$train$value), sort(p$reverse$train$value))
  expect_equal(sort(p$original$train$value), sort(p$random$train$value))
  expect_equal(p$reverse$trait_permutation, rev(seq_len(audit$n_trait)))
  expect_equal(anyDuplicated(p$random$trait_permutation), 0L)

  cell <- lane_b_spatial_manifest()
  cell <- cell[cell$cell_id == "S003", , drop = FALSE]
  a <- lane_b_generate_spatial(cell, 1L, calibration_n = 1000L)
  b <- lane_b_generate_spatial(cell, 1L, calibration_n = 1000L)
  expect_identical(a$train, b$train)
  expect_identical(a$test, b$test)
  expect_true(all(a$train$lon < 0.4 | a$train$lon > 0.6))
  expect_true(all(a$test$lon >= 0.4 & a$test$lon <= 0.6))
  expect_true(all(table(a$train$unit) == 6L))
  expect_true(all(a$test$truth_probability > 0 & a$test$truth_probability < 1))
})

test_that("lightweight B0 regeneration is byte-identical to ordinary training data", {
  cell <- lane_b_ordinary_manifest()[c(1L, 17L, 65L), , drop = FALSE]
  for (i in seq_len(nrow(cell))) {
    full <- lane_b_generate_ordinary(
      cell[i, , drop = FALSE], 3L,
      calibration_n = 1000L, integration_n = 32L
    )
    b0 <- lane_b_generate_ordinary_b0(
      cell[i, , drop = FALSE], 3L,
      calibration_n = 1000L
    )
    expect_identical(b0$train, full$train)
    expect_identical(b0$seed_keys, full$seed_keys)
  }
})

test_that("attempt IDs and summaries retain failures", {
  ids <- vapply(lane_b_arm_order(1L), function(arm)
    lane_b_attempt_id("O001", 1L, arm), character(1))
  expect_equal(anyDuplicated(ids), 0L)
  attempts <- data.frame(
    cell_id = rep("O001", 4L), replicate_id = 1:4,
    arm = rep("mspl", 4L), status = c("success", "failure", "success", "failure"),
    usable = c(TRUE, FALSE, TRUE, FALSE), scaled_gradient = c(1e-6, Inf, 2e-6, Inf)
  )
  out <- lane_b_attempt_summary(attempts)
  expect_equal(out$attempted, 4L)
  expect_equal(out$retained_failures, 2L)
  expect_equal(out$usable_fraction, 0.5)
  expect_lt(out$usable_wilson_lower, out$usable_fraction)
  expect_equal(lane_b_thresholds()$paired_bootstrap_repetitions, 9999L)
})

test_that("paired bootstrap is deterministic and uses frozen comparison direction", {
  x <- seq(-0.02, 0.02, length.out = 21L)
  a <- lane_b_paired_bootstrap(x, B = 99L, seed_key = 1700100010)
  b <- lane_b_paired_bootstrap(x, B = 99L, seed_key = 1700100010)
  expect_identical(a, b)
  expect_equal(unname(a[["estimate"]]), mean(x))
})

test_that("B0 campaign mapping distinguishes complete and quasi-complete separation", {
  skip_if_not_installed("detectseparation", minimum_version = "0.4.0")
  make_dat <- function(x, y) {
    list(
      cell = data.frame(n_trait = 1L, link = "logit"),
      train = data.frame(
        trait = factor(rep("trait_01", length(y))),
        value = y,
        x1 = x
      )
    )
  }
  expect_identical(
    unname(lane_b_b0_status_by_trait(make_dat(c(-2, -1, 1, 2), c(0, 0, 1, 1)))),
    "COMPLETE"
  )
  expect_identical(
    unname(lane_b_b0_status_by_trait(make_dat(c(-1, 0, 0, 1), c(0, 0, 1, 1)))),
    "QUASI_COMPLETE"
  )
  expect_identical(
    unname(lane_b_b0_status_by_trait(make_dat(c(-1, 0, 1, 2), c(0, 1, 0, 1)))),
    "OVERLAP"
  )
  expect_identical(
    unname(lane_b_b0_status_by_trait(make_dat(c(-1, 0, 1, 2), c(0, 0, 0, 0)))),
    "CONSTANT"
  )
})

test_that("frozen promotion metrics are computed cell by cell without pooling", {
  manifest <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  attempts <- expand.grid(replicate_id = seq_len(20L),
                          arm = lane_b_arms()$arm_id, stringsAsFactors = FALSE)
  attempts$cell_id <- manifest$cell_id
  attempts$start_role <- "primary"
  attempts$usable <- TRUE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 1
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  metrics <- lane_b_promotion_metrics(attempts, manifest, B = 49L)
  expect_equal(nrow(metrics), 1L)
  expect_true(metrics$overlap_pass)
  expect_true(metrics$ridge_no_harm)
  expect_false(metrics$ridge_material_benefit)
  expect_true(metrics$promotion_pass)
})

test_that("overlap promotion requires the absolute MSPL usable-rate floor", {
  manifest <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  attempts <- expand.grid(replicate_id = seq_len(20L),
                          arm = lane_b_arms()$arm_id, stringsAsFactors = FALSE)
  attempts$cell_id <- manifest$cell_id
  attempts$start_role <- "primary"
  attempts$usable <- TRUE
  attempts$usable[attempts$arm == "mspl" & attempts$replicate_id > 18L] <- FALSE
  attempts$usable[attempts$arm == "ml" & attempts$replicate_id > 18L] <- FALSE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 1
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  metrics <- lane_b_promotion_metrics(attempts, manifest, B = 49L)
  expect_equal(metrics$usable_fraction, 0.90)
  expect_false(metrics$overlap_absolute_pass)
  expect_false(metrics$overlap_pass)
  expect_false(metrics$promotion_pass)
})

test_that("strict adjudication uses realized B0 strata", {
  manifest <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  manifest$n_rep <- 4L
  attempts <- expand.grid(replicate_id = seq_len(4L),
                          arm = lane_b_arms()$arm_id,
                          start_role = c("primary", "alternate"),
                          stringsAsFactors = FALSE)
  attempts$cell_id <- manifest$cell_id
  attempts$table <- "ordinary"
  attempts$status <- "success"
  attempts$optimizer_success <- TRUE
  attempts$usable <- TRUE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 1
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$sigma_rank <- manifest$q
  attempts$expected_sigma_rank <- manifest$q
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  attempts$sigma_vector <- "1"
  registry <- data.frame(
    cell_id = manifest$cell_id,
    replicate_id = seq_len(4L),
    b0_status_hash_exact = c("OVERLAP", "OVERLAP", "COMPLETE", "QUASI_COMPLETE"),
    b0_stratum = c("OVERLAP", "OVERLAP", "COMPLETE", "QUASI_COMPLETE")
  )
  original <- data.frame(cell_id = manifest$cell_id, promotion_pass = TRUE)
  metrics <- lane_b_adjudicate_ordinary(attempts, registry, manifest,
                                        original_metrics = original, B = 49L)
  expect_setequal(metrics$b0_stratum, c("OVERLAP", "COMPLETE", "QUASI_COMPLETE"))
  expect_equal(metrics$datasets[metrics$b0_stratum == "OVERLAP"], 2L)
})

test_that("strict risk comparisons retain only mutually usable pairs", {
  cell <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  attempts <- expand.grid(replicate_id = seq_len(20L),
                          arm = lane_b_arms()$arm_id, stringsAsFactors = FALSE)
  attempts$usable <- TRUE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 1
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$sigma_rank <- cell$q
  attempts$expected_sigma_rank <- cell$q
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  attempts$alternate_healthy <- TRUE
  bad <- attempts$arm == "mspl" & attempts$replicate_id == 20L
  attempts$usable[bad] <- FALSE
  attempts$beta_squared_error[bad] <- 1e12
  attempts$covariance_squared_error[bad] <- 1e12
  attempts$log_loss[bad] <- 1e6
  metrics <- lane_b_adjudicate_stratum(attempts, cell, "OVERLAP", B = 49L)
  expect_equal(metrics$overlap_pair_n, 20L)
  expect_equal(metrics$overlap_mutually_usable_n, 19L)
  expect_equal(metrics$overlap_beta_rmse_ratio_upper, 1)
  expect_equal(metrics$overlap_covariance_rmse_ratio_upper, 1)
  expect_equal(metrics$overlap_log_loss_difference_upper, 0)
})

test_that("strict adjudication cannot override the immutable v1 gate", {
  cell <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  attempts <- expand.grid(replicate_id = seq_len(20L),
                          arm = lane_b_arms()$arm_id, stringsAsFactors = FALSE)
  attempts$usable <- TRUE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 1
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$sigma_rank <- cell$q
  attempts$expected_sigma_rank <- cell$q
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  attempts$alternate_healthy <- TRUE
  metrics <- lane_b_adjudicate_stratum(
    attempts, cell, "OVERLAP", B = 49L, original_promotion_pass = FALSE
  )
  expect_true(metrics$overlap_pass)
  expect_false(metrics$promotion_pass)
})

test_that("strict spatial adjudication requires healthy agreeing alternate starts", {
  manifest <- lane_b_spatial_manifest()
  manifest <- manifest[manifest$link == "logit" &
                         manifest$structure == "spatial_indep", , drop = FALSE]
  manifest$attempts <- 4L
  attempts <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    z <- expand.grid(
      replicate_id = seq_len(cell$attempts),
      arm = lane_b_arms()$arm_id,
      start_role = c("primary", "alternate"),
      stringsAsFactors = FALSE
    )
    z$cell_id <- cell$cell_id
    z$table <- "spatial"
    z$status <- "success"
    z$optimizer_success <- TRUE
    z$usable <- TRUE
    z$scaled_gradient <- 1e-6
    z$bound_or_clamp <- FALSE
    z$spatial_boundary_contact <- FALSE
    z$spatial_sd_relative_error <- 0
    z$spatial_log_range_error <- 0
    z$spatial_covfun_frob_error <- 0
    z$objective <- 100
    expected_rank <- if (cell$q == 0L) cell$n_trait else cell$q
    z$sigma_rank <- expected_rank
    z$expected_sigma_rank <- expected_rank
    z$sigma_vector <- lane_b_pack_numeric(diag(cell$n_trait))
    z$alternate_objective_gap <- 0
    z$alternate_covariance_gap <- 0
    z
  }))
  stored_v1 <- lane_b_spatial_promotion_metrics(attempts)
  expect_identical(lane_b_authenticate_spatial_v1(attempts, stored_v1),
                   stored_v1)
  altered_v1 <- stored_v1
  altered_v1$pass[[1L]] <- !altered_v1$pass[[1L]]
  expect_error(
    lane_b_authenticate_spatial_v1(attempts, altered_v1),
    "disagree"
  )
  original <- data.frame(cell_id = manifest$cell_id, pass = TRUE)

  metrics <- lane_b_adjudicate_spatial(attempts, original, manifest)
  expect_true(all(metrics$stationary))
  expect_true(all(metrics$alternate_health))
  expect_true(all(metrics$multistart_agreement))
  expect_true(all(metrics$promotion_pass))
  gate <- lane_b_spatial_family_gate(metrics, manifest)
  expect_equal(gate$required_cells, 8L)
  expect_true(gate$design_complete)
  expect_true(gate$pass)

  bad_alternate <- attempts
  idx <- bad_alternate$cell_id == manifest$cell_id[[1L]] &
    bad_alternate$arm == "mspl" & bad_alternate$replicate_id == 1L &
    bad_alternate$start_role == "alternate"
  bad_alternate$scaled_gradient[idx] <- 1
  bad_metrics <- lane_b_adjudicate_spatial(bad_alternate, original, manifest)
  expect_false(bad_metrics$alternate_health[[1L]])
  expect_false(bad_metrics$promotion_pass[[1L]])
  expect_false(lane_b_spatial_family_gate(bad_metrics, manifest)$pass)

  bad_frobenius <- attempts
  idx <- bad_frobenius$cell_id == manifest$cell_id[[1L]] &
    bad_frobenius$arm == "mspl" & bad_frobenius$replicate_id == 1L &
    bad_frobenius$start_role == "alternate"
  bad_frobenius$sigma_vector[idx] <- lane_b_pack_numeric(
    diag(manifest$n_trait[[1L]]) +
      matrix(5e-5, manifest$n_trait[[1L]], manifest$n_trait[[1L]])
  )
  frobenius_metrics <- lane_b_adjudicate_spatial(
    bad_frobenius, original, manifest
  )
  expect_gt(frobenius_metrics$multistart_relative_sigma_gap_max[[1L]], 1e-4)
  expect_false(frobenius_metrics$multistart_agreement[[1L]])
  expect_false(frobenius_metrics$promotion_pass[[1L]])

  withheld <- original
  withheld$pass[[1L]] <- FALSE
  withheld_metrics <- lane_b_adjudicate_spatial(attempts, withheld, manifest)
  expect_true(withheld_metrics$multistart_agreement[[1L]])
  expect_false(withheld_metrics$promotion_pass[[1L]])
})

test_that("strict spatial adjudication rejects an incomplete attempt ledger", {
  manifest <- lane_b_spatial_manifest()[1L, , drop = FALSE]
  manifest$attempts <- 2L
  attempts <- expand.grid(
    replicate_id = seq_len(manifest$attempts),
    arm = lane_b_arms()$arm_id,
    start_role = c("primary", "alternate"),
    stringsAsFactors = FALSE
  )
  attempts$cell_id <- manifest$cell_id
  attempts$table <- "spatial"
  expect_silent(lane_b_validate_spatial_attempt_ledger(attempts, manifest))
  expect_error(
    lane_b_validate_spatial_attempt_ledger(attempts[-1L, ], manifest),
    "not exactly"
  )
})

test_that("relative Frobenius multistart repair supersedes elementwise gaps", {
  primary_sigma <- 10 * diag(6L)
  alternate_sigma <- primary_sigma
  alternate_sigma[1L, 1L] <- alternate_sigma[1L, 1L] + 2e-4
  attempts <- data.frame(
    cell_id = "S001", replicate_id = 1L, arm = "mspl",
    start_role = c("primary", "alternate"),
    sigma_vector = c(lane_b_pack_numeric(primary_sigma),
                     lane_b_pack_numeric(alternate_sigma)),
    alternate_covariance_gap = 2e-4,
    stringsAsFactors = FALSE
  )
  corrected <- lane_b_recompute_relative_multistart(attempts)
  expected <- sqrt(sum((alternate_sigma - primary_sigma)^2)) /
    max(1, sqrt(sum(primary_sigma^2)))
  expect_gt(attempts$alternate_covariance_gap[[1L]], 1e-4)
  expect_lt(expected, 1e-4)
  expect_equal(corrected$alternate_covariance_gap, rep(expected, 2L))
})

test_that("strict adjudication rejects incomplete metric pairs and zero denominators", {
  cell <- lane_b_ordinary_manifest()[1L, , drop = FALSE]
  attempts <- expand.grid(replicate_id = seq_len(20L),
                          arm = lane_b_arms()$arm_id, stringsAsFactors = FALSE)
  attempts$usable <- TRUE
  attempts$scaled_gradient <- 1e-6
  attempts$bound_or_clamp <- FALSE
  attempts$objective <- 100
  attempts$beta_squared_error <- 0
  attempts$covariance_squared_error <- 1
  attempts$log_loss <- 0.4
  attempts$sigma_rank <- cell$q
  attempts$expected_sigma_rank <- cell$q
  attempts$alternate_objective_gap <- 0
  attempts$alternate_covariance_gap <- 0
  attempts$alternate_healthy <- TRUE
  attempts$beta_squared_error[attempts$arm == "mspl" &
                                attempts$replicate_id == 1L] <- NA_real_
  metrics <- lane_b_adjudicate_stratum(attempts, cell, "OVERLAP", B = 49L)
  expect_false(metrics$overlap_metrics_complete)
  expect_false(metrics$overlap_pass)

  attempts$beta_squared_error[attempts$arm == "mspl"] <- 1
  attempts$beta_squared_error[attempts$arm == "ml"] <- 0
  metrics <- lane_b_adjudicate_stratum(attempts, cell, "OVERLAP", B = 49L)
  expect_identical(metrics$overlap_beta_rmse_ratio_upper, Inf)
  expect_false(metrics$overlap_pass)
})

test_that("targeted quasi gate retains failures and checks alternate health", {
  manifest <- lane_b_quasi_manifest()[1:2, , drop = FALSE]
  make_attempts <- function(successes = 496L) {
    pieces <- lapply(seq_len(nrow(manifest)), function(i) {
      cell <- manifest[i, , drop = FALSE]
      z <- expand.grid(replicate_id = seq_len(cell$n_rep),
                       start_role = c("primary", "alternate"),
                       stringsAsFactors = FALSE)
      z$cell_id <- cell$cell_id
      z$arm <- "mspl"
      z$status <- "success"
      z$optimizer_success <- TRUE
      z$usable <- TRUE
      primary_failure <- z$start_role == "primary" & z$replicate_id > successes
      z$status[primary_failure] <- "failure"
      z$optimizer_success[primary_failure] <- FALSE
      z$usable[primary_failure] <- FALSE
      z$scaled_gradient <- ifelse(primary_failure, Inf, 1e-6)
      z$sigma_rank <- cell$q
      z$expected_sigma_rank <- cell$q
      z$bound_or_clamp <- FALSE
      z$objective <- ifelse(primary_failure, NA_real_, 100)
      z$alternate_objective_gap <- 0
      z$alternate_covariance_gap <- 0
      z$sigma_vector <- lane_b_pack_numeric(diag(6L))
      z$b0_status_hash <- paste(c("QUASI_COMPLETE", rep("OVERLAP", 5L)),
                                collapse = ";")
      z
    })
    do.call(rbind, pieces)
  }

  attempts <- make_attempts(496L)
  metrics <- lane_b_quasi_cell_metrics(attempts, manifest)
  expect_true(all(metrics$pass))
  expect_true(all(metrics$alternate_health))
  expect_true(all(metrics$attempted == 500L))
  expect_true(lane_b_quasi_family_gate(metrics)$pass)
  strict <- lane_b_adjudicate_quasi_multistart(attempts, manifest)
  expect_true(all(strict$strict_multistart_pass))
  expect_true(lane_b_quasi_multistart_family_gate(strict, manifest)$pass)

  fail_wilson <- lane_b_quasi_cell_metrics(make_attempts(495L), manifest)
  expect_true(all(fail_wilson$usable_rate == 0.99))
  expect_true(all(fail_wilson$usable_wilson_lower < 0.98))
  expect_false(any(fail_wilson$pass))

  bad_alternate <- attempts
  idx <- bad_alternate$cell_id == manifest$cell_id[[1L]] &
    bad_alternate$replicate_id == 1L & bad_alternate$start_role == "alternate"
  bad_alternate$scaled_gradient[idx] <- 1
  bad_metrics <- lane_b_quasi_cell_metrics(bad_alternate, manifest)
  expect_false(bad_metrics$alternate_health[[1L]])
  expect_false(bad_metrics$pass[[1L]])

  bad_frobenius <- attempts
  idx <- bad_frobenius$cell_id == manifest$cell_id[[1L]] &
    bad_frobenius$replicate_id == 1L &
    bad_frobenius$start_role == "alternate"
  bad_frobenius$sigma_vector[idx] <- lane_b_pack_numeric(
    diag(6L) + matrix(5e-5, 6L, 6L)
  )
  strict_bad <- lane_b_adjudicate_quasi_multistart(bad_frobenius, manifest)
  expect_gt(strict_bad$strict_relative_sigma_gap_max[[1L]], 1e-4)
  expect_false(strict_bad$strict_multistart_pass[[1L]])

  bad_certificate <- attempts
  idx <- bad_certificate$cell_id == manifest$cell_id[[1L]] &
    bad_certificate$replicate_id == 1L & bad_certificate$start_role == "primary"
  bad_certificate$b0_status_hash[idx] <- paste(rep("OVERLAP", 6L), collapse = ";")
  cert_metrics <- lane_b_quasi_cell_metrics(bad_certificate, manifest)
  expect_false(cert_metrics$quasi_certificate_exact[[1L]])
  expect_false(cert_metrics$pass[[1L]])
})

test_that("quasi summary validation rejects malformed ledgers and family gates", {
  manifest <- lane_b_quasi_manifest()[1:2, , drop = FALSE]
  manifest$n_rep <- 2L
  attempts <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    z <- expand.grid(replicate_id = seq_len(cell$n_rep),
                     arm = lane_b_arms()$arm_id,
                     start_role = c("primary", "alternate"),
                     stringsAsFactors = FALSE)
    z$cell_id <- cell$cell_id
    z$status <- "success"; z$optimizer_success <- TRUE; z$usable <- TRUE
    z$scaled_gradient <- 1e-6; z$sigma_rank <- cell$q
    z$expected_sigma_rank <- cell$q; z$bound_or_clamp <- FALSE
    z$objective <- 100; z$alternate_objective_gap <- 0
    z$alternate_covariance_gap <- 0
    z$b0_status_hash <- paste(c("QUASI_COMPLETE", rep("OVERLAP", 5L)),
                              collapse = ";")
    z
  }))
  metrics <- lane_b_quasi_cell_metrics(attempts, manifest)
  gate <- lane_b_quasi_family_gate(metrics)
  summary <- list(label = "QUASI-PROMOTION-WITHHELD", attempts = attempts,
                  cell_metrics = metrics, family_gate = gate)
  expect_silent(lane_b_validate_quasi_summary_tables(summary, manifest))

  missing <- summary
  missing$attempts <- missing$attempts[-1L, , drop = FALSE]
  expect_error(lane_b_validate_quasi_summary_tables(missing, manifest),
               "disagree|ledger")

  wrong_gate <- summary
  wrong_gate$family_gate$pass[[1L]] <- !wrong_gate$family_gate$pass[[1L]]
  expect_error(lane_b_validate_quasi_summary_tables(wrong_gate, manifest),
               "disagree")
})

test_that("archived quasi provenance validates without the current runtime", {
  manifest <- lane_b_quasi_manifest()[1:2, , drop = FALSE]
  manifest$n_rep <- 2L
  attempts <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    z <- expand.grid(
      replicate_id = seq_len(cell$n_rep), arm = lane_b_arms()$arm_id,
      start_role = c("primary", "alternate"), stringsAsFactors = FALSE
    )
    z$cell_id <- cell$cell_id
    z$status <- "success"
    z$optimizer_success <- TRUE
    z$usable <- TRUE
    z$scaled_gradient <- 1e-6
    z$sigma_rank <- cell$q
    z$expected_sigma_rank <- cell$q
    z$bound_or_clamp <- FALSE
    z$objective <- 100
    z$alternate_objective_gap <- 0
    z$alternate_covariance_gap <- 0
    z$sigma_vector <- lane_b_pack_numeric(diag(6L))
    z$b0_status_hash <- paste(c("QUASI_COMPLETE", rep("OVERLAP", 5L)),
                              collapse = ";")
    z
  }))
  metrics <- lane_b_quasi_cell_metrics(attempts, manifest)
  gate <- lane_b_quasi_family_gate(metrics)
  archived_source <- c(`frozen-source.R` = strrep("a", 64L))
  archived_runtime <- list(
    r_version = "archived R", package_version = "0.6.0",
    tmb_version = "1.9.18", detector_version = "0.4.0",
    installed_dll_sha256 = c(gllvmTMB.so = strrep("b", 64L))
  )
  summary <- list(
    label = if (all(gate$pass)) "QUASI-PROMOTION-PASS" else
      "QUASI-PROMOTION-WITHHELD",
    supplement_version = lane_b_quasi_version(),
    manifest_version = lane_b_manifest_version(), attempts = attempts,
    cell_metrics = metrics, family_gate = gate,
    source_sha256 = archived_source
  )
  root <- tempfile("lane-b-archived-quasi-")
  paths <- lane_b_quasi_paths(root)
  invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
  frozen <- list(
    source_sha256 = archived_source,
    runtime_receipt = archived_runtime,
    source_tarball_sha256 = strrep("c", 64L),
    queue = data.frame(shard_id = "quasi-test-0001", stringsAsFactors = FALSE)
  )
  frozen_path <- file.path(paths[["frozen"]], "lane-b-quasi-frozen-v1.rds")
  saveRDS(frozen, frozen_path)
  saveRDS(list(
    frozen_sha256 = lane_b_sha256_file(frozen_path),
    source_tarball_sha256 = frozen$source_tarball_sha256,
    runtime_receipt = archived_runtime
  ), file.path(paths[["session"]], "prepare-receipt-v1.rds"))
  raw_path <- file.path(paths[["raw"]], "quasi-test-0001.rds")
  raw_sha <- lane_b_atomic_save_rds(attempts, raw_path)
  lane_b_atomic_save_rds(
    list(shard_id = "quasi-test-0001", status = "complete",
         rows = nrow(attempts), raw_sha256 = raw_sha),
    file.path(paths[["state/complete"]], "quasi-test-0001.rds")
  )

  expect_false(identical(archived_source, lane_b_quasi_source_receipt()))
  expect_silent(lane_b_validate_quasi_summary(summary, root, manifest))
  lane_b_atomic_save_rds(attempts[-1L, ], raw_path)
  expect_error(
    lane_b_validate_quasi_summary(summary, root, manifest),
    "SHA-256 mismatch"
  )
})

test_that("campaign roots inside the checkout are rejected", {
  expect_error(lane_b_validate_campaign_root(file.path(getwd(), "campaign")),
               "outside the git checkout")
  expect_silent(lane_b_validate_campaign_root(tempfile("lane-b-outside-")))
})

test_that("missing MSPL fails before a shard starts", {
  caps <- lane_b_mspl_capabilities()
  if (all(caps)) skip("The four-arm MSPL surface is now available.")
  expect_error(lane_b_assert_capabilities(FALSE), "No shard was started")
  expect_silent(lane_b_assert_capabilities(TRUE))
})

test_that("private hybrid refreshes objective, gradient, and report at new par", {
  state <- new.env(parent = emptyenv())
  state$last.par <- c(theta_rr_B = 1)
  obj <- list(
    env = state,
    fn = function(x) { state$last.par <- x; sum((x - 2)^2) },
    gr = function(x) 2 * (x - 2),
    report = function() list(Lambda_B = matrix(state$last.par, 1L, 1L),
                             Sigma_B = matrix(state$last.par^2, 1L, 1L))
  )
  fit <- list(opt = list(par = c(theta_rr_B = 1), objective = 1,
                         convergence = 0L), tmb_obj = obj,
              report = list(Lambda_B = matrix(1, 1L, 1L)), fit_health = list(),
              mspl = list(unpenalized_tmb_obj = obj,
                          penalty = list(jeffreys_nll = 0, loading_nll = 0,
                                         covariance_nll = 0, private_ridge_nll = 0)))
  hybrid <- lane_b_private_ridge_reoptimize(fit, tau = 2)
  expect_false(isTRUE(all.equal(hybrid$opt$par, fit$opt$par)))
  expect_equal(hybrid$report$Lambda_B, matrix(hybrid$opt$par, 1L, 1L))
  expect_equal(hybrid$report$Sigma_B, matrix(hybrid$opt$par^2, 1L, 1L))
  expect_equal(hybrid$tmb_obj$env$last.par.best, hybrid$opt$par)
  expect_equal(hybrid$lane_b_private_hybrid$gradient,
               obj$gr(hybrid$opt$par) + hybrid$opt$par / 4,
               tolerance = 1e-8)
  expect_equal(hybrid$opt$objective,
               obj$fn(hybrid$opt$par) + 0.5 * sum(hybrid$opt$par^2) / 4,
               tolerance = 1e-8)
  expect_equal(hybrid$mspl$penalized_nll, hybrid$opt$objective)
  expect_equal(hybrid$mspl$penalty$private_ridge_nll,
               hybrid$lane_b_private_hybrid$loading_ridge_nll)
  expect_equal(hybrid$fit_health$objective, hybrid$opt$objective)
})

test_that("private hybrid recognizes live ordinary and spatial loading names", {
  make_fit <- function(parameter_name) {
    state <- new.env(parent = emptyenv())
    state$last.par <- stats::setNames(1, parameter_name)
    obj <- list(
      env = state,
      fn = function(x) {
        state$last.par <- x
        sum((x - 2)^2)
      },
      gr = function(x) 2 * (x - 2),
      report = function() list()
    )
    list(
      opt = list(par = stats::setNames(1, parameter_name), objective = 1,
                 convergence = 0L),
      tmb_obj = obj,
      mspl = list(
        unpenalized_tmb_obj = obj,
        penalty = list(jeffreys_nll = 0, loading_nll = 0,
                       covariance_nll = 0, private_ridge_nll = 0)
      ),
      fit_health = list()
    )
  }

  for (parameter_name in c("theta_rr_B", "theta_rr_spde_lv")) {
    fit <- lane_b_private_ridge_reoptimize(make_fit(parameter_name), tau = 2)
    expect_identical(fit$lane_b_private_hybrid$loading_indices, 1L)
    expect_gt(fit$lane_b_private_hybrid$loading_ridge_nll, 0)
  }
})

test_that("diagnostic rank helper treats unavailable random-effect Hessians as missing", {
  expect_identical(lane_b_matrix_rank(matrix(numeric(), 0L, 0L)), NA_integer_)
  expect_identical(lane_b_matrix_rank(matrix(NA_real_, 0L, 0L)), NA_integer_)
  expect_identical(lane_b_matrix_rank(diag(c(2, 0))), 1L)
})

test_that("spatial diagnostics use marginal-scale covariance for both structures", {
  kappa <- 2
  fit_indep <- list(
    use = list(spatial_indep = TRUE, spatial_latent = FALSE),
    report = list(kappa = kappa, log_tau_spde = log(c(2, 4)))
  )
  sigma_indep <- lane_b_extract_shared_sigma(fit_indep, spatial = TRUE)
  expected_sd <- 1 / (c(2, 4) * sqrt(4 * pi) * kappa)
  expect_equal(sigma_indep, diag(expected_sd^2), tolerance = 1e-12)

  loading <- matrix(c(2, 1, 0, 3), 2L, 2L)
  fit_latent <- list(
    use = list(spatial_indep = FALSE, spatial_latent = TRUE),
    report = list(kappa = kappa, Lambda_spde = loading)
  )
  expect_equal(
    lane_b_extract_shared_sigma(fit_latent, spatial = TRUE),
    tcrossprod(loading / (sqrt(4 * pi) * kappa)),
    tolerance = 1e-12
  )
})

test_that("smoke preparation freezes every required B2 surface", {
  source_root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    mustWork = FALSE
  )
  skip_if_not(
    file.exists(file.path(source_root, ".git")),
    "requires a source checkout for git-bound campaign receipts"
  )
  root <- tempfile("lane-b-smoke-")
  opt <- list(root = root, smoke = TRUE, shard_size = 25L)
  receipt <- lane_b_prepare(opt)
  expect_equal(receipt$cells, 5L)
  expect_equal(receipt$cell_counts, c(ordinary = 1L, permutation = 1L, spatial = 3L))
  expect_equal(receipt$datasets, 5L)
  expect_equal(receipt$primary_attempts, 28L)
  expect_equal(receipt$shards, 5L)
  frozen <- readRDS(file.path(root, "frozen", "lane-b-b2-frozen.rds"))
  expect_equal(as.integer(table(factor(frozen$queue$table,
                                       levels = c("ordinary", "permutation", "spatial")))),
               c(1L, 1L, 3L))
  expect_true(all(c("ordinary", "permutation", "spatial", "arms") %in%
                    names(frozen$source_manifest_sha256)))
})
