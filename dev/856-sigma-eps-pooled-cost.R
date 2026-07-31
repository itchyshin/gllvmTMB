## Issue #856 -- the measured cost of the pooled scalar sigma_eps.
##
## `src/gllvmTMB.cpp:582` declares `PARAMETER(log_sigma_eps)` as ONE scalar
## residual log-SD shared across every gaussian (fid 0) and lognormal (fid 3)
## row, while every other family gets a `PARAMETER_VECTOR` of length n_traits.
##
## This script quantifies what that costs. The design deliberately includes
## REPLICATES per (unit, trait) cell so that a per-trait sigma_eps_t WOULD be
## identifiable -- that isolates the *restriction* from the RE-09 / Q7
## identifiability confound, which only bites at one row per cell.
##
## Expected result (recorded 2026-07-30, seed 2026): the fitted scalar lands on
## the root-mean-square of the true per-trait SDs, which is exactly what a
## single pooled gaussian scale can represent -- while a model-free
## within-cell estimator recovers both truths almost exactly. The per-trait
## information is present in the data; the model cannot express it.
##
## Companion: dev/856-sigma-eps-degenerate-probe.R measures the DEGENERATE
## (no-replicate) case, which is the one Q7 already guards.

## load_all(), NOT library(): `library(gllvmTMB)` would load the INSTALLED
## package and silently report pre-fix behaviour on a branch that has the fix.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
set.seed(2026)

n_unit <- 120L
R_rep  <- 3L                        # replicates per (unit, trait) -> identified
sd_e   <- c(t1 = 0.2, t2 = 2.0)     # TRUE per-trait residual SDs (10x apart)
sd_u   <- c(t1 = 1.0, t2 = 1.0)     # unit-level per-trait SDs
mu     <- c(t1 = 0.0, t2 = 0.0)

u <- cbind(t1 = rnorm(n_unit, 0, sd_u[1]), t2 = rnorm(n_unit, 0, sd_u[2]))

df <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  do.call(rbind, lapply(1:2, function(tt) {
    data.frame(
      unit  = i,
      trait = paste0("t", tt),
      value = mu[tt] + u[i, tt] + rnorm(R_rep, 0, sd_e[tt])
    )
  }))
}))
df$unit  <- factor(df$unit)
df$trait <- factor(df$trait)

cat("rows:", nrow(df), " units:", nlevels(df$unit), " reps/cell:", R_rep, "\n")
cat("TRUE sigma_eps: t1 =", sd_e[1], " t2 =", sd_e[2], "\n\n")

fit <- suppressMessages(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = df, unit = "unit", trait = "trait"
))

rep_ <- fit$report
cat("converged:", fit$opt$convergence, "\n")
cat("FITTED sigma_eps:", signif(rep_$sigma_eps, 5),
    " (length", length(rep_$sigma_eps), ")\n\n")

## What a pooled scalar can at best represent: the RMS of the true SDs.
pooled_rms <- sqrt(mean(sd_e^2))
cat("RMS of true SDs (best a scalar can do):", signif(pooled_rms, 5), "\n")
if (length(rep_$sigma_eps) == 1L) {
  cat("ratio fitted/RMS:", signif(rep_$sigma_eps / pooled_rms, 4),
      "  <- a ratio near 1 confirms the scalar is the RMS compromise\n\n")
} else {
  cat("sigma_eps is per-trait; per-trait errors:",
      paste(signif(rep_$sigma_eps - sd_e, 3), collapse = ", "), "\n\n")
}

## Model-free: the pooled within-cell SD differences out the unit-level
## random intercept without fitting anything. If this recovers the truths,
## the per-trait information IS in the data.
cellvar <- aggregate(value ~ unit + trait, data = df, FUN = var)
pooled  <- tapply(cellvar$value, cellvar$trait, function(v) sqrt(mean(v)))
cat("model-free within-cell SD: t1 =", signif(pooled[["t1"]], 4),
    " t2 =", signif(pooled[["t2"]], 4), "\n")
cat("(true 0.2 / 2.0 -- so the information is present and estimable)\n")
