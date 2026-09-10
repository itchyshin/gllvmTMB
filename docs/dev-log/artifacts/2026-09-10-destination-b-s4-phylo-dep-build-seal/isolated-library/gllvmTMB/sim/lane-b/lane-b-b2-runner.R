#!/usr/bin/env Rscript

lane_b_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
  if (length(file_arg)) dirname(normalizePath(file_arg[[1L]])) else getwd()
}

if (!exists("lane_b_manifest_version", mode = "function"))
  source(file.path(lane_b_script_dir(), "lane-b-b2-common.R"))

lane_b_parse_cli <- function(args) {
  if (!length(args)) stop("Usage: lane-b-b2-runner.R <prepare|run|resume|aggregate> [options]")
  command <- args[[1L]]; args <- args[-1L]
  out <- list(command = command, smoke = FALSE, provisional = FALSE,
              allow_missing_mspl = FALSE, run_pending = FALSE,
              ordinary_only = FALSE,
              shard_size = 25L, shard_id = NULL, root = Sys.getenv("GLLVMTMB_LANE_B_CAMPAIGN"))
  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a %in% c("--smoke", "--provisional", "--allow-missing-mspl", "--run-pending",
                 "--ordinary-only")) {
      nm <- sub("^--", "", a); nm <- gsub("-", "_", nm); out[[nm]] <- TRUE; i <- i + 1L
    } else if (a %in% c("--root", "--shard-id", "--shard-size")) {
      if (i == length(args)) stop("Missing value after ", a)
      nm <- gsub("-", "_", sub("^--", "", a)); out[[nm]] <- args[[i + 1L]]; i <- i + 2L
    } else stop("Unknown option: ", a)
  }
  out$shard_size <- as.integer(out$shard_size)
  if (!nzchar(out$root)) stop("Set --root or GLLVMTMB_LANE_B_CAMPAIGN.")
  out
}

lane_b_campaign_paths <- function(root) {
  dirs <- c("frozen", "queue", "state/pending", "state/running", "state/complete",
            "state/failed", "raw", "payloads", "summaries", "logs", "session")
  setNames(file.path(root, dirs), dirs)
}

lane_b_harness_dir <- function() {
  ancestors <- unique(Reduce(function(x, y) dirname(x), seq_len(6L),
                             init = normalizePath(getwd()), accumulate = TRUE))
  installed <- system.file("sim", "lane-b", package = "gllvmTMB")
  candidates <- c(
    lane_b_script_dir(),
    file.path(ancestors, "inst", "sim", "lane-b"),
    installed
  )
  hit <- candidates[file.exists(file.path(candidates, "lane-b-b2-common.R"))]
  if (!length(hit)) stop("Cannot resolve the Lane B harness directory.")
  normalizePath(hit[[1L]])
}

lane_b_repo_root <- function() {
  d <- lane_b_harness_dir()
  normalizePath(file.path(d, "..", "..", ".."))
}

