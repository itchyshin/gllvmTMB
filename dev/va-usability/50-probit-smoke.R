## AC / binomial_probit probe -- smoke test, mandatory discipline before
## any grid. A DIFFERENT cell from the logit comparison: response generated
## under pnorm(eta) (probit), fit with family = "binomial_probit",
## link = "probit". Both tiers (gh, ac) checked at n=150, 1 seed each.
##
## binomial_probit is NOT on the public integration fence
## (R/integration-fence.R) -- reached here via direct `.va_r3_fit()` calls
## (the research-only prototype engine), which is how this measurement
## generates evidence a future fence decision would need, without making
## the family user-reachable.
##
## Usage: Rscript dev/va-usability/50-probit-smoke.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

## Verify (not assume) both tiers are legal for family_code 4 (binomial_probit).
cat("resolve_eval_method(\"gh\", family_code=4L):", gllvmTMB:::.va_r3_resolve_eval_method("gh", 4L), "\n")
cat("resolve_eval_method(\"ac\", family_code=4L):", gllvmTMB:::.va_r3_resolve_eval_method("ac", 4L), "\n")
cat("resolve_eval_method(\"auto\", family_code=4L):", gllvmTMB:::.va_r3_resolve_eval_method("auto", 4L), "\n")

for (em in c("gh", "ac")) {
  cat(sprintf("\n---- binomial_probit eval_method=%s N0=150 seed=20260900 ----\n", em))
  t0 <- Sys.time()
  r <- run_seed(20260900L, "binomial_probit", 150L, eval_method = em)
  cat(sprintf("elapsed=%.2fs status=%s healthy=%s\n",
              as.numeric(difftime(Sys.time(), t0, units = "secs")), r$status, r$va_healthy))
  cat("sigma_ratio:", round(r$sigma_ratio, 3), "\n")
  cat("latent_cor_mean:", r$latent_cor_mean, " cancor_mean:", r$cancor_mean, "\n")

  ok <- TRUE
  if (!isTRUE(r$va_healthy)) { cat("SMOKE FAIL: not healthy\n"); ok <- FALSE }
  if (any(is.na(r$sigma_ratio)) || any(!is.finite(r$sigma_ratio)) || any(r$sigma_ratio <= 0)) {
    cat("SMOKE FAIL: sigma_ratio NA/non-finite/non-positive\n"); ok <- FALSE
  }
  if (is.na(r$latent_cor_mean) || !is.finite(r$latent_cor_mean) || abs(r$latent_cor_mean) > 1.001) {
    cat("SMOKE FAIL: latent_cor_mean bad\n"); ok <- FALSE
  }
  cat(if (ok) "SMOKE: PASS\n" else "SMOKE: FAIL -- STOP\n")
}
