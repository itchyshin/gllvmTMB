#!/usr/bin/env Rscript
## Paired Gaussian ML/REML recovery funnel for the 0.6 certificate.
##
## This deliberately records point-recovery evidence only.  It is not the
## profile-interval certificate: promotion to that stage requires a separate,
## predeclared coverage runner and D-43 review.

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}

mode <- arg("mode", "run")
stage <- arg("stage", "deterministic")
fixtures <- strsplit(arg("fixtures", "diag3,latent1_psi3"), ",", fixed = TRUE)[[1L]]
rep_start <- as.integer(arg("rep-start", "1"))
rep_end <- as.integer(arg("rep-end", as.character(rep_start)))
seed_base <- as.integer(arg("seed-base", "20260719"))
n_units <- as.integer(arg("n-units", "50"))
n_obs <- as.integer(arg("n-obs-per-unit", "3"))
out_dir <- arg("out-dir", "docs/dev-log/artifacts/reml-paired")
se <- tolower(arg("se", "true")) %in% c("true", "1", "yes")
gradient_tol <- as.numeric(arg("gradient-tol", "0.01"))
with_profile <- tolower(arg("with-profile", "false")) %in% c("true", "1", "yes")
ci_level <- as.numeric(arg("ci-level", "0.95"))

if (!mode %in% c("run", "aggregate")) stop("--mode must be run or aggregate")
if (mode == "run" && (is.na(rep_start) || is.na(rep_end) || rep_start < 1L || rep_end < rep_start)) {
  stop("--rep-start and --rep-end must define a positive inclusive range")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## Local deterministic tests intentionally use the source tree.  Production
## launchers set GLLVM_REML_FUNNEL_INSTALLED=1 after installing this branch,
## which avoids recompiling the TMB template in every worker.
if (identical(Sys.getenv("GLLVM_REML_FUNNEL_INSTALLED"), "1")) {
  suppressPackageStartupMessages(library(gllvmTMB))
} else if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else {
  suppressPackageStartupMessages(library(gllvmTMB))
}

source_sha <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]],
  error = function(e) NA_character_
)
package_path <- find.package("gllvmTMB")
package_description <- file.path(package_path, "DESCRIPTION")
package_description_mtime <- as.character(file.info(package_description)$mtime)
package_sha <- Sys.getenv("GLLVM_REML_FUNNEL_PACKAGE_SHA", "")
if (identical(Sys.getenv("GLLVM_REML_FUNNEL_INSTALLED"), "1") && !nzchar(package_sha)) {
  stop("Installed funnel runs require GLLVM_REML_FUNNEL_PACKAGE_SHA to bind the loaded package to source.")
}
if (!nzchar(package_sha)) package_sha <- source_sha

fixture_spec <- function(id) {
  switch(id,
    diag3 = list(
      formula = value ~ 0 + trait + indep(0 + trait | unit),
      Lambda_B = NULL, psi_B = c(0.35, 0.55, 0.75), sigma2_eps = 0.25, d = 0L,
      certificate_trait = 2L
    ),
    latent1_psi3 = list(
      formula = value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      Lambda_B = matrix(c(0.8, 0.4, -0.2), nrow = 3L),
      psi_B = c(0.30, 0.40, 0.50), sigma2_eps = 0.20, d = 1L,
      certificate_trait = 1L
    ),
    latent1_psi3_stress = list(
      formula = value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      Lambda_B = matrix(c(0.8, 0.4, -0.2), nrow = 3L),
      psi_B = c(0.20, 0.25, 0.35), sigma2_eps = 0.20, d = 1L,
      n_units = 20L, n_obs_per_unit = 2L, certificate_trait = NA_integer_
    ),
    stop("Unknown fixture: ", id, "; allowed: diag3, latent1_psi3, latent1_psi3_stress")
  )
}

fit_one <- function(data, formula, reml) {
  t0 <- proc.time()[["elapsed"]]
  ans <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      formula, data = data, unit = "unit", trait = "trait", REML = reml,
      control = gllvmTMBcontrol(se = se)
    ))),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  if (inherits(ans, "error")) return(list(fit = NULL, runtime_s = elapsed, error = conditionMessage(ans)))
  list(fit = ans, runtime_s = elapsed, error = NA_character_)
}

profile_total_variance <- function(fit, trait_idx) {
  if (!with_profile || is.na(trait_idx)) {
    return(list(bounds = NULL, error = NA_character_))
  }
  ans <- tryCatch(
    gllvmTMB:::.profile_ci_total_variance(
      fit, tier = "unit", trait_idx = trait_idx, level = ci_level
    ),
    error = function(e) e
  )
  if (inherits(ans, "error")) {
    return(list(bounds = NULL, error = conditionMessage(ans)))
  }
  list(bounds = ans, error = NA_character_)
}

