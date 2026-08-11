#!/usr/bin/env Rscript

## Private G2g reader. It reads serialised retained artifacts only: no package
## loading, likelihood evaluation, optimizer, profile, simulation, or fit.
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "validate")
output <- arg_value("output", NULL)
if (!mode %in% c("validate", "audit") || is.null(output)) stop("require --mode=validate/audit and --output=<fresh-private-root>", call. = FALSE)
output <- normalizePath(if (grepl("^/", output)) output else file.path(getwd(), output), mustWork = FALSE)
roots <- c(
  g2d = "/private/tmp/gllvmtmb-isdm-g2d-six-species/dev/isdm-package-recovery/results/g2d-replacement-smoke-20260811-001",
  g2e = "/private/tmp/gllvmtmb-isdm-g2e-information-diagnostic/dev/isdm-package-recovery/results/g2e-replacement-smoke-20260811-001",
  g2f = "/private/tmp/gllvmtmb-isdm-g2f-pa-replication/dev/isdm-package-recovery/results/g2f-smoke-20260811-001"
)
`%||%` <- function(x, y) if (is.null(x)) y else x
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
verify_manifest <- function(root) {
  manifest <- read.csv(file.path(root, "file-manifest.csv"), stringsAsFactors = FALSE)
  actual <- vapply(file.path(root, manifest$path), hash_file, character(1))
  identical(unname(actual), manifest$md5)
}
read_fit <- function(arc, root) {
  if (identical(arc, "g2d")) readRDS(file.path(root, "fit-receipt.rds"))$three_visit else readRDS(file.path(root, "fit.rds"))
}
read_profile <- function(arc, root) {
  p <- readRDS(file.path(root, "profile-ledger.rds"))
  if (identical(arc, "g2d")) p$three_visit else p
}
lower_profile <- function(profile) {
  ans <- vapply(seq_along(profile), function(k) {
    x <- profile[[k]]
    index <- which(abs(x$offset + 2) < 1e-8)
    if (length(index) != 1L || length(x$delta_nll) < index) stop(paste0("retained profile has no -2 lower offset: ", names(profile)[[k]]), call. = FALSE)
    as.numeric(x$delta_nll[[index]])
  }, numeric(1))
  names(ans) <- names(profile)
  ans
}
fit_correlation_summary <- function(fit) {
  cv <- fit$sd_report$cov.fixed
  stopifnot(is.matrix(cv), nrow(cv) == 36L, ncol(cv) == 36L, length(fit$X_fix_names) == 24L)
  nm <- c(fit$X_fix_names, paste0("lambda_sp", 1:6), paste0("theta_diag_sp", 1:6))
  rownames(cv) <- colnames(cv) <- nm
  cr <- stats::cov2cor(cv)
  gamma <- grep("isdm_gbif_b_bias", nm, fixed = TRUE)
  lambda <- grep("lambda_sp", nm, fixed = TRUE)
  theta <- grep("theta_diag_sp", nm, fixed = TRUE)
  list(
    max_gamma_lambda = max(abs(cr[gamma, lambda, drop = FALSE])),
    max_gamma_theta = max(abs(cr[gamma, theta, drop = FALSE])),
    max_lambda_theta = max(abs(cr[lambda, theta, drop = FALSE]))
  )
}
map_alignment <- function(fit) {
  gate <- "isdm_gbif_b_bias"
  survey <- fit$data$source == "survey"
  gbif <- fit$data$source == "gbif"
  list(
    six_gamma_terms = sum(grepl(gate, fit$X_fix_names, fixed = TRUE)) == 6L,
    survey_gate_zero = all(fit$data[[gate]][survey] == 0),
    gbif_gate_finite = all(is.finite(fit$data[[gate]][gbif])),
    gbif_gate_varying = stats::sd(fit$data[[gate]][gbif]) > 0,
    declared_private_route = identical(fit$isdm_developer$source_gate_column, "isdm_gbif") &&
      identical(fit$isdm_developer$gbif_bias_columns, gate) &&
      identical(fit$isdm_developer$relative_intensity_only, TRUE)
  )
}
covariance_alignment <- function(fit) {
  diagonal_map <- fit$tmb_map[["theta_diag_B", exact = TRUE]]
  diagonal_free <- is.null(diagonal_map) ||
    (length(diagonal_map) == 6L && !anyNA(diagonal_map) && !anyDuplicated(as.integer(diagonal_map)))
  lambda <- fit$report$Lambda_B
  sd <- fit$report$sd_B
  shared_sigma <- tcrossprod(lambda)
  list(
    rank_one_lambda = identical(as.integer(fit$tmb_data$d_B), 1L) &&
      identical(as.integer(fit$tmb_data$use_rr_B), 1L) && length(fit$tmb_params$theta_rr_B) == 6L &&
      is.matrix(lambda) && identical(dim(lambda), c(6L, 1L)),
    diagonal_psi_free = identical(as.integer(fit$tmb_data$use_diag_B), 1L) &&
      length(fit$tmb_params$theta_diag_B) == 6L && diagonal_free,
    extractor_shared_sigma_identity = isTRUE(all.equal(fit$report$Sigma_B, shared_sigma, tolerance = 1e-10)),
    extractor_psi_separate = length(sd) == 6L && all(is.finite(sd)) && all(sd >= 0)
  )
}
one_arc <- function(arc, root) {
  stopifnot(dir.exists(root), verify_manifest(root))
  truth <- readRDS(file.path(root, "truth.rds"))
  fit <- read_fit(arc, root)
  profile <- read_profile(arc, root)
  lower <- lower_profile(profile)
  co <- truth$constants
  mu_g <- sapply(seq_len(6L), function(s) truth$support_g * exp(truth$eta[, s] + co$gbif_contrast[[s]] + truth$b * co$gamma[[s]]))
  gamma_information <- colSums(mu_g * truth$b^2)
  cor_summary <- fit_correlation_summary(fit)
  alignment <- map_alignment(fit)
  covariance <- covariance_alignment(fit)
  gradient <- if (identical(arc, "g2d")) fit$fit_health$max_gradient else readRDS(file.path(root, "decision-ledger.rds"))$eligibility$max_abs_gradient
  gamma_error <- if (identical(arc, "g2d")) readRDS(file.path(root, "metric-ledger.rds"))$three_visit$max_abs_gamma_error else readRDS(file.path(root, "decision-ledger.rds"))$gamma_error
  classification <- if (identical(arc, "g2d")) "G2D_INELIGIBLE" else readRDS(file.path(root, "decision-ledger.rds"))$classification
  data.frame(
    arc = arc, n_cell = truth$n_cell %||% 120L, n_species = 6L,
    n_visit = if (identical(arc, "g2d")) 3L else truth$n_visit,
    gbif_support_multiplier = if (identical(arc, "g2e")) truth$support_multiplier else 1,
    gamma_error = gamma_error, lower_profile_sum = sum(lower),
    lower_profile_min = min(lower), lower_profile_ge2 = sum(lower >= 2),
    gamma_info_min = min(gamma_information), gamma_info_max = max(gamma_information),
    x_b_correlation = stats::cor(truth$x, truth$b), x_b_rank = qr(cbind(1, truth$x, truth$b))$rank,
    x_fix_rank = qr(fit$X_fix)$rank, x_fix_columns = ncol(fit$X_fix),
    six_gamma_terms = alignment$six_gamma_terms, survey_gate_zero = alignment$survey_gate_zero,
    gbif_gate_finite = alignment$gbif_gate_finite, gbif_gate_varying = alignment$gbif_gate_varying,
    declared_private_route = alignment$declared_private_route,
    rank_one_lambda = covariance$rank_one_lambda, diagonal_psi_free = covariance$diagonal_psi_free,
    extractor_shared_sigma_identity = covariance$extractor_shared_sigma_identity,
    extractor_psi_separate = covariance$extractor_psi_separate,
    max_gamma_lambda_correlation = cor_summary$max_gamma_lambda,
    max_gamma_theta_correlation = cor_summary$max_gamma_theta,
    max_lambda_theta_correlation = cor_summary$max_lambda_theta,
    gradient = gradient,
    fit_health_scaled_stationary = isTRUE(fit$fit_health$stationary_by_scaled_gradient),
    fit_health_raw_stationary = isTRUE(fit$fit_health$stationary_by_gradient),
    pd_hessian = isTRUE(fit$fit_health$pd_hessian),
    classification = classification, stringsAsFactors = FALSE
  )
}
validate <- function() {
  stopifnot(identical(names(roots), c("g2d", "g2e", "g2f")), all(vapply(roots, dir.exists, logical(1))))
  tab <- do.call(rbind, Map(one_arc, names(roots), unname(roots)))
  numeric_columns <- vapply(tab, is.numeric, logical(1))
  stopifnot(all(tab$n_cell == 120L), all(tab$n_species == 6L), identical(tab$n_visit, c(3L, 3L, 6L)),
    identical(tab$gbif_support_multiplier, c(1, 2, 1)), all(tab$x_fix_rank == tab$x_fix_columns),
    all(is.finite(as.matrix(tab[, numeric_columns, drop = FALSE]))), all(tab$six_gamma_terms),
    all(tab$survey_gate_zero), all(tab$gbif_gate_finite), all(tab$gbif_gate_varying), all(tab$declared_private_route),
    all(tab$rank_one_lambda), all(tab$diagonal_psi_free), all(tab$extractor_shared_sigma_identity), all(tab$extractor_psi_separate),
    all(tab$fit_health_scaled_stationary), all(tab$fit_health_raw_stationary), all(tab$pd_hessian),
    identical(tab$classification[[2L]], "PROFILE_LIMITED"), identical(tab$classification[[3L]], "NONRESPONSIVE"))
  tab
}
if (identical(mode, "validate")) {
  validate()
  cat("G2G retained-artifact audit validation PASS (no fit)\n")
  quit(save = "no", status = 0L)
}
if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) stop("G2g audit output must be fresh", call. = FALSE)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
tab <- validate()
utils::write.csv(tab, file.path(output, "g2g-mechanism-table.csv"), row.names = FALSE)
audit_receipt <- list(kind = "G2G_RETAINED_ARTIFACT_AUDIT", roots = roots,
  source_manifest_ok = vapply(roots, verify_manifest, logical(1)), created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
saveRDS(audit_receipt, file.path(output, "audit-receipt.rds"))
files <- file.path(output, c("g2g-mechanism-table.csv", "audit-receipt.rds"))
utils::write.csv(data.frame(path = basename(files), md5 = vapply(files, hash_file, character(1))), file.path(output, "audit-file-manifest.csv"), row.names = FALSE)
cat("G2G_RETAINED_ARTIFACT_AUDIT_PASS (no fit)\n")
