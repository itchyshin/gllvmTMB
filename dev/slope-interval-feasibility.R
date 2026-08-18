## Gauss probe (2026-08-18): are CIs on random-SLOPE variance parameters
## mechanically reachable today?
##
## `theta_diag_B_slope` / `theta_rr_B_slope` / `s_B_slope` / `z_B_slope` are
## declared as PARAMETER_VECTOR / PARAMETER_MATRIX in src/gllvmTMB.cpp
## (~line 1030-1046) -- i.e. FIXED effects from TMB's point of view.
## TMB::sdreport() returns par.fixed / cov.fixed for every fixed parameter
## WITHOUT needing ADREPORT.
##
## TWO DISTINCT ROUTES both produce "random slopes" but engage DIFFERENT
## engine parameter blocks, and the question is answered separately per
## route -- this script fits BOTH:
##
##   Route A (phylo):    phylo_indep(1 + x | species, tree = tree)
##                        -> desugars to phylo_slope()'s theta_dep_chol
##                        engine (block-diagonal per-trait Cholesky), per
##                        tests/testthat/test-phylo-indep-slope-gaussian.R.
##                        First-pass probe used the deprecated global
##                        `phylo_tree =` argument; this pass uses the
##                        in-keyword `tree =` form per the deprecation
##                        notice, and reports whichever block the fit
##                        actually contains rather than assuming a name.
##
##   Route B (ordinary): latent(0 + trait + (0 + trait):x | unit, d = K)
##                        -> R/fit-multi.R ~1220-1250 marks this
##                        `.latent_augmented = TRUE`, `kind = "rr"`, grouped
##                        by `unit`, and sets `use_rr_B_slope`/
##                        `use_diag_B_slope` TRUE. This is the route that
##                        engages theta_rr_B_slope / theta_diag_B_slope.
##                        The augmented diagonal (Psi) companion is
##                        Gaussian-only by default (R/fit-multi.R ~2203-2209).
##                        Formula/fixture copied from
##                        tests/testthat/test-ordinary-latent-random-regression.R.
##
## For EACH route this script prints the FULL unique block-name table of
## sd_report$par.fixed (no filtering to an assumed name), then reports
## estimate/SE/finiteness for whichever block(s) that route's own comments
## identify as the slope-variance parameters.
##
## THIS IS A PLUMBING PROBE, NOT A RECOVERY OR CALIBRATION STUDY. It reports
## COMPUTABILITY only: are the slope-block SEs finite, and what would a
## delta-method back-transform require.

devtools::load_all(".", quiet = TRUE)

print_par_fixed_table <- function(fit, label) {
  cat(sprintf("---- %s: sd_report$par.fixed block-name table ----\n", label))
  if (is.null(fit$sd_report)) {
    cat("  fit$sd_report is NULL.\n")
    return(invisible(NULL))
  }
  print(table(names(fit$sd_report$par.fixed)))
  cat(sprintf("  pdHess: %s\n", isTRUE(fit$sd_report$pdHess)))
}

report_block <- function(fit, blk, label) {
  par_fixed_names <- names(fit$sd_report$par.fixed)
  ix <- which(par_fixed_names == blk)
  if (length(ix) == 0L) {
    cat(sprintf("[%s] block '%s' NOT present in sd_report$par.fixed.\n", label, blk))
    return(invisible(NULL))
  }
  est <- as.numeric(fit$sd_report$par.fixed[ix])
  se_diag <- as.numeric(sqrt(diag(fit$sd_report$cov.fixed))[ix])
  cat(sprintf("[%s] block '%s' (n = %d):\n", label, blk, length(ix)))
  print(data.frame(
    index = ix,
    estimate_link_scale = est,
    se_link_scale = se_diag,
    finite_se = is.finite(se_diag),
    positive_se = se_diag > 0
  ))
  invisible(list(est = est, se = se_diag))
}

## =====================================================================
## Route A: phylo_indep(1 + x | species, tree = tree)  -- in-keyword tree
## =====================================================================
cat("======================================================================\n")
cat("ROUTE A: phylo_indep(1 + x | species, tree = tree)\n")
cat("======================================================================\n")

