#!/usr/bin/env Rscript
# tests/va-benchmark/run-va-benchmark.R
#
# Phase-1 VA proof-of-mechanism BENCHMARK (Design 72). EXPERIMENT REPORT, not a
# pass/fail recovery gate. On fixtures engineered to make the Laplace inner
# Hessian go non-PD (small-n Poisson random-slope, the PHY-18 / SPA-10 failure
# mode), it runs BOTH the minimal Laplace fit and the new mean-field-diagonal
# VA fit on the SAME simulated data with KNOWN truth, then prints a comparison
# table:
#   { family, n_group, n, LA: converged? PD?, VA: converged?,
#     truth vs LA-hat vs VA-hat for the variance component(s) }
#
# Decisive reading:
#   GO    = VA converges on LA-skipping cells AND its variance estimates are
#           NOT collapsed toward 0 (within a reasonable band of truth).
#   NO-GO = VA converges but the variance components collapse to ~0.
#
# This script does NOT touch src/gllvmTMB.cpp or the package DLL. It compiles
# the two standalone experimental templates in inst/tmb/ into their own DLLs.

suppressWarnings(suppressMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(".", quiet = TRUE)
  } else {
    # Minimal fallback: source the proto helpers directly.
    source("R/va-proto.R")
  }
  stopifnot(requireNamespace("TMB", quietly = TRUE))
}))

# ---- Compile both standalone DLLs ----------------------------------------
va_dll <- .va_compile(src = "inst/tmb/gllvmTMB_va.cpp", verbose = TRUE)

la_src <- "inst/tmb/gllvmTMB_la_min.cpp"
la_dll <- tools::file_path_sans_ext(basename(la_src))
{
  so <- file.path(dirname(la_src), paste0(la_dll, .Platform$dynlib.ext))
  if (!file.exists(so) || file.info(la_src)$mtime > file.info(so)$mtime) {
    message("Compiling LA comparator: ", la_src)
    TMB::compile(la_src, framework = "TMBad")
  }
  try(dyn.unload(so), silent = TRUE)
  dyn.load(so)
}

fmt <- function(x, digits = 3) {
  if (length(x) == 0 || is.null(x) || all(is.na(x))) return("NA")
  formatC(x, digits = digits, format = "f")
}

# ---- Benchmark grid -------------------------------------------------------
# Cell 1: gaussian SANITY -- VA ELBO must agree with the analytic/LA answer
#         (this validates the ELBO before we trust the Poisson result).
# Tiny-n Poisson cells: the LA non-PD skip regime, where VA's variance
#         components were observed to COLLAPSE toward 0 (NO-GO signal).
# Moderate-n Poisson cells (Option 1): widen the sweep to locate the n at which
#         VA stops collapsing and starts tracking truth, and to see where LA
#         regains a PD Hessian. Same truth (sd0=sd1=0.8, rho=0.3), balanced
#         group sizes. Rows are ordered by n in the printed table below.
grid <- list(
  list(label = "gaussian-sanity",   family = "gaussian", n_group = 20L, n_per = 8L, seed = 11L),
  # tiny-n collapse regime (kept from the first run)
  list(label = "poisson-n12-tiny",  family = "poisson",  n_group = 4L,  n_per = 3L, seed = 24L),
  list(label = "poisson-n18-tiny",  family = "poisson",  n_group = 6L,  n_per = 3L, seed = 23L),
  list(label = "poisson-n24",       family = "poisson",  n_group = 6L,  n_per = 4L, seed = 22L),
  # moderate-n transition sweep (Option 1)
  list(label = "poisson-n30",       family = "poisson",  n_group = 8L,  n_per = 4L, seed = 25L),
  list(label = "poisson-n40",       family = "poisson",  n_group = 10L, n_per = 4L, seed = 21L),
  list(label = "poisson-n60",       family = "poisson",  n_group = 15L, n_per = 4L, seed = 26L),
  list(label = "poisson-n100",      family = "poisson",  n_group = 25L, n_per = 4L, seed = 27L),
  list(label = "poisson-n200",      family = "poisson",  n_group = 40L, n_per = 5L, seed = 28L)
)

