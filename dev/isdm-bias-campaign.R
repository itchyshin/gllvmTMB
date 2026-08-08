## dev/isdm-bias-campaign.R
##
## Phase C campaign runner: builds the configuration tables for G1..G6 (plus
## the pilot) exactly as specified in dev/isdm-phase-c-design.md's grid
## table, and drives them through dev/isdm-bias-harness.R's run_grid_c().
##
## PER THE TASK BRIEF: THIS FILE DOES NOT AUTO-RUN THE CAMPAIGN. Sourcing it
## only defines config-builder functions and a dispatcher; nothing executes
## at top level. To actually run a block, call e.g.
##   Rscript dev/isdm-bias-campaign.R pilot
## which requires an EXPLICIT stage name on the command line (unlike
## dev/isdm-gate-campaign.R, whose default is "all stages" -- deliberately
## not mirrored here, since the task brief says stop after building).
##
## Lane rule: worktree-only. No PR, no merge, no push. Do not touch src/.

source("dev/isdm-bias-harness.R")

REF <- list(kappa = 1, rho = 0.6, omega = 0.5, phi = 0.15, n = 400, T_sp = 8, d_fit = 2, k = 3)

## A "null" row shares every geometry parameter with its paired block but
## always has kappa = 0 (which collapses rho/omega/phi -- D4/the grid table
## note -- so their values here are inert and kept at REF's for bookkeeping
## only).
.null_row <- function(overrides = list()) {
  base <- REF; base$kappa <- 0
  base[names(overrides)] <- overrides
  base
}

.mk_config <- function(rows, block) {
  df <- do.call(rbind, lapply(rows, as.data.frame))
  df$block <- block
  df
}

## =========================================================================
## G1 -- main grid: kappa x rho x omega, n=400, T=8, d_fit=2, k=3
##   1 null + 4*2*3 = 25 configs; x seeds x 6 arms (arms handled inside
##   run_dataset_c(), not expanded here) -> 25 * seeds dataset rows.
## =========================================================================
build_config_g1 <- function(seeds) {
  rows <- list()
  for (s in seeds) rows[[length(rows) + 1]] <- .null_row(list(seed = s))
  for (kappa in c(0.25, 0.5, 1, 2)) {
    for (rho in c(0, 0.6)) {
      for (omega in c(1, 0.5, 0)) {
        for (s in seeds) {
          rows[[length(rows) + 1]] <- modifyList(
            REF, list(kappa = kappa, rho = rho, omega = omega, seed = s)
          )
        }
      }
    }
  }
  .mk_config(rows, "G1")
}

## =========================================================================
## G2 -- n-ladder: n in {100, 1600} (400 is in G1); null + REF, per n
## =========================================================================
build_config_g2 <- function(seeds) {
  rows <- list()
  for (n in c(100, 1600)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- .null_row(list(n = n, seed = s))
      rows[[length(rows) + 1]] <- modifyList(REF, list(n = n, seed = s))
    }
  }
  .mk_config(rows, "G2")
}

## =========================================================================
## G3 -- species-ladder: T_sp in {6, 12} (8 is in G1); null + REF, per T_sp
## =========================================================================
build_config_g3 <- function(seeds) {
  rows <- list()
  for (T_sp in c(6, 12)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- .null_row(list(T_sp = T_sp, seed = s))
      rows[[length(rows) + 1]] <- modifyList(REF, list(T_sp = T_sp, seed = s))
    }
  }
  .mk_config(rows, "G3")
}

## =========================================================================
## G4 -- d_fit sensitivity: d_fit in {1, 3} (truth stays d = 2); null + REF
## =========================================================================
build_config_g4 <- function(seeds) {
  rows <- list()
  for (d_fit in c(1, 3)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- .null_row(list(d_fit = d_fit, seed = s))
      rows[[length(rows) + 1]] <- modifyList(REF, list(d_fit = d_fit, seed = s))
    }
  }
  .mk_config(rows, "G4")
}

## =========================================================================
## G5 -- k = 1 sensitivity (retriggers the theta_diag_B skip for A2 alone,
## D6); null + REF at k = 1
## =========================================================================
build_config_g5 <- function(seeds) {
  rows <- list()
  for (s in seeds) {
    rows[[length(rows) + 1]] <- .null_row(list(k = 1, seed = s))
    rows[[length(rows) + 1]] <- modifyList(REF, list(k = 1, seed = s))
  }
  .mk_config(rows, "G5")
}

## =========================================================================
## G6 -- smoothness: phi in {0, 0.4} at the REF bias setting only (kappa=1,
## rho=0.6, omega=0.5); reuses G1's null (kappa=0) as the paired baseline --
## i.e. G6 contributes ONLY the two REF-bias-setting phi rows, not a second
## null (per the design doc's fit-count table: "1 (REF), reusing G1's null").
## =========================================================================
build_config_g6 <- function(seeds) {
  rows <- list()
  for (phi in c(0, 0.4)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- modifyList(REF, list(phi = phi, seed = s))
    }
  }
  .mk_config(rows, "G6")
}

