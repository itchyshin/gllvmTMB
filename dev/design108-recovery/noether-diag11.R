## Noether diagnostic 11 (mismatch 2, post-DGP-fix): what does EACH arm's
## Sigma_hat actually contain -- loadings-only or total? Verified empirically,
## per arm and per tier, on one small cell. Read-only.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "120"))
T0 <- as.integer(Sys.getenv("D108_T", "8"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
q0 <- 1L; gauss_sd0 <- 0.4; H0 <- 15L
DO_VA <- !identical(Sys.getenv("D108_VA", "1"), "0")

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = 6L)
tr <- sim$truth
rf <- function(h, t) rel_frob(as.matrix(h), as.matrix(t))

cat(sprintf("### N=%d T=%d q=%d seed=%d gauss_sd=%.2f\n\n", N0, T0, q0, seed0, gauss_sd0))

## ---------------- PART A: the DGP's three names --------------------------
cat("======== PART A: DGP truth names ========\n")
for (k in c("tier1", "tier2")) {
  x <- tr[[k]]
  cat(sprintf("%s:  max|Sigma_B - Sigma_B_total| = %.3e   (alias check)\n",
              k, max(abs(x$Sigma_B - x$Sigma_B_total))))
  cat(sprintf("       max|Sigma_B_total - Sigma_B_loadings - diag(psi)| = %.3e\n",
              max(abs(x$Sigma_B_total - x$Sigma_B_loadings - diag(x$psi, T0)))))
  cat(sprintf("       diag means: loadings %.4f  psi %.4f  total %.4f   ||L||_F=%.4f ||tot||_F=%.4f\n",
              mean(diag(x$Sigma_B_loadings)), mean(x$psi), mean(diag(x$Sigma_B_total)),
              sqrt(sum(x$Sigma_B_loadings^2)), sqrt(sum(x$Sigma_B_total^2))))
  cat(sprintf("       rel_frob(loadings, total) = %.4f  <- how much the two estimands differ\n",
              rf(x$Sigma_B_loadings, x$Sigma_B_total)))
}

## ---------------- PART B: Laplace-family arms ----------------------------
## Both `.d108_fit_laplace` (harness.R:382-417) and
## `.d108_fit_gaussian_control` (harness.R:450-486) extract with
## part = "total". Check what "total" and "shared" actually are, per level.
probe_laplace_like <- function(fit, lab, extra_row_var) {
  cat(sprintf("\n---- %s ----\n", lab))
  for (lv in c("unit", "phy")) {
    tot <- tryCatch(as.matrix(gllvmTMB::extract_Sigma(fit, level = lv, part = "total",
                                                      link_residual = "none")$Sigma),
                    error = function(e) NULL)
    sh <- tryCatch(as.matrix(gllvmTMB::extract_Sigma(fit, level = lv, part = "shared",
                                                     link_residual = "none")$Sigma),
                   error = function(e) NULL)
    uq <- tryCatch(gllvmTMB::extract_Sigma(fit, level = lv, part = "unique",
                                           link_residual = "none")$s,
                   error = function(e) NULL)
    if (is.null(tot) || is.null(sh)) { cat(sprintf("  %-5s : extraction failed\n", lv)); next }
    psi_hat <- diag(tot) - diag(sh)
    tier <- if (lv == "unit") tr$tier1 else tr$tier2
    cat(sprintf("  %-5s total-shared is diagonal? max|offdiag(total-shared)|=%.3e\n",
                lv, max(abs((tot - sh)[upper.tri(tot)]))))
    cat(sprintf("        part='unique'$s matches total-shared? %s (max diff %.3e)\n",
                !is.null(uq), if (is.null(uq)) NA_real_ else max(abs(as.numeric(uq) - psi_hat))))
    cat(sprintf("        psi_hat mean = %.4f   truth psi = %.4f",
                mean(psi_hat), mean(tier$psi)))
    if (lv == "unit" && extra_row_var > 0)
      cat(sprintf("   truth psi + gauss_sd^2 = %.4f", mean(tier$psi) + extra_row_var))
    cat("\n")
    cat(sprintf("        rel_frob(total,  Sigma_B_total)    = %.4f\n", rf(tot, tier$Sigma_B_total)))
    cat(sprintf("        rel_frob(shared, Sigma_B_loadings) = %.4f\n", rf(sh, tier$Sigma_B_loadings)))
    cat(sprintf("        rel_frob(total,  Sigma_B_loadings) = %.4f  <- MISMATCHED pairing\n",
                rf(tot, tier$Sigma_B_loadings)))
  }
}

cat("\n======== PART B: Laplace + gaussian control ========\n")
dat <- sim$data
dat$trait <- factor(dat$trait)
dat$species <- factor(dat$species, levels = sim$tree$tip.label)
tree <- sim$tree
fml <- .d108_two_tier_formula(q0, environment())
lap_fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  fml, data = dat, unit = "species", trait = "trait",
  family = stats::binomial(link = "probit"), weights = dat$n_trials,
  control = gllvmTMB::gllvmTMBcontrol())))
