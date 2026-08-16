#!/usr/bin/env Rscript

## Read-only diagnostic of the completed G2k campaign.  It never constructs an
## objective, optimizes, profiles, simulates, or changes a retained artifact.
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  x <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(x)) sub(paste0("^--", name, "="), "", x[[1L]]) else default
}
mode <- arg("mode", "validate")
root <- normalizePath(arg("campaign-root", file.path(
  "dev", "isdm-package-recovery", "results", "g2s-fir-campaign-20260811-001"
)), mustWork = TRUE)
output <- arg("output")
if (!mode %in% c("validate", "audit") || (identical(mode, "audit") && is.null(output))) {
  stop("require --mode=validate|audit and --output for audit", call. = FALSE)
}

ledger_paths <- function(root) {
  sort(list.files(file.path(root, "seeds"), pattern = "decision-ledger.rds$",
                  recursive = TRUE, full.names = TRUE))
}
seed_from <- function(path) as.integer(sub(".*seed-([0-9]+)/.*", "\\1", path))
fit_path <- function(path) sub("decision-ledger.rds$", "fit.rds", path)
profiles_path <- function(path) sub("decision-ledger.rds$", "profiles.rds", path)
truth_path <- function(path) sub("decision-ledger.rds$", "truth.rds", path)
relative_change <- function(raw, candidate) (candidate - raw) / pmax(abs(raw), 1)
first_or_na <- function(x, default = NA) if (length(x)) unname(x[[1L]]) else default

check_campaign <- function(root) {
  summary <- readRDS(file.path(root, "campaign-summary.rds"))
  receipt <- readRDS(file.path(root, "campaign-receipt.rds"))
  paths <- ledger_paths(root)
  stopifnot(
    identical(summary$kind, "G2K_ALL_ATTEMPT_SUMMARY"),
    identical(summary$n_requested, 150L), identical(summary$n_started, 150L),
    identical(summary$n_missing, 0L), length(paths) == 150L,
    identical(receipt$commit, "6ee117774f14cdc54533e21ac22e0157ecd01305"),
    all(file.exists(vapply(paths, fit_path, character(1L)))),
    all(file.exists(vapply(paths, profiles_path, character(1L)))),
    all(file.exists(vapply(paths, truth_path, character(1L))))
  )
  paths
}

if (identical(mode, "validate")) {
  check_campaign(root)
  cat("G2K gradient diagnostic validation PASS (read-only; no fit)\n")
  quit(save = "no")
}

if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) {
  stop("diagnostic output root must be fresh", call. = FALSE)
}
paths <- check_campaign(root)
dir.create(output, recursive = TRUE)