## =========================================================================
## Pilot -- G1's 25 configs at S = 10 seeds (1,500 fits: 25*10*6)
## =========================================================================
build_config_pilot <- function(seeds = 1:10) build_config_g1(seeds)

## =========================================================================
## Fit-count sanity check (no simulation, no fitting -- just arithmetic)
## =========================================================================
expected_fit_counts <- function() {
  c(
    G1     = nrow(build_config_g1(1:100))    * length(ARMS),
    G2     = nrow(build_config_g2(1:50))     * length(ARMS),
    G3     = nrow(build_config_g3(1:50))     * length(ARMS),
    G4     = nrow(build_config_g4(1:50))     * length(ARMS),
    G5     = nrow(build_config_g5(1:50))     * length(ARMS),
    G6     = nrow(build_config_g6(1:50))     * length(ARMS),
    pilot  = nrow(build_config_pilot(1:10))  * length(ARMS)
  )
}

## =========================================================================
## Pre-flight gates (P0-1 .. P0-6). Each is a single small, fast check.
## Call run_preflight_gates() explicitly; not run on source().
## =========================================================================
`%||%` <- function(a, b) if (is.null(a)) b else a

run_preflight_gates <- function(n_cores = 1L) {
  hr <- function(x) cat("\n", strrep("=", 12), " ", x, " ", strrep("=", 12), "\n", sep = "")
  truth <- species_truth(8)

  hr("P0-1/P0-2/P0-6: one REF dataset, all six arms")
  df <- sim_phase_c(seed = 1, n = REF$n, T_sp = REF$T_sp, phi = REF$phi,
                     kappa = REF$kappa, rho = REF$rho, omega = REF$omega, k = REF$k, truth = truth)
  stopifnot(nrow(df) == REF$n * REF$T_sp * 2)
  cat("P0-1 nrow OK:", nrow(df), "\n")

  cfg <- as.list(REF); cfg$seed <- 1; cfg$block <- "preflight"
  for (a in ARMS) {
    fit <- tryCatch(fit_arm(df, arm = a, d_fit = REF$d_fit), error = function(e) e)
    if (inherits(fit, "condition")) {
      cat(sprintf("P0-6 FAIL [%s]: %s\n", a, conditionMessage(fit))); next
    }
    if (a == "A5") {
      dbs <- sum(fit$tmb_data$diag_B_skip %||% 0)
      cat("P0-1 diag_B_skip (A5, expect 0):", dbs, "\n")
    }
    if (a == "A6") {
      nb <- sum(grepl(":bstar$", fit$X_fix_names))
      cat("P0-6 A6 trait:bstar columns (expect T=8):", nb, "\n")
    }
    Sres <- tryCatch(extract_Sigma(fit, level = "unit", part = "total", link_residual = "none"),
                      error = function(e) e)
    if (!inherits(Sres, "condition")) {
      R <- Sres$R
      cat(sprintf("P0-2 [%s] max|off-diag R|=%.4f any NA=%s\n",
                  a, max(abs(R[upper.tri(R)])), anyNA(R)))
    }
  }
  invisible(NULL)
}

## =========================================================================
## Dispatch (Rscript-only; sourcing this file never runs anything)
## =========================================================================
if (sys.nframe() == 0L) {
  ARGS <- commandArgs(trailingOnly = TRUE)
  if (length(ARGS) == 0L) {
    cat("dev/isdm-bias-campaign.R: no stage given, nothing executed.\n")
    cat("Available stages: preflight, pilot, g1, g2, g3, g4, g5, g6, counts\n")
    cat("Usage: Rscript dev/isdm-bias-campaign.R <stage> [<stage> ...]\n")
  } else {
    N_CORES <- max(1L, min(18L, parallel::detectCores() - 2L))
    if ("counts" %in% ARGS) print(expected_fit_counts())
    if ("preflight" %in% ARGS) run_preflight_gates()
    if ("pilot" %in% ARGS) {
      cfg <- build_config_pilot()
      cat(sprintf("pilot: %d dataset rows x %d arms = %d fits\n",
                  nrow(cfg), length(ARMS), nrow(cfg) * length(ARMS)))
      res <- run_grid_c(cfg, n_cores = N_CORES, backend = "mclapply")
      saveRDS(res, "dev/isdm-bias-pilot-results.rds")
    }
    for (g in c("g1", "g2", "g3", "g4", "g5", "g6")) {
      if (g %in% ARGS) {
        builder <- get(paste0("build_config_", g))
        seeds <- if (g == "g1") 1:100 else 1:50
        cfg <- builder(seeds)
        cat(sprintf("%s: %d dataset rows x %d arms = %d fits\n",
                    g, nrow(cfg), length(ARMS), nrow(cfg) * length(ARMS)))
        res <- run_grid_c(cfg, n_cores = N_CORES, backend = "mclapply")
        saveRDS(res, sprintf("dev/isdm-bias-%s-results.rds", g))
      }
    }
  }
}
