## Issue #872-B: private mapped-point prevalence receipt.
##
## Exact scope only: ordinary native Gaussian ML/Laplace, rank-1 unit latent
## term plus diagonal nested unit-observation tier.  This is not a package test,
## a convergence criterion, or a user-facing diagnostic.
##
## The original issue reports a 0.197 "relative parameter distance" but did not
## retain its calculation.  We therefore do not claim that historical number is
## reproduced.  This receipt records two fully specified alternatives:
## (i) the merged #959 outer-vector distance and (ii) a mapped-back outer
## distance.  Objective-gap prevalence is estimand-independent.
##
## Run: Rscript dev/872-mapped-point-prevalence.R [out_dir]

suppressMessages({ library(devtools); library(gllvmTMB); library(parallel) })
load_all(quiet = TRUE)

out_dir <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(out_dir)) out_dir[[1L]] else
  file.path("docs", "dev-log", "simulation-artifacts", "2026-08-13-872-mapped-point-prevalence")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fail <- function(...) stop(sprintf(...), call. = FALSE)
rel_l2 <- function(x, y) {
  if (length(x) != length(y) || any(!is.finite(x)) || any(!is.finite(y))) return(NA_real_)
  sqrt(sum((x - y)^2)) / max(sqrt(sum(y^2)), 1e-12)
}
rel_max <- function(x, y) {
  if (length(x) != length(y) || any(!is.finite(x)) || any(!is.finite(y))) return(NA_real_)
  max(abs(x - y) / pmax(abs(y), 1e-12))
}

seeds <- 1:10
n_sites_grid <- c(150L, 400L)
k <- 5000
workers <- as.integer(Sys.getenv("GRID_WORKERS", "1"))
if (!is.finite(workers) || workers < 1L || workers > 150L) fail("GRID_WORKERS must be 1--150")
fml <- value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site_species)
expected_outer <- c("b_fix", "theta_rr_B", "theta_diag_B", "theta_diag_W")