rows <- lapply(paths, function(path) {
  ledger <- readRDS(path)
  fit <- readRDS(fit_path(path))
  profiles <- readRDS(profiles_path(path))
  polish <- ledger$polish
  raw <- polish$raw; candidate <- polish$candidate
  candidate_position <- if (length(candidate$gradient)) which.max(abs(candidate$gradient)) else NA_integer_
  candidate_name <- if (is.na(candidate_position)) NA_character_ else
    first_or_na(names(candidate$gradient)[[candidate_position]], NA_character_)
  metrics <- ledger$recovery_metrics
  profile_rows <- do.call(rbind, profiles)
  lower_one <- profile_rows[profile_rows$offset == -1L, , drop = FALSE]
  cov_fixed <- fit$sd_report$cov.fixed
  data.frame(
    seed = seed_from(path),
    classification = ledger$classification,
    strict_pass = identical(ledger$classification, "PRE_RUN_RECOVERY_PASS"),
    recovery_pass = isTRUE(ledger$recovery_metrics_pass),
    three_restarts = isTRUE(ledger$three_restarts),
    profile_valid = isTRUE(ledger$profile_valid),
    final_gradient = ledger$final_gradient,
    raw_gradient = raw$max_gradient,
    candidate_gradient = candidate$max_gradient,
    gradient_reduction = raw$max_gradient - candidate$max_gradient,
    gradient_reduction_relative = relative_change(raw$max_gradient, candidate$max_gradient),
    scaled_gradient = fit$fit_health$scaled_gradient,
    optimizer_converged = isTRUE(fit$fit_health$optimizer_converged),
    pd_hessian = isTRUE(fit$sd_report$pdHess),
    hessian_condition = if (isTRUE(fit$sd_report$pdHess)) kappa(cov_fixed, exact = FALSE) else NA_real_,
    covariance_rcond = if (isTRUE(fit$sd_report$pdHess)) rcond(cov_fixed) else NA_real_,
    boundary = paste(raw$boundary_flags, collapse = ";"),
    boundary_diagonal_index = paste(polish$boundary$diagonal_indices, collapse = ";"),
    boundary_theta = first_or_na(polish$boundary$candidate_theta_diag_values),
    raw_max_block = first_or_na(raw$max_gradient_parameter_block, NA_character_),
    raw_max_index = first_or_na(raw$max_gradient_parameter_index),
    candidate_max_position = candidate_position,
    candidate_max_name = candidate_name,
    polish_eligible = isTRUE(polish$eligible),
    polish_attempted = isTRUE(polish$attempted),
    polish_accepted = isTRUE(polish$accepted),
    objective_change = candidate$objective - raw$objective,
    min_lower_profile_delta = min(lower_one$delta_nll),
    n_weak_lower_profiles = sum(lower_one$delta_nll <= 2),
    beta_pass = metrics$max_abs_beta_error <= .30,
    gamma_pass = metrics$max_abs_gamma_error <= .30,
    map_pass = metrics$min_map_correlation >= .70,
    shared_pass = metrics$shared_relative_frobenius <= .50,
    psi_pass = metrics$max_abs_psi_variance_error <= .20,
    gradient_pass = ledger$final_gradient <= 1e-3,
    beta_error = metrics$max_abs_beta_error,
    gamma_error = metrics$max_abs_gamma_error,
    min_map_correlation = metrics$min_map_correlation,
    shared_frobenius = metrics$shared_relative_frobenius,
    psi_error = metrics$max_abs_psi_variance_error,
    stringsAsFactors = FALSE
  )
})
attempts <- do.call(rbind, rows)

summary_row <- data.frame(
  n_attempts = nrow(attempts),
  n_strict_pass = sum(attempts$strict_pass),
  n_recovery_pass = sum(attempts$recovery_pass),
  n_gradient_pass = sum(attempts$gradient_pass),
  n_recovery_only_hold = sum(attempts$recovery_pass & !attempts$gradient_pass),
  n_gradient_only_hold = sum(attempts$gradient_pass & !attempts$recovery_pass),
  n_nonstationary_signature = sum(!attempts$optimizer_converged | !attempts$pd_hessian |
                                    !is.finite(attempts$scaled_gradient) |
                                    attempts$scaled_gradient > 1e-3),
  n_near_boundary = sum(attempts$boundary == "near_zero_sd_B"),
  median_raw_gradient = stats::median(attempts$raw_gradient, na.rm = TRUE),
  median_candidate_gradient = stats::median(attempts$candidate_gradient, na.rm = TRUE),
  median_scaled_gradient = stats::median(attempts$scaled_gradient, na.rm = TRUE),
  median_hessian_condition = stats::median(attempts$hessian_condition, na.rm = TRUE),
  median_weak_lower_profiles = stats::median(attempts$n_weak_lower_profiles, na.rm = TRUE),
  stringsAsFactors = FALSE
)

cross <- as.data.frame.matrix(table(
  recovery_metrics = attempts$recovery_pass,
  gradient_admission = attempts$gradient_pass
))
cross$recovery_metrics <- row.names(cross)
row.names(cross) <- NULL

