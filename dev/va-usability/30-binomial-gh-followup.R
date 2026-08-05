## Follow-up to A2: is binomial's attenuation the JJ BOUND's fault, or the
## family's? Re-fit the EXACT SAME 50+50 seeds as the original binomial
## cells (dev/va-usability/raw/A2-binomial_n150.rds / _n400.rds), forcing
## eval_method = "gh" (exact Gauss-Hermite quadrature) instead of the
## default "auto" -> "jj" (Jaakkola-Jordan/Polya-Gamma bound). Paired by
## seed against the already-computed JJ results -- everything else
## (DGP, health gate, trace-ratio/Procrustes-correlation statistics)
## identical, per dev/va-usability/attenuation-lib.R.
##
## Verified before running (not assumed): gllvmTMB:::.va_r3_resolve_eval_method("gh", 1L)
## returns "gh" -- binomial's registry entry lists tiers = c("gh","jj").
##
## Usage: Rscript dev/va-usability/30-binomial-gh-followup.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== A2 binomial GH follow-up start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
cat("== VA-R3 DLL warm-loaded", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

source("dev/va-usability/attenuation-lib.R")

N_CORES <- min(50L, as.integer(Sys.getenv("PILOT_CORES", "8")))

run_gh_cell <- function(N0) {
  seeds <- readRDS(sprintf("dev/va-usability/raw/.seeds_binomial_n%d.rds", N0))
  cat(sprintf("\n-- GH cell binomial N0=%d (%d paired seeds, %d cores) start %s --\n",
              N0, length(seeds), N_CORES, format(Sys.time(), "%H:%M:%S")))
  flush.console()
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) {
    tryCatch(run_seed(seed_id = s, family = "binomial", N0 = N0, eval_method = "gh"),
             error = function(e) list(seed = s, family = "binomial", N0 = N0,
                                       va_healthy = FALSE,
                                       status = paste0("harness_error: ", conditionMessage(e)),
                                       sigma_ratio = rep(NA_real_, T0),
                                       latent_cor_axis = rep(NA_real_, Q0),
                                       latent_cor_mean = NA_real_, cancor_mean = NA_real_))
  }, mc.cores = N_CORES, mc.preschedule = FALSE)
  cat(sprintf("   done in %.1fs\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  saveRDS(res, sprintf("dev/va-usability/raw/A2-binomial_n%d_gh.rds", N0))
  res
}

gh150 <- run_gh_cell(150L)
gh400 <- run_gh_cell(400L)

## ---- per-seed trace ratio + latent cor, for BOTH jj (already saved) and gh
per_seed_stats <- function(res, N0) {
  out <- data.frame(seed = integer(0), trace_ratio = numeric(0),
                    latent_cor_mean = numeric(0), fit_s = numeric(0),
                    healthy = logical(0))
  for (r in res) {
    row <- data.frame(seed = r$seed, trace_ratio = NA_real_,
                      latent_cor_mean = r$latent_cor_mean %||% NA_real_,
                      fit_s = r$fit_s %||% NA_real_,
                      healthy = isTRUE(r$va_healthy))
    if (isTRUE(r$va_healthy) && !any(is.na(r$sigma_ratio))) {
      b <- sim_cell(r$seed, "binomial", N0)
      sigma_hat_jj <- r$sigma_ratio * b$sigma_jj_true
      row$trace_ratio <- sum(sigma_hat_jj) / sum(b$sigma_jj_true)
    }
    out <- rbind(out, row)
  }
  out
}

jj150 <- per_seed_stats(readRDS("dev/va-usability/raw/A2-binomial_n150.rds"), 150L)
jj400 <- per_seed_stats(readRDS("dev/va-usability/raw/A2-binomial_n400.rds"), 400L)
gh150_s <- per_seed_stats(gh150, 150L)
gh400_s <- per_seed_stats(gh400, 400L)

pair_report <- function(jj, gh, N0) {
  m <- merge(jj, gh, by = "seed", suffixes = c("_jj", "_gh"))
  cat(sprintf("\n== N0=%d: paired n=%d (of %d/%d healthy jj/gh) ==\n",
              N0, nrow(m), sum(jj$healthy), sum(gh$healthy)))
  d_tr <- m$trace_ratio_gh - m$trace_ratio_jj
  d_lc <- m$latent_cor_mean_gh - m$latent_cor_mean_jj
  cat(sprintf("trace ratio   JJ: mean=%.3f median=%.3f sd=%.3f\n",
              mean(m$trace_ratio_jj, na.rm=TRUE), stats::median(m$trace_ratio_jj, na.rm=TRUE), stats::sd(m$trace_ratio_jj, na.rm=TRUE)))
  cat(sprintf("trace ratio   GH: mean=%.3f median=%.3f sd=%.3f\n",
              mean(m$trace_ratio_gh, na.rm=TRUE), stats::median(m$trace_ratio_gh, na.rm=TRUE), stats::sd(m$trace_ratio_gh, na.rm=TRUE)))
  cat(sprintf("paired diff (GH-JJ) trace ratio: mean=%.3f median=%.3f sd=%.3f  [n=%d pairs]\n",
              mean(d_tr, na.rm=TRUE), stats::median(d_tr, na.rm=TRUE), stats::sd(d_tr, na.rm=TRUE), sum(!is.na(d_tr))))
  cat(sprintf("latent-r      JJ: mean=%.3f sd=%.3f\n", mean(m$latent_cor_mean_jj, na.rm=TRUE), stats::sd(m$latent_cor_mean_jj, na.rm=TRUE)))
  cat(sprintf("latent-r      GH: mean=%.3f sd=%.3f\n", mean(m$latent_cor_mean_gh, na.rm=TRUE), stats::sd(m$latent_cor_mean_gh, na.rm=TRUE)))
  cat(sprintf("paired diff (GH-JJ) latent-r:    mean=%.3f median=%.3f sd=%.3f\n",
              mean(d_lc, na.rm=TRUE), stats::median(d_lc, na.rm=TRUE), stats::sd(d_lc, na.rm=TRUE)))
  cat(sprintf("fit_s median  JJ=%.2fs  GH=%.2fs  cost ratio GH/JJ=%.2fx\n",
              stats::median(m$fit_s_jj, na.rm=TRUE), stats::median(m$fit_s_gh, na.rm=TRUE),
              stats::median(m$fit_s_gh, na.rm=TRUE) / stats::median(m$fit_s_jj, na.rm=TRUE)))
  invisible(m)
}

m150 <- pair_report(jj150, gh150_s, 150L)
m400 <- pair_report(jj400, gh400_s, 400L)

cat(sprintf("\n== A2 binomial GH follow-up done %s ==\n", format(Sys.time(), "%H:%M:%S")))
