## Slice A2 -- full grid: Lambda/latent-score attenuation at the fenced cells.
## families in {gaussian_anchor, binomial, poisson} x n in {150, 400}, q=2,
## p=8 (T0 in the shared lib), 50 seeds/cell. See dev/va-usability/A2-ATTENUATION.md
## for the write-up and dev/va-usability/attenuation-lib.R for the DGP/fit/metric code.
##
## Smoke-tested first (00-attenuation-smoke.R, 01-...-n400-and-binom-probe.R):
## all 3 families healthy at n=150 AND n=400; the occasional large per-trait
## ratio was traced to near-zero true Sigma_jj (division instability, not a
## fit failure) -- handled below via a trace ratio (sum/sum) alongside the
## per-trait median/IQR.
##
## Usage: Rscript dev/va-usability/10-attenuation-grid.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== A2 grid start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
cat("== VA-R3 DLL warm-loaded", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

source("dev/va-usability/attenuation-lib.R")

FAMILIES <- c("gaussian_anchor", "binomial", "poisson")
NS       <- c(150L, 400L)
N_SEEDS  <- 50L
N_CORES  <- min(N_SEEDS, as.integer(Sys.getenv("PILOT_CORES", "8")))

dir.create("dev/va-usability/raw", showWarnings = FALSE, recursive = TRUE)

run_cell <- function(family, N0, fam_idx, n_idx) {
  cat(sprintf("\n-- cell family=%s N0=%d (%d seeds, %d cores) start %s --\n",
              family, N0, N_SEEDS, N_CORES, format(Sys.time(), "%H:%M:%S")))
  flush.console()
  ## Disjoint seed streams per cell: base + family block + n block + seed idx.
  base_seed <- 20261100L + fam_idx * 10000L + n_idx * 1000L
  seed_ids <- base_seed + seq_len(N_SEEDS)
  t0 <- Sys.time()
  res <- mclapply(seed_ids, function(s) {
    tryCatch(run_seed(seed_id = s, family = family, N0 = N0),
             error = function(e) list(seed = s, family = family, N0 = N0,
                                       va_healthy = FALSE,
                                       status = paste0("harness_error: ", conditionMessage(e)),
                                       sigma_ratio = rep(NA_real_, T0),
                                       latent_cor_axis = rep(NA_real_, Q0),
                                       latent_cor_mean = NA_real_, cancor_mean = NA_real_))
  }, mc.cores = N_CORES, mc.preschedule = FALSE)
  cell_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("   done in %.1fs (%.2fs/seed averaged over %d cores)\n",
              cell_s, cell_s, N_CORES))
  tag <- sprintf("%s_n%d", family, N0)
  saveRDS(res, sprintf("dev/va-usability/raw/A2-%s.rds", tag))
  res
}

all_results <- list()
cell_id <- 0L
for (fam_idx in seq_along(FAMILIES)) {
  for (n_idx in seq_along(NS)) {
    cell_id <- cell_id + 1L
    fam <- FAMILIES[fam_idx]; N0 <- NS[n_idx]
    all_results[[sprintf("%s_n%d", fam, N0)]] <- run_cell(fam, N0, fam_idx, n_idx)
  }
}

## ---- aggregate ------------------------------------------------------------
summarise_cell <- function(res, family, N0) {
  ok <- function(r) is.null(r$error) || is.na(r$error %||% NA)
  `%||%` <- function(a, b) if (is.null(a)) b else a
  healthy <- vapply(res, function(r) isTRUE(r$va_healthy), logical(1))
  n_attempted <- length(res)
  n_healthy <- sum(healthy)

  ## per-seed trace ratio: sum(Sigma_hat_jj) / sum(Sigma_true_jj). Needs the
  ## true diag too, so recompute per seed from the same DGP (cheap; avoids
  ## threading sigma_jj_true through run_seed's return just for this).
  trace_ratio <- rep(NA_real_, n_attempted)
  per_trait_ratio <- vector("list", n_attempted)
  for (i in seq_along(res)) {
    r <- res[[i]]
    if (!isTRUE(r$va_healthy) || any(is.na(r$sigma_ratio))) next
    b <- sim_cell(r$seed, family, N0)
    sigma_hat_jj <- r$sigma_ratio * b$sigma_jj_true
    trace_ratio[i] <- sum(sigma_hat_jj) / sum(b$sigma_jj_true)
    per_trait_ratio[[i]] <- r$sigma_ratio
  }
  latent_cor <- vapply(res, function(r) r$latent_cor_mean %||% NA_real_, numeric(1))
  cancor_m   <- vapply(res, function(r) r$cancor_mean %||% NA_real_, numeric(1))
  pooled_trait_ratio <- unlist(per_trait_ratio)

  list(
    family = family, N0 = N0,
    n_attempted = n_attempted, n_healthy = n_healthy,
    yield = n_healthy / n_attempted,
    trace_ratio_mean = mean(trace_ratio, na.rm = TRUE),
    trace_ratio_median = stats::median(trace_ratio, na.rm = TRUE),
    trace_ratio_sd = stats::sd(trace_ratio, na.rm = TRUE),
    trace_ratio_q25 = stats::quantile(trace_ratio, 0.25, na.rm = TRUE, names = FALSE),
    trace_ratio_q75 = stats::quantile(trace_ratio, 0.75, na.rm = TRUE, names = FALSE),
    trace_ratio_min = suppressWarnings(min(trace_ratio, na.rm = TRUE)),
    trace_ratio_max = suppressWarnings(max(trace_ratio, na.rm = TRUE)),
    per_trait_ratio_median = stats::median(pooled_trait_ratio, na.rm = TRUE),
    per_trait_ratio_q25 = stats::quantile(pooled_trait_ratio, 0.25, na.rm = TRUE, names = FALSE),
    per_trait_ratio_q75 = stats::quantile(pooled_trait_ratio, 0.75, na.rm = TRUE, names = FALSE),
    latent_cor_mean = mean(latent_cor, na.rm = TRUE),
    latent_cor_median = stats::median(latent_cor, na.rm = TRUE),
    latent_cor_sd = stats::sd(latent_cor, na.rm = TRUE),
    cancor_mean = mean(cancor_m, na.rm = TRUE)
  )
}

summary_rows <- list()
for (fam_idx in seq_along(FAMILIES)) {
  for (n_idx in seq_along(NS)) {
    fam <- FAMILIES[fam_idx]; N0 <- NS[n_idx]
    key <- sprintf("%s_n%d", fam, N0)
    summary_rows[[key]] <- summarise_cell(all_results[[key]], fam, N0)
  }
}
summary_df <- do.call(rbind, lapply(summary_rows, as.data.frame))
rownames(summary_df) <- NULL

write.csv(summary_df, "dev/va-usability/A2-summary.csv", row.names = FALSE)
cat("\n== SUMMARY TABLE ==\n")
print(summary_df, digits = 3)

cat(sprintf("\n== A2 grid done %s ==\n", format(Sys.time(), "%H:%M:%S")))
