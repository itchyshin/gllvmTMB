## Noether diagnostic 7 (VA double-diagonal, STEP 3): the campaign's actual
## configuration. `.d108_fit_va()` fits binomial_probit (harness.R:270), where
## `log_sigma` is mapped OFF (R/va-r3-proto.R:1816-1833, "log_sigma free only on
## Gaussian traits") -- so the row-level variance has nowhere to go EXCEPT the
## two byte-identical diagonal tiers 2 and 4. That is the configuration the
## confound question is about. The gaussian arm is run too, for contrast: there
## a free per-trait `log_sigma` competes with both tiers.
##
## Full precision throughout; no rounding to 4 dp (the previous run's "0.0000"
## hid whether a tier collapsed or merely got small).
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0    <- as.integer(Sys.getenv("D108_N", "100"))
T0    <- as.integer(Sys.getenv("D108_T", "10"))
seed0 <- as.integer(Sys.getenv("D108_SEED", "1"))
q0 <- 1L; gauss_sd0 <- 0.4; H0 <- 15L
FAMS <- strsplit(Sys.getenv("D108_FAMS", "binomial_probit,gaussian"), ",")[[1]]

sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                         n_trials = 6L)
p1 <- sim$truth$tier1$psi; p2 <- sim$truth$tier2$psi
L1 <- sim$truth$tier1$Lambda; L2 <- sim$truth$tier2$Lambda

unit <- sim$data$unit; trait <- sim$data$trait
X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, unit, T0, q0)

run_family <- function(fam) {
  dat <- sim$data
  if (identical(fam, "gaussian")) {
    set.seed(seed0 + 900000L)
    dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gauss_sd0)
    link <- "identity"
    row_true <- p1 + p2 + gauss_sd0^2
    row_lab <- "psi1 + psi2 + gauss_sd^2"
  } else {
    link <- "probit"
    row_true <- p1 + p2
    row_lab <- "psi1 + psi2"
  }
  v <- gllvmTMB:::.va_r3_validate_data(
    y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q0, family = fam, link = link, unique = TRUE,
    structured = phy$structured, extra_tiers = phy$extra_tiers)
  lay <- v$tier_layout
  psi_of <- function(par, k) {
    ls <- par[names(par) == "log_sd_tier"]
    off <- lay$sd_offset[k]
    exp(ls[(off + 1L):(off + T0)])^2
  }
  lam_of <- function(par, k) {
    th <- par[names(par) == "theta_rr"]; d <- lay$dim[k]
    len <- gllvmTMB:::.va_r3_theta_length(T0, d); off <- lay$theta_offset[k]
    gllvmTMB:::.va_r3_unpack_theta_rr(th[(off + 1L):(off + len)], T0, d)
  }
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB:::.va_r3_fit(
        y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
        q = q0, family = fam, link = link, unique = TRUE,
        structured = phy$structured, extra_tiers = phy$extra_tiers,
        H = H0, n_starts = 1L, silent = TRUE))),
      error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  el <- proc.time()[["elapsed"]] - t0
  cat(sprintf("\n================ family = %s  (%.1fs) ================\n", fam, el))
  if (inherits(f, "va_err")) { cat("ERROR:", f$msg, "\n"); return(NULL) }
  par <- f$best$par
  ps2 <- psi_of(par, 2L); ps4 <- psi_of(par, 4L); Lp <- lam_of(par, 3L)
  cat(sprintf("status = %s   objective = %.6f   admitted = %s\n",
              f$status %||% "?", f$best$objective %||% NA_real_,
              isTRUE(f$health$admitted)))
  cat(sprintf("\ntruth: %s -> mean %.6f   (psi1 %.4f, psi2 %.4f)\n",
              row_lab, mean(row_true), mean(p1), mean(p2)))
  cat("\ntier 2 'psi'        psi_hat (per trait):\n"); print(signif(ps2, 4))
  cat("tier 4 'phylo_psi'  psi_hat (per trait):\n"); print(signif(ps4, 4))
  cat(sprintf("\n  tier2 mean = %.6e     tier4 mean = %.6e\n", mean(ps2), mean(ps4)))
  cat(sprintf("  SUM  mean  = %.6f      vs truth %.6f\n", mean(ps2 + ps4), mean(row_true)))
  cat(sprintf("  tier4 share of the row-level diagonal = %.2f%%\n",
              100 * mean(ps4) / mean(ps2 + ps4)))
  if (identical(fam, "gaussian")) {
    lsig <- par[names(par) == "log_sigma"]
    if (length(lsig)) cat(sprintf("  free log_sigma^2 (per-trait gaussian residual) mean = %.6f\n",
                                  mean(exp(lsig)^2)))
  }
  cat(sprintf("\n  VA tier-2 Sigma_hat = Lp Lp' + diag(psi4):  diag mean = %.6f\n",
              mean(diag(Lp %*% t(Lp)) + ps4)))
  cat(sprintf("     of which  Lp Lp' = %.6f   and  psi4 = %.6f\n",
              mean(diag(Lp %*% t(Lp))), mean(ps4)))
  cat(sprintf("  truth tier-2: Lambda2 Lambda2' diag mean = %.6f, psi2 mean = %.6f\n",
              mean(diag(L2 %*% t(L2))), mean(p2)))
  list(par = par, psi2 = ps2, psi4 = ps4, Lp = Lp, obj = f$best$objective,
       status = f$status, lay = lay, elapsed = el)
}

cat(sprintf("### N=%d T=%d q=%d seed=%d H=%d n_trials=6\n", N0, T0, q0, seed0, H0))
out <- list()
for (fam in FAMS) out[[fam]] <- run_family(fam)
saveRDS(out, sprintf("dev/design108-recovery/pilot-results/noether-diag7-N%d-T%d-s%d.rds",
                     N0, T0, seed0))
cat("\nDONE\n")
