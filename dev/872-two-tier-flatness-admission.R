## Issue #872 private admission harness.
##
## This is deliberately separate from dev/scale-equivariance-check.R, which is
## the single-tier #851 regression oracle.  It evaluates the exact ordinary
## Gaussian, native-Laplace fixture from #872 at a mapped outer parameter point
## and retains an auditable receipt.  It is not a package test or a user-facing
## convergence diagnostic.
##
## Run: Rscript dev/872-two-tier-flatness-admission.R [out_dir]

suppressMessages(devtools::load_all(quiet = TRUE))

out_dir <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(out_dir)) out_dir[[1L]] else
  file.path("docs", "dev-log", "simulation-artifacts", "2026-08-13-872-smoke")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fail <- function(message) stop(sprintf("#872 HOLD: %s", message), call. = FALSE)
rel_err <- function(x, y) {
  x <- as.numeric(x); y <- as.numeric(y)
  if (!length(x) || !length(y) || length(x) != length(y) ||
      any(!is.finite(x)) || any(!is.finite(y))) return(NA_real_)
  max(abs(x - y) / pmax(abs(y), 1e-12))
}

## Exact immutable issue fixture: Gaussian n=150, p=4, rank-1 B latent term
## plus the diagonal nested W tier.  Keep this definition in sync with the
## original oracle only by deliberate review, never by importing its results.
seed <- 7L; n_traits <- 4L; n_sites <- 150L; k <- 5000
set.seed(seed)
base <- gllvmTMB::simulate_site_trait(
  n_sites = n_sites, n_species = 3L, n_traits = n_traits,
  mean_species_per_site = 2L,
  Lambda_B = matrix(c(0.9, 0.6, -0.5, 0.4), n_traits, 1L),
  psi_B = rep(0.3, n_traits), psi_W = rep(0.3, n_traits),
  beta = matrix(0, n_traits, 2L), seed = seed
)
fml <- value ~ 0 + trait + latent(0 + trait | site, d = 1) +
  unique(0 + trait | site_species)

fit_at <- function(scale) {
  d <- base$data
  d$value <- d$value * scale
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    fml, data = d, family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = TRUE)
  )))
}

elapsed <- system.time({
  fit_1 <- fit_at(1)
  fit_k <- fit_at(k)
})[["elapsed"]]

## The marginal objective keeps z_B, s_B, and s_W in MakeADFun(random = ...).
## Mapping only opt$par is therefore intentional: obj$fn(mapped_outer) finds
## the conditional modes afresh and returns the native Laplace marginal nll.
expect_random <- c("z_B", "s_B", "s_W")
if (!identical(fit_1$random, expect_random) || !identical(fit_k$random, expect_random))
  fail("random blocks differ from z_B, s_B, s_W")
if (!identical(fit_1$REML, FALSE) || !identical(fit_k$REML, FALSE) ||
    !identical(fit_1$estimator, "ML") || !identical(fit_k$estimator, "ML"))
  fail("fixture is not ordinary ML Laplace")
if (!identical(fit_1$opt$convergence, 0L) || !identical(fit_k$opt$convergence, 0L) ||
    !isTRUE(fit_1$sd_report$pdHess) || !isTRUE(fit_k$sd_report$pdHess))
  fail("one or both fitted endpoints lack convergence=0 and pdHess=TRUE")
if (isTRUE(fit_1$aghq$used) || isTRUE(fit_k$aghq$used) ||
    isTRUE(fit_1$aghq$penalised) || isTRUE(fit_k$aghq$penalised) ||
    any(fit_1$tmb_data$family_id_vec != 0L) || any(fit_k$tmb_data$family_id_vec != 0L) ||
    any(fit_1$tmb_data$weights_i != 1) || any(fit_k$tmb_data$weights_i != 1) ||
    any(fit_1$tmb_data$offset_vec != 0) || any(fit_k$tmb_data$offset_vec != 0))
  fail("fixture is not unweighted, offset-free Gaussian native Laplace")
