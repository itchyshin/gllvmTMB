# nbinom2 mitigation ladder — does a KNOWN fix rescue Sigma_unit_diag recovery?
# 3 arms x n-ladder, per the 2026-05 audits' proposed mitigations:
#   default   : plain fit (my earlier n-ladder baseline; ~0.5 flat)
#   warmstart : single_trait_warmup inits (Mitigation A; gllvm start.fit pattern)
#   knownphi  : fix phi at the true DGP value (proxy for shared-dispersion/Mit-C ceiling)
# Reads whether Sigma/truth -> 1 under any arm as n grows. Point estimates only.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("dev/m3-grid.R")

fit_arm <- function(tr, sim, arm) {
  ctrl <- if (arm == "warmstart")
    gllvmTMB::gllvmTMBcontrol(init_strategy = "single_trait_warmup") else
    gllvmTMB::gllvmTMBcontrol()
  fit <- tryCatch(withCallingHandlers(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit),
      data = sim$data, family = gllvmTMB::nbinom2(), unit = "unit", control = ctrl),
    warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) e)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi") ||
      !identical(fit$opt$convergence, 0L)) return(NULL)
  if (arm == "knownphi") {
    fit <- tryCatch(m3_refit_known_nbinom2_phi(fit, phi = tr$nuisance$phi),
                    error = function(e) NULL)
    if (is.null(fit) || !inherits(fit, "gllvmTMB_multi")) return(NULL)
  }
  ed <- diag(gllvmTMB::extract_Sigma(fit, level = "unit", link_residual = "none")$Sigma)
  mean(ed / tr$diag_Sigma, na.rm = TRUE)
}

ns <- c(150L, 400L, 800L)
arms <- c("default", "warmstart", "knownphi")
seeds <- 1:8
rows <- list()
for (n in ns) for (s in seeds) {
  tr <- m3_sample_truth("nbinom2", 1L, 5L, n, seed = s, lambda_scale = 0.5773503)
  sim <- m3_simulate_response(tr)
  r <- list(n = n, seed = s)
  for (a in arms) r[[a]] <- tryCatch(fit_arm(tr, sim, a), error = function(e) NA_real_) %||% NA_real_
  rows[[length(rows) + 1L]] <- as.data.frame(r)
  cat(sprintf("n=%4d s=%d  default=%.2f  warmstart=%.2f  knownphi=%.2f\n",
    n, s, r$default %||% NA, r$warmstart %||% NA, r$knownphi %||% NA))
}
d <- do.call(rbind, rows)
saveRDS(d, "dev/nbinom2-mitigation-ladder-results.rds")
cat("\n=== median Sigma/truth by n x arm (1.0 = unbiased) ===\n")
for (n in ns) { s <- d[d$n == n, ]; cat(sprintf(
  "n=%4d  default=%.2f  warmstart=%.2f  knownphi=%.2f\n", n,
  median(s$default, na.rm = TRUE), median(s$warmstart, na.rm = TRUE),
  median(s$knownphi, na.rm = TRUE))) }
cat("\nIf knownphi -> ~1.0 and default/warmstart stay ~0.5: phi estimation IS the problem,",
    "\nand shared-dispersion (disp_group, unbuilt) is the indicated fix.\n")
