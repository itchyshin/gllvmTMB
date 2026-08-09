## dev/isdm-phase-c-analyse-official.R
##
## Official, fail-closed analysis for the frozen Phase C ISDM campaign.
## This script deliberately does not discover files. Every campaign result and
## the output directory must be supplied explicitly:
##
##   Rscript dev/isdm-phase-c-analyse-official.R \
##     --pilot /absolute/path/pilot-v2.rds \
##     --result G1=/absolute/path/g1.rds \
##     --result G2=/absolute/path/g2.rds \
##     --result G3=/absolute/path/g3.rds \
##     --result G4=/absolute/path/g4.rds \
##     --result G5=/absolute/path/g5.rds \
##     --result G6=/absolute/path/g6.rds \
##     --out-dir /absolute/path/phase-c-official
##
## Pilot, smoke, preflight, old-pilot, and C-lite files are rejected. The six
## official stages are required exactly once. Existing output files are never
## overwritten, preventing an official analysis from being mixed with an older
## run.
##
## Required result schema (one row per logical fit):
##   stage, block, kappa, rho, omega, phi_x, phi_bias, n, T_sp, d_fit,
##   k, beta0_shift, seed, arm,
##   elapsed_sec, realised_prevalence, bias_sharing, fit_error,
##   convergence, pdHess, diag_B_skip, oracle_collapsed, estimand,
##   D_bias, D_rmse, D_max, D_z, rank_d_D_bias, rank_d_D_rmse, signflip,
##   diag_rmse, psi_rmse, lambda_proc_rmse, beta_bias, beta_rmse,
##   n_heywood_psi, n_heywood_loading.
##
## Pairing contract: a biased fit is matched to exactly one null using only
##   stage + seed + arm + n + T_sp + d_fit + k.
## block, rho, omega, and phi_bias are intentionally NOT null-join keys: they
## describe the biased configuration and collapse at kappa = 0. phi_x is
## prospectively frozen to 0.15 and checked before this key is used. Full fit
## uniqueness is checked using every canonical configuration field first.

Sys.setenv(NOT_CRAN = "true")
source("dev/isdm-bias-campaign.R")

.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

.near <- function(x, value, tol = 1e-10) {
  is.finite(x) & abs(x - value) <= tol
}

.blank_error <- function(x) {
  is.na(x) | !nzchar(trimws(as.character(x)))
}

.key_piece <- function(x) {
  if (is.numeric(x)) {
    ifelse(is.na(x), "<NA>", sprintf("%.17g", x))
  } else if (is.logical(x)) {
    ifelse(is.na(x), "<NA>", ifelse(x, "TRUE", "FALSE"))
  } else {
    y <- as.character(x)
    ifelse(is.na(y), "<NA>", y)
  }
}

.make_key <- function(df, cols) {
  if (!all(cols %in% names(df))) {
    .stopf("Internal key error: missing columns: %s",
           paste(setdiff(cols, names(df)), collapse = ", "))
  }
  pieces <- lapply(df[cols], .key_piece)
  do.call(paste, c(pieces, sep = "\r"))
}

.safe_stats <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (!n) return(c(n = 0, mean = NA_real_, sd = NA_real_, mcse = NA_real_))
  sx <- if (n >= 2L) stats::sd(x) else NA_real_
  c(n = n, mean = mean(x), sd = sx,
    mcse = if (n >= 2L) sx / sqrt(n) else NA_real_)
}

.flag_3mcse <- function(estimate, mcse, direction = c("absolute", "positive", "negative"),
                        magnitude = 0) {
  direction <- match.arg(direction)
  if (!is.finite(estimate) || !is.finite(mcse) || mcse <= 0) return(FALSE)
  if (direction == "absolute") {
    abs(estimate) > 0 && abs(estimate) >= magnitude && abs(estimate) >= 3 * mcse
  } else if (direction == "positive") {
    estimate > 0 && estimate >= magnitude && estimate >= 3 * mcse
  } else {
    estimate < 0 && estimate <= -magnitude && -estimate >= 3 * mcse
  }
}

.parse_cli <- function(args) {
  results <- character()
  receipts <- character()
  pilot <- NULL
  preflight_receipt <- NULL
  pilot_compute_receipt <- NULL
  pilot_decision_receipt <- NULL
  calibration_receipt <- NULL
  out_dir <- NULL
  singleton <- function(current, value, name) {
    if (!is.null(current)) .stopf("%s collision: supplied twice", name)
    value
  }
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (identical(arg, "--help")) {
      cat("Usage: Rscript dev/isdm-phase-c-analyse-official.R ",
          "--pilot pilot-v2.rds --result G1=file ... --result G6=file ",
          "--receipt G1=file ... --receipt G6=file --preflight-receipt=file ",
          "--pilot-compute-receipt=file --pilot-decision-receipt=file ",
          "[--calibration-receipt=file] --out-dir directory\n", sep = "")
      return(list(help = TRUE))
    }
    target <- NULL
    if (identical(arg, "--result")) {
      i <- i + 1L
      if (i > length(args)) .stopf("--result requires STAGE=FILE")
      spec <- args[[i]]
      target <- "result"
    } else if (startsWith(arg, "--result=")) {
      spec <- substring(arg, nchar("--result=") + 1L)
      target <- "result"
    } else if (identical(arg, "--receipt")) {
      i <- i + 1L
      if (i > length(args)) .stopf("--receipt requires STAGE=FILE")
      spec <- args[[i]]
      target <- "receipt"
    } else if (startsWith(arg, "--receipt=")) {
      spec <- substring(arg, nchar("--receipt=") + 1L)
      target <- "receipt"
    } else if (identical(arg, "--pilot")) {
      i <- i + 1L
      if (i > length(args)) .stopf("--pilot requires a file")
      if (!is.null(pilot)) .stopf("Pilot collision: --pilot was supplied twice")
      pilot <- args[[i]]
      i <- i + 1L
      next
    } else if (startsWith(arg, "--pilot=")) {
      if (!is.null(pilot)) .stopf("Pilot collision: --pilot was supplied twice")
      pilot <- substring(arg, nchar("--pilot=") + 1L)
      i <- i + 1L
      next
    } else if (startsWith(arg, "--preflight-receipt=")) {
      preflight_receipt <- singleton(
        preflight_receipt, substring(arg, nchar("--preflight-receipt=") + 1L),
        "preflight receipt"
      )
      i <- i + 1L; next
    } else if (startsWith(arg, "--pilot-compute-receipt=")) {
      pilot_compute_receipt <- singleton(
        pilot_compute_receipt, substring(arg, nchar("--pilot-compute-receipt=") + 1L),
        "pilot compute receipt"
      )
      i <- i + 1L; next
    } else if (startsWith(arg, "--pilot-decision-receipt=")) {
      pilot_decision_receipt <- singleton(
        pilot_decision_receipt, substring(arg, nchar("--pilot-decision-receipt=") + 1L),
        "pilot decision receipt"
      )
      i <- i + 1L; next
    } else if (startsWith(arg, "--calibration-receipt=")) {
      calibration_receipt <- singleton(
        calibration_receipt, substring(arg, nchar("--calibration-receipt=") + 1L),
        "calibration receipt"
      )
      i <- i + 1L; next
    } else if (identical(arg, "--out-dir")) {
      i <- i + 1L
      if (i > length(args)) .stopf("--out-dir requires a directory")
      out_dir <- args[[i]]
      i <- i + 1L
      next
    } else if (startsWith(arg, "--out-dir=")) {
      out_dir <- substring(arg, nchar("--out-dir=") + 1L)
      i <- i + 1L
      next
    } else {
      .stopf("Unknown argument: %s", arg)
    }
    pos <- regexpr("=", spec, fixed = TRUE)
    if (pos < 2L || pos == nchar(spec)) .stopf("Invalid --%s value: %s", target, spec)
    stage <- toupper(substr(spec, 1L, pos - 1L))
    path <- substring(spec, pos + 1L)
    dest <- if (target == "result") results else receipts
    if (stage %in% names(dest)) .stopf("%s stage collision: %s was supplied twice", target, stage)
    dest[[stage]] <- path
    if (target == "result") results <- dest else receipts <- dest
    i <- i + 1L
  }

  required_stages <- paste0("G", 1:6)
  if (!identical(sort(names(results)), required_stages)) {
    .stopf("Official analysis requires exactly G1-G6; got: %s",
           paste(sort(names(results)), collapse = ", "))
  }
  if (!identical(sort(names(receipts)), required_stages)) {
    .stopf("Official analysis requires exactly G1-G6 receipts; got: %s",
           paste(sort(names(receipts)), collapse = ", "))
  }
  if (is.null(pilot) || !nzchar(pilot)) .stopf("An explicit corrected --pilot is required")
  required_singletons <- c(
    preflight_receipt = is.null(preflight_receipt),
    pilot_compute_receipt = is.null(pilot_compute_receipt),
    pilot_decision_receipt = is.null(pilot_decision_receipt)
  )
  if (any(required_singletons)) {
    .stopf("Missing required receipt argument(s): %s", paste(names(required_singletons)[required_singletons], collapse = ", "))
  }
  if (is.null(out_dir) || !nzchar(out_dir)) .stopf("An explicit --out-dir is required")
  list(
    help = FALSE, pilot = pilot, results = results, receipts = receipts,
    preflight_receipt = preflight_receipt,
    pilot_compute_receipt = pilot_compute_receipt,
    pilot_decision_receipt = pilot_decision_receipt,
    calibration_receipt = calibration_receipt, out_dir = out_dir
  )
}

