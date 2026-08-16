## Design 119 §4 coverage campaign — D-139 PRE-RUN TEST (gaussian wave 1).
##
## 2 reps x 4 cells = 8 fits, single-core, using the SAME run_one_rep()
## as the full driver (sourced below), so what this measures is exactly
## what the campaign will do. Prints per-fit wall seconds and the four
## per-fit coverage values. Show this output to Shinichi and get approval
## BEFORE launching cov119-driver.R (D-139: estimate first, pre-run test,
## approval; a run that overruns its estimate stops and re-reports).
##
## Run (from a directory containing cov119-dgp.R + cov119-driver.R):
##   export OPENBLAS_NUM_THREADS=1
##   export COV119_REPO_ROOT=/path/to/gllvmTMB-checkout
##   COV119_CORES=1 COV119_PRERUN=1 Rscript cov119-prerun.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", COV119_CORES = "1",
           COV119_PRERUN = "1")

## Source the driver's function definitions WITHOUT running its grid:
## we re-source cov119-dgp.R and copy the two functions we need by
## evaluating the driver in a bounded environment is overkill — instead
## the prerun simply defines its own loop over the driver's primitives.
source("cov119-dgp.R")

stopifnot(requireNamespace("gllvmTMB", quietly = TRUE))
stopifnot(exists("predict_missing", where = asNamespace("gllvmTMB")))
suppressPackageStartupMessages(library(gllvmTMB))

## Pull run_one_rep / fit_wide_model / helpers from the driver file by
## parsing it and evaluating ONLY function definitions plus constants —
## the driver's executable tail (task list, mclapply, CSV writes) is
## guarded from here by evaluating up to the marker line.
driver_lines <- readLines("cov119-driver.R")
marker <- grep("^## ---- task list", driver_lines)[1]
stopifnot("driver marker not found" = is.finite(marker))
eval(parse(text = driver_lines[seq_len(marker - 1L)]), envir = globalenv())

fmtc <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))
fmti <- function(x) ifelse(is.na(x), "NA", sprintf("%d", x))

cat("=== D-139 pre-run: 2 reps x 4 cells, single core ===\n")
cat(sprintf("gllvmTMB %s | %s\n\n",
            as.character(utils::packageVersion("gllvmTMB")),
            R.version.string))

pre_rows <- list()
for (mi in seq_along(COV119_MECHS)) {
  for (rep in 1:2) {
    res <- run_one_rep(COV119_MECHS[mi], mi, rep)
    pre_rows[[length(pre_rows) + 1L]] <- res
    cat(sprintf(
      paste0("%-16s rep=%d seed=%d  converged=%-5s  %6.1f s/fit  ",
             "cov90_conf=%s cov95_conf=%s cov90_pred=%s cov95_pred=%s",
             "  se_bad=%s/%s%s\n"),
      res$mechanism, rep, res$seed, res$converged, res$elapsed_s,
      fmtc(res$cov90_conf), fmtc(res$cov95_conf),
      fmtc(res$cov90_pred), fmtc(res$cov95_pred),
      fmti(res$n_se_bad_conf), fmti(res$n_se_bad_pred),
      if (nzchar(res$error)) paste0("  ERROR: ", res$error) else ""
    ))
  }
}

pre_df <- do.call(rbind, pre_rows)
mean_s <- mean(pre_df$elapsed_s, na.rm = TRUE)
n_total <- length(COV119_MECHS) * COV119_N_REPS
cat(sprintf("\nMean per-fit time: %.1f s (n = %d fits)\n", mean_s, nrow(pre_df)))
cat(sprintf("Projected full campaign: %d fits x %.1f s = %.1f core-hours;",
            n_total, mean_s, n_total * mean_s / 3600))
cat(sprintf(" wall ~%.0f min at 40 cores.\n", n_total * mean_s / 40 / 60))
cat(sprintf("Converged: %d/%d. Non-finite/non-positive SEs: %s.\n",
            sum(pre_df$converged), nrow(pre_df),
            sum(pre_df$n_se_bad_conf, pre_df$n_se_bad_pred, na.rm = TRUE)))
cat("\nSTOP here. Report this output; launch cov119-driver.R only after\n")
cat("approval, and only if the projection stays inside the approved budget.\n")