if (!identical(fit_1$tmb_map, fit_k$tmb_map) ||
    !identical(names(fit_1$opt$par), names(fit_k$opt$par)) ||
    !identical(fit_1$tmb_data$X_fix, fit_k$tmb_data$X_fix) ||
    !identical(fit_1$tmb_data$site_id, fit_k$tmb_data$site_id) ||
    !identical(fit_1$tmb_data$species_id, fit_k$tmb_data$species_id))
  fail("outer parameter maps or names differ")

map_outer <- function(par, scale) {
  out <- par
  nm <- names(out)
  raw_scale <- nm %in% c("b_fix", "theta_rr_B")
  log_scale <- nm %in% c("log_sigma_eps", "theta_diag_B", "theta_diag_W")
  inactive <- setdiff(unique(nm), c("b_fix", "theta_rr_B", "log_sigma_eps",
                                    "theta_diag_B", "theta_diag_W"))
  if (length(inactive)) fail(sprintf("unexpected free block(s): %s",
                                    paste(inactive, collapse = ", ")))
  out[raw_scale] <- out[raw_scale] * scale
  out[log_scale] <- out[log_scale] + log(scale)
  out
}

mapped_outer <- map_outer(fit_1$opt$par, k)
## TMB caches inner modes.  Warm once, then retain a second evaluation at each
## point; the latter is the comparable native-Laplace value/gradient pair.
evaluate <- function(obj, par) {
  obj$fn(par); obj$gr(par)
  grad <- obj$gr(par)
  ## TMB returns an unnamed numeric gradient.  The named outer parameter vector
  ## is the authoritative block map for every chain-rule transformation below.
  names(grad) <- names(par)
  list(value = obj$fn(par), gradient = grad)
}
base_eval <- evaluate(fit_1$tmb_obj, fit_1$opt$par)
mapped_eval <- evaluate(fit_k$tmb_obj, mapped_outer)
base_nll <- base_eval$value
base_grad <- base_eval$gradient
mapped_nll <- mapped_eval$value
mapped_grad <- mapped_eval$gradient
if (!is.finite(base_nll) || any(!is.finite(base_grad)) || !is.finite(mapped_nll) || any(!is.finite(mapped_grad)))
  fail("mapped marginal objective or gradient is non-finite")

n_obs <- nrow(base$data)
identity_residual <- mapped_nll - base_nll - n_obs * log(k)
if (abs(identity_residual) > 1e-6)
  fail(sprintf("Laplace-marginal identity residual %.3g exceeds 1e-6", identity_residual))
pullback_gradient <- mapped_grad
pullback_gradient[names(pullback_gradient) %in% c("b_fix", "theta_rr_B")] <-
  pullback_gradient[names(pullback_gradient) %in% c("b_fix", "theta_rr_B")] * k
gradient_identity_residual <- max(abs(pullback_gradient - base_grad))
if (gradient_identity_residual > 2e-4)
  fail(sprintf("near-stationary mapped gradient residual %.3g exceeds 2e-4", gradient_identity_residual))

## A stationary gradient cannot test a derivative identity sharply.  This fixed
## probe has a nonzero score and tests the chain rule separately from the
## optimizer's inner-mode tolerance floor.
probe_base <- fit_1$opt$par
probe_raw <- names(probe_base) %in% c("b_fix", "theta_rr_B")
probe_log <- names(probe_base) %in% c("log_sigma_eps", "theta_diag_B", "theta_diag_W")
probe_base[probe_raw] <- probe_base[probe_raw] + 0.01 * pmax(1, abs(probe_base[probe_raw]))
probe_base[probe_log] <- probe_base[probe_log] + 0.01
probe_eval <- evaluate(fit_1$tmb_obj, probe_base)
probe_mapped_eval <- evaluate(fit_k$tmb_obj, map_outer(probe_base, k))
probe_objective_residual <- probe_mapped_eval$value - probe_eval$value - n_obs * log(k)
if (abs(probe_objective_residual) > 1e-6)
  fail(sprintf("nonstationary objective identity residual %.3g exceeds 1e-6", probe_objective_residual))