emit_rows <- function(id, rep_id) {
  spec <- fixture_spec(id)
  seed <- seed_base + match(id, fixtures) * 100000L + rep_id
  cell_n_units <- if (is.null(spec$n_units)) n_units else spec$n_units
  cell_n_obs <- if (is.null(spec$n_obs_per_unit)) n_obs else spec$n_obs_per_unit
  sim <- simulate_unit_trait(
    n_units = cell_n_units, n_obs_per_unit = cell_n_obs, n_traits = 3L,
    Lambda_B = spec$Lambda_B, psi_B = spec$psi_B,
    sigma2_eps = spec$sigma2_eps, seed = seed
  )
  truth_sigma <- if (is.null(spec$Lambda_B)) {
    diag(spec$psi_B)
  } else {
    spec$Lambda_B %*% t(spec$Lambda_B) + diag(spec$psi_B)
  }
  do.call(rbind, lapply(c(FALSE, TRUE), function(reml) {
    out <- fit_one(sim$data, spec$formula, reml)
    estimator <- if (reml) "REML" else "ML"
    if (is.null(out$fit)) {
      profile_method <- rep(NA_character_, 3L)
      if (with_profile && !is.na(spec$certificate_trait)) {
        profile_method[[spec$certificate_trait]] <- "profile_total"
      }
      return(data.frame(
        fixture_id = id, stage = stage, source_sha = source_sha, package_sha = package_sha,
        package_path = package_path, package_description_mtime = package_description_mtime,
        rep = rep_id, seed = seed,
        n_units = cell_n_units, n_obs_per_unit = cell_n_obs, n_traits = 3L, d = spec$d,
        formula = paste(deparse(spec$formula), collapse = " "), estimator = estimator,
        target = paste0("Sigma_unit_diag:", paste0("trait_", 1:3)), truth = diag(truth_sigma),
        estimate = NA_real_, convergence = NA_integer_, pd_hessian = NA,
        max_gradient = NA_real_, gradient_tol = gradient_tol, boundary_flag = NA,
        certificate_trait = spec$certificate_trait,
        ci_method = profile_method,
        ci_level = if (with_profile) ci_level else NA_real_, ci_lower = NA_real_,
        ci_upper = NA_real_, ci_available = NA, covered = NA, ci_error = NA_character_,
        logLik = NA_real_, objective = NA_real_,
        runtime_s = out$runtime_s, error = out$error, stringsAsFactors = FALSE
      ))
    }
    fit <- out$fit
    sigma <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total")$Sigma)
    grad <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
    diag_sigma <- diag(sigma)
    prof <- profile_total_variance(fit, spec$certificate_trait)
    lo <- hi <- rep(NA_real_, length(diag_sigma))
    ci_estimate <- rep(NA_real_, length(diag_sigma))
    ci_available <- rep(NA, length(diag_sigma))
    profile_method <- rep(NA_character_, length(diag_sigma))
    if (with_profile && !is.na(spec$certificate_trait)) {
      profile_method[[spec$certificate_trait]] <- "profile_total"
    }
    if (!is.null(prof$bounds) && nrow(prof$bounds) == 1L) {
      tt <- spec$certificate_trait
      lo[[tt]] <- prof$bounds$lower[[1L]]
      hi[[tt]] <- prof$bounds$upper[[1L]]
      ci_estimate[[tt]] <- prof$bounds$estimate[[1L]]
      ci_available[[tt]] <- is.finite(ci_estimate[[tt]]) && is.finite(lo[[tt]]) && is.finite(hi[[tt]]) &&
        lo[[tt]] < ci_estimate[[tt]] && ci_estimate[[tt]] < hi[[tt]] &&
        isTRUE(all.equal(ci_estimate[[tt]], diag_sigma[[tt]], tolerance = 1e-6))
    }
    data.frame(
      fixture_id = id, stage = stage, source_sha = source_sha, package_sha = package_sha,
      package_path = package_path, package_description_mtime = package_description_mtime,
      rep = rep_id, seed = seed,
      n_units = cell_n_units, n_obs_per_unit = cell_n_obs, n_traits = 3L, d = spec$d,
      formula = paste(deparse(spec$formula), collapse = " "), estimator = estimator,
      target = paste0("Sigma_unit_diag:", names(diag_sigma)), truth = diag(truth_sigma),
      estimate = unname(diag_sigma), convergence = fit$opt$convergence,
      pd_hessian = if (se) isTRUE(fit$sd_report$pdHess) else NA,
      max_gradient = grad, gradient_tol = gradient_tol,
      boundary_flag = any(diag_sigma < 1e-6),
      certificate_trait = spec$certificate_trait,
      ci_method = profile_method,
      ci_level = if (with_profile) ci_level else NA_real_, ci_estimate = ci_estimate,
      ci_lower = lo, ci_upper = hi,
      ci_available = ci_available,
      covered = ifelse(ci_available, diag(truth_sigma) >= lo & diag(truth_sigma) <= hi, NA),
      ci_error = ifelse(seq_along(diag_sigma) == spec$certificate_trait, prof$error, NA_character_),
      logLik = as.numeric(logLik(fit)),
      objective = fit$opt$objective, runtime_s = out$runtime_s, error = NA_character_, stringsAsFactors = FALSE
    )
  }))
}

