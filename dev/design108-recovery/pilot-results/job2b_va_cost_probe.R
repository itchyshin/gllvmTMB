## Design 108 recovery pilot -- JOB 2b: what does a VA fit COST at ladder scale?
##
## This exists because the campaign's schedule rests on ONE unmeasured number.
## Every timing we hold is control/Laplace: ~250 s at N=1000, T=20, scaling
## about N^1.12. NOTHING is known about VA cost at these sizes -- the only VA
## timings are toy cells (N=30-120, T=3-8). If VA is 3x Laplace the grid is a
## few hours; if it is 10x it is an overnight job or a scope cut. Guessing that
## factor would be guessing the whole estimate.
##
## So: measure it, small ladder, ONE seed per cell. This is a COST probe, not a
## recovery measurement -- rel_frob is recorded only to confirm the fits are
## real rather than degenerate shells, NOT to draw any inference from n=1.
##
## Also measures peak RSS, because R3's whole justification is that the joint
## route is arithmetically impossible at scale (~1,127 GB at N=5,000) while the
## profiled route is constant in N. That claim was measured on gaussian toy
## cells; this is the first check of it on the real probit two-tier path.
##
## Results are LOCAL only (D-50).
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

T0 <- 20L; q0 <- 1L; n_trials0 <- 6L
Ns <- as.integer(strsplit(Sys.getenv("D108_N", "250,500,1000"), ",")[[1]])
seed0 <- 1L

## `n_starts = 1` deliberately: the multistart gate needs 3 healthy starts and
## would triple the cost of a pure COST probe. 1 is the explicit bypass.
NSTARTS <- 1L; H0 <- 15L

rows <- list(); i <- 0L
for (N in Ns) {
  sim <- simulate_two_tier(N = N, T = T0, q = q0, seed = seed0,
                           phylo_scale = 1, n_trials = n_trials0)

  ## Laplace reference on the SAME draw, so the ratio is paired rather than
  ## compared across differently-generated data.
  t0 <- proc.time()[["elapsed"]]
  lap <- .d108_fit_laplace(sim, q0)
  lap_s <- proc.time()[["elapsed"]] - t0

  t0 <- proc.time()[["elapsed"]]
  va <- tryCatch(.d108_fit_va(sim, q0, route = "augmented",
                              source = .d108_va_source(), dll_stash = NULL,
                              profile_variational = TRUE, n_starts = NSTARTS, H = H0),
                 error = function(e) list(status = "HARD_ERROR", note = conditionMessage(e),
                                          peak_rss_mb = NA_real_, Sigma1_load = NULL,
                                          Sigma2_load = NULL))
  va_s <- proc.time()[["elapsed"]] - t0

  sc <- function(hat, true) if (is.null(hat)) NA_real_ else rel_frob(hat, true)
  i <- i + 1L
  rows[[i]] <- data.frame(
    N = N, T = T0, q = q0, seed = seed0,
    lap_status = lap$status, va_status = va$status,
    lap_s = lap_s, va_s = va_s, va_over_lap = va_s / lap_s,
    lap_rss_mb = lap$peak_rss_mb, va_rss_mb = va$peak_rss_mb,
    va_rf_load_t1 = sc(va$Sigma1_load, sim$truth$tier1$Sigma_B_loadings),
    va_rf_load_t2 = sc(va$Sigma2_load, sim$truth$tier2$Sigma_B_loadings),
    lap_rf_load_t1 = sc(lap$Sigma1_load, sim$truth$tier1$Sigma_B_loadings),
    lap_rf_load_t2 = sc(lap$Sigma2_load, sim$truth$tier2$Sigma_B_loadings),
    va_note = substr(va$note %||% "", 1, 120), stringsAsFactors = FALSE)

  cat(sprintf("N=%5d | lap %6.1fs (%s) | VA %7.1fs (%s) | VA/lap = %5.2fx | RSS lap %.0f VA %.0f MB\n",
              N, lap_s, lap$status, va_s, va$status, va_s / lap_s,
              lap$peak_rss_mb %||% NA_real_, va$peak_rss_mb %||% NA_real_))
  cat(sprintf("        loadings rel_frob -- VA t1=%.4f t2=%.4f | lap t1=%.4f t2=%.4f  [n=1, NOT inference]\n",
              rows[[i]]$va_rf_load_t1, rows[[i]]$va_rf_load_t2,
              rows[[i]]$lap_rf_load_t1, rows[[i]]$lap_rf_load_t2))
  utils::flush.console()
  saveRDS(do.call(rbind, rows), file.path(OUTDIR, "job2b_va_cost.rds"))
}

res <- do.call(rbind, rows)
cat("\n=== VA cost ladder ===\n"); print(res[, c("N","lap_s","va_s","va_over_lap","va_rss_mb","va_status")])
if (nrow(res) >= 2L && all(is.finite(res$va_s))) {
  fit <- stats::lm(log(va_s) ~ log(N), data = res)
  ex <- unname(coef(fit)[2])
  cat(sprintf("\nVA cost exponent: va_s ~ N^%.2f  (Laplace/control measured ~N^1.12)\n", ex))
  for (target in c(2500, 5000, 10000)) {
    pred <- exp(predict(fit, newdata = data.frame(N = target)))
    cat(sprintf("  extrapolated VA fit at N=%5d: %.0f s (%.1f min) -- EXTRAPOLATION, not measured\n",
                target, pred, pred / 60))
  }
}
cat("\nJOB2B_DONE\n")