set.seed(42L)
n_sp_A <- 60L
n_traits_A <- 3L
n_rep_A <- 6L
tree_A <- ape::rcoal(n_sp_A)
tree_A$tip.label <- paste0("sp", seq_len(n_sp_A))
A_phy <- ape::vcv(tree_A, corr = TRUE)
LA <- t(chol(A_phy + diag(1e-8, n_sp_A)))
s2_int_A <- c(0.4, 0.6, 0.3); s2_slope_A <- c(0.3, 0.5, 0.2)
b_int <- b_slope <- matrix(0, n_sp_A, n_traits_A)
for (t in seq_len(n_traits_A)) {
  b_int[, t]   <- sqrt(s2_int_A[t])   * (LA %*% stats::rnorm(n_sp_A))
  b_slope[, t] <- sqrt(s2_slope_A[t]) * (LA %*% stats::rnorm(n_sp_A))
}
rows <- list()
for (i in seq_len(n_sp_A)) for (r in seq_len(n_rep_A)) {
  x <- stats::rnorm(1)
  for (t in seq_len(n_traits_A)) rows[[length(rows) + 1L]] <- data.frame(
    species = tree_A$tip.label[i], trait = paste0("t", t), x = x,
    value = 0.5 + b_int[i, t] + x * b_slope[i, t] + stats::rnorm(1, 0, 0.3),
    stringsAsFactors = FALSE
  )
}
df_A <- do.call(rbind, rows)
df_A$species <- factor(df_A$species, levels = tree_A$tip.label)
df_A$trait <- factor(df_A$trait, levels = paste0("t", seq_len(n_traits_A)))

cat(sprintf("n_sp = %d, n_traits = %d, n_rep = %d, n_obs = %d\n",
            n_sp_A, n_traits_A, n_rep_A, nrow(df_A)))
cat("formula: value ~ 0 + trait + phylo_indep(1 + x | species, tree = tree_A)\n")
cat("family: gaussian(); control: gllvmTMBcontrol(se = TRUE)\n\n")

t0 <- Sys.time()
fit_A <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + phylo_indep(1 + x | species, tree = tree_A),
  data = df_A,
  unit = "species",
  family = stats::gaussian(),
  control = gllvmTMBcontrol(se = TRUE)
)))
t1 <- Sys.time()
cat(sprintf("Fit time: %.1f s | opt$convergence: %s | pd_hessian: %s\n\n",
            as.numeric(t1 - t0, units = "secs"), fit_A$opt$convergence,
            isTRUE(fit_A$fit_health$pd_hessian)))

print_par_fixed_table(fit_A, "Route A (phylo_indep, tree in-keyword)")
cat("\n")
cat("Route A slope-variance parameter is theta_dep_chol (per\n")
cat("tests/testthat/test-phylo-indep-slope-gaussian.R: phylo_indep desugars to\n")
cat("phylo_slope's block-diagonal Cholesky engine, NOT theta_diag_B_slope /\n")
cat("theta_rr_B_slope). theta_dep_chol packs, per trait, 2 diagonal Cholesky\n")
cat("entries (log-scale int SD, log-scale slope SD) + 1 within-block\n")
cat("off-diagonal -- 3 * n_traits entries total. The SLOPE variance for trait t\n")
cat("is entry 2 of that trait's 3-entry block (index 3*(t-1)+2), on a LOG scale.\n\n")
routeA_res <- report_block(fit_A, "theta_dep_chol", "Route A")
if (!is.null(routeA_res)) {
  slope_idx_within_block <- seq(2L, 3L * n_traits_A, by = 3L)
  cat(sprintf(
    "\nRoute A slope-SD sub-entries (index %s within theta_dep_chol):\n",
    paste(slope_idx_within_block, collapse = ", ")
  ))
  print(data.frame(
    trait = seq_len(n_traits_A),
    theta_hat = routeA_res$est[slope_idx_within_block],
    se_theta = routeA_res$se[slope_idx_within_block],
    finite_se = is.finite(routeA_res$se[slope_idx_within_block]),
    positive_se = routeA_res$se[slope_idx_within_block] > 0
  ))
}

