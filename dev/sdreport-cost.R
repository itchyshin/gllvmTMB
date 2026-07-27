#!/usr/bin/env Rscript
## dev/sdreport-cost.R
##
## FISHER TASK: measure what TMB::sdreport() costs as a fraction of a full
## Laplace fit, at n = 200, 400, 800.
##
## Background: every prior timing comparison in this repo (dev/controlled-gh-
## vs-jj.R, dev/scale/run-scale.R, dev/totoro-grid/) measured POINT ESTIMATES
## ONLY. The production Laplace route additionally pays TMB::sdreport() after
## nlminb() converges (R/fit-multi.R:4920-4937) to get standard errors. That
## cost has never been isolated. If it is large, every prior Laplace-vs-VA
## speed claim needs restating in terms of "point only" vs "point + inference".
##
## Method (A/B via the public control knob):
##   gllvmTMBcontrol(se = FALSE) skips the TMB::sdreport() call entirely
##   (see the `sdreport_error <- "standard-error calculation skipped..."`
##   branch at R/fit-multi.R:4920-4937). gllvmTMBcontrol(se = TRUE) (default)
##   runs it. Both arms otherwise run the IDENTICAL formula/data/control
##   pipeline (same nlminb optimisation, same deterministic start since
##   n_init = 1 has jitter_sd = 0 -- R/fit-multi.R:4838/4860), so the
##   difference between the two arms' wall-clock times isolates the
##   sdreport cost. opt$evaluations (nlminb function/gradient call counts)
##   is recorded for both arms as a sanity check that the optimisation work
##   really was identical -- if it isn't, the timing difference is
##   contaminated and must be flagged, not silently trusted.
##
## Timing discipline (CLAUDE.md guard, five retracted claims in this
## project): NEVER time from a single sequential pass. There is a ~3x
## first-fit-in-session penalty from the one-time TMB template compile. A
## warm-up fit (discarded) forces the compile before the timed grid starts.
## Within each n cell, replicates alternate A/B order (odd reps: A then B;
## even reps: B then A) so "always fitted second" is not systematically
## confounded with sdreport cost. All reported timings are per-cell MEDIANS
## across >= 3 replicates, not single draws.
##
## Design choice: A and B are fit on the SAME simulated dataset within a
## replicate (same seed) so the pairing is clean -- any residual difference
## in optimisation work between the two arms of a replicate is a data
## artefact, not a resimulation artefact.
##
## Internal research only. No @export, no method= argument, no testthat.

suppressPackageStartupMessages({
  library(stats)
})

root <- "/private/tmp/gllvmtmb-va-wiring-20260726"
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))

if (!requireNamespace("TMB", quietly = TRUE)) {
  stop("This script requires the TMB package (sdreport is what we're timing).",
       call. = FALSE)
}

# ---------------------------------------------------------------------------
# DGP: Gaussian, n units x 8 traits, q = 2 latent axes. Matches the pattern
# in dev/laplace-comparator-psi.R (same trait count / q / wide-frame shape),
# switched from Poisson to Gaussian per task instructions, and fit with
# latent(..., unique = FALSE) -- loadings-only, no Psi -- exactly as asked.
# ---------------------------------------------------------------------------
simulate_gaussian_gllvm <- function(n_unit, n_trait = 8L, q = 2L, seed,
                                     lambda_sd = 0.7, resid_sd = 1) {
  set.seed(seed)
  Lambda_true <- matrix(rnorm(n_trait * q, sd = lambda_sd), n_trait, q)
  Z_true <- matrix(rnorm(n_unit * q), n_unit, q)
  eta <- Z_true %*% t(Lambda_true)
  Y <- eta + matrix(rnorm(n_unit * n_trait, sd = resid_sd), n_unit, n_trait)
  colnames(Y) <- paste0("sp", seq_len(n_trait))
  df <- cbind(data.frame(unit = factor(seq_len(n_unit))), as.data.frame(Y))
  df
}

