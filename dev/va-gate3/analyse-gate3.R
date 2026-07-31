#!/usr/bin/env Rscript
## Gate 3 analysis -- applies the FROZEN pass rule from
## docs/dev-log/2026-07-30-gate3-preregistration.md to the per-fit rows
## dev/va-gate3/run-gate3.R writes under dev/va-gate3/results/cells/.
##
## Exact status matching only (== / %in%), never grepl: an unanchored grepl
## on a status string once matched "not_converged" as a substring of
## "converged" and produced a published wrong number
## (dev/totoro-grid/analyse-grid.R:100). run-gate3.R's status column is one
## of exactly "ok" / "error" / "nonconvergence" / "guard_rejected" -- none is
## a substring of another, so == is always sufficient here; grepl is not used
## anywhere below.
##
## Run from the repository root, after run-gate3.R has written at least one
## dev/va-gate3/results/cells/cell_*.rds file.

suppressMessages(library(stats))

RESULTS_DIR <- file.path("dev", "va-gate3", "results")
CELLS_DIR   <- file.path(RESULTS_DIR, "cells")

load_gate3_rows <- function(cells_dir = CELLS_DIR) {
  files <- list.files(cells_dir, pattern = "^cell_[0-9]+\\.rds$", full.names = TRUE)
  if (!length(files)) {
    stop("No cell_*.rds files found under ", cells_dir,
         " -- run dev/va-gate3/run-gate3.R first.", call. = FALSE)
  }
  do.call(rbind, lapply(files, readRDS))
}

## ---- MCSE for a 0/1 rate: standard binomial SE, "between replicates" by
## construction (each replicate contributes one TRUE/FALSE draw). ----------
.rate_mcse <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n == 0L) return(NA_real_)
  p_hat <- mean(x)
  sqrt(p_hat * (1 - p_hat) / n)
}

## ---- RMSE_arm = sqrt(mean_over_seeds(x_i^2)) and its MCSE, x_i = ONE
## seed's overall relative-Frobenius error (already a single scalar computed
## from that seed's full p x p Sigma_B comparison). "Between replicates,
## never by pooling Sigma_B entries as independent trials" (frozen spec):
## the unit of replication here is the seed, never a matrix entry.
## Delta method: RMSE = sqrt(mean(x^2)) => d(RMSE)/d(mean(x^2)) = 1/(2*RMSE),
## so Var(RMSE) ~= Var(x^2) / (n * 4 * RMSE^2); MCSE = sqrt(Var(x^2)/n) / (2*RMSE).
.rmse_and_mcse <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n == 0L) return(c(rmse = NA_real_, mcse = NA_real_, n = 0))
  rmse <- sqrt(mean(x^2))
  if (n < 2L || !is.finite(rmse) || rmse == 0) return(c(rmse = rmse, mcse = NA_real_, n = n))
  mcse <- sqrt(stats::var(x^2) / n) / (2 * rmse)
  c(rmse = rmse, mcse = mcse, n = n)
}