failure_decomposition <- data.frame(
  criterion = c("raw_gradient", "psi_variance", "map", "beta", "gbif_gamma",
                "shared_covariance"),
  n_pass = c(sum(attempts$gradient_pass), sum(attempts$psi_pass),
             sum(attempts$map_pass), sum(attempts$beta_pass),
             sum(attempts$gamma_pass), sum(attempts$shared_pass)),
  n_fail = c(sum(!attempts$gradient_pass), sum(!attempts$psi_pass),
             sum(!attempts$map_pass), sum(!attempts$beta_pass),
             sum(!attempts$gamma_pass), sum(!attempts$shared_pass)),
  stringsAsFactors = FALSE
)
interaction_patterns <- as.data.frame(
  table(raw_gradient_pass = attempts$gradient_pass,
        psi_pass = attempts$psi_pass,
        map_pass = attempts$map_pass),
  stringsAsFactors = FALSE
)
numerical_health <- as.data.frame(
  table(optimizer_converged = attempts$optimizer_converged,
        pd_hessian = attempts$pd_hessian,
        scaled_gradient_pass = attempts$scaled_gradient <= 1e-3),
  stringsAsFactors = FALSE
)
admission_decomposition <- as.data.frame(
  table(recovery_pass = attempts$recovery_pass,
        raw_gradient_pass = attempts$gradient_pass,
        three_restarts = attempts$three_restarts,
        profile_valid = attempts$profile_valid,
        polish_accepted = attempts$polish_accepted,
        strict_pass = attempts$strict_pass),
  stringsAsFactors = FALSE
)
polish_decomposition <- as.data.frame(
  table(recovery_pass = attempts$recovery_pass,
        raw_gradient_pass = attempts$gradient_pass,
        boundary = attempts$boundary,
        polish_eligible = attempts$polish_eligible,
        polish_attempted = attempts$polish_attempted,
        polish_accepted = attempts$polish_accepted),
  stringsAsFactors = FALSE
)
utils::write.csv(attempts, file.path(output, "all-attempt-gradient-diagnostic.csv"), row.names = FALSE)
utils::write.csv(summary_row, file.path(output, "diagnostic-summary.csv"), row.names = FALSE)
utils::write.csv(cross, file.path(output, "gradient-recovery-cross-tab.csv"), row.names = FALSE)
utils::write.csv(failure_decomposition, file.path(output, "failure-decomposition.csv"), row.names = FALSE)
utils::write.csv(interaction_patterns, file.path(output, "interaction-patterns.csv"), row.names = FALSE)
utils::write.csv(numerical_health, file.path(output, "numerical-health-decomposition.csv"), row.names = FALSE)
utils::write.csv(admission_decomposition, file.path(output, "admission-decomposition.csv"), row.names = FALSE)
utils::write.csv(polish_decomposition, file.path(output, "polish-decomposition.csv"), row.names = FALSE)
saveRDS(list(
  kind = "G2K_GRADIENT_DIAGNOSTIC_V1", campaign_root = normalizePath(root),
  campaign_summary = readRDS(file.path(root, "campaign-summary.rds")),
  attempts = attempts, summary = summary_row, cross_tab = cross,
  failure_decomposition = failure_decomposition,
  interaction_patterns = interaction_patterns,
  numerical_health = numerical_health,
  admission_decomposition = admission_decomposition,
  polish_decomposition = polish_decomposition,
  interpretation_boundary = paste(
    "Read-only diagnostic; no new fit, optimizer call, profile, DGP, threshold,",
    "or parameter-map change was made."
  )
), file.path(output, "gradient-diagnostic.rds"))
writeLines(c(
  "# G2K_GRADIENT_DIAGNOSTIC_COMPLETE",
  "Read-only extraction from the completed 150-attempt campaign.",
  paste0("strict_pass=", summary_row$n_strict_pass),
  paste0("recovery_pass=", summary_row$n_recovery_pass),
  paste0("gradient_pass=", summary_row$n_gradient_pass)
), file.path(output, "receipt.md"))
cat("G2K_GRADIENT_DIAGNOSTIC_COMPLETE\n")
