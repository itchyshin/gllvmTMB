## Noether diagnostic 6 (VA double-diagonal, STEP 2): empirical.
## Fit the VA-R3 engine on the SAME gaussian control data the Laplace arm sees,
## with the harness's OWN tier declaration, and read the two row-level diagonal
## tiers (tier 2 "psi", tier 4 "phylo_psi") off the fitted parameter vector.
##
## Q1: does the VA tier-2 Sigma_hat contain a row-level diagonal the Laplace
##     arm's cannot?  -> compare diag(Sigma2_hat) across engines.
## Q2: does tier 4 collapse (harmless, like sd_phy_diag's 1.98e-08) or absorb
##     variance (a confound)?  -> read psi4_hat, and vary the START to see
##     whether the 2-vs-4 split moves while the SUM stays put.
##
## Read-only; writes only under pilot-results/.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0    <- as.integer(Sys.getenv("D108_N", "100"))
T0    <- as.integer(Sys.getenv("D108_T", "10"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
q0 <- 1L; gauss_sd0 <- 0.4; H0 <- 15L

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = 6L)
dat <- sim$data
set.seed(seed0 + 900000L)
dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gauss_sd0)

p1 <- sim$truth$tier1$psi; p2 <- sim$truth$tier2$psi
L1 <- sim$truth$tier1$Lambda; L2 <- sim$truth$tier2$Lambda
row_total_true <- p1 + p2 + gauss_sd0^2

unit <- dat$unit; trait <- dat$trait
X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
sp <- sim$species_levels
phy <- .d108_va_phylo_tiers("augmented", sim$tree, sp, unit, T0, q0)

v <- gllvmTMB:::.va_r3_validate_data(
  y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
  q = q0, family = "gaussian", link = "identity", unique = TRUE,
  structured = phy$structured, extra_tiers = phy$extra_tiers)
lay <- v$tier_layout

## Read a tier's diagonal psi off the flat log_sd_tier vector, using the
## layout's own sd_offset (same recipe as .d108_va_tier_sigma, harness.R:196-201).
psi_of_tier <- function(par, tier_idx) {
  ls <- par[names(par) == "log_sd_tier"]
  off <- lay$sd_offset[tier_idx]
  exp(ls[(off + 1L):(off + T0)])^2
}
lambda_of_tier <- function(par, tier_idx) {
  th <- par[names(par) == "theta_rr"]
  d <- lay$dim[tier_idx]
  len <- gllvmTMB:::.va_r3_theta_length(T0, d)
  off <- lay$theta_offset[tier_idx]
  gllvmTMB:::.va_r3_unpack_theta_rr(th[(off + 1L):(off + len)], T0, d)
}

fit_once <- function(start_id, tag) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB:::.va_r3_fit(
      y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
      q = q0, family = "gaussian", link = "identity", unique = TRUE,
      structured = phy$structured, extra_tiers = phy$extra_tiers,
      H = H0, n_starts = start_id, silent = TRUE))),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "va_err")) { cat("  [", tag, "] ERROR:", f$msg, "\n"); return(NULL) }
  par <- f$best$par
  ps2 <- psi_of_tier(par, 2L); ps4 <- psi_of_tier(par, 4L)
  Lp <- lambda_of_tier(par, 3L)
  cat(sprintf("\n[%s] status=%s  obj=%.4f  (%.1fs)\n", tag,
              f$status %||% "?", f$best$objective %||% NA_real_, el))
  cat(sprintf("  tier2 psi_hat (label 'psi')      : mean=%.4f  range=[%.4f, %.4f]\n",
              mean(ps2), min(ps2), max(ps2)))
  cat(sprintf("  tier4 psi_hat (label 'phylo_psi'): mean=%.4f  range=[%.4f, %.4f]\n",
              mean(ps4), min(ps4), max(ps4)))
  cat(sprintf("  SUM tier2+tier4 : mean=%.4f   (true psi1+psi2+gauss_sd^2 = %.4f)\n",
              mean(ps2 + ps4), mean(row_total_true)))
  cat(sprintf("  tier4 share of the row-level diagonal: %.1f%%\n",
              100 * mean(ps4) / mean(ps2 + ps4)))
  cat(sprintf("  VA tier-2 Sigma_hat diag mean = %.4f  (= LpLp' %.4f + psi4 %.4f)\n",
              mean(diag(Lp %*% t(Lp))) + mean(ps4), mean(diag(Lp %*% t(Lp))), mean(ps4)))
  list(par = par, psi2 = ps2, psi4 = ps4, obj = f$best$objective, Lp = Lp,
       status = f$status, elapsed = el)
}

cat(sprintf("### N=%d T=%d q=%d seed=%d, gaussian, H=%d\n", N0, T0, q0, seed0, H0))
cat(sprintf("### DGP row-level truth: psi1=%.4f psi2=%.4f gauss_sd^2=%.4f  sum=%.4f\n",
            mean(p1), mean(p2), gauss_sd0^2, mean(row_total_true)))
cat(sprintf("### tier 3 truth: diag(Lambda2 Lambda2') mean = %.4f\n",
            mean(diag(L2 %*% t(L2)))))

res <- list()
for (s in c(1L, 2L, 3L)) res[[as.character(s)]] <- fit_once(s, paste0("n_starts=", s))

saveRDS(list(res = res, truth = list(p1 = p1, p2 = p2, gsd2 = gauss_sd0^2,
                                     L1 = L1, L2 = L2), lay = lay, N = N0, T = T0),
        sprintf("dev/design108-recovery/pilot-results/noether-diag6-N%d-T%d-s%d.rds",
                N0, T0, seed0))
cat("\nDONE\n")