rows <- list()
for (cell in grid) {
  sim <- simulate_va_fixture(
    n_group = cell$n_group, n_per = cell$n_per,
    sd0 = 0.8, sd1 = 0.8, rho = 0.3,
    beta0 = 0.5, beta1 = 0.4,
    family = cell$family, seed = cell$seed
  )
  dat <- sim$data
  tr <- sim$truth
  n <- nrow(dat)

  la <- tryCatch(fit_la(dat, family = cell$family, dll_base = la_dll),
                 error = function(e) list(method = "LA", converged = FALSE,
                                          pd_hess = FALSE, message = conditionMessage(e),
                                          beta = c(NA, NA), sd_intercept = NA,
                                          sd_slope = NA, corr = NA))
  va <- tryCatch(fit_va(dat, family = cell$family, dll_base = va_dll),
                 error = function(e) list(method = "VA", converged = FALSE,
                                          message = conditionMessage(e),
                                          beta = c(NA, NA), sd_intercept = NA,
                                          sd_slope = NA, corr = NA))

  rows[[length(rows) + 1L]] <- data.frame(
    cell = cell$label,
    family = cell$family,
    n_group = cell$n_group,
    n = n,
    LA_conv = isTRUE(la$converged),
    LA_PD = isTRUE(la$pd_hess),
    VA_conv = isTRUE(va$converged),
    truth_sd0 = tr$sd_intercept,
    LA_sd0 = la$sd_intercept,
    VA_sd0 = va$sd_intercept,
    truth_sd1 = tr$sd_slope,
    LA_sd1 = la$sd_slope,
    VA_sd1 = va$sd_slope,
    truth_rho = tr$corr,
    LA_rho = la$corr,
    VA_rho = va$corr,
    stringsAsFactors = FALSE
  )

  cat(sprintf("\n=== cell %s (family=%s, n_group=%d, n=%d) ===\n",
              cell$label, cell$family, cell$n_group, n))
  cat(sprintf("  LA : conv=%s PD=%s  sd0=%s sd1=%s rho=%s%s\n",
              isTRUE(la$converged), isTRUE(la$pd_hess),
              fmt(la$sd_intercept), fmt(la$sd_slope), fmt(la$corr),
              if (!is.null(la$message) && !is.na(la$message)) paste0("  [", la$message, "]") else ""))
  cat(sprintf("  VA : conv=%s        sd0=%s sd1=%s rho=%s%s\n",
              isTRUE(va$converged),
              fmt(va$sd_intercept), fmt(va$sd_slope), fmt(va$corr),
              if (!is.null(va$message) && !is.na(va$message)) paste0("  [", va$message, "]") else ""))
  cat(sprintf("  truth: sd0=%s sd1=%s rho=%s\n",
              fmt(tr$sd_intercept), fmt(tr$sd_slope), fmt(tr$corr)))
}

tbl <- do.call(rbind, rows)
# Order by n so the collapse -> recovery transition reads top-to-bottom.
# (gaussian sanity is largest-n so it lands at/near the bottom; that is fine.)
tbl <- tbl[order(tbl$n), , drop = FALSE]

cat("\n\n================ VA vs LA vs TRUTH BENCHMARK TABLE ================\n")
print(tbl, row.names = FALSE, digits = 3)

# ---- GO / NO-GO reading (reported, not gated) -----------------------------
# Identify cells where LA failed (non-PD or non-convergence) but VA converged.
la_failed <- !tbl$LA_PD | !tbl$LA_conv
va_ok <- tbl$VA_conv
rescued <- la_failed & va_ok
# Variance NOT collapsed: VA sd0 and sd1 both above a small floor relative to truth.
floor_frac <- 0.25
not_collapsed <- with(tbl,
  is.finite(VA_sd0) & is.finite(VA_sd1) &
  VA_sd0 > floor_frac * truth_sd0 & VA_sd1 > floor_frac * truth_sd1)