lane_b_checkout_head <- function() {
  out <- suppressWarnings(system2("git", c("-C", shQuote(lane_b_repo_root()),
                                             "rev-parse", "HEAD"),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L
  if (status != 0L || length(out) != 1L) stop("Lane B requires a git checkout with a resolvable HEAD.")
  out[[1L]]
}

lane_b_code_receipt <- function() {
  d <- lane_b_harness_dir()
  files <- c("lane-b-b2-common.R", "lane-b-b2-runner.R", "SYMBOLIC-ALIGNMENT.md")
  setNames(vapply(file.path(d, files), lane_b_sha256_file, character(1)), files)
}

lane_b_model_source_receipt <- function() {
  root <- lane_b_repo_root()
  files <- c("DESCRIPTION", "R/gllvmTMB.R", "R/fit-multi.R", "R/mspl.R",
             "src/gllvmTMB.cpp", "src/lane_b_jeffreys_maxvol_atomic_v8.h")
  setNames(vapply(files, function(x) {
    path <- file.path(root, x)
    if (file.exists(path)) lane_b_sha256_file(path) else "MISSING"
  }, character(1)), files)
}

lane_b_verify_frozen_runtime <- function(frozen) {
  if (!identical(frozen$checkout_head, lane_b_checkout_head()))
    stop("Checkout HEAD drifted from the frozen campaign receipt.")
  if (!identical(frozen$harness_sha256, lane_b_code_receipt()))
    stop("Lane B harness drifted from the frozen campaign receipt.")
  if (!identical(frozen$model_source_sha256, lane_b_model_source_receipt()))
    stop("gllvmTMB model source drifted from the frozen campaign receipt.")
  invisible(TRUE)
}

lane_b_prepare <- function(opt) {
  root <- lane_b_validate_campaign_root(opt$root)
  paths <- lane_b_campaign_paths(root)
  invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
  manifest <- lane_b_ordinary_manifest()
  permutation <- lane_b_permutation_manifest(manifest)
  spatial <- lane_b_spatial_manifest()
  include_spatial <- !isTRUE(opt$ordinary_only)
  if (!include_spatial) spatial <- spatial[0, , drop = FALSE]
  queue <- lane_b_build_all_queue(
    manifest, permutation, spatial, opt$smoke, include_spatial = include_spatial
  )
  arms <- lane_b_arms()
  if (opt$smoke) {
    om <- manifest[manifest$cell_id == "O007", , drop = FALSE]; om$n_rep <- 1L
    pm <- permutation[1L, , drop = FALSE]; pm$audit_attempts <- 1L
    sm <- spatial[spatial$cell_id %in% queue$cell_id[queue$table == "spatial"], , drop = FALSE]
    if (nrow(sm)) sm$attempts <- 1L
    seed_registry <- lane_b_seed_registry_all(om, pm, sm)
  } else seed_registry <- lane_b_seed_registry_all(manifest, permutation, spatial)
  frozen <- list(manifest_version = lane_b_manifest_version(), smoke = opt$smoke,
                 campaign_scope = if (include_spatial) "all" else "ordinary_only",
                 manifest = manifest, ordinary_manifest = manifest,
                 permutation_manifest = permutation, spatial_manifest = spatial,
                 arms = arms, seed_registry = seed_registry,
                 queue = queue, thresholds = lane_b_thresholds(),
                 checkout_head = lane_b_checkout_head(),
                 harness_sha256 = lane_b_code_receipt(),
                 model_source_sha256 = lane_b_model_source_receipt(),
                 source_manifest_sha256 = c(
                   ordinary = "7a95fddb25fb239c751a1a9a8fdd41b995d9e0d4c59fa150e1f834506095b0dd",
                   permutation = "6471d2f78e3ac29da33591cdc2571dbb5a11dd49c9be7c70a1564973b545cf60",
                   spatial = "f8c83569d4f6e4e14e0efba49015f0e10be948a4fb60953118d3be60f147364e",
                   arms = "67919144a82ef60aaf0770c372c796baaf0e927265e5c1d81b80d52e121f1dfc"),
                 semantic_substreams = c("truth/data", "train covariates", "latent scores",
                   "outcomes", "test covariates/scores", "prediction integration",
                   "alternate start", "capsule"))
  frozen_path <- file.path(paths[["frozen"]], "lane-b-b2-frozen.rds")
  if (file.exists(frozen_path)) {
    old <- readRDS(frozen_path)
    if (!identical(old, frozen)) stop("Frozen campaign state drift; refusing to overwrite.")
  } else lane_b_atomic_save_rds(frozen, frozen_path)
  write.csv(queue, file.path(paths[["queue"]], "lane-b-b2-queue.csv"), row.names = FALSE)
  for (id in queue$shard_id) {
    p <- file.path(paths[["state/pending"]], paste0(id, ".rds"))
    if (!file.exists(p)) saveRDS(list(shard_id = id, status = "pending"), p)
  }
  receipt <- list(created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                  manifest_version = lane_b_manifest_version(), smoke = opt$smoke,
                  cells = if (opt$smoke) if (include_spatial) 5L else 2L else
                    nrow(manifest) + nrow(permutation) + nrow(spatial),
                  cell_counts = if (opt$smoke) {
                    if (include_spatial) c(ordinary = 1L, permutation = 1L, spatial = 3L) else
                      c(ordinary = 1L, permutation = 1L, spatial = 0L)
                  } else c(ordinary = nrow(manifest), permutation = nrow(permutation), spatial = nrow(spatial)),
                  campaign_scope = if (include_spatial) "all" else "ordinary_only",
                  datasets = sum(queue$dataset_count),
                  primary_attempts = sum(queue$primary_attempt_count), shards = nrow(queue),
                  frozen_sha256 = lane_b_sha256_file(frozen_path))
  saveRDS(receipt, file.path(paths[["session"]], "prepare-receipt.rds"))
  print(receipt)
  invisible(receipt)
}

lane_b_fit_dataset_attempts <- function(dat, result_cell, table, frozen) {
  out <- list(); k <- 0L; replicate_id <- dat$replicate_id
  order_role <- dat$order_role %||% "original"
  b0_status_hash <- lane_b_b0_status_hash(dat)
  presence <- as.integer(tapply(dat$train$value, dat$train$trait, sum))
  total <- as.integer(tapply(dat$train$value, dat$train$trait, length))
  if (!is.null(dat$trait_permutation)) {
    scientific_presence <- scientific_total <- integer(length(presence))
    scientific_presence[dat$trait_permutation] <- presence
    scientific_total[dat$trait_permutation] <- total
    presence <- scientific_presence; total <- scientific_total
  }
  for (arm in lane_b_arm_order(replicate_id)) {
      pair_rows <- list(); pair_diag <- list()
      for (start_role in c("primary", "alternate")) {
        k <- k + 1L
        seed_key <- if (start_role == "primary") dat$seed_keys[["start"]] else dat$seed_keys[["alternate"]]
        seed_state <- lane_b_substreams(seed_key)[[if (start_role == "primary") 1L else 7L]]
        started <- proc.time()[["elapsed"]]
        fit <- tryCatch(lane_b_fit_arm(dat, arm, start_role, seed_state), error = identity)
        elapsed <- proc.time()[["elapsed"]] - started
        if (inherits(fit, "condition")) {
          row <- lane_b_failure_row(result_cell, replicate_id, arm, order_role, fit, elapsed,
                                    start_role, table)
          d <- NULL
        } else {
          is_spatial <- identical(table, "spatial")
          d <- lane_b_extract_fit_diagnostics(fit, dat$cell$q[[1L]], spatial = is_spatial)
          truth_b <- tryCatch(lane_b_truth_bfix(dat, names(d$bfix)), error = function(e) NULL)
          beta_error <- if (!is.null(truth_b) && all(is.finite(d$bfix)))
            sum((d$bfix - truth_b)^2) else NA_real_
          prediction <- tryCatch(if (is_spatial) {
            as.numeric(stats::predict(fit, newdata = dat$test, type = "response"))
          } else lane_b_predict_whole_unit(fit, dat, d$sigma,
            integration_n = if (isTRUE(frozen$smoke)) 256L else 2048L),
            error = function(e) rep(NA_real_, nrow(dat$test)))
          log_loss <- if (all(is.finite(prediction)))
            lane_b_log_loss(dat$test$value, prediction) else NA_real_
          row <- lane_b_empty_attempts()[NA_integer_, ]
          row[1, ] <- list(
            lane_b_attempt_id(result_cell$cell_id[[1L]], replicate_id, arm, start_role,
                              order_role, table),
            lane_b_manifest_version(), table, result_cell$cell_id[[1L]], replicate_id, arm,
            start_role, order_role, "success", "", "", elapsed, d$optimizer_success,
            d$usable, d$objective, d$scaled_gradient, d$max_abs_parameter,
            d$hessian_rank, d$sigma_rank, d$expected_sigma_rank, d$bound_or_clamp,
            beta_error, if (length(d$sigma)) sum((d$sigma - dat$truth$Sigma)^2) else NA_real_,
            log_loss, NA_real_, NA_real_, dat$cell$n_unit[[1L]])
        }
        if (!is.null(d)) {
          beta_matrix <- tryCatch(lane_b_bfix_matrix(dat, d$bfix), error = function(e) NULL)
          beta_matrix <- lane_b_unpermute_matrix(beta_matrix, dat$trait_permutation)
          sigma_matrix <- lane_b_unpermute_matrix(d$sigma, dat$trait_permutation,
                                                  covariance = TRUE)
          row$beta_vector <- if (is.null(beta_matrix)) NA_character_ else lane_b_pack_numeric(beta_matrix)
          row$sigma_vector <- if (!length(sigma_matrix)) NA_character_ else lane_b_pack_numeric(sigma_matrix)
          if (is_spatial && length(d$sigma)) {
            fitted_range <- tryCatch(sqrt(8) / as.numeric(fit$report$kappa)[1L],
                                     error = function(e) NA_real_)
            row$spatial_sd_relative_error <- median(abs(
              sqrt(pmax(diag(d$sigma), 0)) - sqrt(diag(dat$truth$Sigma))) /
                pmax(sqrt(diag(dat$truth$Sigma)), 1e-12))
            row$spatial_log_range_error <- log(fitted_range / dat$truth$effective_range)
            distances <- c(0, 0.1 * sqrt(2), 0.5 * sqrt(2))
            fitted_corr <- vapply(distances, function(dd) {
              a <- sqrt(8) * dd / fitted_range
              if (dd == 0) 1 else a * besselK(a, 1)
            }, numeric(1))
            truth_corr <- vapply(distances, function(dd) {
              a <- sqrt(8) * dd / dat$truth$effective_range
              if (dd == 0) 1 else a * besselK(a, 1)
            }, numeric(1))
            fitted_stack <- do.call(c, lapply(fitted_corr, function(r) d$sigma * r))
            truth_stack <- do.call(c, lapply(truth_corr, function(r) dat$truth$Sigma * r))
            row$spatial_covfun_frob_error <- sqrt(sum((fitted_stack - truth_stack)^2)) /
              max(sqrt(sum(truth_stack^2)), 1e-12)
            row$spatial_boundary_contact <- !is.finite(fitted_range) || fitted_range < 1e-4 || fitted_range > 1e4
          } else {
            row$spatial_sd_relative_error <- row$spatial_log_range_error <-
              row$spatial_covfun_frob_error <- NA_real_
            row$spatial_boundary_contact <- FALSE
          }
        } else {
          row$beta_vector <- row$sigma_vector <- NA_character_
          row$spatial_sd_relative_error <- row$spatial_log_range_error <-
            row$spatial_covfun_frob_error <- NA_real_
          row$spatial_boundary_contact <- FALSE
        }
        row$trait_permutation_hash <- dat$trait_permutation_hash %||% "identity"
        row$b0_status_hash <- b0_status_hash
        row$presence_count_hash <- paste(presence, collapse = ";")
        row$absence_count_hash <- paste(total - presence, collapse = ";")
        row$runaway_parameter <- if (is.null(d)) FALSE else d$runaway
        row$outward_improvement <- if (is.null(d)) FALSE else d$outward_improvement
        out[[k]] <- row; pair_rows[[start_role]] <- k; pair_diag[[start_role]] <- d
      }
      if (!is.null(pair_diag$primary) && !is.null(pair_diag$alternate)) {
        objective_gap <- pair_diag$alternate$objective - pair_diag$primary$objective
        primary_sigma <- pair_diag$primary$sigma
        alternate_sigma <- pair_diag$alternate$sigma
        comparable_sigma <- is.matrix(primary_sigma) && is.matrix(alternate_sigma) &&
          length(primary_sigma) > 0L && identical(dim(primary_sigma), dim(alternate_sigma)) &&
          all(is.finite(primary_sigma)) && all(is.finite(alternate_sigma))
        covariance_gap <- if (comparable_sigma) {
          max(abs(alternate_sigma - primary_sigma))
        } else {
          Inf
        }
        for (idx in unlist(pair_rows, use.names = FALSE)) {
          out[[idx]]$alternate_objective_gap <- objective_gap
          out[[idx]]$alternate_covariance_gap <- covariance_gap
        }
      }
  }
  do.call(rbind, out)
}

lane_b_shard_attempts <- function(frozen, shard, allow_missing_mspl = FALSE) {
  lane_b_assert_capabilities(allow_missing_mspl)
  out <- list(); k <- 0L
  for (replicate_id in seq.int(shard$replicate_first, shard$replicate_last)) {
    calibration_n <- if (isTRUE(frozen$smoke)) 5000L else 200000L
    if (shard$table[[1L]] == "ordinary") {
      cell <- frozen$ordinary_manifest[
        frozen$ordinary_manifest$cell_id == shard$cell_id[[1L]], , drop = FALSE]
      datasets <- list(lane_b_generate_ordinary(cell, replicate_id, calibration_n,
        integration_n = if (isTRUE(frozen$smoke)) 256L else 2048L))
      result_cell <- cell
    } else if (shard$table[[1L]] == "permutation") {
      audit <- frozen$permutation_manifest[
        frozen$permutation_manifest$audit_cell_id == shard$cell_id[[1L]], , drop = FALSE]
      datasets <- lane_b_generate_permutation(audit, replicate_id, frozen$ordinary_manifest,
        calibration_n, if (isTRUE(frozen$smoke)) 256L else 2048L)
      source <- frozen$ordinary_manifest[
        frozen$ordinary_manifest$cell_id == audit$source_cell_id[[1L]], , drop = FALSE]
      result_cell <- source; result_cell$cell_id <- audit$audit_cell_id[[1L]]
    } else if (shard$table[[1L]] == "spatial") {
      cell <- frozen$spatial_manifest[
        frozen$spatial_manifest$cell_id == shard$cell_id[[1L]], , drop = FALSE]
      datasets <- list(lane_b_generate_spatial(cell, replicate_id, calibration_n))
      result_cell <- cell
    } else stop("Unknown shard table: ", shard$table[[1L]])
    for (dat in datasets) {
      k <- k + 1L
      out[[k]] <- lane_b_fit_dataset_attempts(dat, result_cell, shard$table[[1L]], frozen)
    }
  }
  do.call(rbind, out)
}

lane_b_run <- function(opt) {
  root <- lane_b_validate_campaign_root(opt$root); paths <- lane_b_campaign_paths(root)
  frozen_path <- file.path(paths[["frozen"]], "lane-b-b2-frozen.rds")
  if (!file.exists(frozen_path)) stop("Run prepare first.")
  frozen <- readRDS(frozen_path)
  lane_b_verify_frozen_runtime(frozen)
  if (is.null(opt$shard_id)) stop("run requires --shard-id.")
  shard <- frozen$queue[frozen$queue$shard_id == opt$shard_id, , drop = FALSE]
  if (nrow(shard) != 1L) stop("Unknown shard: ", opt$shard_id)
  complete <- file.path(paths[["state/complete"]], paste0(opt$shard_id, ".rds"))
  if (file.exists(complete)) return(invisible(readRDS(complete)))
  lane_b_assert_capabilities(opt$allow_missing_mspl)
  lock <- file.path(paths[["state/running"]], paste0(opt$shard_id, ".lock"))
  if (!file.create(lock)) stop("Shard is already locked: ", opt$shard_id)
  on.exit(if (file.exists(lock)) unlink(lock), add = TRUE)
  attempts <- tryCatch(lane_b_shard_attempts(frozen, shard, opt$allow_missing_mspl), error = identity)
  if (inherits(attempts, "condition")) {
    saveRDS(list(shard_id = opt$shard_id, status = "failed",
                 message = conditionMessage(attempts)),
            file.path(paths[["state/failed"]], paste0(opt$shard_id, ".rds")))
    stop(attempts)
  }
  raw_path <- file.path(paths[["raw"]], paste0(opt$shard_id, ".rds"))
  hash <- lane_b_atomic_save_rds(attempts, raw_path)
  receipt <- list(shard_id = opt$shard_id, status = "complete", rows = nrow(attempts),
                  sha256 = hash, completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
  lane_b_atomic_save_rds(receipt, complete)
  pending <- file.path(paths[["state/pending"]], paste0(opt$shard_id, ".rds"))
  if (file.exists(pending)) unlink(pending)
  invisible(receipt)
}

lane_b_resume <- function(opt) {
  root <- lane_b_validate_campaign_root(opt$root); paths <- lane_b_campaign_paths(root)
  frozen <- readRDS(file.path(paths[["frozen"]], "lane-b-b2-frozen.rds"))
  lane_b_verify_frozen_runtime(frozen)
  done <- basename(sub("\\.rds$", "", list.files(paths[["state/complete"]], pattern = "\\.rds$", full.names = FALSE)))
  pending <- setdiff(frozen$queue$shard_id, done)
  cat(sprintf("%d/%d shards complete; %d pending.\n", length(done), nrow(frozen$queue), length(pending)))
  if (length(list.files(paths[["state/running"]], pattern = "\\.lock$")))
    cat("Running locks exist; they are never deleted automatically.\n")
  if (opt$run_pending) for (id in pending) { opt$shard_id <- id; lane_b_run(opt) }
  invisible(pending)
}

lane_b_aggregate <- function(opt) {
  root <- lane_b_validate_campaign_root(opt$root); paths <- lane_b_campaign_paths(root)
  frozen <- readRDS(file.path(paths[["frozen"]], "lane-b-b2-frozen.rds"))
  lane_b_verify_frozen_runtime(frozen)
  verified <- lane_b_verify_shard_receipts(
    frozen$queue, paths[["raw"]], paths[["state/complete"]],
    hash_field = "sha256", require_complete = !opt$provisional
  )
  missing <- verified$missing
  attempts <- do.call(rbind, verified$attempts)
  summary <- lane_b_attempt_summary(attempts)
  ordinary_attempts <- attempts[attempts$table == "ordinary", , drop = FALSE]
  promotion <- lane_b_promotion_metrics(ordinary_attempts, frozen$ordinary_manifest,
    B = frozen$thresholds$paired_bootstrap_repetitions)
  permutation_metrics <- lane_b_permutation_metrics(attempts)
  spatial_metrics <- lane_b_spatial_promotion_metrics(attempts)
  label <- if (length(missing)) "PROVISIONAL-NOT-EVIDENCE" else "COMPLETE"
  result <- list(label = label, manifest_version = frozen$manifest_version,
                 campaign_scope = frozen$campaign_scope %||% "all",
                 attempts = attempts, cell_arm_summary = summary,
                 cell_promotion_metrics = promotion,
                 permutation_invariance_metrics = permutation_metrics,
                 spatial_promotion_metrics = spatial_metrics,
                 thresholds = frozen$thresholds, missing_shards = missing,
                 verified_shards = verified$ids)
  path <- file.path(paths[["summaries"]], "ordinary-summary.rds")
  lane_b_atomic_save_rds(result, path)
  cat(label, "\n"); print(summary)
  invisible(result)
}

lane_b_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opt <- lane_b_parse_cli(args)
  switch(opt$command, prepare = lane_b_prepare(opt), run = lane_b_run(opt),
         resume = lane_b_resume(opt), aggregate = lane_b_aggregate(opt),
         stop("Unknown command: ", opt$command))
}

if (sys.nframe() == 0L) lane_b_main()