probe_pullback_grad <- probe_mapped_eval$gradient
probe_pullback_grad[names(probe_pullback_grad) %in% c("b_fix", "theta_rr_B")] <-
  probe_pullback_grad[names(probe_pullback_grad) %in% c("b_fix", "theta_rr_B")] * k
probe_gradient_relative_error <- max(abs(probe_pullback_grad - probe_eval$gradient)) /
  max(max(abs(probe_pullback_grad)), max(abs(probe_eval$gradient)), 1e-3)
if (probe_gradient_relative_error > 1e-3)
  utils::write.csv(data.frame(
    block = names(probe_eval$gradient), base_gradient = probe_eval$gradient,
    mapped_gradient = probe_mapped_eval$gradient,
    pullback_gradient = probe_pullback_grad,
    absolute_residual = probe_pullback_grad - probe_eval$gradient
  ), file.path(out_dir, "probe-gradient-hold.csv"), row.names = FALSE)
if (probe_gradient_relative_error > 1e-3)
  fail(sprintf("nonstationary pullback gradient relative error %.3g exceeds 1e-3", probe_gradient_relative_error))

## Pull the scaled fit back to scale 1 for named-block diagnostics.  At q=1,
## only a sign ambiguity remains for Lambda; compare covariance targets rather
## than loading cells in the receipt.
pullback <- map_outer(fit_k$opt$par, 1 / k)
block_distance <- vapply(unique(names(pullback)), function(block) {
  ii <- names(pullback) == block
  rel_err(pullback[ii], fit_1$opt$par[ii])
}, numeric(1))

safe_sigma <- function(fit, level) tryCatch(
  gllvmTMB::extract_Sigma(fit, level = level), error = function(e) e
)
sig_B_1 <- safe_sigma(fit_1, "unit")
sig_B_k <- safe_sigma(fit_k, "unit")
sig_W_1 <- safe_sigma(fit_1, "unit_obs")
sig_W_k <- safe_sigma(fit_k, "unit_obs")
if (any(vapply(list(sig_B_1, sig_B_k, sig_W_1, sig_W_k), inherits,
               logical(1), what = "error")))
  fail("could not extract both tier covariance matrices")
repeat_1 <- tryCatch(gllvmTMB::extract_repeatability(fit_1), error = function(e) e)
repeat_k <- tryCatch(gllvmTMB::extract_repeatability(fit_k), error = function(e) e)
if (inherits(repeat_1, "error") || inherits(repeat_k, "error"))
  fail("could not extract repeatability")

scaled_gradient <- function(fit) {
  cov <- fit$sd_report$cov.fixed
  grad <- fit$tmb_obj$gr(fit$opt$par)
  if (is.null(cov) || any(!is.finite(cov)) || nrow(cov) != length(grad)) return(NA_real_)
  ## The Hessian-scaled score is invariant to a common response-unit scaling.
  max(abs(backsolve(chol(solve(cov)), grad)))
}
parameter_distance <- sqrt(sum((fit_k$opt$par - mapped_outer)^2)) /
  max(sqrt(sum(mapped_outer^2)), 1e-12)
source_files <- c("dev/872-two-tier-flatness-admission.R")
source_hashes <- unname(tools::md5sum(source_files))