.reject_nonofficial_path <- function(path, label, allow_pilot = FALSE) {
  bad_terms <- if (allow_pilot) "c-?lite|lite|old|smoke|preflight" else
    "c-?lite|lite|pilot|old|smoke|preflight"
  bad <- sprintf("(^|[-_.])(%s)([-_.]|$)", bad_terms)
  if (grepl(bad, tolower(basename(path)), perl = TRUE)) {
    .stopf("Rejected non-official %s path: %s", label, path)
  }
}

.validate_one_stage <- function(x, block_label, path, expected_stage = "campaign") {
  if (!is.data.frame(x)) .stopf("%s is not a data.frame: %s", block_label, path)
  required <- c(
    "stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias", "n",
    "T_sp", "d_fit", "k", "beta0_shift", "seed", "arm", "elapsed_sec",
    "realised_prevalence", "bias_sharing", "fit_error", "convergence",
    "pdHess", "diag_B_skip", "oracle_collapsed", "estimand", "D_bias",
    "D_rmse", "D_max", "D_z", "rank_d_D_bias", "rank_d_D_rmse",
    "signflip", "diag_rmse", "psi_rmse",
    "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi",
    "n_heywood_loading", "theoretical_bias_rho",
    "theoretical_bias_sharing", "theoretical_bias_variance",
    "realised_bias_rho_mean", "realised_bias_rho_max_abs_error",
    "realised_bias_sharing_mean", "realised_bias_sharing_max_abs_error",
    "realised_bias_variance_mean", "realised_bias_variance_max_abs_error",
    "fit_attempted"
  )
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    .stopf("%s is missing required columns: %s", block_label, paste(missing, collapse = ", "))
  }
  if (!nrow(x)) .stopf("%s contains zero rows", block_label)

  block <- unique(toupper(as.character(x$block)))
  if (length(block) != 1L || is.na(block) || block != block_label) {
    .stopf("Stage collision: file assigned to %s contains block value(s): %s",
           block_label, paste(block, collapse = ", "))
  }
  embedded <- unique(tolower(as.character(x$stage)))
  if (length(embedded) != 1L || is.na(embedded) || embedded != expected_stage) {
    .stopf("Rejected unexpected stage in %s: %s", block_label,
           paste(embedded, collapse = ", "))
  }
  x$stage <- expected_stage
  x$block <- block_label
  x$arm <- as.character(x$arm)
  if (anyNA(x$arm) || !all(x$arm %in% paste0("A", 1:6))) {
    .stopf("%s contains missing or unknown arm labels", block_label)
  }

  config_numeric <- c("kappa", "rho", "omega", "phi_x", "phi_bias", "n",
                      "T_sp", "d_fit", "k", "beta0_shift", "seed")
  for (nm in config_numeric) {
    if (!is.numeric(x[[nm]]) || any(!is.finite(x[[nm]]))) {
      .stopf("%s column %s must be finite numeric on every row", block_label, nm)
    }
  }
  if (any(x$kappa < 0) || any(x$n <= 0) || any(x$T_sp <= 0) ||
      any(x$d_fit <= 0) || any(x$k <= 0)) {
    .stopf("%s contains an impossible configuration value", block_label)
  }
  if (any(!.near(x$phi_x, 0.15))) {
    .stopf("%s violates the prospective phi_x = 0.15 freeze", block_label)
  }

  fit_attempted <- x$fit_attempted
  if (!is.logical(fit_attempted)) {
    if ((is.numeric(fit_attempted) || is.integer(fit_attempted)) &&
        all(is.na(fit_attempted) | fit_attempted %in% c(0, 1))) {
      fit_attempted <- as.logical(fit_attempted)
    } else {
      .stopf("%s fit_attempted must be logical or 0/1", block_label)
    }
  }
  if (any(is.na(fit_attempted) | !fit_attempted)) {
    .stopf("%s contains a DGP/pre-fit failure rather than a model-level fit error", block_label)
  }
  x$fit_attempted <- fit_attempted
  target_sharing <- x$rho^2 + (1 - x$rho^2) * x$omega
  if (any(!.near(x$theoretical_bias_rho, x$rho)) ||
      any(!.near(x$theoretical_bias_sharing, target_sharing)) ||
      any(!.near(x$theoretical_bias_variance, x$kappa^2))) {
    .stopf("%s theoretical bias-geometry columns differ from the frozen treatments", block_label)
  }
  biased_geometry <- x$kappa > 0
  geometry_error_fields <- c(
    "realised_bias_rho_max_abs_error",
    "realised_bias_sharing_max_abs_error",
    "realised_bias_variance_max_abs_error"
  )
  for (nm in geometry_error_fields) {
    if (any(biased_geometry & (!is.finite(x[[nm]]) | x[[nm]] > 1e-9))) {
      .stopf("%s violates exact finite-sample geometry in %s", block_label, nm)
    }
  }
  if (any(!biased_geometry &
          (!.near(x$realised_bias_variance_max_abs_error, 0) |
           !is.na(x$realised_bias_rho_max_abs_error) |
           !is.na(x$realised_bias_sharing_max_abs_error)))) {
    .stopf("%s null rows have invalid realised geometry diagnostics", block_label)
  }

  completed <- .blank_error(x$fit_error)
  always_numeric <- c(
    "elapsed_sec", "realised_prevalence", "bias_sharing", "convergence",
    "diag_B_skip", "D_bias", "D_rmse", "D_max", "D_z", "rank_d_D_bias",
    "rank_d_D_rmse", "signflip", "diag_rmse", "psi_rmse",
    "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi",
    "n_heywood_loading", "theoretical_bias_rho",
    "theoretical_bias_sharing", "theoretical_bias_variance",
    "realised_bias_rho_mean", "realised_bias_rho_max_abs_error",
    "realised_bias_sharing_mean", "realised_bias_sharing_max_abs_error",
    "realised_bias_variance_mean", "realised_bias_variance_max_abs_error"
  )
  for (nm in always_numeric) {
    if (!is.numeric(x[[nm]]) && !is.integer(x[[nm]])) {
      .stopf("%s column %s must be numeric", block_label, nm)
    }
  }
  estimand <- as.character(x$estimand)
  total <- completed & estimand == "total_sigma"
  rank_d <- completed & estimand == "loadings_only_rank_d"
  if (any(completed & !(total | rank_d))) {
    .stopf("%s has completed rows with missing or unknown estimands", block_label)
  }
  expected_rank <- x$block == "G5" & x$arm == "A2"
  if (any(completed & (rank_d != expected_rank))) {
    .stopf("%s violates the G5/A2-only rank-d estimand contract", block_label)
  }
  total_required <- c(
    "elapsed_sec", "realised_prevalence", "bias_sharing", "convergence",
    "diag_B_skip", "D_bias", "D_rmse", "D_max", "D_z", "signflip",
    "diag_rmse", "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
    "n_heywood_psi", "n_heywood_loading"
  )
  rank_required <- c(
    "elapsed_sec", "realised_prevalence", "bias_sharing", "convergence",
    "diag_B_skip", "rank_d_D_bias", "rank_d_D_rmse", "lambda_proc_rmse",
    "beta_bias", "beta_rmse", "n_heywood_loading"
  )
  for (nm in total_required) {
    bad <- total & !is.finite(x[[nm]])
    if (any(bad)) {
      .stopf("%s has %d completed total-Sigma row(s) with unlabeled non-finite %s",
             block_label, sum(bad), nm)
    }
  }
  for (nm in rank_required) {
    bad <- rank_d & !is.finite(x[[nm]])
    if (any(bad)) {
      .stopf("%s has %d completed rank-d row(s) with unlabeled non-finite %s",
             block_label, sum(bad), nm)
    }
  }
  if (any(rank_d & x$diag_B_skip <= 0)) {
    .stopf("%s has G5/A2 rank-d rows without diag_B_skip > 0", block_label)
  }
  if (any(rank_d & (is.finite(x$D_bias) | is.finite(x$D_rmse)))) {
    .stopf("%s leaks G5/A2 rank-d results into total-Sigma columns", block_label)
  }
  pd <- x$pdHess
  if (!is.logical(pd)) {
    if (is.numeric(pd) && all(is.na(pd) | pd %in% c(0, 1))) {
      pd <- as.logical(pd)
    } else {
      .stopf("%s pdHess must be logical or 0/1", block_label)
    }
  }
  if (any(completed & is.na(pd))) {
    .stopf("%s has completed fits with unlabeled pdHess", block_label)
  }
  x$pdHess <- pd
  oc <- x$oracle_collapsed
  if (!is.logical(oc)) {
    if (is.numeric(oc) && all(is.na(oc) | oc %in% c(0, 1))) oc <- as.logical(oc)
    else .stopf("%s oracle_collapsed must be logical or 0/1", block_label)
  }
  if (any(completed & is.na(oc))) .stopf("%s has unlabeled oracle-collapse states", block_label)
  x$oracle_collapsed <- oc
  x$fit_complete <- completed
  x
}

