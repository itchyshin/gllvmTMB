## dev/isdm-bias-run-reduced.R
##
## REDUCED Phase C run ("C-lite"). NOT the pre-registered campaign.
##
## Why this file exists: the pre-registered Phase C campaign
## (dev/isdm-phase-c-design.md, 21,300 fits) was never run -- the harness and
## runner were committed UNSMOKED/UNRUN at 30129160 and no results file was
## ever produced. This script runs the smallest slice that can address the
## PRIMARY ENDPOINT (P4) and the headline distortion CURVE, at reduced seed
## count. Every deviation from the pre-registered design is listed in
## dev/isdm-bias-findings.md; the frozen thresholds (0.10, 0.05, 3 MCSE) are
## NOT altered.
##
## Slice: 8 configs x S seeds x 6 arms, all at n=400, T=8, d_fit=2, k=3,
## phi=0.15. Blocks G2..G6 (n-ladder, T-ladder, d_fit, k=1, smoothness) are
## NOT run.
##
## Usage: NOT_CRAN=true Rscript dev/isdm-bias-run-reduced.R <S>
## Lane rule: worktree-only. No PR, no merge, no push. Do not touch src/.

source("dev/isdm-bias-harness.R")

REF_C <- list(phi = 0.15, n = 400, T_sp = 8, d_fit = 2, k = 3)

.cfg_row <- function(kappa, rho, omega, seed, tag) {
  as.data.frame(c(REF_C, list(kappa = kappa, rho = rho, omega = omega,
                              seed = seed, block = tag)))
}

build_config_lite <- function(seeds) {
  spec <- list(
    ## kappa = 0 null: rho/omega collapse (no field); shared by every contrast
    list(0.00, 0,   1,   "NULL"),
    ## the distortion ladder, at the PRIMARY endpoint's rho = 0, omega = 1
    list(0.25, 0,   1,   "K025"),
    list(0.50, 0,   1,   "K050"),
    list(1.00, 0,   1,   "K100"),   # <- PRIMARY ENDPOINT (P4)
    list(2.00, 0,   1,   "K200"),
    ## cross-species sharing contrast at kappa = 1, rho = 0
    list(1.00, 0,   0.5, "W050"),
    list(1.00, 0,   0,   "W000"),
    ## environmental confounding contrast at kappa = 1, omega = 1
    list(1.00, 0.6, 1,   "RHO6")
  )
  rows <- list()
  for (s in seeds) for (sp in spec) {
    rows[[length(rows) + 1]] <- .cfg_row(sp[[1]], sp[[2]], sp[[3]], s, sp[[4]])
  }
  do.call(rbind, rows)
}

if (sys.nframe() == 0L) {
  ARGS <- commandArgs(trailingOnly = TRUE)
  S <- if (length(ARGS) >= 1L) as.integer(ARGS[[1]]) else 10L
  OUT <- if (length(ARGS) >= 2L) ARGS[[2]] else "dev/isdm-bias-results.rds"
  N_CORES <- max(1L, min(18L, parallel::detectCores() - 2L))
  cfg <- build_config_lite(seq_len(S))
  cat(sprintf("C-lite: S=%d seeds, %d dataset rows x %d arms = %d fits on %d cores\n",
              S, nrow(cfg), length(ARMS), nrow(cfg) * length(ARMS), N_CORES))
  t0 <- Sys.time()
  res <- run_grid_c(cfg, n_cores = N_CORES, backend = "mclapply")
  cat(sprintf("elapsed: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
  saveRDS(res, OUT)
  cat("wrote", OUT, "rows:", nrow(res), "\n")
}