## =====================================================================
## Route B: latent(0 + trait + (0 + trait):x | unit, d = K)  -- ordinary
## =====================================================================
cat("\n======================================================================\n")
cat("ROUTE B: latent(0 + trait + (0 + trait):temperature | individual, d = 2)\n")
cat("======================================================================\n")

make_ordinary_latent_rr_fixture <- function(
  seed = 9101L, n_ind = 50L, n_traits = 3L, n_rep = 6L
) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions))
  df <- merge(df, sessions, by = c("individual", "rep", "session_id"), sort = FALSE)

  alpha <- c(0.2, -0.1, 0.05)[seq_len(n_traits)]
  beta <- c(0.3, -0.2, 0.1)[seq_len(n_traits)]
  Lambda_aug <- matrix(
    c(0.45, 0.00, 0.18, 0.25, -0.30, 0.00,
      0.10, -0.18, 0.35, 0.00, -0.08, 0.20)[seq_len(2L * n_traits * 2L)],
    nrow = 2L * n_traits, ncol = 2L, byrow = TRUE
  )
  z <- matrix(stats::rnorm(2L * n_ind), nrow = 2L)
  ## Genuine idiosyncratic Psi noise on the augmented (intercept, slope) x
  ## trait coefficient vector, ADDED on top of Lambda_aug %*% z. Without this
  ## the true diagonal-Psi companion (theta_diag_B_slope, on by default for
  ## Gaussian augmented latent()) is exactly zero -- a boundary case that
  ## collapses the parameter and produces a non-PD Hessian (observed on the
  ## first attempt). psi_sd is deliberately away from zero, matching the
  ## instruction to keep true slope SDs away from the boundary.
  psi_sd <- rep(0.2, 2L * n_traits)
  psi_noise <- matrix(
    stats::rnorm(2L * n_traits * n_ind, sd = psi_sd),
    nrow = 2L * n_traits, ncol = n_ind
  )
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o]); ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug %*% z[, ii] + psi_noise[, ii]
    eta[o] <- alpha[tt] + beta[tt] * df$temperature[o] +
      coeff[base + 1L] + coeff[base + 2L] * df$temperature[o]
  }
  df$value <- eta + stats::rnorm(nrow(df), sd = 0.35)
  list(data = df, n_traits = n_traits)
}

fx_B <- make_ordinary_latent_rr_fixture()
cat(sprintf("n_ind = %d, n_traits = %d, n_obs = %d\n",
            length(unique(fx_B$data$individual)), fx_B$n_traits, nrow(fx_B$data)))
cat(paste(
  "formula: value ~ 0 + trait + (0 + trait):temperature +",
  "latent(0 + trait + (0 + trait):temperature | individual, d = 2)\n"
))
cat("family: gaussian() (default); control: gllvmTMBcontrol(se = TRUE)\n\n")

t0 <- Sys.time()
fit_B <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 +
    trait +
    (0 + trait):temperature +
    latent(0 + trait + (0 + trait):temperature | individual, d = 2),
  data = fx_B$data,
  trait = "trait",
  unit = "individual",
  unit_obs = "session_id",
  control = gllvmTMBcontrol(
    se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS")
  )
)))
t1 <- Sys.time()
cat(sprintf("Fit time: %.1f s | opt$convergence: %s | pd_hessian: %s\n",
            as.numeric(t1 - t0, units = "secs"), fit_B$opt$convergence,
            isTRUE(fit_B$fit_health$pd_hessian)))
cat(sprintf("use_rr_B_slope: %s, use_diag_B_slope: %s\n\n",
            fit_B$tmb_data$use_rr_B_slope, fit_B$tmb_data$use_diag_B_slope))

print_par_fixed_table(fit_B, "Route B (ordinary latent, unit tier)")
cat("\n")

