#!/usr/bin/env Rscript

## Read-only audit of the retained G2i seed-86122 recovery pre-run.  This file
## must never construct an objective, load the package, or fit a model.
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg("mode", "validate")
output <- arg("output")
source_root <- arg("source-root", "/private/tmp/gllvmtmb-isdm-g2i-polish-recovery/dev/isdm-package-recovery/results/g2i-recovery-prerun-20260811-001")
if (!mode %in% c("validate", "audit") || (identical(mode, "audit") && is.null(output))) {
  stop("require --mode=validate|audit; audit also requires --output=PATH", call. = FALSE)
}

required <- c("root-receipt.rds", "truth.rds", "fit.rds", "profiles.rds",
              "recovery-summary.rds", "decision-ledger.rds",
              "final-provenance-closure.rds")
if (!dir.exists(source_root) || !all(file.exists(file.path(source_root, required)))) {
  stop("retained G2i root is incomplete", call. = FALSE)
}
if (identical(mode, "validate")) {
  cat("G2J retained-Psi diagnostic validation PASS (no fit)\n")
  quit(save = "no")
}

if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) {
  stop("audit output root must be fresh", call. = FALSE)
}
dir.create(output, recursive = TRUE)
truth <- readRDS(file.path(source_root, "truth.rds"))
fit <- readRDS(file.path(source_root, "fit.rds"))
profiles <- readRDS(file.path(source_root, "profiles.rds"))
metrics <- readRDS(file.path(source_root, "recovery-summary.rds"))
decision <- readRDS(file.path(source_root, "decision-ledger.rds"))
closure <- readRDS(file.path(source_root, "final-provenance-closure.rds"))

closure_hashes <- tools::md5sum(file.path(source_root, names(closure$files)))
if (!identical(unname(closure_hashes), unname(closure$files))) stop("retained closure hash mismatch")
if (!identical(fit$use$rr_B, TRUE) || !identical(fit$use$diag_B, TRUE)) stop("rank-one plus diagonal-Psi contract drift")
theta <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
sd_b <- as.numeric(fit$report$sd_B)
unique_from_extract <- as.numeric(metrics$psi_variance_hat)
shared_from_extract <- as.matrix(metrics$shared_Sigma_hat)
if (length(theta) != 6L || length(sd_b) != 6L || length(unique_from_extract) != 6L) stop("expected six Psi coordinates")
if (!isTRUE(all.equal(unique_from_extract, sd_b^2, tolerance = 1e-12))) stop("unique extractor is not report$sd_B^2")
if (!isTRUE(all.equal(sd_b^2, exp(2 * theta), tolerance = 1e-12))) stop("theta-to-Psi variance transform drift")
lambda_b <- as.matrix(fit$report$Lambda_B)
if (!identical(dim(lambda_b), c(6L, 1L))) stop("expected a six-by-one rank-one loading matrix")
if (!isTRUE(all.equal(unname(shared_from_extract), unname(tcrossprod(lambda_b)), tolerance = 1e-12))) stop("shared extractor is not Lambda Lambda transpose")

fixed <- summary(fit$sd_report, "fixed")
theta_ix <- grep("theta_diag_B", rownames(fixed), fixed = TRUE)
if (length(theta_ix) != 6L) stop("sdreport lacks six theta_diag_B entries")
profiles_ok <- identical(names(profiles), paste0("sp", 1:6)) && all(vapply(profiles, function(x) {
  nrow(x) == 5L && identical(x$offset, c(-2, -1, 0, 1, 2)) && all(is.finite(x$nll)) && all(x$convergence == 0L)
}, logical(1L)))
if (!profiles_ok) stop("retained Psi profiles are invalid")

species <- paste0("sp", 1:6)
profile_lower <- vapply(profiles, function(x) x$delta_nll[match(-1, x$offset)], numeric(1L))
profile_upper <- vapply(profiles, function(x) x$delta_nll[match(1, x$offset)], numeric(1L))
theta_se <- fixed[theta_ix, "Std. Error"]
theta_lo <- theta - 1.96 * theta_se
theta_hi <- theta + 1.96 * theta_se
truth_var <- as.numeric(truth$psi_variance)
lambda_ix <- grep("theta_rr_B", rownames(fixed), fixed = TRUE)
if (length(lambda_ix) != 6L) stop("sdreport lacks six theta_rr_B entries")
fixed_cov <- fit$sd_report$cov.fixed
fixed_sd <- sqrt(diag(fixed_cov))
theta_lambda_cor <- fixed_cov[theta_ix, lambda_ix, drop = FALSE] /
  outer(fixed_sd[theta_ix], fixed_sd[lambda_ix])
weak_lower_profiles <- sum(profile_lower < 2) >= 3L
material_component_correlation <- max(abs(theta_lambda_cor)) >= .25
held_psi_metric <- is.finite(metrics$max_abs_psi_variance_error) &&
  metrics$max_abs_psi_variance_error > .20
verdict <- if (held_psi_metric && weak_lower_profiles && material_component_correlation) {
  "COMPONENT_INFORMATION_LIMITED_NOT_EXTRACTION_MISMATCH"
} else {
  "ONE_SEED_CRITERION_UNRESOLVED"
}
audit <- data.frame(
  species = species,
  truth_variance = truth_var,
  realised_eps_variance = apply(truth$eps, 2, stats::var),
  theta_hat = theta,
  theta_se = theta_se,
  psi_variance_hat = unique_from_extract,
  psi_variance_error = unique_from_extract - truth_var,
  psi_wald_lower = exp(2 * theta_lo),
  psi_wald_upper = exp(2 * theta_hi),
  true_variance_in_wald_interval = truth_var >= exp(2 * theta_lo) & truth_var <= exp(2 * theta_hi),
  lower_profile_delta_at_minus_1 = profile_lower,
  upper_profile_delta_at_plus_1 = profile_upper,
  stringsAsFactors = FALSE
)

result <- list(
  kind = "G2J_RETAINED_PSI_DIAGNOSTIC",
  source_root = normalizePath(source_root),
  source_commit = readRDS(file.path(source_root, "root-receipt.rds"))$commit,
  closure_hashes_verified = TRUE,
  extractor_scale_verified = TRUE,
  source_gate_valid = identical(decision$diagnostic_state, "VALID"),
  profile_valid = profiles_ok,
  final_gradient = decision$final_gradient,
  recovery_psi_max_abs_error = metrics$max_abs_psi_variance_error,
  held_psi_metric = held_psi_metric,
  weak_lower_profiles = weak_lower_profiles,
  material_component_correlation = material_component_correlation,
  max_abs_theta_lambda_correlation = max(abs(theta_lambda_cor)),
  psi_table = audit,
  verdict = verdict
)
saveRDS(result, file.path(output, "g2j-psi-diagnostic.rds"))
utils::write.csv(audit, file.path(output, "g2j-psi-table.csv"), row.names = FALSE)
writeLines(c(
  "# G2J_RETAINED_PSI_DIAGNOSTIC_COMPLETE",
  paste0("verdict=", verdict),
  "fit_calls=0",
  paste0("source_commit=", result$source_commit)
), file.path(output, "receipt.md"))
cat("G2J_RETAINED_PSI_DIAGNOSTIC_COMPLETE\n")
