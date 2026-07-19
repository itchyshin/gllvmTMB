#!/usr/bin/env Rscript
## Independent raw-shard audit for the Gaussian REML paired funnel.
## Recomputes the profile-coverage denominators and gate from run_*.rds;
## it intentionally does not trust PROFILE_SUMMARY.rds.

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "=", ""), "", hit[[1L]]) else default
}

out_dir <- arg("out-dir")
if (is.null(out_dir) || !nzchar(out_dir)) stop("Supply --out-dir=PATH")
lcb_threshold <- as.numeric(arg("lcb-threshold", "0.94"))
files <- list.files(out_dir, pattern = "^run_.*\\.rds$", full.names = TRUE)
if (!length(files)) stop("No raw run_*.rds files under ", out_dir)
raw <- do.call(rbind, lapply(files, readRDS))
if (!all(c("fixture_id", "estimator", "rep", "target", "source_sha", "package_sha", "ci_method") %in% names(raw))) {
  stop("Raw files do not have the paired profile schema")
}
profile <- raw[!is.na(raw$ci_method), , drop = FALSE]
if (!nrow(profile)) stop("No profile rows found; this is not a profile campaign")
key <- do.call(paste, c(profile[c("fixture_id", "estimator", "rep", "target")], sep = "\r"))
if (anyDuplicated(key)) stop("Duplicate profile rows in raw shards")
if (length(unique(profile$source_sha)) != 1L) stop("Mixed source SHA in raw shards")
if (length(unique(profile$package_sha)) != 1L) stop("Mixed installed-package SHA in raw shards")
if (!identical(unique(profile$source_sha), unique(profile$package_sha))) {
  stop("Source SHA and installed-package SHA disagree")
}
expected_target <- paste0("Sigma_unit_diag:trait_", profile$certificate_trait)
if (any(profile$target != expected_target)) {
  stop("Profile rows do not match their predeclared certificate trait")
}
expected_reps <- seq.int(min(profile$rep), max(profile$rep))
if (!identical(sort(unique(profile$rep)), expected_reps)) {
  stop("Profile shard repetitions are incomplete")
}

optimizer_ok <- with(
  profile,
  convergence == 0L & pd_hessian & is.finite(max_gradient) &
    is.finite(gradient_tol) & max_gradient <= gradient_tol
)
profile_ok <- !is.na(profile$ci_available) & profile$ci_available
profile$optimizer_ok <- optimizer_ok
profile$profile_ok <- profile_ok

by_cell <- split(profile, list(profile$fixture_id, profile$estimator, profile$target), drop = TRUE)
summary <- do.call(rbind, lapply(by_cell, function(z) {
  n_attempted <- nrow(z)
  n_optimizer_ok <- sum(z$optimizer_ok)
  n_profile_ok <- sum(z$profile_ok)
  n_covered <- sum(z$covered[z$profile_ok], na.rm = TRUE)
  conditional <- if (n_profile_ok) n_covered / n_profile_ok else NA_real_
  unconditional <- n_covered / n_attempted
  lcb <- if (n_profile_ok) stats::binom.test(n_covered, n_profile_ok)$conf.int[[1L]] else NA_real_
  status <- if (n_optimizer_ok < n_attempted) {
    "WITHHELD_optimizer"
  } else if (n_profile_ok < n_attempted) {
    "WITHHELD_profile"
  } else if (is.na(lcb) || lcb < lcb_threshold) {
    "NOT_READY_lcb"
  } else {
    "PASS"
  }
  data.frame(
    fixture_id = z$fixture_id[[1L]], estimator = z$estimator[[1L]], target = z$target[[1L]],
    source_sha = z$source_sha[[1L]], package_sha = z$package_sha[[1L]], n_attempted = n_attempted,
    n_optimizer_ok = n_optimizer_ok, n_profile_ok = n_profile_ok,
    n_covered = n_covered, coverage_conditional = conditional,
    coverage_unconditional = unconditional,
    mcse_conditional = if (n_profile_ok) sqrt(conditional * (1 - conditional) / n_profile_ok) else NA_real_,
    lcb95_conditional = lcb, lcb_threshold = lcb_threshold, gate_status = status,
    stringsAsFactors = FALSE
  )
}))
utils::write.csv(summary, file.path(out_dir, "RAW_AUDIT.csv"), row.names = FALSE)
saveRDS(summary, file.path(out_dir, "RAW_AUDIT.rds"))
print(summary, row.names = FALSE)
cat(sprintf("[raw-audit] %d raw rows, %d profile rows, %d shards; %s\n",
            nrow(raw), nrow(profile), length(files), out_dir))