map_outer <- function(par, scale) {
  out <- par; nm <- names(out)
  allowed <- c("b_fix", "theta_rr_B", "theta_diag_B", "theta_diag_W")
  if (!setequal(unique(nm), allowed)) fail("unexpected outer parameter blocks: %s", paste(unique(nm), collapse = ", "))
  out[nm %in% c("b_fix", "theta_rr_B")] <- out[nm %in% c("b_fix", "theta_rr_B")] * scale
  out[nm %in% c("theta_diag_B", "theta_diag_W")] <- out[nm %in% c("theta_diag_B", "theta_diag_W")] + log(scale)
  out
}
evaluate <- function(obj, par) {
  obj$fn(par); obj$gr(par) # warm the TMB inner solve/cache
  grad <- obj$gr(par); names(grad) <- names(par)
  list(value = obj$fn(par), gradient = grad)
}
one <- function(seed, n_sites) tryCatch({
  base <- simulate_site_trait(n_sites = n_sites, n_species = 3L, n_traits = 4L,
    mean_species_per_site = 2L, Lambda_B = matrix(c(.9, .6, -.5, .4), 4L, 1L),
    psi_B = rep(.3, 4L), psi_W = rep(.3, 4L), beta = matrix(0, 4L, 2L), seed = seed)
  fit_at <- function(scale) {
    d <- base$data; d$value <- d$value * scale
    suppressMessages(suppressWarnings(gllvmTMB(fml, data = d, family = gaussian(),
      silent = TRUE, control = gllvmTMBcontrol(se = TRUE))))
  }
  elapsed <- system.time({ fit1 <- fit_at(1); fitk <- fit_at(k) })[["elapsed"]]
  endpoint_ok <- identical(fit1$random, c("z_B", "s_B", "s_W")) &&
    identical(fitk$random, c("z_B", "s_B", "s_W")) &&
    identical(fit1$REML, FALSE) && identical(fitk$REML, FALSE) &&
    identical(fit1$estimator, "ML") && identical(fitk$estimator, "ML") &&
    !isTRUE(fit1$aghq$used) && !isTRUE(fitk$aghq$used) &&
    !isTRUE(fit1$aghq$penalised) && !isTRUE(fitk$aghq$penalised) &&
    all(fit1$tmb_data$family_id_vec == 0L) && all(fitk$tmb_data$family_id_vec == 0L) &&
    all(fit1$tmb_data$weights_i == 1) && all(fitk$tmb_data$weights_i == 1) &&
    all(fit1$tmb_data$offset_vec == 0) && all(fitk$tmb_data$offset_vec == 0) &&
    identical(names(fit1$opt$par), names(fitk$opt$par)) &&
    setequal(unique(names(fit1$opt$par)), expected_outer)
  if (!endpoint_ok) fail("fixture contract mismatch")
  mapped <- map_outer(fit1$opt$par, k)
  ev1 <- evaluate(fit1$tmb_obj, fit1$opt$par)
  evk <- evaluate(fitk$tmb_obj, fitk$opt$par)
  evm <- evaluate(fitk$tmb_obj, mapped)
  identity <- evm$value - ev1$value - nrow(base$data) * log(k)
  if (!is.finite(identity) || abs(identity) > 1e-6) fail("mapped identity residual %.4g", identity)
  pullback_grad <- evm$gradient
  pullback_grad[names(pullback_grad) %in% c("b_fix", "theta_rr_B")] <-
    pullback_grad[names(pullback_grad) %in% c("b_fix", "theta_rr_B")] * k
  grad_residual <- max(abs(pullback_grad - ev1$gradient))
  sigma1_B <- extract_Sigma(fit1, level = "unit")$Sigma
  sigmak_B <- extract_Sigma(fitk, level = "unit")$Sigma
  sigma1_W <- extract_Sigma(fit1, level = "unit_obs")$Sigma
  sigmak_W <- extract_Sigma(fitk, level = "unit_obs")$Sigma
  data.frame(issue = 872L, seed = seed, n_sites = n_sites, k = k,
    status = "OK", endpoint_health = fit1$opt$convergence == 0L && fitk$opt$convergence == 0L &&
      isTRUE(fit1$sd_report$pdHess) && isTRUE(fitk$sd_report$pdHess),
    fit1_convergence = fit1$opt$convergence, fitk_convergence = fitk$opt$convergence,
    fit1_pdHess = isTRUE(fit1$sd_report$pdHess), fitk_pdHess = isTRUE(fitk$sd_report$pdHess),
    fit1_gradient = max(abs(ev1$gradient)), fitk_gradient = max(abs(evk$gradient)),
    mapped_gradient = max(abs(evm$gradient)), identity_residual = identity,
    gradient_identity_residual = grad_residual, fitk_objective = evk$value,
    mapped_objective = evm$value, reached_minus_mapped = evk$value - evm$value,
    outer_distance_959 = rel_l2(fitk$opt$par, mapped),
    mapped_back_outer_distance = rel_l2(map_outer(fitk$opt$par, 1 / k), fit1$opt$par),
    unit_Sigma_relative_error = rel_max(sigmak_B, sigma1_B * k^2),
    unit_obs_Sigma_relative_error = rel_max(sigmak_W, sigma1_W * k^2),
    elapsed_seconds = elapsed, error = NA_character_)
}, error = function(e) data.frame(issue = 872L, seed = seed, n_sites = n_sites, k = k,
  status = "ERROR", endpoint_health = NA, fit1_convergence = NA_integer_, fitk_convergence = NA_integer_,
  fit1_pdHess = NA, fitk_pdHess = NA, fit1_gradient = NA_real_, fitk_gradient = NA_real_,
  mapped_gradient = NA_real_, identity_residual = NA_real_, gradient_identity_residual = NA_real_,
  fitk_objective = NA_real_, mapped_objective = NA_real_, reached_minus_mapped = NA_real_,
  outer_distance_959 = NA_real_, mapped_back_outer_distance = NA_real_,
  unit_Sigma_relative_error = NA_real_, unit_obs_Sigma_relative_error = NA_real_,
  elapsed_seconds = NA_real_, error = conditionMessage(e)))

grid <- expand.grid(seed = seeds, n_sites = n_sites_grid, KEEP.OUT.ATTRS = FALSE)
cells <- do.call(rbind, mclapply(seq_len(nrow(grid)), function(i) one(grid$seed[[i]], grid$n_sites[[i]]),
  mc.cores = workers, mc.preschedule = FALSE))
provenance <- list(commit = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  source_hash = unname(tools::md5sum("dev/872-mapped-point-prevalence.R")),
  command = "Rscript dev/872-mapped-point-prevalence.R", platform = R.version$platform,
  R = R.version.string, package = as.character(packageVersion("gllvmTMB")),
  TMB = as.character(packageVersion("TMB")), omp_threads = Sys.getenv("OMP_NUM_THREADS", "unset"), workers = workers,
  fixture = "Gaussian ML/Laplace; latent(0 + trait | site, d = 1) + unique(0 + trait | site_species); p=4, q=1",
  metric_note = "Historical issue #872 distance formula was not retained; neither recorded distance is called its 0.197 metric.")
saveRDS(list(cells = cells, provenance = provenance), file.path(out_dir, "campaign.rds"))
write.csv(cells, file.path(out_dir, "cells.csv"), row.names = FALSE)
writeLines(capture.output(str(provenance)), file.path(out_dir, "provenance.txt"))
cat(sprintf("#872-B wrote %d rows; %d OK; %d healthy endpoints\n", nrow(cells), sum(cells$status == "OK"), sum(cells$endpoint_health %in% TRUE)))
