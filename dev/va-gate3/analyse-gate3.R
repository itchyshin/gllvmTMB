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
  ## UNDEFINED IS NOT FAILURE. `is.finite(x) & x <= tol` silently turns NA into
  ## FALSE, scoring a cell as failing a criterion that was never measured. That
  ## bit the collapse half in 6 cells where `n_ok == 0`: no fit produced a
  ## usable axis, so `collapse_rate` is NA -- undefined, not 0% and not 100%.
  ## Scoring those FAIL made va_gh's collapse record read 51/54 when its
  ## MEASURED record is 51/51, and va_jj's 45/54 when it is 45/51.
  ##
  ## NA now propagates deliberately: a cell whose criterion is undefined is
  ## reported as NA and is NOT scored -- the same treatment the R2
  ## no-comparator cells get below. Downstream summaries must use na.rm and
  ## report the NA count separately; folding NA into the failure count is the
  ## bug this replaces.
  merged$pass_rmse     <- ifelse(is.na(merged$rmse_gap), NA,
                                 merged$rmse_gap <= 0.05)
  merged$pass_collapse <- ifelse(is.na(merged$collapse_rate), NA,
                                 merged$collapse_rate <= 0.05)
  merged$pass <- merged$pass_rmse & merged$pass_collapse
  merged[order(merged$truth, merged$q, merged$p, merged$n, merged$arm), ]
}

## ---- R2: paired exclusion of ML-degenerate replicates --------------------
## The 2026-07-31 scope freeze pre-declares EXACTLY TWO admissible rules and
## forbids a third. R1 is the raw rule above. R2 drops every replicate in which
## the ML comparator is itself degenerate by the two-sided detector
## (rel_frob > 10 OR kappa < 1/3), and drops it from ALL arms so the comparison
## stays paired -- excluding it from ML alone would compare arms on different
## data.
##
## R2 is the CONSERVATIVE direction: it removes ML's disasters, which makes
## VA's bar harder rather than easier. Both are computed and reported for every
## cell; whichever is chosen, the other is published beside it.
##
## Why this is not optional. Exercised against the partial campaign, R1 already
## produced cells with sigma_rmse_ml near 2.98e+04, where rmse_gap is about
## -2.98e+04 and pass_rmse is TRUE -- VA "passing" solely because ML exploded.
## A rule a broken comparator makes trivially passable certifies nothing.
.ml_degenerate_keys <- function(rows) {
  ml <- rows[rows$arm == "ml_laplace", , drop = FALSE]
  bad <- (is.finite(ml$sigma_relfrob) & ml$sigma_relfrob > 10) |
         (is.finite(ml$kappa) & ml$kappa < 1 / 3) |
         !is.finite(ml$sigma_relfrob)
  unique(paste(ml$truth, ml$q, ml$p, ml$n, ml$seed, sep = "\r")[bad])
}

.drop_ml_degenerate <- function(rows) {
  drop <- .ml_degenerate_keys(rows)
  key <- paste(rows$truth, rows$q, rows$p, rows$n, rows$seed, sep = "\r")
  rows[!(key %in% drop), , drop = FALSE]
}

