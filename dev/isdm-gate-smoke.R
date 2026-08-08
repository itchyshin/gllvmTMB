## dev/isdm-gate-smoke.R
##
## SMOKE test of dev/isdm-gate-harness.R -- NOT the full grid.
## Runs: PB @ n=200, prevalence=0.3, seed=1, both arms (U1, U0) end to end;
## PP and BB once each at the same n/prevalence/seed/arm=U1; one PB n=1600
## timing fit; then projects the full-grid core-hours / wall-clock.
##
## Run with: Rscript dev/isdm-gate-smoke.R
## Lane rule: this worktree only. Do not touch R/, src/, tests/.

source("dev/isdm-gate-harness.R")

hr <- function(x) cat("\n", strrep("=", 12), x, strrep("=", 12), "\n", sep = "")

all_rows <- list()
timings <- list()

## =========================================================================
## Planted truth
## =========================================================================
hr("Planted truth")
cat("Lambda_true:", paste(sprintf("%s=%.3f", names(PLANTED$Lambda), PLANTED$Lambda), collapse = ", "), "\n")
cat("psi_true:   ", paste(sprintf("%s=%.3f", names(PLANTED$psi), PLANTED$psi), collapse = ", "), "\n")

## =========================================================================
## SMOKE 1: PB @ n=200, prevalence=0.3, seed=1 -- both arms
## =========================================================================
hr("SMOKE 1: PB, n=200, prevalence=0.3, seed=1, arm=U1")

t0 <- Sys.time()
row_pb_u1 <- run_one(list(cell = "PB", n_units = 200, prevalence = 0.3, seed = 1, arm = "U1"))
timings$pb_u1_n200 <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("PB U1 fit time: %.2f s\n", timings$pb_u1_n200))
cat("Scored row (full):\n"); print(row_pb_u1)
all_rows$pb_u1 <- row_pb_u1

## Inspect one fit past its guards -- confirm no silent all-NA from a
## guard-blocked operation.
df_pb <- simulate_cell("PB", 200, 0.3, seed = 1, planted = PLANTED)
fit_pb_u1 <- fit_cell(df_pb, arm = "U1")
cat("\nfit_pb_u1 top-level names:\n"); print(names(fit_pb_u1))
cat("convergence:", fit_pb_u1$opt$convergence, " pdHess:", fit_pb_u1$sd_report$pdHess, "\n")
cat("diag_B_skip (per-species pin flag):", paste(fit_pb_u1$tmb_data$diag_B_skip, collapse = ","), "\n")
Lambda_hat_pb <- extract_loadings(fit_pb_u1, level = "unit")
cat("\nextract_loadings(fit_pb_u1):\n"); print(Lambda_hat_pb)
cat("any NA in Lambda_hat:", anyNA(Lambda_hat_pb), "\n")
psi_hat_pb <- extract_Sigma(fit_pb_u1, level = "unit", part = "unique", link_residual = "none")$s
cat("psi_hat (part='unique'):", paste(sprintf("%.4g", psi_hat_pb), collapse = ", "), "\n")
cat("any NA in psi_hat:", anyNA(psi_hat_pb), "\n")

hr("SMOKE 1b: PB, n=200, prevalence=0.3, seed=1, arm=U0")
t0 <- Sys.time()
row_pb_u0 <- run_one(list(cell = "PB", n_units = 200, prevalence = 0.3, seed = 1, arm = "U0"))
timings$pb_u0_n200 <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("PB U0 fit time: %.2f s\n", timings$pb_u0_n200))
cat("Scored row (full):\n"); print(row_pb_u0)
all_rows$pb_u0 <- row_pb_u0

## =========================================================================
## SMOKE 2: PP and BB, same n/prevalence/seed, arm=U1
## =========================================================================
hr("SMOKE 2: PP, n=200, prevalence=0.3, seed=1, arm=U1")
t0 <- Sys.time()
row_pp_u1 <- run_one(list(cell = "PP", n_units = 200, prevalence = 0.3, seed = 1, arm = "U1"))
timings$pp_u1_n200 <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("PP U1 fit time: %.2f s\n", timings$pp_u1_n200))
print(row_pp_u1)
all_rows$pp_u1 <- row_pp_u1

hr("SMOKE 2b: BB, n=200, prevalence=0.3, seed=1, arm=U1")
t0 <- Sys.time()
row_bb_u1 <- run_one(list(cell = "BB", n_units = 200, prevalence = 0.3, seed = 1, arm = "U1"))
timings$bb_u1_n200 <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("BB U1 fit time: %.2f s\n", timings$bb_u1_n200))
print(row_bb_u1)
all_rows$bb_u1 <- row_bb_u1