receipt <- list(
  status = "PASS",
  issue = 872L,
  fixture = list(seed = seed, n_sites = n_sites, n_traits = n_traits,
                 rank_B = 1L, n_species = 3L, scale = k,
                 formula = paste(deparse(fml), collapse = " "), family = "gaussian"),
  provenance = list(commit = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
                    platform = R.version$platform, R = R.version.string,
                    package = as.character(utils::packageVersion("gllvmTMB")),
                    TMB = as.character(utils::packageVersion("TMB")),
                    elapsed_seconds = elapsed, n_obs = n_obs,
                    command = "Rscript dev/872-two-tier-flatness-admission.R",
                    source_hashes = stats::setNames(source_hashes, source_files),
                    git_dirty = nzchar(system2("git", "status --porcelain", stdout = TRUE)),
                    omp_threads = Sys.getenv("OMP_NUM_THREADS", unset = "unset"),
                    control = "gllvmTMBcontrol(se = TRUE); default nlminb; one start"),
  random_blocks = fit_1$random,
  fit_1 = list(objective = base_nll, optimizer_objective = fit_1$opt$objective, convergence = fit_1$opt$convergence,
               message = fit_1$opt$message %||% NA_character_,
               max_abs_gradient = max(abs(fit_1$tmb_obj$gr(fit_1$opt$par))),
               hessian_scaled_gradient = scaled_gradient(fit_1),
               pdHess = fit_1$sd_report$pdHess %||% NA,
               hessian_condition = kappa(fit_1$sd_report$cov.fixed)),
  fit_k = list(objective = fit_k$tmb_obj$fn(fit_k$opt$par), optimizer_objective = fit_k$opt$objective, convergence = fit_k$opt$convergence,
               message = fit_k$opt$message %||% NA_character_,
               max_abs_gradient = max(abs(fit_k$tmb_obj$gr(fit_k$opt$par))),
               hessian_scaled_gradient = scaled_gradient(fit_k),
               pdHess = fit_k$sd_report$pdHess %||% NA,
               hessian_condition = kappa(fit_k$sd_report$cov.fixed)),
  mapped = list(objective = mapped_nll, max_abs_gradient = max(abs(mapped_grad)),
                identity_residual = identity_residual,
                gradient_identity_residual = gradient_identity_residual,
                probe_objective_residual = probe_objective_residual,
                probe_gradient_relative_error = probe_gradient_relative_error,
                reached_minus_mapped = fit_k$opt$objective - mapped_nll,
                relative_parameter_distance = parameter_distance,
                blockwise_pullback_relative_error = block_distance,
                unit_Sigma_relative_error = rel_err(sig_B_k$Sigma, sig_B_1$Sigma * k^2),
                unit_R_relative_error = rel_err(sig_B_k$R, sig_B_1$R),
                unit_obs_Sigma_relative_error = rel_err(sig_W_k$Sigma, sig_W_1$Sigma * k^2),
                unit_obs_R_relative_error = rel_err(sig_W_k$R, sig_W_1$R),
                repeatability_relative_error = rel_err(repeat_k$R, repeat_1$R)),
  thresholds = list(identity_abs = 1e-6, stationary_gradient_abs = 2e-4,
                    probe_gradient_relative = 1e-3,
                    status = "SMOKE_PASS only if fixture/map/finite/identity checks pass; not campaign admission"),
  attempts = list(total = 2L, retained = 2L, exclusions = 0L)
)

saveRDS(receipt, file.path(out_dir, "receipt.rds"))
utils::write.csv(data.frame(
  issue = 872L, seed = seed, n_sites = n_sites, n_traits = n_traits, k = k,
  n_obs = n_obs, fit1_objective = base_nll,
  fitk_objective = fit_k$tmb_obj$fn(fit_k$opt$par), mapped_objective = mapped_nll,
  identity_residual = identity_residual,
  gradient_identity_residual = gradient_identity_residual,
  probe_objective_residual = probe_objective_residual,
  probe_gradient_relative_error = probe_gradient_relative_error,
  reached_minus_mapped = fit_k$opt$objective - mapped_nll,
  fit1_gradient = receipt$fit_1$max_abs_gradient,
  fitk_gradient = receipt$fit_k$max_abs_gradient,
  mapped_gradient = receipt$mapped$max_abs_gradient,
  fit1_hessian_scaled_gradient = receipt$fit_1$hessian_scaled_gradient,
  fitk_hessian_scaled_gradient = receipt$fit_k$hessian_scaled_gradient,
  relative_parameter_distance = parameter_distance,
  unit_Sigma_relative_error = receipt$mapped$unit_Sigma_relative_error,
  unit_obs_Sigma_relative_error = receipt$mapped$unit_obs_Sigma_relative_error,
  repeatability_relative_error = receipt$mapped$repeatability_relative_error,
  elapsed_seconds = elapsed
), file.path(out_dir, "cells.csv"), row.names = FALSE)
cat(sprintf("#872 PASS: mapped identity residual %.3g; reached-minus-mapped %.6f; %.1fs\n",
            identity_residual, receipt$mapped$reached_minus_mapped, elapsed))
