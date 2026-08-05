setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

cat("== n=400 smoke, one seed per family ==\n")
for (fam in c("gaussian_anchor", "binomial", "poisson")) {
  t0 <- Sys.time()
  r <- run_seed(seed_id = 20260900L, family = fam, N0 = 400L)
  cat(sprintf("family=%-16s elapsed=%.2fs status=%s healthy=%s latent_cor_mean=%.3f\n",
              fam, as.numeric(difftime(Sys.time(), t0, units="secs")),
              r$status, r$va_healthy, r$latent_cor_mean))
  cat("  sigma_ratio:", round(r$sigma_ratio, 3), "\n")
}

cat("\n== binomial n=150, 6 more seeds -- probe the large-ratio trait ==\n")
for (s in 1:6) {
  r <- run_seed(seed_id = 20260900L + s, family = "binomial", N0 = 150L)
  b <- sim_cell(20260900L + s, "binomial", 150L)
  cat(sprintf("seed=%d status=%s healthy=%s latent_cor_mean=%.3f max_abs_grad=%.3g\n",
              s, r$status, r$va_healthy, r$latent_cor_mean,
              NA_real_))
  cat("  sigma_true_jj:", round(b$sigma_jj_true, 3), "\n")
  cat("  sigma_ratio  :", round(r$sigma_ratio, 3), "\n")
}
