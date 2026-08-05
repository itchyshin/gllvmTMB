## Laplace control (coordinator follow-up): paired against the ALREADY-RUN
## VA cells, same seeds, same DGP, all 3 families x n in {150,400}. Fit via
## the PUBLIC route (gllvmTMB()), scored on the SAME two statistics as VA
## (trace ratio, Procrustes-aligned latent-r) -- see attenuation-lib.R's
## run_seed_laplace() for the `unique` reasoning (NOT copied blindly from
## the VA arm's flag).
##
## Usage: Rscript dev/va-usability/40-laplace-control-grid.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== Laplace control grid start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
cat("== load_all done", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

source("dev/va-usability/attenuation-lib.R")

FAMILIES <- c("gaussian_anchor", "binomial", "poisson")
NS       <- c(150L, 400L)
N_CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))

run_cell <- function(family, N0) {
  seeds <- readRDS(sprintf("dev/va-usability/raw/.seeds_%s_n%d.rds", family, N0))
  cat(sprintf("\n-- LA cell family=%s N0=%d (%d paired seeds, %d cores) start %s --\n",
              family, N0, length(seeds), N_CORES, format(Sys.time(), "%H:%M:%S")))
  flush.console()
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) {
    tryCatch(run_seed_laplace(seed_id = s, family = family, N0 = N0),
             error = function(e) list(seed = s, family = family, N0 = N0,
                                       la_healthy = FALSE,
                                       status = paste0("harness_error: ", conditionMessage(e)),
                                       sigma_ratio = rep(NA_real_, T0),
                                       latent_cor_axis = rep(NA_real_, Q0),
                                       latent_cor_mean = NA_real_, cancor_mean = NA_real_))
  }, mc.cores = N_CORES, mc.preschedule = FALSE)
  cat(sprintf("   done in %.1fs\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  saveRDS(res, sprintf("dev/va-usability/raw/A2-laplace-%s_n%d.rds", family, N0))
  res
}

all_results <- list()
for (fam in FAMILIES) for (N0 in NS) {
  all_results[[sprintf("%s_n%d", fam, N0)]] <- run_cell(fam, N0)
}

## ---- paired report: LA vs VA, same seeds -----------------------------
per_seed_stats_la <- function(res, N0, family) {
  out <- data.frame(seed = numeric(0), trace_ratio = numeric(0),
                    latent_cor_mean = numeric(0), healthy = logical(0))
  for (r in res) {
    row <- data.frame(seed = r$seed, trace_ratio = NA_real_,
                      latent_cor_mean = r$latent_cor_mean %||% NA_real_,
                      healthy = isTRUE(r$la_healthy))
    if (isTRUE(r$la_healthy) && !any(is.na(r$sigma_ratio))) {
      b <- sim_cell(r$seed, family, N0)
      sigma_hat_jj <- r$sigma_ratio * b$sigma_jj_true
      row$trace_ratio <- sum(sigma_hat_jj) / sum(b$sigma_jj_true)
    }
    out <- rbind(out, row)
  }
  out
}
per_seed_stats_va <- function(res, N0, family) {
  out <- data.frame(seed = numeric(0), trace_ratio = numeric(0),
                    latent_cor_mean = numeric(0), healthy = logical(0))
  for (r in res) {
    row <- data.frame(seed = r$seed, trace_ratio = NA_real_,
                      latent_cor_mean = r$latent_cor_mean %||% NA_real_,
                      healthy = isTRUE(r$va_healthy))
    if (isTRUE(r$va_healthy) && !any(is.na(r$sigma_ratio))) {
      b <- sim_cell(r$seed, family, N0)
      sigma_hat_jj <- r$sigma_ratio * b$sigma_jj_true
      row$trace_ratio <- sum(sigma_hat_jj) / sum(b$sigma_jj_true)
    }
    out <- rbind(out, row)
  }
  out
}

cat("\n\n== PAIRED LA vs VA SUMMARY ==\n")
summary_rows <- list()
for (fam in FAMILIES) for (N0 in NS) {
  la_raw <- all_results[[sprintf("%s_n%d", fam, N0)]]
  va_raw <- readRDS(sprintf("dev/va-usability/raw/A2-%s_n%d.rds", fam, N0))
  la_s <- per_seed_stats_la(la_raw, N0, fam)
  va_s <- per_seed_stats_va(va_raw, N0, fam)
  m <- merge(va_s, la_s, by = "seed", suffixes = c("_va", "_la"))
  cat(sprintf("\nfamily=%-16s N0=%d  yield VA=%d/%d LA=%d/%d  paired n=%d\n",
              fam, N0, sum(va_s$healthy), nrow(va_s), sum(la_s$healthy), nrow(la_s), nrow(m)))
  cat(sprintf("  trace ratio  VA: mean=%.3f median=%.3f sd=%.3f\n",
              mean(m$trace_ratio_va, na.rm=TRUE), stats::median(m$trace_ratio_va, na.rm=TRUE), stats::sd(m$trace_ratio_va, na.rm=TRUE)))
  cat(sprintf("  trace ratio  LA: mean=%.3f median=%.3f sd=%.3f\n",
              mean(m$trace_ratio_la, na.rm=TRUE), stats::median(m$trace_ratio_la, na.rm=TRUE), stats::sd(m$trace_ratio_la, na.rm=TRUE)))
  cat(sprintf("  latent-r     VA: mean=%.3f sd=%.3f\n", mean(m$latent_cor_mean_va, na.rm=TRUE), stats::sd(m$latent_cor_mean_va, na.rm=TRUE)))
  cat(sprintf("  latent-r     LA: mean=%.3f sd=%.3f\n", mean(m$latent_cor_mean_la, na.rm=TRUE), stats::sd(m$latent_cor_mean_la, na.rm=TRUE)))
  d_lc <- m$latent_cor_mean_la - m$latent_cor_mean_va
  cat(sprintf("  paired diff (LA-VA) latent-r: mean=%.3f median=%.3f sd=%.3f [n=%d]\n",
              mean(d_lc, na.rm=TRUE), stats::median(d_lc, na.rm=TRUE), stats::sd(d_lc, na.rm=TRUE), sum(!is.na(d_lc))))
  summary_rows[[length(summary_rows)+1]] <- data.frame(
    family = fam, N0 = N0,
    va_trace_mean = mean(m$trace_ratio_va, na.rm=TRUE), la_trace_mean = mean(m$trace_ratio_la, na.rm=TRUE),
    va_latent_r = mean(m$latent_cor_mean_va, na.rm=TRUE), la_latent_r = mean(m$latent_cor_mean_la, na.rm=TRUE),
    diff_latent_r = mean(d_lc, na.rm=TRUE), n_paired = nrow(m)
  )
}
summary_df <- do.call(rbind, summary_rows)
write.csv(summary_df, "dev/va-usability/A2-laplace-control-summary.csv", row.names = FALSE)
cat("\n"); print(summary_df, digits = 3)

cat(sprintf("\n== Laplace control grid done %s ==\n", format(Sys.time(), "%H:%M:%S")))