trait_names <- paste0("sp", 1:8)
## NOTE: `q` must exist in .GlobalEnv (the formula's environment) at fit
## time, not only inside fit_one()'s local scope -- gllvmTMB() evaluates
## `d = q` using the formula's stored environment, which is .GlobalEnv here
## since `fml` is built at top level. Base R also defines a `q()` (quit)
## function, so an accidental scoping miss resolves to a closure, not an
## integer, and errors as "cannot coerce type 'closure' to vector of type
## 'integer'" -- caught by the toy smoke test below, fixed by assigning
## `q <- 2L` at top level here.
q <- 2L
fml <- stats::as.formula(paste0(
  "traits(", paste(trait_names, collapse = ", "),
  ") ~ 1 + latent(1 | unit, d = q, unique = FALSE)"
))

fit_one <- function(df, se) {
  t0 <- proc.time()[["elapsed"]]
  fit <- gllvmTMB(
    fml, data = df, unit = "unit", family = gaussian(),
    control = gllvmTMBcontrol(se = se)
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  list(fit = fit, elapsed = elapsed)
}

# ---------------------------------------------------------------------------
# TOY SMOKE TEST -- one tiny fit, se = TRUE (default). Confirm a real fitted
# object with a non-NULL $sd_report before running anything else. Abort on
# failure per task instructions.
# ---------------------------------------------------------------------------
cat("=== TOY SMOKE TEST ===\n")
smoke_df <- simulate_gaussian_gllvm(n_unit = 30L, seed = 1L)
smoke <- tryCatch(fit_one(smoke_df, se = TRUE),
                   error = function(e) structure(list(error = conditionMessage(e)),
                                                 class = "smoke_error"))
if (inherits(smoke, "smoke_error")) {
  cat("SMOKE FAILED (error):", smoke$error, "\n")
  stop("Aborting: smoke test errored.", call. = FALSE)
}
smoke_fit <- smoke$fit
if (!inherits(smoke_fit, "gllvmTMB_multi")) {
  cat("SMOKE FAILED: fit is not class gllvmTMB_multi. class(fit) =",
      paste(class(smoke_fit), collapse = ", "), "\n")
  stop("Aborting: smoke test did not return a real fitted object.", call. = FALSE)
}
if (is.null(smoke_fit$sd_report)) {
  cat("SMOKE FAILED: $sd_report is NULL.\n")
  stop("Aborting: smoke test's sd_report is NULL.", call. = FALSE)
}
cat("Smoke OK: class =", paste(class(smoke_fit), collapse = ", "), "\n")
cat("Smoke OK: sd_report is non-NULL, pdHess =", smoke_fit$sd_report$pdHess, "\n")
cat("Smoke OK: elapsed =", round(smoke$elapsed, 3), "s\n\n")
rm(smoke, smoke_fit, smoke_df)

# ---------------------------------------------------------------------------
# WARM-UP (discarded) -- force the one-time TMB template compile before the
# timed grid starts. Same formula/family structure as the timed cells so the
# same compiled DLL is reused throughout.
# ---------------------------------------------------------------------------
cat("=== WARM-UP (discarded) ===\n")
warmup_df <- simulate_gaussian_gllvm(n_unit = 50L, seed = 999L)
t0 <- proc.time()[["elapsed"]]
invisible(fit_one(warmup_df, se = TRUE))
cat("Warm-up elapsed:", round(proc.time()[["elapsed"]] - t0, 3), "s (discarded)\n\n")
rm(warmup_df)

# ---------------------------------------------------------------------------
# TIMED GRID: n = 200, 400, 800; 3 replicates per n; A (se=FALSE) vs
# B (se=TRUE) on the SAME simulated dataset per replicate; alternating A/B
# order across replicates.
# ---------------------------------------------------------------------------
n_values <- c(200L, 400L, 800L)
## Bumped from the task's minimum of 3 to 7: the first 3-rep run landed the
## n=200 cell at 29.8%, within noise of the 30% decision gate on a shared
## laptop (short ~1s absolute fit times make the ratio sensitive to GC/OS
## jitter). More reps tighten the median before trusting a verdict this
## close to the boundary.
n_reps <- 7L
base_seed <- 20260726L

cell_rows <- list()
row_i <- 0L

for (n_unit in n_values) {
  cat(sprintf("=== n = %d ===\n", n_unit))
  point_only_secs <- numeric(n_reps)
  point_plus_se_secs <- numeric(n_reps)
  evals_A <- vector("list", n_reps)
  evals_B <- vector("list", n_reps)
  conv_A <- logical(n_reps)
  conv_B <- logical(n_reps)

  for (rep_idx in seq_len(n_reps)) {
    seed <- base_seed + n_unit * 100L + rep_idx
    df <- simulate_gaussian_gllvm(n_unit = n_unit, seed = seed)

    order <- if (rep_idx %% 2L == 1L) c("A", "B") else c("B", "A")
    res <- list()
    for (arm in order) {
      se_flag <- identical(arm, "B")
      out <- tryCatch(fit_one(df, se = se_flag),
                       error = function(e) structure(list(error = conditionMessage(e)),
                                                     class = "arm_error"))
      res[[arm]] <- out
      cat(sprintf("  rep %d arm %s (se=%s): %s\n", rep_idx, arm, se_flag,
                  if (inherits(out, "arm_error")) paste("ERROR:", out$error)
                  else sprintf("%.3fs, convergence=%s", out$elapsed,
                              out$fit$opt$convergence)))
    }

    if (inherits(res$A, "arm_error") || inherits(res$B, "arm_error")) {
      cat(sprintf("  rep %d: ABORTING CELL n=%d -- an arm errored.\n", rep_idx, n_unit))
      point_only_secs[rep_idx] <- NA_real_
      point_plus_se_secs[rep_idx] <- NA_real_
      next
    }

    point_only_secs[rep_idx] <- res$A$elapsed
    point_plus_se_secs[rep_idx] <- res$B$elapsed
    evals_A[[rep_idx]] <- res$A$fit$opt$evaluations
    evals_B[[rep_idx]] <- res$B$fit$opt$evaluations
    conv_A[rep_idx] <- identical(res$A$fit$opt$convergence, 0L)
    conv_B[rep_idx] <- identical(res$B$fit$opt$convergence, 0L)
  }

  row_i <- row_i + 1L
  cell_rows[[row_i]] <- list(
    n = n_unit,
    point_only_secs = point_only_secs,
    point_plus_se_secs = point_plus_se_secs,
    evals_A = evals_A,
    evals_B = evals_B,
    conv_A = conv_A,
    conv_B = conv_B
  )
  cat("\n")
}

# ---------------------------------------------------------------------------
# Assemble results table (medians across replicates).
# ---------------------------------------------------------------------------
results <- do.call(rbind, lapply(cell_rows, function(cell) {
  ok <- !is.na(cell$point_only_secs) & !is.na(cell$point_plus_se_secs)
  if (!any(ok)) {
    return(data.frame(n = cell$n, point_only_secs = NA_real_,
                      point_plus_se_secs = NA_real_, sdreport_secs = NA_real_,
                      sdreport_pct_of_total = NA_real_, n_ok_reps = 0L))
  }
  po <- stats::median(cell$point_only_secs[ok])
  pse <- stats::median(cell$point_plus_se_secs[ok])
  sdr <- pse - po
  data.frame(
    n = cell$n,
    point_only_secs = po,
    point_plus_se_secs = pse,
    sdreport_secs = sdr,
    sdreport_pct_of_total = 100 * sdr / pse,
    n_ok_reps = sum(ok)
  )
}))

cat("=== RESULTS (median across replicates) ===\n")
print(results, row.names = FALSE)

# Sanity check: opt$evaluations should match closely between arms A and B
# within a replicate (identical objective/data/start -- se only changes
# what happens AFTER nlminb converges). Large mismatches would mean the
# timing difference is contaminated by different optimisation work, not
# purely sdreport.
cat("\n=== Sanity check: nlminb function/gradient evaluations, A vs B ===\n")
for (cell in cell_rows) {
  for (rep_idx in seq_along(cell$evals_A)) {
    eA <- cell$evals_A[[rep_idx]]
    eB <- cell$evals_B[[rep_idx]]
    if (is.null(eA) || is.null(eB)) next
    cat(sprintf("  n=%d rep=%d: A function/gradient=%s  B function/gradient=%s  conv_A=%s conv_B=%s\n",
               cell$n, rep_idx,
               paste(eA, collapse = "/"), paste(eB, collapse = "/"),
               cell$conv_A[rep_idx], cell$conv_B[rep_idx]))
  }
}

# ---------------------------------------------------------------------------
# Write results table to dev/sdreport-cost.md
# ---------------------------------------------------------------------------
md_path <- file.path(root, "dev", "sdreport-cost.md")

fmt_secs <- function(x) sprintf("%.3f", x)
fmt_pct <- function(x) sprintf("%.1f%%", x)

any_incomplete <- any(results$n_ok_reps < n_reps)
overall_pct <- results$sdreport_pct_of_total
max_pct <- suppressWarnings(max(overall_pct, na.rm = TRUE))
gate_answer <- if (all(is.na(overall_pct))) {
  "UNKNOWN -- no cell produced usable timings."
} else if (max_pct > 30) {
  sprintf("YES -- sdreport reaches %.1f%% of total time-to-inference at n=%d, above the 30%% gate.",
         max_pct, results$n[which.max(overall_pct)])
} else {
  sprintf("NO -- sdreport stays below the 30%% gate across n=200/400/800 (max observed %.1f%% at n=%d).",
         max_pct, results$n[which.max(overall_pct)])
}

md_lines <- c(
  "# sdreport() cost as a fraction of a full Laplace fit",
  "",
  sprintf("Generated by `dev/sdreport-cost.R` on %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "DGP: Gaussian, 8 traits, q = 2 latent axes, `latent(1 | unit, d = q, unique = FALSE)`",
  sprintf("(loadings-only, no Psi). Each n cell: %d replicates, A (se=FALSE) vs B (se=TRUE) fit on", n_reps),
  "the SAME simulated dataset per replicate, A/B order alternated across replicates. A",
  "discarded warm-up fit precedes the timed grid to absorb the one-time TMB compile",
  "penalty. Values below are MEDIANS across replicates (not single draws).",
  "",
  "| n | point_only_secs | point_plus_se_secs | sdreport_secs | sdreport_pct_of_total |",
  "|---|---|---|---|---|"
)
for (i in seq_len(nrow(results))) {
  r <- results[i, ]
  md_lines <- c(md_lines, sprintf(
    "| %d | %s | %s | %s | %s |",
    r$n,
    if (is.na(r$point_only_secs)) "NA (fit failed)" else fmt_secs(r$point_only_secs),
    if (is.na(r$point_plus_se_secs)) "NA (fit failed)" else fmt_secs(r$point_plus_se_secs),
    if (is.na(r$sdreport_secs)) "NA" else fmt_secs(r$sdreport_secs),
    if (is.na(r$sdreport_pct_of_total)) "NA" else fmt_pct(r$sdreport_pct_of_total)
  ))
}
md_lines <- c(
  md_lines, "",
  if (any_incomplete)
    sprintf("**Incomplete replicates:** %s.",
           paste(sprintf("n=%d had %d/%d usable reps", results$n, results$n_ok_reps, n_reps),
                 collapse = "; "))
  else
    sprintf("All cells completed %d/%d usable replicates.", n_reps, n_reps),
  "",
  "## Verdict",
  "",
  gate_answer
)
writeLines(md_lines, md_path)
cat("\nWrote", md_path, "\n")