## Explicitly check whether the BB psi-pinning trap fired (diag_B_skip).
df_bb <- simulate_cell("BB", 200, 0.3, seed = 1, planted = PLANTED)
fit_bb_u1 <- fit_cell(df_bb, arm = "U1")
cat("\nBB U1 diag_B_skip (per-species, 1 = psi pinned to 1e-6):",
    paste(fit_bb_u1$tmb_data$diag_B_skip, collapse = ","), "\n")
psi_hat_bb <- extract_Sigma(fit_bb_u1, level = "unit", part = "unique", link_residual = "none")$s
cat("BB U1 psi_hat:", paste(sprintf("%.4g", psi_hat_bb), collapse = ", "), "\n")

hr("SMOKE 2c: PP and BB, arm=U0 (for completeness / cross-cell comparability)")
t0 <- Sys.time()
row_pp_u0 <- run_one(list(cell = "PP", n_units = 200, prevalence = 0.3, seed = 1, arm = "U0"))
timings$pp_u0_n200 <- as.numeric(Sys.time() - t0, units = "secs")
print(row_pp_u0)
all_rows$pp_u0 <- row_pp_u0

t0 <- Sys.time()
row_bb_u0 <- run_one(list(cell = "BB", n_units = 200, prevalence = 0.3, seed = 1, arm = "U0"))
timings$bb_u0_n200 <- as.numeric(Sys.time() - t0, units = "secs")
print(row_bb_u0)
all_rows$bb_u0 <- row_bb_u0

## =========================================================================
## SMOKE 3: timing at n=1600 (PB, U1) to extrapolate the full grid
## =========================================================================
hr("SMOKE 3: PB, n=1600, prevalence=0.3, seed=1, arm=U1 -- timing only")
t0 <- Sys.time()
row_pb_u1_n1600 <- run_one(list(cell = "PB", n_units = 1600, prevalence = 0.3, seed = 1, arm = "U1"))
timings$pb_u1_n1600 <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("PB U1 n=1600 fit time: %.2f s\n", timings$pb_u1_n1600))
print(row_pb_u1_n1600)
all_rows$pb_u1_n1600 <- row_pb_u1_n1600

## =========================================================================
## Combined results table
## =========================================================================
hr("Combined smoke results")
results_df <- do.call(rbind, all_rows)
rownames(results_df) <- NULL
print(results_df)

## =========================================================================
## Timing summary + full-grid projection
## =========================================================================
hr("Timing summary (seconds per fit)")
for (nm in names(timings)) cat(sprintf("  %-16s %.3f s\n", nm, timings[[nm]]))

## Grid: 3 cells x 5 n x 4 prevalences x 100 seeds x 2 arms = 12000 fits.
## Per-fit cost model: use the n=200 PB/PP/BB times as representative of the
## small end, and the single n=1600 PB timing point to extrapolate the
## n-scaling (assume a power law using the two PB U1 timing points we have:
## n=200 and n=1600 -- 3 doublings).
n_small <- 200
n_big <- 1600
t_small <- timings$pb_u1_n200
t_big <- timings$pb_u1_n1600
## power-law exponent from two points: t ~ n^k
k <- log(t_big / t_small) / log(n_big / n_small)
cat(sprintf("\nEstimated n-scaling exponent (PB, from n=200 -> n=1600): k = %.3f (t ~ n^k)\n", k))

cost_at_n <- function(n, base_cell_time) {
  base_cell_time * (n / n_small)^k
}

## Representative per-fit time for each cell type at n=200 (U1 arm; U0 timed
## once for PB and assumed comparable -- see findings note).
cell_base_time <- c(PP = timings$pp_u1_n200, BB = timings$bb_u1_n200, PB = timings$pb_u1_n200)

grid_n <- N_LADDER
total_fit_seconds <- 0
for (cell in CELL_TYPES) {
  for (n in grid_n) {
    per_fit <- cost_at_n(n, cell_base_time[[cell]])
    n_configs <- length(PREVALENCE_LADDER) * 100 * 2  # prevalences x seeds x arms
    total_fit_seconds <- total_fit_seconds + per_fit * n_configs
  }
}
total_core_hours <- total_fit_seconds / 3600
n_fits_total <- length(CELL_TYPES) * length(grid_n) * length(PREVALENCE_LADDER) * 100 * 2
cat(sprintf("\nFull grid: %d fits (3 cells x %d n x %d prevalences x 100 seeds x 2 arms)\n",
            n_fits_total, length(grid_n), length(PREVALENCE_LADDER)))