## ---- R2 cells with zero surviving replicates: no valid comparator ---------
## Paired exclusion removes a seed from ALL arms, so a cell in which 100% of
## seeds have a degenerate ML comparator loses its va_gh/va_jj rows too -- not
## because VA failed, but because R2's own restriction leaves nothing to
## compare against. Those rows then vanish from the R2 table entirely, which
## breaks the pre-registration's commitment that BOTH rules are computed and
## reported for EVERY cell, and it hides a finding: an ML comparator that is
## degenerate in 40 of 40 replicates is itself evidence about Laplace.
##
## They are restored as explicit `pass = NA` ("no_comparator") rows: reported,
## never silently dropped, and NOT scored as either pass or fail. This is a
## reporting convention, not a third analysis rule -- it changes no estimand,
## no tolerance, and no exclusion filter.
.append_no_comparator_cells <- function(rows, rows_r2, verdict_r2) {
  key <- c("truth", "q", "p", "n")
  all_cells <- unique(rows[key])
  survived  <- if (nrow(rows_r2)) unique(rows_r2[key]) else all_cells[0, , drop = FALSE]
  all_k  <- do.call(paste, c(all_cells, sep = "\r"))
  surv_k <- do.call(paste, c(survived,  sep = "\r"))
  dropped <- all_cells[!(all_k %in% surv_k), , drop = FALSE]
  if (!"verdict_note" %in% names(verdict_r2)) verdict_r2$verdict_note <- NA_character_
  if (!nrow(dropped)) return(verdict_r2)
  cat(sprintf("\nR2 WARNING: %d cell(s) had a degenerate ML comparator in EVERY replicate.\n",
              nrow(dropped)))
  cat("  Reported as NA (no_comparator) and NOT scored. This is a finding about ML, not VA:\n")
  print(dropped)
  template <- verdict_r2[0, , drop = FALSE]
  extra <- do.call(rbind, lapply(seq_len(nrow(dropped)), function(i) {
    cell <- dropped[i, , drop = FALSE]
    n_seeds <- sum(rows$truth == cell$truth & rows$q == cell$q &
                     rows$p == cell$p & rows$n == cell$n & rows$arm == "ml_laplace")
    do.call(rbind, lapply(c("va_gh", "va_jj"), function(a) {
      r <- template[NA_integer_, , drop = FALSE]
      r[1, names(cell)] <- cell
      r$arm  <- a
      r$pass <- NA
      r$pass_rmse <- NA
      r$pass_collapse <- NA
      r$verdict_note <- sprintf("no_comparator: ML degenerate in %d/%d replicates",
                                n_seeds, n_seeds)
      r
    }))
  }))
  out <- rbind(verdict_r2, extra)
  out[order(out$truth, out$q, out$p, out$n, out$arm), , drop = FALSE]
}

## ==================================================== run =================
rows <- load_gate3_rows()

cat("status counts, exact labels (never a success-substring collapse):\n")
print(table(arm = rows$arm, status = rows$status, useNA = "ifany"))

.summarise_all <- function(r) {
  k <- interaction(r$truth, r$q, r$p, r$n, r$arm, drop = TRUE)
  s <- do.call(rbind, lapply(split(r, k), summarise_cell))
  rownames(s) <- NULL
  s
}

summary_df <- .summarise_all(rows)
verdict_r1 <- apply_pass_rule(summary_df)

rows_r2 <- .drop_ml_degenerate(rows)
n_dropped <- (nrow(rows) - nrow(rows_r2)) / 3L
cat(sprintf("\nR2 paired exclusion: %d replicate(s) dropped from ALL arms because the ML comparator was degenerate (%.1f%% of replicates).\n",
            n_dropped, 100 * n_dropped / (nrow(rows) / 3L)))
verdict_r2 <- if (nrow(rows_r2)) apply_pass_rule(.summarise_all(rows_r2)) else verdict_r1[0, ]
verdict_r2 <- .append_no_comparator_cells(rows, rows_r2, verdict_r2)
if (!"verdict_note" %in% names(verdict_r1)) verdict_r1$verdict_note <- NA_character_
stopifnot(nrow(verdict_r1) == nrow(verdict_r2))   # both rules, every cell

dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)
utils::write.csv(summary_df, file.path(RESULTS_DIR, "gate3-cell-summary.csv"), row.names = FALSE)
utils::write.csv(verdict_r1, file.path(RESULTS_DIR, "gate3-verdict-R1-raw.csv"), row.names = FALSE)
utils::write.csv(verdict_r2, file.path(RESULTS_DIR, "gate3-verdict-R2-paired-exclusion.csv"), row.names = FALSE)
## Retained under the original name so nothing downstream silently reads only
## one rule while believing it read "the" verdict.
utils::write.csv(verdict_r1, file.path(RESULTS_DIR, "gate3-verdict.csv"), row.names = FALSE)

cat(sprintf("\n%d cell x arm summaries; R1 %d verdict rows, R2 %d verdict rows, written to %s/.\n",
            nrow(summary_df), nrow(verdict_r1), nrow(verdict_r2), RESULTS_DIR))
cols <- c("truth", "q", "p", "n", "arm", "n_attempted", "sigma_rmse", "sigma_rmse_ml",
          "rmse_gap", "collapse_rate", "pass")
cat("\n=== R1 (raw) — pass rule read literally ===\n")
print(utils::head(verdict_r1[, cols], 20))
cat("\n=== R2 (paired exclusion of ML-degenerate replicates) ===\n")
print(utils::head(verdict_r2[, cols], 20))
cat("\nBoth rules are reported. Which one carries the verdict is the maintainer's\n",
    "choice under the recorded Design 85 s11 departure; the other is published beside it.\n", sep = "")
