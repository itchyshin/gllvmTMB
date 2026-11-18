#!/usr/bin/env Rscript

## G2o reads completed G2k/G2n artifacts, evaluates the stored-point gradient,
## and performs descriptive matrix arithmetic. It never invokes an optimizer,
## fitter, profiler, or simulator.
args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
g2n_root <- value("g2n-root")
g2k_root <- value("g2k-root")
output <- value("output")
if (!mode %in% c("validate", "report") || is.null(g2n_root) || is.null(g2k_root) || is.null(output)) {
  stop("require --mode=validate|report, --g2n-root, --g2k-root, and --output", call. = FALSE)
}
g2n_root <- normalizePath(g2n_root, mustWork = TRUE)
g2k_root <- normalizePath(g2k_root, mustWork = TRUE)
required_g2n <- c("g2n-decision-ledger.rds", "g2n-postrun-provenance-addendum.rds",
                  "g2n-final-provenance-closure.rds", "g2n-truth.rds")
required_g2k <- c("gradient-diagnostic.rds", "receipt.md")
stopifnot(all(file.exists(file.path(g2n_root, required_g2n))),
          all(file.exists(file.path(g2k_root, required_g2k))))
if (identical(mode, "validate")) {
  cat("G2O postmortem validation PASS (no fit)\n")
  quit(save = "no")
}
output <- normalizePath(output, mustWork = FALSE)
if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) {
  stop("output must be a fresh root", call. = FALSE)
}
dir.create(output, recursive = TRUE)
fit <- readRDS(file.path(g2n_root, "g2i-delegate", "fit.rds"))
truth <- readRDS(file.path(g2n_root, "g2n-truth.rds"))
metrics <- readRDS(file.path(g2n_root, "g2i-delegate", "recovery-summary.rds"))
profiles <- readRDS(file.path(g2n_root, "g2i-delegate", "profiles.rds"))
g2n_ledger <- readRDS(file.path(g2n_root, "g2n-decision-ledger.rds"))
g2n_provenance <- readRDS(file.path(g2n_root, "g2n-postrun-provenance-addendum.rds"))
g2k <- readRDS(file.path(g2k_root, "gradient-diagnostic.rds"))

V <- fit$sd_report$cov.fixed
p <- fit$opt$par
g <- as.numeric(fit$tmb_obj$gr(p))
stopifnot(length(p) == length(g), identical(length(p), 36L),
          is.matrix(V), identical(dim(V), c(36L, 36L)), all(is.finite(V)), all(is.finite(g)))
blocks <- list(intercept = 1:6, env = 7:12, gbif_contrast = 13:18,
               gbif_bias = 19:24, lambda = 25:30, psi_theta = 31:36)
covariance_scaled_score <- as.numeric(V %*% g)
## The Newton update for this objective would be -Vg. Vg below is retained only
## as a descriptive covariance-scaled score, never as an update or candidate.
block_summary <- t(sapply(names(blocks), function(name) {
  index <- blocks[[name]]
  c(max_abs_gradient = max(abs(g[index])),
    l2_gradient = sqrt(sum(g[index]^2)),
    max_abs_covariance_scaled_score = max(abs(covariance_scaled_score[index])),
    max_abs_covariance_scaled_score_se = max(abs(covariance_scaled_score[index] / sqrt(diag(V)[index]))),
    covariance_condition = kappa(V[index, index, drop = FALSE]))
}))
block_summary <- data.frame(block = rownames(block_summary), block_summary,
                            row.names = NULL, check.names = FALSE)
fixed_names <- fit$X_fix_names
parameter_table <- data.frame(
  position = seq_along(p), block = rep(names(blocks), lengths(blocks)),
  species = rep(paste0("sp", seq_len(6L)), 6L),
  fixed_effect = c(fixed_names, rep(NA_character_, 12L)),
  parameter = p, gradient = g, covariance_scaled_score = covariance_scaled_score,
  standard_error = sqrt(diag(V)),
  covariance_scaled_score_se = covariance_scaled_score / sqrt(diag(V)),
  stringsAsFactors = FALSE
)
psi_table <- data.frame(
  species = names(metrics$psi_variance_hat), truth = truth$psi_variance,
  estimate = metrics$psi_variance_hat,
  error = metrics$psi_variance_hat - truth$psi_variance,
  relative_error = metrics$psi_variance_hat / truth$psi_variance - 1,
  stringsAsFactors = FALSE
)
profile_table <- do.call(rbind, profiles)
profile_lower <- subset(profile_table, offset == -1L,
                        select = c(species, offset, delta_nll, convergence))
attempts <- g2k$attempts
available <- !is.na(attempts$psi_pass)
g2k_summary <- list(
  n_attempts = nrow(attempts), n_raw_gradient_fail = sum(!attempts$gradient_pass),
  n_b_fix_gradient_fail = sum(!attempts$gradient_pass & attempts$raw_max_block == "b_fix"),
  n_theta_rr_gradient_fail = sum(!attempts$gradient_pass & attempts$raw_max_block == "theta_rr_B"),
  psi_profile_spearman = stats::cor(attempts$psi_error[available],
    attempts$n_weak_lower_profiles[available], method = "spearman"),
  psi_failure_median_weak = median(attempts$n_weak_lower_profiles[available & !attempts$psi_pass]),
  psi_pass_median_weak = median(attempts$n_weak_lower_profiles[available & attempts$psi_pass])
)
certificate <- list(
  kind = "G2O_NO_FIT_POSTMORTEM_V1",
  g2n_status = g2n_ledger$classification,
  g2k_status = "G2K_CALIBRATION_HOLD",
  source_gate_valid = g2n_provenance$source_gate$valid,
  numerical_admission = g2n_ledger$numerical_admission,
  block_summary = block_summary,
  parameter_table = parameter_table,
  psi_table = psi_table,
  profile_lower = profile_lower,
  g2k_summary = g2k_summary,
  interpretation_boundary = paste(
    "Descriptive covariance-scaled scores are not optimizer candidates;",
    "no threshold, model, DGP, or estimator is changed."
  )
)
saveRDS(certificate, file.path(output, "g2o-postmortem-certificate.rds"))
utils::write.csv(block_summary, file.path(output, "block-summary.csv"), row.names = FALSE)
utils::write.csv(parameter_table, file.path(output, "parameter-summary.csv"), row.names = FALSE)
utils::write.csv(psi_table, file.path(output, "psi-summary.csv"), row.names = FALSE)
utils::write.csv(profile_lower, file.path(output, "psi-lower-profiles.csv"), row.names = FALSE)
files <- list.files(output, full.names = TRUE)
utils::write.csv(data.frame(path = basename(files), md5 = unname(tools::md5sum(files))),
                 file.path(output, "file-manifest.csv"), row.names = FALSE)
cat("G2O postmortem report PASS (no fit)\n")
