## Noether diagnostic 10 (VA double-diagonal, STEP 6): does the HARNESS's own
## machinery ever land on the tier-4 corner?
##
## diag8 showed the two corners are exactly equal in objective, and reached the
## tier-4 corner from a deliberately mirrored start. That is a latent landmine
## only if `.va_r3_fit()`'s own starts can reach it. `run_cell()` defaults to
## n_starts = 4L (harness.R:457); the jitter table perturbs log_sd_tier
## (R/va-r3-proto.R:1106-1107). Run the harness's own configuration across
## several seeds and record which corner each lands on, plus `admitted`.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- as.integer(Sys.getenv("D108_N", "100"))
T0 <- as.integer(Sys.getenv("D108_T", "10"))
SEEDS <- as.integer(strsplit(Sys.getenv("D108_SEEDS", "1,2,3"), ",")[[1]])
NSTARTS <- as.integer(Sys.getenv("D108_NSTARTS", "4"))
q0 <- 1L; H0 <- 15L

rows <- list()
for (seed0 in SEEDS) {
  sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0, phylo_scale = 1,
                           n_trials = 6L)
  dat <- sim$data
  unit <- dat$unit; trait <- dat$trait
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
  phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, unit, T0, q0)
  v <- gllvmTMB:::.va_r3_validate_data(
    y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
    structured = phy$structured, extra_tiers = phy$extra_tiers)
  lay <- v$tier_layout
  psi_of <- function(par, k) {
    ls <- par[names(par) == "log_sd_tier"]; off <- lay$sd_offset[k]
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
        q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
        structured = phy$structured, extra_tiers = phy$extra_tiers,
        H = H0, n_starts = NSTARTS, silent = TRUE))),
      error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "va_err")) { cat(sprintf("seed %d ERROR: %s\n", seed0, f$msg)); next }
  par <- f$best$par
  ps2 <- mean(psi_of(par, 2L)); ps4 <- mean(psi_of(par, 4L)); Lp <- lam_of(par, 3L)
  L2t <- sim$truth$tier2$Lambda; p2t <- sim$truth$tier2$psi
  share <- 100 * ps4 / (ps2 + ps4)
  cat(sprintf("seed %d | n_starts=%d admitted=%-5s healthy=%s | obj=%.4f | psi2=%.4e psi4=%.4e SUM=%.4f | tier4 share=%6.2f%% | (%.0fs)\n",
              seed0, NSTARTS, isTRUE(f$health$admitted),
              f$health$healthy_starts %||% NA, f$best$objective, ps2, ps4, ps2 + ps4,
              share, el))
  cat(sprintf("        VA tier-2 Sigma_hat diag mean = %.4f (LpLp' %.4f + psi4 %.4f) ; truth L2L2' %.4f + psi2 %.4f\n",
              mean(diag(Lp %*% t(Lp))) + ps4, mean(diag(Lp %*% t(Lp))), ps4,
              mean(diag(L2t %*% t(L2t))), mean(p2t)))
  rows[[length(rows) + 1L]] <- data.frame(
    seed = seed0, n_starts = NSTARTS, admitted = isTRUE(f$health$admitted),
    obj = f$best$objective, psi2 = ps2, psi4 = ps4, share4 = share,
    LpLp = mean(diag(Lp %*% t(Lp))), elapsed = el)
}
if (length(rows)) {
  res <- do.call(rbind, rows)
  print(res, row.names = FALSE)
  saveRDS(res, sprintf("dev/design108-recovery/pilot-results/noether-diag10-N%d-T%d-ns%d.rds",
                       N0, T0, NSTARTS))
}
cat("\nDONE\n")
