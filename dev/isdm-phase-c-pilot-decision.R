#!/usr/bin/env Rscript

## Sealed corrected-pilot integrity and decision gate.
## Reads only the corrected pilot and only the four prospectively permitted
## summaries. It never accepts C-lite or the sealed original pilot.

Sys.setenv(NOT_CRAN = "true")
source("dev/isdm-bias-campaign.R")

.blank_error_c <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))

.arg_c <- function(args, name, required = TRUE, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) > 1L) stop("Duplicate --", name)
  if (!length(hit)) {
    if (required) stop("Missing --", name, "= option")
    return(default)
  }
  sub(paste0("^--", name, "="), "", hit)
}

.pilot_decision_c <- function(pilot_path, pilot_compute_receipt,
                              preflight_receipt, decision_receipt,
                              calibration_receipt = NULL) {
  if (file.exists(decision_receipt)) stop("Refusing to overwrite decision receipt: ", decision_receipt)
  if (grepl("c-?lite|lite|old", basename(pilot_path), ignore.case = TRUE)) {
    stop("Rejected non-official pilot path: ", pilot_path)
  }
  preflight <- .require_receipt_c(preflight_receipt, "preflight_compute")
  compute <- .require_receipt_c(pilot_compute_receipt, "pilot_compute")
  pilot_path <- normalizePath(pilot_path, mustWork = TRUE)
  if (!identical(normalizePath(compute$output_path, mustWork = TRUE), pilot_path) ||
      !identical(compute$output_sha256, .sha256_c(pilot_path))) {
    stop("Pilot file does not match its compute receipt")
  }
  x <- readRDS(pilot_path)
  required <- c(
    "stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias",
    "n", "T_sp", "d_fit", "k", "beta0_shift", "seed", "arm",
    "elapsed_sec", "realised_prevalence", "fit_error", "pdHess",
    "estimand", "D_bias", "D_rmse", "oracle_collapsed"
  )
  if (!is.data.frame(x) || !all(required %in% names(x))) stop("Pilot schema is incomplete")
  if (nrow(x) != 1500L || !identical(unique(x$stage), "pilot_v2") ||
      !identical(unique(x$block), "G1") || length(unique(x$seed)) != 10L) {
    stop("Pilot does not match the frozen 1,500-row pilot_v2 grid")
  }
  key <- c("stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias",
           "n", "T_sp", "d_fit", "k", "beta0_shift", "seed", "arm")
  if (anyDuplicated(x[key])) stop("Pilot contains duplicate full keys")
  dataset_key <- setdiff(key, "arm")
  arms <- split(as.character(x$arm), do.call(paste, c(x[dataset_key], sep = "|")))
  if (any(vapply(arms, function(a) !identical(sort(a), ARMS), logical(1)))) {
    stop("Pilot does not contain all six arms per dataset")
  }
  null_key <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")
  biased <- x[x$kappa > 0, , drop = FALSE]
  null <- x[x$kappa == 0, , drop = FALSE]
  nk <- do.call(paste, c(null[null_key], sep = "|"))
  bk <- do.call(paste, c(biased[null_key], sep = "|"))
  idx <- match(bk, nk)
  if (anyNA(idx) || anyDuplicated(nk)) stop("Pilot null pairing is not exactly one-to-one")
  completed <- .blank_error_c(x$fit_error)
  total <- completed & x$estimand == "total_sigma"
  if (any(total & (!is.finite(x$D_bias) | !is.finite(x$D_rmse)))) {
    stop("Pilot contains an unlabelled non-finite headline result")
  }
  if (any(x$kappa == 0 & x$arm == "A6" & completed & !x$oracle_collapsed)) {
    stop("Pilot A6 null is not marked oracle_collapsed")
  }

  ## First permitted statistic: pooled PA prevalence, deduplicated by seed.
  prev <- unique(x[c("seed", "realised_prevalence", "beta0_shift")])
  if (nrow(prev) != 10L || any(!is.finite(prev$realised_prevalence))) {
    stop("Pilot prevalence is not structurally defined once per seed")
  }
  pooled_prev <- mean(prev$realised_prevalence)
  beta0_shift <- unique(x$beta0_shift)
  if (length(beta0_shift) != 1L) stop("Pilot does not use one beta0_shift")
  if (beta0_shift != 0) {
    calibration <- .require_receipt_c(calibration_receipt, "pilot_calibration")
    if (!isTRUE(all.equal(as.numeric(calibration$beta0_shift), beta0_shift, tolerance = 0))) {
      stop("Pilot beta0_shift does not match the calibration receipt")
    }
  }
  if (pooled_prev < 0.25 || pooled_prev > 0.50) {
    if (is.null(calibration_receipt) || !nzchar(calibration_receipt)) {
      stop("Out-of-range prevalence requires --calibration-receipt= output path")
    }
    if (file.exists(calibration_receipt)) {
      stop("Refusing to overwrite calibration receipt: ", calibration_receipt)
    }
    cal <- calibrate_beta0_shift()
    .write_receipt_c(calibration_receipt, list(
      receipt_type = "pilot_calibration", status = "PASS",
      source_sha = .git_sha_c(), source_branch = .git_branch_c(),
      source_dirty = .git_dirty_c(), instrument_id = .instrument_id_c(),
      source_pilot_sha256 = .sha256_c(pilot_path),
      beta0_shift = cal$beta0_shift, calibrated_prevalence = cal$prevalence,
      calibration_target = cal$target, calibration_tolerance = cal$tolerance,
      calibration_lower = cal$lower, calibration_upper = cal$upper,
      calibration_iterations = cal$iterations,
      calibration_expansions = cal$expansions,
      calibration_seed_min = 1, calibration_seed_max = 10,
      calibration_config_sha256 = .object_sha256_c(build_config_pilot(1:10, cal$beta0_shift)),
      created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
    ))
    .write_receipt_c(decision_receipt, list(
      receipt_type = "pilot_decision", status = "RERUN_REQUIRED",
      source_sha = .git_sha_c(), source_branch = .git_branch_c(),
      source_dirty = .git_dirty_c(), instrument_id = .instrument_id_c(),
      preflight_receipt_sha256 = .sha256_c(preflight_receipt),
      pilot_compute_receipt_sha256 = .sha256_c(pilot_compute_receipt),
      pilot_sha256 = .sha256_c(pilot_path), pooled_prevalence = pooled_prev,
      beta0_shift_old = beta0_shift, beta0_shift_new = cal$beta0_shift,
      calibrated_prevalence = cal$prevalence, calibration_target = cal$target,
      calibration_tolerance = cal$tolerance, calibration_iterations = cal$iterations,
      calibration_expansions = cal$expansions,
      calibration_receipt_sha256 = .sha256_c(calibration_receipt)
    ))
    return(invisible(list(status = "RERUN_REQUIRED", receipt = decision_receipt)))
  }

  ## Remaining permitted summaries: A1 REF precision, timing, and failures.
  ref <- biased$arm == "A1" & biased$kappa == 1 & biased$rho == 0.6 &
    biased$omega == 0.5 & biased$phi_x == 0.15 & biased$phi_bias == 0.15 &
    biased$n == 400 & biased$T_sp == 8 & biased$d_fit == 2 & biased$k == 3
  ref_rows <- biased[ref, , drop = FALSE]
  ref_idx <- idx[ref]
  pair_complete <- .blank_error_c(ref_rows$fit_error) & .blank_error_c(null$fit_error[ref_idx])
  dD <- ref_rows$D_bias[pair_complete] - null$D_bias[ref_idx[pair_complete]]
  if (length(dD) < 2L || any(!is.finite(dD))) stop("Insufficient completed A1 REF pairs")
  sd_ref <- stats::sd(dD)
  precision <- 3 * sd_ref / sqrt(100)
  g1_seeds <- if (precision <= 0.05) 100L else 200L
  elapsed <- x$elapsed_sec[is.finite(x$elapsed_sec)]
  if (!length(elapsed)) stop("Pilot has no finite elapsed times")
  mean_sec <- mean(elapsed)
  fit_errors <- sum(!completed)
  exclusion_rate <- fit_errors / nrow(x)

  .write_receipt_c(decision_receipt, list(
    receipt_type = "pilot_decision", status = "PASS",
    source_sha = .git_sha_c(), source_branch = .git_branch_c(),
    source_dirty = .git_dirty_c(), instrument_id = .instrument_id_c(),
    preflight_receipt_sha256 = .sha256_c(preflight_receipt),
    pilot_compute_receipt_sha256 = .sha256_c(pilot_compute_receipt),
    pilot_path = pilot_path, pilot_sha256 = .sha256_c(pilot_path),
    calibration_receipt_sha256 = if (!is.null(calibration_receipt) && file.exists(calibration_receipt)) {
      .sha256_c(calibration_receipt)
    } else "",
    pilot_rows = nrow(x), a1_ref_pairs = length(dD), a1_ref_sd_dD_bias = sd_ref,
    projected_3mcse_s100 = precision, g1_seeds = g1_seeds,
    beta0_shift = beta0_shift, pooled_prevalence = pooled_prev,
    mean_seconds_per_fit = mean_sec,
    campaign_route = if (mean_sec > 10) "totoro" else "local",
    fit_errors = fit_errors, exclusion_rate = exclusion_rate,
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ))
  invisible(list(status = "PASS", receipt = decision_receipt, g1_seeds = g1_seeds))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- .pilot_decision_c(
    .arg_c(args, "pilot"), .arg_c(args, "pilot-compute-receipt"),
    .arg_c(args, "preflight-receipt"), .arg_c(args, "decision-receipt"),
    .arg_c(args, "calibration-receipt", required = FALSE)
  )
  cat("Pilot decision status:", out$status, "\nReceipt:", out$receipt, "\n")
}