routeB_diag <- report_block(fit_B, "theta_diag_B_slope", "Route B")
cat("\n")
routeB_rr <- report_block(fit_B, "theta_rr_B_slope", "Route B")

cat("\n======================================================================\n")
cat("Delta-method back-transform requirement\n")
cat("======================================================================\n")
cat(paste(
  "theta_diag_B_slope (Route B augmented Psi companion) is a log-SD:",
  "  sd_hat = exp(theta_hat); se(sd_hat) = exp(theta_hat) * se(theta_hat)",
  "  (delta method, d/dtheta exp(theta) = exp(theta)); CI = sd_hat +/- z*se(sd_hat),",
  "  or exponentiate a link-scale Wald interval directly for a positivity guarantee.",
  "theta_dep_chol (Route A) diagonal Cholesky entries are ALSO log-SDs by the",
  "  same construction (log-scale diagonal of a Cholesky factor), so the same",
  "  univariate delta method applies to its slope sub-entries.",
  "theta_rr_B_slope (Route B loadings, if present) packs the loadings matrix",
  "  Lambda_B_slope; Sigma_B_slope = Lambda_B_slope %*% t(Lambda_B_slope) is a",
  "  nonlinear function of MULTIPLE theta_rr_B_slope entries at once, so any",
  "  natural-scale variance/SD needs the FULL relevant cov.fixed sub-block",
  "  propagated through that quadratic form (multivariate delta method /",
  "  numerical jacobian), not a single exp() per element.",
  sep = "\n"
), "\n\n")

worked_example <- function(est, se, label) {
  if (is.null(est) || is.null(se) || length(est) == 0L) {
    cat(sprintf("[%s] no block to compute a worked example from.\n", label))
    return(invisible(NULL))
  }
  ok <- is.finite(se) & se > 0
  if (!any(ok)) {
    cat(sprintf("[%s] SEs not finite/positive -- no worked example computed.\n", label))
    return(invisible(NULL))
  }
  i <- which(ok)[1L]
  z <- stats::qnorm(0.975)
  sd_hat <- exp(est[i])
  se_sd_delta <- sd_hat * se[i]
  lo_delta <- sd_hat - z * se_sd_delta; hi_delta <- sd_hat + z * se_sd_delta
  lo_exp <- exp(est[i] - z * se[i]); hi_exp <- exp(est[i] + z * se[i])
  cat(sprintf("[%s] worked example (element %d):\n", label, i))
  cat(sprintf("  theta_hat = %.6f, se(theta_hat) = %.6f\n", est[i], se[i]))
  cat(sprintf("  sd_hat = exp(theta_hat) = %.6f\n", sd_hat))
  cat(sprintf("  delta-method se(sd_hat) = %.6f\n", se_sd_delta))
  cat(sprintf("  95%% CI (delta, symmetric on SD scale)  = [%.6f, %.6f]\n", lo_delta, hi_delta))
  cat(sprintf("  95%% CI (exponentiated link-scale Wald) = [%.6f, %.6f]\n", lo_exp, hi_exp))
}

cat("======================================================================\n")
cat("Worked examples\n")
cat("======================================================================\n")
if (!is.null(routeA_res)) {
  slope_idx_within_block <- seq(2L, 3L * n_traits_A, by = 3L)
  worked_example(routeA_res$est[slope_idx_within_block],
                  routeA_res$se[slope_idx_within_block],
                  "Route A theta_dep_chol slope sub-entries")
}
if (!is.null(routeB_diag)) {
  worked_example(routeB_diag$est, routeB_diag$se, "Route B theta_diag_B_slope")
}

cat("\n======================================================================\n")
cat("Step 4: existing extractor grep\n")
cat("======================================================================\n")
system("grep -rln 'theta_diag_B_slope\\|theta_rr_B_slope' R/")
cat("\nprofile_targets() grep (does the profile-target inventory list B_slope?):\n")
system("grep -n 'B_slope' R/profile-targets.R || echo '  (no match)'")

cat("\nDone.\n")