if (identical(mode, "run")) {
  rows <- do.call(rbind, unlist(lapply(fixtures, function(id) {
    lapply(seq.int(rep_start, rep_end), function(rep_id) emit_rows(id, rep_id))
  }), recursive = FALSE))
  file <- file.path(out_dir, sprintf("run_%s_%06d_%06d.rds", stage, rep_start, rep_end))
  saveRDS(rows, file)
  cat(sprintf("Wrote %d rows to %s\n", nrow(rows), file))
} else {
  files <- list.files(out_dir, pattern = "^run_.*\\.rds$", full.names = TRUE)
  if (!length(files)) stop("No run_*.rds files under ", out_dir)
  rows <- do.call(rbind, lapply(files, readRDS))
  key <- c("fixture_id", "rep", "target")
  ml <- rows[rows$estimator == "ML", c(key, "truth", "estimate", "convergence", "pd_hessian", "max_gradient", "gradient_tol", "error"), drop = FALSE]
  reml <- rows[rows$estimator == "REML", c(key, "estimate", "convergence", "pd_hessian", "max_gradient", "gradient_tol", "error"), drop = FALSE]
  names(ml)[5:10] <- c("estimate_ml", "convergence_ml", "pd_hessian_ml", "max_gradient_ml", "gradient_tol", "error_ml")
  names(reml)[4:9] <- c("estimate_reml", "convergence_reml", "pd_hessian_reml", "max_gradient_reml", "gradient_tol_reml", "error_reml")
  paired <- merge(ml, reml, by = key, all = TRUE, sort = TRUE)
  paired$estimate_reml_minus_ml <- paired$estimate_reml - paired$estimate_ml
  paired$paired_ok <- with(paired, is.finite(estimate_ml) & is.finite(estimate_reml) & convergence_ml == 0L & convergence_reml == 0L)
  paired$paired_optimizer_ok <- with(
    paired,
    paired_ok & pd_hessian_ml & pd_hessian_reml &
      is.finite(max_gradient_ml) & is.finite(max_gradient_reml) &
      max_gradient_ml <= gradient_tol & max_gradient_reml <= gradient_tol
  )
  saveRDS(rows, file.path(out_dir, "ALL_ROWS.rds"))
  saveRDS(paired, file.path(out_dir, "PAIRED.rds"))
  utils::write.csv(paired, file.path(out_dir, "PAIRED.csv"), row.names = FALSE)
  if ("ci_method" %in% names(rows) && any(!is.na(rows$ci_method))) {
    profile_rows <- rows[!is.na(rows$ci_method), , drop = FALSE]
    coverage_summary <- do.call(rbind, lapply(split(profile_rows, list(profile_rows$fixture_id, profile_rows$estimator, profile_rows$target), drop = TRUE), function(z) {
      available <- !is.na(z$ci_available) & z$ci_available
      n_available <- sum(available)
      n_covered <- sum(z$covered[available], na.rm = TRUE)
      conditional <- if (n_available) n_covered / n_available else NA_real_
      unconditional <- n_covered / nrow(z)
      lcb95 <- if (n_available) stats::binom.test(n_covered, n_available)$conf.int[[1L]] else NA_real_
      data.frame(
        fixture_id = z$fixture_id[[1L]], estimator = z$estimator[[1L]], target = z$target[[1L]],
        n_attempted = nrow(z), n_optimizer_ok = sum(z$convergence == 0L & z$pd_hessian & z$max_gradient <= z$gradient_tol, na.rm = TRUE),
        n_ci_available = n_available, n_covered = n_covered,
        coverage_conditional = conditional, coverage_unconditional = unconditional,
        mcse_conditional = if (n_available) sqrt(conditional * (1 - conditional) / n_available) else NA_real_,
        lcb95_conditional = lcb95, stringsAsFactors = FALSE
      )
    }))
    saveRDS(coverage_summary, file.path(out_dir, "PROFILE_SUMMARY.rds"))
    utils::write.csv(coverage_summary, file.path(out_dir, "PROFILE_SUMMARY.csv"), row.names = FALSE)
  }
  cat(sprintf("Aggregated %d rows and %d paired target rows under %s\n", nrow(rows), nrow(paired), out_dir))
}