cat(sprintf("Projected total core-seconds: %.0f\n", total_fit_seconds))
cat(sprintf("Projected total core-hours:   %.2f\n", total_core_hours))
cat(sprintf("Estimated wall-clock at 120 cores: %.2f hours (%.1f minutes)\n",
            total_core_hours / 120, total_core_hours / 120 * 60))
cat(sprintf("Estimated wall-clock at 384 cores: %.2f hours (%.1f minutes)\n",
            total_core_hours / 384, total_core_hours / 384 * 60))

## =========================================================================
## Write findings file
## =========================================================================
hr("Writing findings file")

findings_path <- "dev/isdm-gate-smoke-findings.md"
sink(findings_path)
cat("# ISDM Design-108-style mixed-curvature gate: SMOKE findings\n\n")
cat("Harness: `dev/isdm-gate-harness.R`. Smoke runner: `dev/isdm-gate-smoke.R`.\n")
cat("Package: gllvmTMB **0.6.0** (installed, `library(gllvmTMB)`). R 4.6.0.\n")
cat("This is a SMOKE test only -- NOT the full grid.\n\n")

cat("## Planted truth\n\n")
cat("```\n")
cat("Lambda_true:", paste(sprintf("%s=%.3f", names(PLANTED$Lambda), PLANTED$Lambda), collapse = ", "), "\n")
cat("psi_true:   ", paste(sprintf("%s=%.3f", names(PLANTED$psi), PLANTED$psi), collapse = ", "), "\n")
cat("```\n\n")

cat("## Design\n\n")
cat("T = 6 species, d = 1 latent factor. Each (cell, species) contributes\n")
cat("two rows (block1, block2) sharing the same latent score u_i and the\n")
cat("same loading lambda_j. Cells: PP (both blocks Poisson-log), BB (both\n")
cat("blocks Bernoulli-cloglog), PB (block1 Poisson-log, block2\n")
cat("Bernoulli-cloglog -- the gate cell). Two arms: U1 (`latent(unique =\n")
cat("TRUE)`, Sigma = Lambda Lambda' + diag(psi), the package's real\n")
cat("estimand) and U0 (`unique = FALSE`, Sigma = Lambda Lambda' only, all\n")
cat("three cells strictly comparable).\n\n")

cat("## Smoke results (n=200, prevalence=0.3, seed=1)\n\n")
cat("```\n")
print(results_df)
cat("```\n\n")

cat("## Guard-inspection past the fit (PB, U1, n=200, seed=1)\n\n")
cat("```\n")
cat("convergence:", fit_pb_u1$opt$convergence, " pdHess:", fit_pb_u1$sd_report$pdHess, "\n")
cat("diag_B_skip (per-species pin flag):", paste(fit_pb_u1$tmb_data$diag_B_skip, collapse = ","), "\n")
cat("Lambda_hat:\n"); print(Lambda_hat_pb)
cat("any NA in Lambda_hat:", anyNA(Lambda_hat_pb), "\n")
cat("psi_hat:", paste(sprintf("%.4g", psi_hat_pb), collapse = ", "), "\n")
cat("any NA in psi_hat:", anyNA(psi_hat_pb), "\n")
cat("```\n\n")

cat("## BB psi-pinning check (arm=U1, n=200, seed=1)\n\n")
cat("```\n")
cat("diag_B_skip (1 = psi pinned to 1e-6):", paste(fit_bb_u1$tmb_data$diag_B_skip, collapse = ","), "\n")
cat("psi_hat:", paste(sprintf("%.4g", psi_hat_bb), collapse = ", "), "\n")
cat("```\n\n")

cat("## Timings\n\n")
cat("```\n")
for (nm in names(timings)) cat(sprintf("  %-16s %.3f s\n", nm, timings[[nm]]))
cat(sprintf("\nn-scaling exponent (PB, n=200 -> n=1600): k = %.3f (t ~ n^k)\n", k))
cat("```\n\n")

cat("## Full-grid projection\n\n")
cat("```\n")
cat(sprintf("Full grid: %d fits (3 cells x %d n x %d prevalences x 100 seeds x 2 arms)\n",
            n_fits_total, length(grid_n), length(PREVALENCE_LADDER)))
cat(sprintf("Projected total core-hours:   %.2f\n", total_core_hours))
cat(sprintf("Estimated wall-clock at 120 cores: %.2f hours (%.1f minutes)\n",
            total_core_hours / 120, total_core_hours / 120 * 60))
cat(sprintf("Estimated wall-clock at 384 cores: %.2f hours (%.1f minutes)\n",
            total_core_hours / 384, total_core_hours / 384 * 60))
cat("```\n")
sink()

cat("Findings written to:", findings_path, "\n")

hr("DONE")
