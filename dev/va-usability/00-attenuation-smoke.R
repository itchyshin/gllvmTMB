## Slice A2 smoke test -- ONE seed, ONE cell (n=150) per admitted family,
## before any grid is launched. Confirms:
##   - the fit is healthy (multi-start gate admits it)
##   - va_fit$report$Sigma_B is a finite T x T matrix (Lambda recovery target)
##   - va_fit$latent$scores is a finite N x q matrix (latent-score target)
##   - the derived attenuation ratio and latent-score correlation are finite
##     and in a plausible range
##
## Per CLAUDE.md/task discipline: STOP and report if this is not clean --
## do not proceed to 10-attenuation-grid.R.
##
## Usage: Rscript dev/va-usability/00-attenuation-smoke.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== A2 smoke start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())
cat("== VA-R3 DLL warm-loaded", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

source("dev/va-usability/attenuation-lib.R")

for (fam in c("gaussian_anchor", "binomial", "poisson")) {
  cat(sprintf("\n---- family = %s, N0 = 150, seed = 20260900 ----\n", fam))
  t0 <- Sys.time()
  r <- run_seed(seed_id = 20260900L, family = fam, N0 = 150L)
  cat(sprintf("elapsed: %.2fs\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat("status:", r$status, " va_healthy:", r$va_healthy, "\n")
  cat("sigma_ratio (Sigma_hat_jj / Sigma_true_jj):\n")
  print(r$sigma_ratio)
  cat("latent_cor_axis (Procrustes-aligned):", r$latent_cor_axis, "\n")
  cat("latent_cor_mean:", r$latent_cor_mean, "  cancor_mean:", r$cancor_mean, "\n")

  ## ---- sanity gates: STOP if any of these fail ----------------------------
  ok <- TRUE
  if (!isTRUE(r$va_healthy)) { cat("SMOKE FAIL: fit not healthy\n"); ok <- FALSE }
  if (any(is.na(r$sigma_ratio))) { cat("SMOKE FAIL: sigma_ratio has NA\n"); ok <- FALSE }
  if (any(!is.finite(r$sigma_ratio))) { cat("SMOKE FAIL: sigma_ratio non-finite\n"); ok <- FALSE }
  if (any(r$sigma_ratio <= 0)) { cat("SMOKE FAIL: sigma_ratio <= 0\n"); ok <- FALSE }
  if (any(r$sigma_ratio > 10 | r$sigma_ratio < 0.05)) {
    cat("SMOKE WARN: sigma_ratio outside [0.05, 10] -- inspect\n")
  }
  if (is.na(r$latent_cor_mean) || !is.finite(r$latent_cor_mean)) {
    cat("SMOKE FAIL: latent_cor_mean NA/non-finite\n"); ok <- FALSE
  }
  if (!is.na(r$latent_cor_mean) && (r$latent_cor_mean < -1.001 || r$latent_cor_mean > 1.001)) {
    cat("SMOKE FAIL: latent_cor_mean outside [-1,1]\n"); ok <- FALSE
  }
  cat(if (ok) "SMOKE: PASS (structurally sane)\n" else "SMOKE: FAIL -- STOP, do not launch grid\n")
}

cat(sprintf("\n== A2 smoke done %s ==\n", format(Sys.time(), "%H:%M:%S")))
