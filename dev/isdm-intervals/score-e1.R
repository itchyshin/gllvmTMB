#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## E1 scorer — per-cell x per-species Wald coverage of the trait:env slope,
## with Wilson intervals and Design 118's three-way verdict.
##
## Pre-registration: docs/dev-log/research/2026-08-18-e1-calibration-preregistration.md
##
## THE ONE RULE THIS FILE EXISTS TO ENFORCE: never pool. Coverage is scored
## per (cell x species). Pooling across cells or species is what manufactured
## the gamma-recovery v1 false finding, and this campaign inherits that lesson
## explicitly (proposal section 2). There is deliberately no "overall coverage"
## number anywhere in this output.
##
## Usage:
##   Rscript score-e1.R <results.csv> [out-prefix]
## ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  ok <- requireNamespace("stats", quietly = TRUE)
}))

## Design 118 band + gates ----------------------------------------------------
BAND_LO   <- 0.92
BAND_HI   <- 0.98
WILSON_CL <- 0.90   # 90% Wilson band, matching the feasibility run
K3_FLOOR  <- 0.80   # catastrophic-undercoverage alarm

CELL_KEYS <- c("n_cells", "eff_ratio", "n_sources", "amp")
SPECIES   <- c("cov_env_sp1", "cov_env_sp2", "cov_env_sp3")
TRUE_BETA <- c(cov_env_sp1 = 0.5, cov_env_sp2 = -0.3, cov_env_sp3 = 0.4)

#' Wilson score interval for a binomial proportion.
#'
#' Wilson rather than Wald: at coverage near 0.95 with n in the hundreds the
#' Wald interval is both too narrow and can exceed 1, which would silently
#' manufacture PASS verdicts at exactly the boundary this campaign is testing.
wilson_ci <- function(x, n, conf = WILSON_CL) {
  if (n == 0L) return(c(lo = NA_real_, hi = NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- x / n
  d <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / d
  half <- (z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d
  c(lo = max(0, centre - half), hi = min(1, centre + half))
}

#' Design 118 three-way verdict.
#'
#' PASS  - the whole Wilson interval sits inside the band: the estimator is
#'         calibrated here, at this resolution.
#' FAIL  - the whole interval sits outside: it is miscalibrated here.
#' INDET - the interval straddles a boundary: this run cannot tell. NOT a
#'         pass. The distinction is the entire point of the escalation rule;
#'         collapsing INDET into PASS is how an underpowered grid becomes a
#'         false claim.
verdict <- function(lo, hi) {
  if (is.na(lo) || is.na(hi)) return("INDETERMINATE")
  if (lo >= BAND_LO && hi <= BAND_HI) return("PASS")
  if (hi < BAND_LO || lo > BAND_HI) return("FAIL")
  "INDETERMINATE"
}

score_e1 <- function(csv_path) {
  d <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  needed <- c(CELL_KEYS, "pd", "se_ok", SPECIES)
  missing <- setdiff(needed, names(d))
  if (length(missing)) {
    stop("results file is missing column(s): ", paste(missing, collapse = ", "))
  }

  ## Denominator = PD-Hessian fits with a usable SE, exactly as the
  ## feasibility grid did. Non-PD fits are EXCLUDED, never imputed: a fit
  ## whose Hessian is not positive-definite has no Wald interval to score,
  ## and counting it as a miss would understate coverage for a reason that
  ## has nothing to do with calibration.
  d$.usable <- as.logical(d$pd) & as.logical(d$se_ok)

  cells <- unique(d[CELL_KEYS])
  cells <- cells[do.call(order, cells), , drop = FALSE]

  rows <- list()
  for (i in seq_len(nrow(cells))) {
    key <- cells[i, , drop = FALSE]
    sel <- rep(TRUE, nrow(d))
    for (k in CELL_KEYS) sel <- sel & d[[k]] == key[[k]]
    sub <- d[sel, , drop = FALSE]
    n_fits <- nrow(sub)
    use <- sub[sub$.usable, , drop = FALSE]
    n_pd <- nrow(use)

    for (sp in SPECIES) {
      hits <- sum(as.integer(use[[sp]]), na.rm = TRUE)
      n_sp <- sum(!is.na(use[[sp]]))
      cov <- if (n_sp > 0L) hits / n_sp else NA_real_
      ci <- wilson_ci(hits, n_sp)
      mcse <- if (n_sp > 0L) sqrt(cov * (1 - cov) / n_sp) else NA_real_
      rows[[length(rows) + 1L]] <- data.frame(
        key,
        species     = sub("^cov_env_", "", sp),
        true_beta   = unname(TRUE_BETA[[sp]]),
        n_fits      = n_fits,
        n_pd        = n_pd,
        n_scored    = n_sp,
        pd_rate     = if (n_fits > 0L) n_pd / n_fits else NA_real_,
        coverage    = cov,
        mcse        = mcse,
        wilson_lo   = unname(ci["lo"]),
        wilson_hi   = unname(ci["hi"]),
        half_width  = unname((ci["hi"] - ci["lo"]) / 2),
        verdict     = verdict(ci["lo"], ci["hi"]),
        k3_alarm    = !is.na(cov) && cov < K3_FLOOR,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

report <- function(s) {
  cat("=== E1 per-cell x per-species verdicts (never pooled) ===\n")
  cat("cells:", nrow(unique(s[CELL_KEYS])), " verdicts:", nrow(s), "\n\n")
  tab <- table(factor(s$verdict, levels = c("PASS", "INDETERMINATE", "FAIL")))
  for (nm in names(tab)) cat(sprintf("  %-14s %d\n", nm, tab[[nm]]))
  cat("\n  point coverage range: ",
      sprintf("%.3f - %.3f", min(s$coverage, na.rm = TRUE),
              max(s$coverage, na.rm = TRUE)), "\n", sep = "")
  cat("  in [0.90, 0.98]: ",
      sum(s$coverage >= 0.90 & s$coverage <= 0.98, na.rm = TRUE),
      "/", nrow(s), "\n", sep = "")
  cat("  median Wilson half-width: ",
      sprintf("%.4f", stats::median(s$half_width, na.rm = TRUE)), "\n", sep = "")
  cat("  K3 alarms (coverage < 0.80): ", sum(s$k3_alarm, na.rm = TRUE), "\n", sep = "")
  cat("  PD rate range: ",
      sprintf("%.3f - %.3f", min(s$pd_rate, na.rm = TRUE),
              max(s$pd_rate, na.rm = TRUE)), "\n", sep = "")
  invisible(s)
}

if (sys.nframe() == 0L || identical(environment(), globalenv())) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 1L) {
    s <- score_e1(args[[1]])
    report(s)
    if (length(args) >= 2L) {
      utils::write.csv(s, paste0(args[[2]], "-verdicts.csv"), row.names = FALSE)
      cat("\nwrote: ", args[[2]], "-verdicts.csv\n", sep = "")
    }
  }
}