probe_laplace_like(lap_fit, "laplace (binomial-probit)", 0)

datg <- sim$data
set.seed(seed0 + 900000L)
datg$y <- datg$eta_true + stats::rnorm(nrow(datg), 0, gauss_sd0)
datg$trait <- factor(datg$trait)
datg$species <- factor(datg$species, levels = sim$tree$tip.label)
fmlg <- .d108_two_tier_formula(q0, environment())
gc_fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  fmlg, data = datg, unit = "species", trait = "trait", family = stats::gaussian(),
  control = gllvmTMB::gllvmTMBcontrol())))
probe_laplace_like(gc_fit, "gaussian_control", gauss_sd0^2)

## ---------------- PART C: the VA arm -------------------------------------
if (DO_VA) {
  cat("\n======== PART C: VA arm ========\n")
  unit <- sim$data$unit; trait <- sim$data$trait
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
  phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, unit, T0, q0)
  cat("tier declarations now in harness.R:\n")
  for (i in seq_along(phy$extra_tiers)) {
    e <- phy$extra_tiers[[i]]
    cat(sprintf("  extra %d: kind=%-9s dim=%-3d structured=%-5s label=%s\n",
                i, e$kind, e$dim, e$structured, e$label))
  }
  v <- gllvmTMB:::.va_r3_validate_data(
    y = sim$data$y, n_trials = sim$data$n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
    structured = phy$structured, extra_tiers = phy$extra_tiers)
  lay <- v$tier_layout
  cat(sprintf("  layout n_levels: %s   structured: %s\n",
              paste(lay$n_levels, collapse = " | "), paste(lay$structured, collapse = " | ")))
  f <- suppressMessages(suppressWarnings(gllvmTMB:::.va_r3_fit(
    y = sim$data$y, n_trials = sim$data$n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
    structured = phy$structured, extra_tiers = phy$extra_tiers,
    H = H0, n_starts = 1L, silent = TRUE)))
  par <- f$best$par
  s1 <- .d108_va_tier_sigma(par, lay, 1L, 2L, T0)
  s2 <- .d108_va_tier_sigma(par, lay, 3L, 4L, T0)
  for (nm in c("s1", "s2")) {
    s <- get(nm); tier <- if (nm == "s1") tr$tier1 else tr$tier2
    LL <- s$Lambda %*% t(s$Lambda)
    cat(sprintf("\n  %s (%s):\n", nm, if (nm == "s1") "tier 1 / unit" else "tier 2 / phylo"))
    cat(sprintf("    returns fields: %s\n", paste(names(s), collapse = ", ")))
    cat(sprintf("    Sigma_B == Lambda Lambda' + diag(psi)? max diff = %.3e\n",
                max(abs(s$Sigma_B - (LL + diag(s$psi, T0))))))
    cat(sprintf("    psi_hat mean = %.4f  (truth psi %.4f)\n", mean(s$psi), mean(tier$psi)))
    cat(sprintf("    rel_frob(Sigma_B,  Sigma_B_total)    = %.4f\n", rf(s$Sigma_B, tier$Sigma_B_total)))
    cat(sprintf("    rel_frob(LambdaL', Sigma_B_loadings) = %.4f\n", rf(LL, tier$Sigma_B_loadings)))
    cat(sprintf("    rel_frob(Sigma_B,  Sigma_B_loadings) = %.4f  <- MISMATCHED pairing\n",
                rf(s$Sigma_B, tier$Sigma_B_loadings)))
  }
}
cat("\nDONE\n")