# "In band" = VA recovers BOTH variances within [0.25x, 4x] of truth. This is
# the transition criterion for the moderate-n sweep: where does VA stop
# collapsing/over-shrinking and start tracking truth on BOTH components?
band_lo <- 0.25
band_hi <- 4.0
in_band <- with(tbl,
  is.finite(VA_sd0) & is.finite(VA_sd1) &
  VA_sd0 > band_lo * truth_sd0 & VA_sd0 < band_hi * truth_sd0 &
  VA_sd1 > band_lo * truth_sd1 & VA_sd1 < band_hi * truth_sd1)

cat("\n---- GO / NO-GO summary ----\n")
cat(sprintf("Cells where LA failed (non-PD or non-converged): %s\n",
            paste(tbl$cell[la_failed], collapse = ", ")))
cat(sprintf("Of those, VA converged: %s\n",
            paste(tbl$cell[rescued], collapse = ", ")))
cat(sprintf("Of the rescued cells, VA variances NOT collapsed (>%.0f%% of truth): %s\n",
            100 * floor_frac, paste(tbl$cell[rescued & not_collapsed], collapse = ", ")))

# Smallest n at which VA recovers BOTH variances within band, restricted to the
# Poisson sweep (the gaussian sanity cell is a control, not part of the sweep).
pois <- tbl$family == "poisson"
pois_in_band <- in_band & pois & tbl$VA_conv
if (any(pois_in_band)) {
  k <- which(pois_in_band)[which.min(tbl$n[pois_in_band])]
  cat(sprintf(
    "Smallest Poisson n with VA BOTH variances in-band [%.2fx, %.1fx]: n=%d (cell %s); LA PD there = %s\n",
    band_lo, band_hi, tbl$n[k], tbl$cell[k], tbl$LA_PD[k]))
  recover_n <- tbl$n[k]
  recover_cell <- tbl$cell[k]
  recover_la_pd <- tbl$LA_PD[k]
} else {
  cat("Smallest Poisson n with VA BOTH variances in-band: NONE in this sweep\n")
  recover_n <- NA_integer_
  recover_cell <- NA_character_
  recover_la_pd <- NA
}

n_rescued <- sum(rescued)
n_rescued_good <- sum(rescued & not_collapsed)
verdict <- if (n_rescued == 0L) {
  "INCONCLUSIVE: no cell had LA fail while VA converged in this run."
} else if (n_rescued_good == n_rescued) {
  "GO signal: VA converges on every LA-failing cell WITHOUT collapsing variances."
} else if (n_rescued_good == 0L) {
  "NO-GO signal: VA converges on LA-failing cells but variances COLLAPSE."
} else {
  "MIXED: VA rescues some LA-failing cells with intact variances, collapses others."
}
cat(sprintf("\nVERDICT (reported, maintainer decides the gate): %s\n", verdict))
if (!is.na(recover_n)) {
  cat(sprintf(
    "TRANSITION: VA first tracks BOTH variances at Poisson n=%d (cell %s). LA Hessian PD there: %s.\n",
    recover_n, recover_cell, recover_la_pd))
  cat("Read: if LA is also non-PD at/below that n while VA tracks truth, the tiny-n collapse is\n")
  cat("      genuine small-n under-identification rather than a VA-specific mean-field artifact.\n")
} else {
  cat("TRANSITION: VA did not bring BOTH variances in-band anywhere in this Poisson sweep.\n")
}

# ---- Write artifact -------------------------------------------------------
out_dir <- "tests/va-benchmark"
out_csv <- file.path(out_dir, "va-benchmark-table.csv")
utils::write.csv(tbl, out_csv, row.names = FALSE)
cat(sprintf("\nWrote table to %s\n", out_csv))
cat("\nVA benchmark complete.\n")