.assert_a5_a6_null_equal <- function(x, label) {
  null <- x[.near(x$kappa, 0) & x$arm %in% c("A5", "A6"), , drop = FALSE]
  a5 <- null[null$arm == "A5", , drop = FALSE]
  a6 <- null[null$arm == "A6", , drop = FALSE]
  key <- c("stage", "block", "seed", "n", "T_sp", "d_fit", "k", "beta0_shift")
  idx <- match(.make_key(a5, key), .make_key(a6, key))
  if (nrow(a5) != nrow(a6) || anyNA(idx)) {
    .stopf("%s A5/A6-null rows do not pair exactly", label)
  }
  a6 <- a6[idx, , drop = FALSE]
  if (any(a5$fit_complete != a6$fit_complete)) {
    .stopf("%s A5/A6-null completion states differ", label)
  }
  fields <- c(
    "convergence", "pdHess", "diag_B_skip", "estimand", "D_bias", "D_rmse",
    "D_max", "D_z", "signflip", "diag_rmse", "psi_rmse",
    "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi",
    "n_heywood_loading"
  )
  complete <- a5$fit_complete
  for (field in fields) {
    if (!isTRUE(all.equal(a5[[field]][complete], a6[[field]][complete], tolerance = 0))) {
      .stopf("%s A5/A6-null field is not exactly equal: %s", label, field)
    }
  }
  invisible(TRUE)
}