## ---- one (truth,q,p,n,arm) cell summary ----------------------------------
## "Every attempted fit in the denominator" governs n_attempted/rate_ok
## (every row for this cell x arm, whatever its status). The RMSE and
## collapse-rate figures are necessarily computed only among fits that
## produced a usable number (a true "error"/timeout row has no Sigma_hat to
## compare) -- n_sigma_usable and n_healthy_nonseparated are reported
## alongside every RMSE/collapse-rate cell so that narrowing is always
## visible, never silent. See the handoff note: whether a fit that ran but
## failed the engine's own health/guard checks should still count toward
## the RMSE average (it DOES here, whenever it produced finite numbers --
## consistent with "never filter on status/admitted before computing
## metrics") is a genuine reading of an underspecified point in the pass
## rule and is flagged there, not resolved silently.
summarise_cell <- function(rows) {
  ok <- rows$status == "ok"
  rf <- .rmse_and_mcse(rows$sigma_relfrob)
  ## "otherwise healthy, non-separated replicates": the frozen spec names
  ## this condition without a computable definition beyond "healthy" (there
  ## is no separation diagnostic anywhere in this design). Operationalised
  ## here as status == "ok" (exact match). Flagged in the handoff.
  healthy_nonseparated <- ok
  collapse_among_healthy <- rows$any_axis_collapsed[healthy_nonseparated]
  collapse_among_healthy <- collapse_among_healthy[is.finite(collapse_among_healthy)]
  data.frame(
    truth = rows$truth[1], q = rows$q[1], p = rows$p[1], n = rows$n[1], arm = rows$arm[1],
    n_attempted = nrow(rows),
    n_ok = sum(ok),
    rate_ok = mean(ok),
    rate_ok_mcse = .rate_mcse(ok),
    n_sigma_usable = unname(rf["n"]),
    sigma_rmse = unname(rf["rmse"]),
    sigma_rmse_mcse = unname(rf["mcse"]),
    n_healthy_nonseparated = sum(healthy_nonseparated),
    n_collapse_usable = length(collapse_among_healthy),
    collapse_rate = if (length(collapse_among_healthy)) mean(collapse_among_healthy) else NA_real_,
    collapse_rate_mcse = .rate_mcse(collapse_among_healthy),
    kappa_median = stats::median(rows$kappa, na.rm = TRUE),
    guard_rejected_rate = mean(rows$status == "guard_rejected"),
    stringsAsFactors = FALSE
  )
}

## ---- the frozen pass rule, applied per (truth,q,p,n) x VA-arm ------------
##   PASS iff RMSE_va - RMSE_ml <= 0.05 (absolute)
##        AND collapse_rate <= 0.05 among healthy, non-separated replicates.
apply_pass_rule <- function(summary_df) {
  key <- c("truth", "q", "p", "n")
  ml <- summary_df[summary_df$arm == "ml_laplace", c(key, "sigma_rmse", "n_sigma_usable")]
  names(ml)[names(ml) == "sigma_rmse"]      <- "sigma_rmse_ml"
  names(ml)[names(ml) == "n_sigma_usable"]  <- "n_sigma_usable_ml"
  va <- summary_df[summary_df$arm %in% c("va_gh", "va_jj"), ]
  merged <- merge(va, ml, by = key, all.x = TRUE)
  merged$rmse_gap <- merged$sigma_rmse - merged$sigma_rmse_ml
  merged$pass_rmse <- is.finite(merged$rmse_gap) & merged$rmse_gap <= 0.05
  merged$pass_collapse <- is.finite(merged$collapse_rate) & merged$collapse_rate <= 0.05
  merged$pass <- merged$pass_rmse & merged$pass_collapse
  merged[order(merged$truth, merged$q, merged$p, merged$n, merged$arm), ]
}

## ==================================================== run =================
rows <- load_gate3_rows()

cat("status counts, exact labels (never a success-substring collapse):\n")
print(table(arm = rows$arm, status = rows$status, useNA = "ifany"))

split_key <- interaction(rows$truth, rows$q, rows$p, rows$n, rows$arm, drop = TRUE)
summary_df <- do.call(rbind, lapply(split(rows, split_key), summarise_cell))
rownames(summary_df) <- NULL

verdict <- apply_pass_rule(summary_df)

dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)
utils::write.csv(summary_df, file.path(RESULTS_DIR, "gate3-cell-summary.csv"), row.names = FALSE)
utils::write.csv(verdict, file.path(RESULTS_DIR, "gate3-verdict.csv"), row.names = FALSE)

cat(sprintf("\n%d cell x arm summar%s, %d VA-vs-ML verdict row%s written to %s/.\n",
            nrow(summary_df), if (nrow(summary_df) == 1L) "y" else "ies",
            nrow(verdict), if (nrow(verdict) == 1L) "" else "s", RESULTS_DIR))
cat("\nverdict (rmse_gap <= 0.05 AND collapse_rate <= 0.05):\n")
print(verdict[, c("truth", "q", "p", "n", "arm", "n_attempted", "sigma_rmse", "sigma_rmse_ml",
                   "rmse_gap", "collapse_rate", "pass")])
