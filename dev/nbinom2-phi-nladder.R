# nbinom2 phi/psi recovery n-ladder — the info-vs-limit test the May audits left open.
# Question: as n grows, does the estimated-phi bias (and the psi/Sigma under-estimate it
# drives) SHRINK toward 0 (information/power problem -> coverage recovers at large n) or
# PERSIST (genuine dispersion/latent identifiability limit)? Reads the SIGN + TREND per the
# 2026-07-13 "direction of the n-effect" principle. Point estimates only (no bootstrap).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("dev/m3-grid.R")

fit_one <- function(family, d, n_units, seed, lambda_scale = 0.5773503) {
  tr <- m3_sample_truth(family = family, d = d, n_traits = 5L, n_units = n_units,
                        seed = seed, lambda_scale = lambda_scale)
  sim <- m3_simulate_response(tr)
  fam_list <- gllvmTMB::nbinom2()  # uniform nbinom2 (single object; a list => mixed-family mode)
  fit <- tryCatch(withCallingHandlers(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = d) + unique(0 + trait | unit),
      data = sim$data, family = fam_list, unit = "unit"),
    warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) e)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi") ||
      !identical(fit$opt$convergence, 0L)) return(NULL)
  est_diag <- diag(gllvmTMB::extract_Sigma(fit, level = "unit", link_residual = "none")$Sigma)
  est_psi  <- as.numeric(fit$report$sd_B)^2
  est_phi  <- as.numeric(fit$report$phi_nbinom2)
  data.frame(
    n = n_units, seed = seed,
    phi_ratio   = mean(est_phi / tr$nuisance$phi, na.rm = TRUE),
    psi_ratio   = mean(est_psi / tr$psi, na.rm = TRUE),
    sigma_ratio = mean(est_diag / tr$diag_Sigma, na.rm = TRUE))
}

ns <- c(50L, 150L, 400L, 800L, 1500L)
seeds <- 1:8
rows <- list()
for (n in ns) for (s in seeds) {
  r <- tryCatch(fit_one("nbinom2", 1L, n, s), error = function(e) NULL)
  if (!is.null(r)) rows[[length(rows) + 1L]] <- r
  cat(sprintf("n=%4d seed=%d %s\n", n, s, if (is.null(r)) "FAIL" else sprintf(
    "phi/tru=%.2f psi/tru=%.2f Sig/tru=%.2f", r$phi_ratio, r$psi_ratio, r$sigma_ratio)))
}
d <- do.call(rbind, rows)
cat("\n=== nbinom2 recovery vs n (mean ratio to truth; 1.0 = unbiased) ===\n")
agg <- aggregate(cbind(phi_ratio, psi_ratio, sigma_ratio) ~ n, d, mean)
agg$n_ok <- as.integer(table(factor(d$n, levels = ns)))
print(agg, digits = 3, row.names = FALSE)
saveRDS(d, "dev/nbinom2-phi-nladder-results.rds")
cat("\nREAD THE TREND: ratios -> 1.0 with n = information/power (recovers at big n).",
    "\nStuck below 1.0 = genuine dispersion/latent identifiability LIMIT.\n")