.load_official_results <- function(paths) {
  normalized <- character()
  blocks <- names(paths)
  out <- vector("list", length(paths)); names(out) <- blocks
  for (block in blocks) {
    path <- paths[[block]]
    .reject_nonofficial_path(path, "result")
    if (!file.exists(path)) .stopf("Result file does not exist: %s", path)
    normalized[[block]] <- normalizePath(path, mustWork = TRUE)
  }
  if (anyDuplicated(unname(normalized))) .stopf("Stage collision: one result file was assigned twice")
  for (block in blocks) {
    out[[block]] <- .validate_one_stage(readRDS(normalized[[block]]), block, normalized[[block]])
  }
  all <- do.call(rbind, out)
  rownames(all) <- NULL
  .assert_a5_a6_null_equal(all, "Campaign")

  full_cols <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
                 "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  full_key <- .make_key(all, full_cols)
  if (anyDuplicated(full_key)) {
    dup <- unique(full_key[duplicated(full_key) | duplicated(full_key, fromLast = TRUE)])
    .stopf("Full-key collision: %d duplicated stage/config/seed/arm key(s)", length(dup))
  }

  dataset_cols <- c("stage", "block", "seed", "kappa", "rho", "omega",
                    "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  by_dataset <- split(all$arm, .make_key(all, dataset_cols))
  bad_six <- vapply(by_dataset, function(a) !identical(sort(a), paste0("A", 1:6)), logical(1))
  if (any(bad_six)) {
    .stopf("Six-arm contract failed for %d dataset configuration(s)", sum(bad_six))
  }

  shifts <- unique(all$beta0_shift)
  if (length(shifts) != 1L) .stopf("Campaign files do not share one frozen beta0_shift")
  a6_null <- all[.near(all$kappa, 0) & all$arm == "A6", ]
  if (!nrow(a6_null) || any(!a6_null$oracle_collapsed)) {
    .stopf("A6 logical null rows are missing or not marked oracle_collapsed")
  }
  if (any(all$fit_complete & !.near(all$kappa, 0) & all$arm == "A6" & all$oracle_collapsed)) {
    .stopf("A biased A6 row is incorrectly marked oracle_collapsed")
  }

  null_cols <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")
  expected_null_keys <- unique(.make_key(all, null_cols))
  null <- all[.near(all$kappa, 0), , drop = FALSE]
  null_keys <- .make_key(null, null_cols)
  counts <- table(factor(null_keys, levels = expected_null_keys))
  if (any(counts != 1L)) {
    .stopf("Null contract failed: %d stage+seed+arm+n+T_sp+d_fit+k group(s) do not have exactly one null",
           sum(counts != 1L))
  }
  all
}

.load_official_pilot <- function(path) {
  .reject_nonofficial_path(path, "pilot", allow_pilot = TRUE)
  if (!file.exists(path)) .stopf("Corrected pilot file does not exist: %s", path)
  path <- normalizePath(path, mustWork = TRUE)
  x <- .validate_one_stage(readRDS(path), "G1", path, expected_stage = "pilot_v2")
  .assert_a5_a6_null_equal(x, "Corrected pilot")
  full_cols <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
                 "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  if (anyDuplicated(.make_key(x, full_cols))) .stopf("Corrected pilot has duplicate full keys")
  dataset_cols <- setdiff(full_cols, "arm")
  by_dataset <- split(x$arm, .make_key(x, dataset_cols))
  if (any(vapply(by_dataset, function(a) !identical(sort(a), paste0("A", 1:6)), logical(1)))) {
    .stopf("Corrected pilot violates the six-arm contract")
  }
  null_cols <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")
  expected <- unique(.make_key(x, null_cols))
  null <- x[.near(x$kappa, 0), , drop = FALSE]
  counts <- table(factor(.make_key(null, null_cols), levels = expected))
  if (any(counts != 1L)) .stopf("Corrected pilot violates the exact null-key contract")
  a6_null <- x[.near(x$kappa, 0) & x$arm == "A6", ]
  if (!nrow(a6_null) || any(!a6_null$oracle_collapsed)) {
    .stopf("Corrected pilot lacks attributable A6-null aliases")
  }
  x
}

.make_paired <- function(all) {
  null_cols <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")
  null <- all[.near(all$kappa, 0), , drop = FALSE]
  biased <- all[!.near(all$kappa, 0), , drop = FALSE]
  null_key <- .make_key(null, null_cols)
  idx <- match(.make_key(biased, null_cols), null_key)
  if (anyNA(idx)) .stopf("Internal pairing failure: at least one biased row has no null")

  metrics <- c("D_bias", "D_rmse", "D_max", "D_z", "rank_d_D_bias",
               "rank_d_D_rmse", "signflip", "diag_rmse", "psi_rmse",
               "lambda_proc_rmse", "beta_bias", "beta_rmse")
  paired <- biased
  for (nm in c(metrics, "fit_complete", "pdHess", "convergence", "diag_B_skip",
               "n_heywood_psi", "n_heywood_loading")) {
    paired[[paste0(nm, "_null")]] <- null[[nm]][idx]
  }
  paired$completed_pair <- paired$fit_complete & paired$fit_complete_null
  paired$both_pdHess <- paired$completed_pair & paired$pdHess & paired$pdHess_null
  for (nm in metrics) {
    dnm <- paste0("d", nm)
    paired[[dnm]] <- ifelse(
      paired$completed_pair,
      paired[[nm]] - paired[[paste0(nm, "_null")]],
      NA_real_
    )
  }
  paired$headline_eligible <- !(paired$block == "G5" & paired$arm == "A2")
  paired
}

.summarise_pairs <- function(paired, metrics, extra_mask = rep(TRUE, nrow(paired))) {
  group_cols <- c("stage", "block", "arm", "kappa", "rho", "omega",
                  "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  use <- which(extra_mask)
  if (!length(use)) return(data.frame())
  groups <- split(use, .make_key(paired[use, , drop = FALSE], group_cols))
  rows <- lapply(groups, function(ii) {
    z <- paired[ii, , drop = FALSE]
    row <- z[1L, group_cols, drop = FALSE]
    row$n_pairs <- nrow(z)
    row$n_completed_pairs <- sum(z$completed_pair)
    row$n_excluded_pairs <- row$n_pairs - row$n_completed_pairs
    row$exclusion_rate <- row$n_excluded_pairs / row$n_pairs
    row$exclusion_gt_5pct <- row$exclusion_rate > 0.05
    row$n_both_pdHess <- sum(z$both_pdHess)
    row$n_nonzero_convergence_biased <- sum(z$fit_complete & z$convergence != 0)
    row$n_nonzero_convergence_null <- sum(z$fit_complete_null & z$convergence_null != 0)
    for (metric in metrics) {
      sa <- .safe_stats(z[[metric]][z$completed_pair])
      sp <- .safe_stats(z[[metric]][z$both_pdHess])
      row[[paste0(metric, "_mean_all")]] <- unname(sa[["mean"]])
      row[[paste0(metric, "_sd_all")]] <- unname(sa[["sd"]])
      row[[paste0(metric, "_mcse_all")]] <- unname(sa[["mcse"]])
      row[[paste0(metric, "_mean_both_pdHess")]] <- unname(sp[["mean"]])
      row[[paste0(metric, "_sd_both_pdHess")]] <- unname(sp[["sd"]])
      row[[paste0(metric, "_mcse_both_pdHess")]] <- unname(sp[["mcse"]])
      row[[paste0(metric, "_pdHess_diff_gt_1_all_mcse")]] <-
        is.finite(sa[["mean"]]) && is.finite(sp[["mean"]]) && is.finite(sa[["mcse"]]) &&
        abs(sp[["mean"]] - sa[["mean"]]) > sa[["mcse"]]
    }
    row
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[do.call(order, out[group_cols]), , drop = FALSE]
}

.a1_ref_precision <- function(paired) {
  take <- paired$stage == "pilot_v2" & paired$block == "G1" & paired$arm == "A1" &
    .near(paired$kappa, 1) & .near(paired$rho, 0.6) &
    .near(paired$omega, 0.5) & .near(paired$phi_x, 0.15) &
    .near(paired$phi_bias, 0.15) &
    .near(paired$n, 400) & .near(paired$T_sp, 8) &
    .near(paired$d_fit, 2) & .near(paired$k, 3)
  z <- paired[take, , drop = FALSE]
  if (!nrow(z)) .stopf("A1 REF precision cell is absent")
  sa <- .safe_stats(z$dD_bias[z$completed_pair])
  sp <- .safe_stats(z$dD_bias[z$both_pdHess])
  projected <- 3 * unname(sa[["sd"]]) / sqrt(100)
  data.frame(
    stage = "pilot_v2", block = "G1", arm = "A1", kappa = 1, rho = 0.6,
    omega = 0.5, phi_x = 0.15, phi_bias = 0.15, n = 400, T_sp = 8,
    d_fit = 2, k = 3, beta0_shift = unique(z$beta0_shift),
    n_pairs = nrow(z), n_completed_pairs = unname(sa[["n"]]),
    mean_dD_bias_all = unname(sa[["mean"]]), sd_dD_bias_all = unname(sa[["sd"]]),
    mcse_dD_bias_all = unname(sa[["mcse"]]), projected_3mcse_at_S100 = projected,
    precision_decision = if (is.finite(projected) && projected <= 0.05) {
      "S100_CLEARS_FROZEN_PRECISION_RULE"
    } else {
      "FROZEN_PRECISION_ESCALATION_REQUIRED"
    },
    n_both_pdHess = unname(sp[["n"]]),
    mean_dD_bias_both_pdHess = unname(sp[["mean"]]),
    mcse_dD_bias_both_pdHess = unname(sp[["mcse"]]),
    stringsAsFactors = FALSE
  )
}

.primary_endpoint <- function(paired) {
  take <- paired$stage == "campaign" & paired$block == "G1" & paired$arm == "A1" &
    .near(paired$kappa, 1) & .near(paired$rho, 0) & .near(paired$omega, 1) &
    .near(paired$phi_x, 0.15) & .near(paired$phi_bias, 0.15) &
    .near(paired$n, 400) & .near(paired$T_sp, 8) &
    .near(paired$d_fit, 2) & .near(paired$k, 3)
  z <- paired[take, , drop = FALSE]
  if (!nrow(z)) .stopf("Frozen A1 primary endpoint is absent")
  out <- .summarise_pairs(z, c("dD_bias"))
  raw_b <- .safe_stats(z$D_bias[z$fit_complete])
  raw_n <- .safe_stats(z$D_bias_null[z$fit_complete_null])
  out$D_bias_biased_mean_unpaired <- unname(raw_b[["mean"]])
  out$D_bias_biased_mcse_unpaired <- unname(raw_b[["mcse"]])
  out$D_bias_null_mean_unpaired <- unname(raw_n[["mean"]])
  out$D_bias_null_mcse_unpaired <- unname(raw_n[["mcse"]])
  out$primary_clears_all <- mapply(
    .flag_3mcse, out$dD_bias_mean_all, out$dD_bias_mcse_all,
    MoreArgs = list(direction = "positive", magnitude = 0.10)
  )
  out$primary_clears_both_pdHess <- mapply(
    .flag_3mcse, out$dD_bias_mean_both_pdHess, out$dD_bias_mcse_both_pdHess,
    MoreArgs = list(direction = "positive", magnitude = 0.10)
  )
  out
}

.c1_c2 <- function(summary) {
  out <- summary
  out$C1_all <- mapply(
    .flag_3mcse, out$dD_bias_mean_all, out$dD_bias_mcse_all,
    MoreArgs = list(direction = "absolute", magnitude = 0.10)
  )
  out$C1_both_pdHess <- mapply(
    .flag_3mcse, out$dD_bias_mean_both_pdHess, out$dD_bias_mcse_both_pdHess,
    MoreArgs = list(direction = "absolute", magnitude = 0.10)
  )
  out$C2_all <- mapply(
    .flag_3mcse, out$dsignflip_mean_all, out$dsignflip_mcse_all,
    MoreArgs = list(direction = "positive", magnitude = 0.05)
  )
  out$C2_both_pdHess <- mapply(
    .flag_3mcse, out$dsignflip_mean_both_pdHess, out$dsignflip_mcse_both_pdHess,
    MoreArgs = list(direction = "positive", magnitude = 0.05)
  )
  out$CORRUPTED_all <- out$C1_all | out$C2_all
  out$CORRUPTED_both_pdHess <- out$C1_both_pdHess | out$C2_both_pdHess
  out
}

.a5_a6_contrasts <- function(paired) {
  cfg_cols <- c("stage", "block", "seed", "kappa", "rho", "omega",
                "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  a5 <- paired[paired$arm == "A5", , drop = FALSE]
  a6 <- paired[paired$arm == "A6", , drop = FALSE]
  key6 <- .make_key(a6, cfg_cols)
  idx <- match(.make_key(a5, cfg_cols), key6)
  if (anyNA(idx) || anyDuplicated(key6)) .stopf("A5-A6 pairing contract failed")
  out <- a5[cfg_cols]
  out$D_bias_A5_minus_A6 <- ifelse(
    a5$fit_complete & a6$fit_complete[idx], a5$D_bias - a6$D_bias[idx], NA_real_)
  out$dD_bias_A5_minus_A6 <- ifelse(
    a5$completed_pair & a6$completed_pair[idx], a5$dD_bias - a6$dD_bias[idx], NA_real_)
  out$completed_A5_A6 <- a5$fit_complete & a6$fit_complete[idx]
  out$both_pdHess_A5_A6 <- out$completed_A5_A6 & a5$pdHess & a6$pdHess[idx]
  out$completed_paired_A5_A6 <- a5$completed_pair & a6$completed_pair[idx]
  out$both_paired_pdHess_A5_A6 <- out$completed_paired_A5_A6 &
    a5$both_pdHess & a6$both_pdHess[idx]

  group_cols <- setdiff(cfg_cols, "seed")
  groups <- split(seq_len(nrow(out)), .make_key(out, group_cols))
  rows <- lapply(groups, function(ii) {
    z <- out[ii, , drop = FALSE]
    row <- z[1L, group_cols, drop = FALSE]
    for (metric in c("D_bias_A5_minus_A6", "dD_bias_A5_minus_A6")) {
      raw_metric <- identical(metric, "D_bias_A5_minus_A6")
      all_mask <- if (raw_metric) z$completed_A5_A6 else z$completed_paired_A5_A6
      pd_mask <- if (raw_metric) z$both_pdHess_A5_A6 else z$both_paired_pdHess_A5_A6
      sa <- .safe_stats(z[[metric]][all_mask]); sp <- .safe_stats(z[[metric]][pd_mask])
      row[[paste0(metric, "_mean_all")]] <- unname(sa[["mean"]])
      row[[paste0(metric, "_mcse_all")]] <- unname(sa[["mcse"]])
      row[[paste0(metric, "_mean_both_pdHess")]] <- unname(sp[["mean"]])
      row[[paste0(metric, "_mcse_both_pdHess")]] <- unname(sp[["mcse"]])
      row[[paste0(metric, "_n_all")]] <- unname(sa[["n"]])
      row[[paste0(metric, "_n_both_pdHess")]] <- unname(sp[["n"]])
    }
    row
  })
  summary <- do.call(rbind, rows); rownames(summary) <- NULL
  summary$C3_all <- mapply(
    .flag_3mcse, summary$D_bias_A5_minus_A6_mean_all,
    summary$D_bias_A5_minus_A6_mcse_all,
    MoreArgs = list(direction = "positive", magnitude = 0)
  )
  summary$C3_both_pdHess <- mapply(
    .flag_3mcse, summary$D_bias_A5_minus_A6_mean_both_pdHess,
    summary$D_bias_A5_minus_A6_mcse_both_pdHess,
    MoreArgs = list(direction = "positive", magnitude = 0)
  )
  list(fit_level = out, summary = summary)
}

.ladder_vs_ref <- function(paired) {
  ref <- paired[paired$stage == "campaign" & paired$block == "G1" & .near(paired$kappa, 1) &
                  .near(paired$rho, 0.6) & .near(paired$omega, 0.5) &
                  .near(paired$phi_x, 0.15) & .near(paired$phi_bias, 0.15) &
                  .near(paired$n, 400) &
                  .near(paired$T_sp, 8) & .near(paired$d_fit, 2) & .near(paired$k, 3), ]
  ref_key <- .make_key(ref, c("seed", "arm"))
  if (anyDuplicated(ref_key)) .stopf("G1 REF is not unique by seed+arm")
  z <- paired[paired$stage == "campaign" & paired$block %in% paste0("G", 2:6) &
                paired$headline_eligible, ]
  idx <- match(.make_key(z, c("seed", "arm")), ref_key)
  if (anyNA(idx)) .stopf("At least one G2-G6 row has no same-seed, same-arm G1 REF")
  metrics <- c("dD_bias", "dD_rmse", "dsignflip", "ddiag_rmse", "dpsi_rmse", "dbeta_bias")
  for (metric in metrics) {
    z[[paste0(metric, "_vs_REF")]] <- ifelse(
      z$completed_pair & ref$completed_pair[idx],
      z[[metric]] - ref[[metric]][idx], NA_real_)
  }
  z$completed_vs_REF <- z$completed_pair & ref$completed_pair[idx]
  z$both_pdHess_vs_REF <- z$both_pdHess & ref$both_pdHess[idx]

  group_cols <- c("stage", "block", "arm", "kappa", "rho", "omega",
                  "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  groups <- split(seq_len(nrow(z)), .make_key(z, group_cols))
  rows <- lapply(groups, function(ii) {
    zz <- z[ii, , drop = FALSE]
    row <- zz[1L, group_cols, drop = FALSE]
    row$n_all <- sum(zz$completed_vs_REF)
    row$n_both_pdHess <- sum(zz$both_pdHess_vs_REF)
    for (metric in paste0(metrics, "_vs_REF")) {
      sa <- .safe_stats(zz[[metric]][zz$completed_vs_REF])
      sp <- .safe_stats(zz[[metric]][zz$both_pdHess_vs_REF])
      row[[paste0(metric, "_mean_all")]] <- unname(sa[["mean"]])
      row[[paste0(metric, "_mcse_all")]] <- unname(sa[["mcse"]])
      row[[paste0(metric, "_mean_both_pdHess")]] <- unname(sp[["mean"]])
      row[[paste0(metric, "_mcse_both_pdHess")]] <- unname(sp[["mcse"]])
    }
    row
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out
}

.fit_status <- function(all) {
  group_cols <- c("stage", "block", "arm", "kappa", "rho", "omega",
                  "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  groups <- split(seq_len(nrow(all)), .make_key(all, group_cols))
  rows <- lapply(groups, function(ii) {
    z <- all[ii, , drop = FALSE]
    row <- z[1L, group_cols, drop = FALSE]
    row$n_fits <- nrow(z)
    row$n_scheduled <- nrow(z)
    row$n_fit_errors <- sum(!z$fit_complete)
    row$n_excluded <- row$n_fit_errors
    row$exclusion_rate <- row$n_excluded / row$n_scheduled
    row$exclusion_gt_5pct <- row$exclusion_rate > 0.05
    row$n_completed <- sum(z$fit_complete)
    row$n_convergence_nonzero <- sum(z$fit_complete & z$convergence != 0)
    row$n_pdHess_false <- sum(z$fit_complete & !z$pdHess)
    row$n_heywood_psi <- sum(z$n_heywood_psi[z$fit_complete], na.rm = TRUE)
    row$n_heywood_loading <- sum(z$n_heywood_loading[z$fit_complete], na.rm = TRUE)
    row$n_heywood_psi_unavailable <- sum(z$fit_complete & !is.finite(z$n_heywood_psi))
    row$n_heywood_loading_unavailable <- sum(z$fit_complete & !is.finite(z$n_heywood_loading))
    row
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out
}

.omega_contrast <- function(paired) {
  base <- paired[paired$stage == "campaign" & paired$block == "G1" & .near(paired$rho, 0) &
                   paired$omega %in% c(0, 1), , drop = FALSE]
  one <- base[.near(base$omega, 1), ]; zero <- base[.near(base$omega, 0), ]
  cols <- c("stage", "block", "seed", "arm", "kappa", "rho", "phi_x",
            "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  idx <- match(.make_key(one, cols), .make_key(zero, cols))
  if (anyNA(idx)) .stopf("R3 omega=1 versus omega=0 pairing failed")
  one$omega1_minus_omega0 <- ifelse(
    one$completed_pair & zero$completed_pair[idx], one$dD_bias - zero$dD_bias[idx], NA_real_)
  one$omega_pair_complete <- one$completed_pair & zero$completed_pair[idx]
  one$omega_pair_pdHess <- one$both_pdHess & zero$both_pdHess[idx]
  group_cols <- c("stage", "block", "arm", "kappa", "rho", "phi_x",
                  "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  groups <- split(seq_len(nrow(one)), .make_key(one, group_cols))
  rows <- lapply(groups, function(ii) {
    z <- one[ii, , drop = FALSE]
    sa <- .safe_stats(z$omega1_minus_omega0[z$omega_pair_complete])
    sp <- .safe_stats(z$omega1_minus_omega0[z$omega_pair_pdHess])
    row <- z[1L, group_cols, drop = FALSE]
    row$mean_all <- unname(sa[["mean"]]); row$mcse_all <- unname(sa[["mcse"]])
    row$mean_both_pdHess <- unname(sp[["mean"]]); row$mcse_both_pdHess <- unname(sp[["mcse"]])
    row
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out
}

.refutation_evidence <- function(summary, c1c2, c3, omega) {
  template <- data.frame(
    condition = character(), stage = character(), block = character(), arm = character(),
    kappa = numeric(), rho = numeric(), omega = numeric(), phi_x = numeric(),
    phi_bias = numeric(), n = numeric(), T_sp = numeric(), d_fit = numeric(),
    k = numeric(), beta0_shift = numeric(),
    population = character(), estimate = numeric(), mcse = numeric(),
    status = character(), note = character(), stringsAsFactors = FALSE
  )
  add <- list()
  push <- function(condition, x, population, estimate, mcse, status, note) {
    if (!nrow(x)) return(NULL)
    data.frame(
      condition = condition, stage = x$stage, block = x$block, arm = x$arm,
      kappa = x$kappa, rho = x$rho, omega = x$omega, phi_x = x$phi_x,
      phi_bias = x$phi_bias, n = x$n, T_sp = x$T_sp, d_fit = x$d_fit,
      k = x$k, beta0_shift = x$beta0_shift,
      population = population, estimate = estimate, mcse = mcse,
      status = status, note = note, stringsAsFactors = FALSE
    )
  }

  r1 <- summary[summary$stage == "campaign" & summary$block == "G1" &
                  summary$arm == "A1" & .near(summary$omega, 1), ]
  add[[length(add) + 1L]] <- push(
    "R1_flat_curve", r1, "all_completed", r1$dD_bias_mean_all, r1$dD_bias_mcse_all,
    ifelse(abs(r1$dD_bias_mean_all) < 0.05 &
             abs(r1$dD_bias_mean_all) < 3 * r1$dD_bias_mcse_all,
           "CELL_SUPPORTS_R1", "CELL_DOES_NOT_SUPPORT_R1"),
    "R1 is triggered only if every kappa cell through 2 satisfies the frozen flat-curve rule."
  )

  r2 <- c3[.near(c3$kappa, 2), ]
  r2$arm <- "A5-A6"
  add[[length(add) + 1L]] <- push(
    "R2_unattributable", r2, "all_completed",
    r2$D_bias_A5_minus_A6_mean_all, r2$D_bias_A5_minus_A6_mcse_all,
    ifelse(abs(r2$D_bias_A5_minus_A6_mean_all) <=
             3 * r2$D_bias_A5_minus_A6_mcse_all,
           "TRIGGERED", "NOT_TRIGGERED"),
    "Raw same-seed A5 minus A6 D_bias contrast at kappa=2."
  )

  if (nrow(omega)) {
    omega$omega <- NA_real_
    add[[length(add) + 1L]] <- push(
      "R3_wrong_mechanism", omega, "all_completed", omega$mean_all, omega$mcse_all,
      ifelse(omega$mean_all <= 3 * omega$mcse_all,
             "TRIGGER_REVIEW_NOT_SEPARATED", "NOT_TRIGGERED"),
      "Gap is dD_bias(omega=1)-dD_bias(omega=0); no equivalence margin was frozen."
    )
  }

  r4 <- c1c2
  add[[length(add) + 1L]] <- push(
    "R4_diagonal_only", r4, "all_completed", r4$dD_bias_mean_all, r4$dD_bias_mcse_all,
    ifelse(!r4$C1_all, "UNRESOLVED_REVIEW_DIAGONAL_METRICS", "NOT_TRIGGERED_BY_C1"),
    paste0("No frozen threshold defines 'diag_rmse and psi_rmse rise sharply'; inspect paired ",
           "headline summary without inventing one post hoc.")
  )

  r5 <- summary
  add[[length(add) + 1L]] <- push(
    "R5_wrong_sign", r5, "all_completed", r5$dD_bias_mean_all, r5$dD_bias_mcse_all,
    ifelse(mapply(.flag_3mcse, r5$dD_bias_mean_all, r5$dD_bias_mcse_all,
                  MoreArgs = list(direction = "negative", magnitude = 0)),
           "TRIGGERED", "NOT_TRIGGERED"),
    "Significantly negative dD_bias at the frozen 3-MCSE rule."
  )
  good <- Filter(function(x) !is.null(x) && nrow(x), add)
  if (!length(good)) return(template)
  do.call(rbind, good)
}

.refutation_aggregate <- function(refutations) {
  required <- c("condition", "status")
  if (!is.data.frame(refutations) || !all(required %in% names(refutations))) {
    .stopf("Refutation evidence lacks condition/status columns")
  }
  count_status <- function(condition, status) {
    sum(refutations$condition == condition & refutations$status == status, na.rm = TRUE)
  }
  n_condition <- function(condition) sum(refutations$condition == condition, na.rm = TRUE)

  r1_n <- n_condition("R1_flat_curve")
  rows <- list(
    data.frame(
      condition = "R1_flat_curve",
      aggregate_verdict = if (r1_n > 0L &&
        count_status("R1_flat_curve", "CELL_SUPPORTS_R1") == r1_n) "TRIGGERED" else "NOT_TRIGGERED",
      trigger_rows = count_status("R1_flat_curve", "CELL_SUPPORTS_R1"),
      evaluated_rows = r1_n,
      rule = "trigger only when every frozen A1 omega=1 kappa cell supports R1",
      stringsAsFactors = FALSE
    ),
    data.frame(
      condition = "R2_unattributable",
      aggregate_verdict = if (count_status("R2_unattributable", "TRIGGERED") > 0L)
        "TRIGGERED" else "NOT_TRIGGERED",
      trigger_rows = count_status("R2_unattributable", "TRIGGERED"),
      evaluated_rows = n_condition("R2_unattributable"),
      rule = "trigger when any frozen kappa=2 A5-A6 attribution cell is within 3 MCSE",
      stringsAsFactors = FALSE
    ),
    data.frame(
      condition = "R3_wrong_mechanism",
      aggregate_verdict = "UNRESOLVED_NO_FROZEN_EQUIVALENCE_MARGIN",
      trigger_rows = count_status("R3_wrong_mechanism", "TRIGGER_REVIEW_NOT_SEPARATED"),
      evaluated_rows = n_condition("R3_wrong_mechanism"),
      rule = "report review flags only; no adaptive equivalence threshold",
      stringsAsFactors = FALSE
    ),
    data.frame(
      condition = "R4_diagonal_only",
      aggregate_verdict = "UNRESOLVED_NO_FROZEN_DIAGONAL_THRESHOLD",
      trigger_rows = count_status("R4_diagonal_only", "UNRESOLVED_REVIEW_DIAGONAL_METRICS"),
      evaluated_rows = n_condition("R4_diagonal_only"),
      rule = "report unresolved cells only; no adaptive diagonal threshold",
      stringsAsFactors = FALSE
    ),
    data.frame(
      condition = "R5_wrong_sign",
      aggregate_verdict = if (count_status("R5_wrong_sign", "TRIGGERED") > 0L)
        "TRIGGERED" else "NOT_TRIGGERED",
      trigger_rows = count_status("R5_wrong_sign", "TRIGGERED"),
      evaluated_rows = n_condition("R5_wrong_sign"),
      rule = "trigger when any strictly negative dD_bias clears 3 MCSE",
      stringsAsFactors = FALSE
    )
  )
  out <- do.call(rbind, rows)
  decisive <- out$condition %in% c("R1_flat_curve", "R2_unattributable", "R5_wrong_sign")
  overall <- if (any(out$aggregate_verdict[decisive] == "TRIGGERED")) {
    "H_SINK_REFUTED"
  } else if (any(startsWith(out$aggregate_verdict, "UNRESOLVED"))) {
    "H_SINK_NOT_REFUTED_WITH_UNRESOLVED_CONDITIONS"
  } else {
    "H_SINK_NOT_REFUTED"
  }
  out$overall_h_sink_verdict <- overall
  out
}

.self_test_refutation_rules <- function() {
  stopifnot(
    !.flag_3mcse(0, 0, "positive"),
    !.flag_3mcse(0, 0, "negative"),
    !.flag_3mcse(0, 0, "absolute"),
    .flag_3mcse(0.10, 0.01, "positive", 0.10),
    .flag_3mcse(-0.10, 0.01, "negative", 0.10)
  )
  fixture <- data.frame(
    condition = c(
      "R1_flat_curve", "R1_flat_curve", "R2_unattributable",
      "R3_wrong_mechanism", "R4_diagonal_only", "R5_wrong_sign",
      "R5_wrong_sign"
    ),
    status = c(
      "CELL_SUPPORTS_R1", "CELL_DOES_NOT_SUPPORT_R1", "NOT_TRIGGERED",
      "TRIGGER_REVIEW_NOT_SEPARATED", "UNRESOLVED_REVIEW_DIAGONAL_METRICS",
      "NOT_TRIGGERED", "TRIGGERED"
    ),
    stringsAsFactors = FALSE
  )
  aggregate <- .refutation_aggregate(fixture)
  stopifnot(
    identical(unique(aggregate$overall_h_sink_verdict), "H_SINK_REFUTED"),
    aggregate$aggregate_verdict[aggregate$condition == "R1_flat_curve"] == "NOT_TRIGGERED",
    aggregate$trigger_rows[aggregate$condition == "R5_wrong_sign"] == 1L
  )
  cat("SELF_TEST_REFUTATION_RULES_PASS\n")
  invisible(TRUE)
}

.write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "NA")
  if (!file.exists(path) || file.info(path)$size <= 0) .stopf("Failed to write non-empty output: %s", path)
}

.verify_compute_v2_identity <- function(receipt, expected_stage, expected_block, label) {
  required <- c(
    "schema_version", "stage", "block", "seed_list", "config_sha256",
    "config_rds_sha256", "input_config_rds_sha256",
    "expected_logical_rows", "actual_logical_rows",
    "expected_model_fit_attempts", "actual_model_fit_attempts",
    "optimizer_control_mode", "optimizer_control", "package_versions",
    "session_platform", "input_predecessor_paths", "input_predecessor_sha256"
  )
  missing <- setdiff(required, names(receipt))
  if (length(missing)) {
    .stopf("%s lacks phase_c_compute_v2 field(s): %s", label,
           paste(missing, collapse = ", "))
  }
  if (!identical(receipt$schema_version, "phase_c_compute_v2") ||
      !identical(receipt$stage, expected_stage) ||
      !identical(receipt$block, expected_block)) {
    .stopf("%s has noncanonical v2 stage/block/schema", label)
  }
  sha256_value <- function(x) {
    length(x) == 1L && !is.na(x) && grepl("^[0-9a-f]{64}$", x)
  }
  if (!sha256_value(receipt$config_sha256) ||
      !sha256_value(receipt$config_rds_sha256) ||
      !sha256_value(receipt$input_config_sha256) ||
      !sha256_value(receipt$input_config_rds_sha256) ||
      !identical(receipt$input_config_sha256, receipt$config_sha256) ||
      !identical(receipt$input_config_rds_sha256, receipt$config_rds_sha256) ||
      !nzchar(receipt$seed_list) || !nzchar(receipt$optimizer_control) ||
      !nzchar(receipt$session_platform)) {
    .stopf("%s has an invalid v2 config/seed/control/session field", label)
  }
  invisible(TRUE)
}

.verify_official_receipts <- function(pilot_path, paths, receipt_paths,
                                      preflight_path, pilot_compute_path,
                                      decision_path, calibration_path = NULL) {
  preflight <- .require_receipt_c(preflight_path, "preflight_compute")
  pilot_compute <- .require_receipt_c(pilot_compute_path, "pilot_compute")
  decision <- .require_receipt_c(decision_path, "pilot_decision")
  .verify_compute_v2_identity(preflight, "preflight", "preflight", "preflight receipt")
  .verify_compute_v2_identity(pilot_compute, "pilot_v2", "G1", "pilot compute receipt")
  preflight_contract <- build_preflight_contract_c()
  if (!identical(preflight$config_sha256,
                 .canonical_object_sha256_c(preflight_contract)) ||
      !identical(preflight$input_config_sha256, preflight$config_sha256) ||
      !identical(preflight$seed_list,
                 paste(preflight_contract$seed_inventory, collapse = ",")) ||
      !identical(preflight$seed_inventory_roles,
                 preflight_contract$seed_inventory_roles)) {
    .stopf("Preflight receipt does not match the frozen structural contract and seed inventory")
  }
  preflight_hash <- .sha256_c(preflight_path)
  pilot_compute_hash <- .sha256_c(pilot_compute_path)
  decision_hash <- .sha256_c(decision_path)
  if (!grepl(paste0("preflight:", preflight_hash),
             pilot_compute$predecessor_receipt_hashes, fixed = TRUE)) {
    .stopf("Pilot-compute receipt is not bound to the supplied preflight receipt")
  }
  if (!identical(decision$preflight_receipt_sha256, preflight_hash) ||
      !identical(decision$pilot_compute_receipt_sha256, pilot_compute_hash)) {
    .stopf("Pilot-decision receipt is not bound to the supplied preflight and pilot-compute receipts")
  }
  early_shas <- unique(c(preflight$source_sha, pilot_compute$source_sha, decision$source_sha))
  early_branches <- unique(c(preflight$source_branch, pilot_compute$source_branch, decision$source_branch))
  if (length(early_shas) != 1L || !identical(early_branches, "claude/experiment-integrated-sdm")) {
    .stopf("Preflight, corrected pilot, and pilot decision do not share one Lane C source SHA")
  }
  pilot_norm <- normalizePath(pilot_path, mustWork = TRUE)
  if (!identical(normalizePath(pilot_compute$output_path, mustWork = TRUE), pilot_norm) ||
      !identical(pilot_compute$output_sha256, .sha256_c(pilot_norm)) ||
      !identical(decision$pilot_sha256, .sha256_c(pilot_norm))) {
    .stopf("Corrected pilot does not match its compute and decision receipts")
  }
  beta0_shift <- as.numeric(decision$beta0_shift)
  if (!is.finite(beta0_shift) ||
      !identical(pilot_compute$config_sha256,
                 .canonical_object_sha256_c(build_config_pilot(1:10, beta0_shift))) ||
      !identical(pilot_compute$input_config_sha256,
                 pilot_compute$config_sha256)) {
    .stopf("Pilot compute receipt does not match the frozen pilot configuration")
  }
  if (beta0_shift != 0) {
    calibration <- .require_receipt_c(calibration_path, "pilot_calibration")
    if (!isTRUE(all.equal(as.numeric(calibration$beta0_shift), beta0_shift, tolerance = 0)) ||
        !identical(decision$calibration_receipt_sha256, .sha256_c(calibration_path))) {
      .stopf("Calibration receipt does not match the frozen pilot decision")
    }
  }
  receipts <- vector("list", length(paths)); names(receipts) <- names(paths)
  for (block in names(paths)) {
    r <- .require_receipt_c(receipt_paths[[block]], paste0(tolower(block), "_compute"))
    .verify_compute_v2_identity(r, "campaign", block, paste(block, "compute receipt"))
    path <- normalizePath(paths[[block]], mustWork = TRUE)
    if (!identical(normalizePath(r$output_path, mustWork = TRUE), path) ||
        !identical(r$output_sha256, .sha256_c(path)) ||
        as.integer(r$expected_rows) != as.integer(r$actual_rows) ||
        as.integer(r$expected_logical_rows) != as.integer(r$actual_logical_rows) ||
        as.integer(r$expected_model_fit_attempts) != as.integer(r$actual_model_fit_attempts) ||
        !identical(r$unique_key_verdict, "PASS") ||
        as.integer(r$unlabelled_nonfinite_rows) != 0L ||
        isTRUE(as.logical(r$source_dirty))) {
      .stopf("%s result does not satisfy its compute receipt", block)
    }
    if (!isTRUE(all.equal(as.numeric(r$beta0_shift), beta0_shift, tolerance = 0))) {
      .stopf("%s receipt does not use the frozen beta0_shift", block)
    }
    seeds <- if (identical(block, "G1")) seq_len(as.integer(decision$g1_seeds)) else 1:50
    expected_config <- get(paste0("build_config_", tolower(block)))(
      seeds, beta0_shift = beta0_shift
    )
    if (!identical(r$config_sha256, .canonical_object_sha256_c(expected_config)) ||
        !identical(r$input_config_sha256, r$config_sha256)) {
      .stopf("%s receipt does not match the frozen source-built configuration", block)
    }
    required_predecessors <- c(
      paste0("preflight:", preflight_hash),
      paste0("pilot_decision:", decision_hash)
    )
    if (!all(vapply(required_predecessors, grepl, logical(1),
                    x = r$predecessor_receipt_hashes, fixed = TRUE))) {
      .stopf("%s receipt is not bound to the supplied preflight and pilot decision", block)
    }
    receipts[[block]] <- r
  }
  campaign_shas <- unique(vapply(receipts, `[[`, character(1), "source_sha"))
  if (length(campaign_shas) != 1L) .stopf("G1-G6 were not run from one immutable source SHA")
  branches <- unique(vapply(receipts, `[[`, character(1), "source_branch"))
  if (!identical(branches, "claude/experiment-integrated-sdm")) {
    .stopf("Campaign receipts do not identify the Lane C branch")
  }
  g1_seeds <- as.integer(decision$g1_seeds)
  if (!g1_seeds %in% c(100L, 200L) ||
      as.integer(receipts$G1$g1_seeds) != g1_seeds ||
      as.integer(receipts$G1$seed_count) != g1_seeds) {
    .stopf("G1 receipt does not match the frozen S100/S200 pilot decision")
  }
  g1_hash <- .sha256_c(receipt_paths[["G1"]])
  if (!grepl(paste0("g1:", g1_hash), receipts$G6$predecessor_receipt_hashes, fixed = TRUE)) {
    .stopf("G6 receipt is not bound to the official G1 receipt")
  }
  list(
    preflight = preflight, pilot_compute = pilot_compute, decision = decision,
    campaign = receipts, beta0_shift = beta0_shift, g1_seeds = g1_seeds,
    campaign_source_sha = campaign_shas
  )
}

.analyse_official <- function(pilot_path, paths, out_dir, receipt_paths,
                              preflight_receipt, pilot_compute_receipt,
                              pilot_decision_receipt, calibration_receipt = NULL) {
  .reject_nonofficial_path(out_dir, "output directory")
  receipt_bundle <- .verify_official_receipts(
    pilot_path, paths, receipt_paths, preflight_receipt,
    pilot_compute_receipt, pilot_decision_receipt, calibration_receipt
  )
  ## Outcome firewall: validate and calculate the corrected-pilot precision
  ## branch before any production campaign RDS is opened.
  pilot <- .load_official_pilot(pilot_path)
  pilot_paired <- .make_paired(pilot)
  precision <- .a1_ref_precision(pilot_paired)
  if (!is.finite(precision$projected_3mcse_at_S100)) {
    .stopf("Corrected pilot has insufficient completed A1 REF pairs for the precision decision")
  }
  if (length(unique(pilot$seed)) != 10L || nrow(pilot) != 1500L) {
    .stopf("Corrected pilot does not match the frozen 10-seed, 1,500-row grid")
  }
  if (!isTRUE(all.equal(
    precision$projected_3mcse_at_S100,
    as.numeric(receipt_bundle$decision$projected_3mcse_s100), tolerance = 1e-12
  ))) {
    .stopf("Recomputed pilot precision does not match the frozen decision receipt")
  }

  all <- .load_official_results(paths)
  if (!identical(unique(pilot$beta0_shift), unique(all$beta0_shift))) {
    .stopf("Corrected pilot and campaign do not share the frozen beta0_shift")
  }
  if (normalizePath(pilot_path, mustWork = TRUE) %in%
      normalizePath(unname(paths), mustWork = TRUE)) {
    .stopf("Stage collision: corrected pilot was also supplied as a campaign block")
  }
  expected_g1_seeds <- receipt_bundle$g1_seeds
  observed_g1_seeds <- length(unique(all$seed[all$block == "G1"]))
  if (observed_g1_seeds != expected_g1_seeds) {
    .stopf("Campaign G1 has %d seeds but corrected-pilot precision requires %d",
           observed_g1_seeds, expected_g1_seeds)
  }
  expected_rows <- c(
    G1 = 25L * expected_g1_seeds * 6L,
    G2 = 1200L, G3 = 1200L, G4 = 1200L, G5 = 600L, G6 = 600L
  )
  observed_rows <- table(factor(all$block, levels = names(expected_rows)))
  if (any(observed_rows != expected_rows)) {
    .stopf("Campaign block row counts do not match the frozen scheduled denominators")
  }
  paired <- .make_paired(all)
  paired_metrics <- paste0("d", c("D_bias", "D_rmse", "D_max", "D_z", "signflip",
                                   "diag_rmse", "psi_rmse", "lambda_proc_rmse",
                                   "beta_bias", "beta_rmse"))
  headline <- .summarise_pairs(paired, paired_metrics, paired$headline_eligible)
  primary <- .primary_endpoint(paired)
  c1c2 <- .c1_c2(headline)
  a56 <- .a5_a6_contrasts(paired)
  ladder <- .ladder_vs_ref(paired)
  g5_a2 <- paired[paired$stage == "campaign" & paired$block == "G5" &
                    paired$arm == "A2", ]
  g5_a2$scope <- "RANK_D_SENSITIVITY_ONLY_NOT_TOTAL_SIGMA_HEADLINE"
  status <- .fit_status(all)
  omega <- .omega_contrast(paired)
  refutations <- .refutation_evidence(headline, c1c2, a56$summary, omega)
  refutation_aggregate <- .refutation_aggregate(refutations)

  files <- c(
    "00-a1-ref-precision.csv", "01-primary-endpoint.csv",
    "02-paired-headline-summary.csv", "03-c1-c2-verdicts.csv",
    "04-c3-a5-a6-summary.csv", "05-a5-a6-fit-level.csv",
    "06-g2-g6-ladder-vs-ref.csv", "07-g5-a2-rank-d-sensitivity.csv",
    "08-refutation-evidence.csv", "09-fit-status-by-cell.csv",
    "10-paired-fit-level.rds", "11-input-manifest.csv",
    "12-refutation-aggregate.csv"
  )
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) .stopf("Could not create output directory: %s", out_dir)
  targets <- file.path(out_dir, files)
  existing <- targets[file.exists(targets)]
  if (length(existing)) {
    .stopf("Refusing to overwrite %d existing official output(s): %s",
           length(existing), paste(basename(existing), collapse = ", "))
  }

  ## Precision is intentionally written first: the frozen precision verdict is
  ## evaluated before any broad campaign table is emitted.
  .write_csv(precision, targets[[1]])
  .write_csv(primary, targets[[2]])
  .write_csv(headline, targets[[3]])
  .write_csv(c1c2, targets[[4]])
  .write_csv(a56$summary, targets[[5]])
  .write_csv(a56$fit_level, targets[[6]])
  .write_csv(ladder, targets[[7]])
  .write_csv(g5_a2, targets[[8]])
  .write_csv(refutations, targets[[9]])
  .write_csv(status, targets[[10]])
  saveRDS(paired, targets[[11]])
  if (!file.exists(targets[[11]]) || file.info(targets[[11]])$size <= 0) {
    .stopf("Failed to write paired fit-level RDS")
  }
  manifest <- data.frame(
    stage = c("pilot_v2", rep("campaign", length(paths))),
    block = c("G1", names(paths)),
    input = c(normalizePath(pilot_path, mustWork = TRUE),
              normalizePath(unname(paths), mustWork = TRUE)),
    rows = c(nrow(pilot), vapply(names(paths), function(b) sum(all$block == b), integer(1))),
    receipt = c(
      normalizePath(pilot_compute_receipt, mustWork = TRUE),
      normalizePath(unname(receipt_paths), mustWork = TRUE)
    ),
    receipt_sha256 = c(
      .sha256_c(pilot_compute_receipt),
      vapply(unname(receipt_paths), .sha256_c, character(1))
    ),
    stringsAsFactors = FALSE
  )
  .write_csv(manifest, targets[[12]])
  .write_csv(refutation_aggregate, targets[[13]])
  invisible(targets)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (identical(args, "--self-test-refutations")) {
    .self_test_refutation_rules()
  } else {
    cli <- .parse_cli(args)
    if (!isTRUE(cli$help)) {
    written <- .analyse_official(
      cli$pilot, cli$results, cli$out_dir, cli$receipts,
      cli$preflight_receipt, cli$pilot_compute_receipt,
      cli$pilot_decision_receipt, cli$calibration_receipt
    )
    cat("Official Phase C analysis wrote:\n", paste0("  ", written, collapse = "\n"), "\n", sep = "")
    }
  }
}
