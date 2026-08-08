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
## Pre-flight gates (P0-1 .. P0-6), followed by the handover's paired
## low/high-bias smoke. Call these explicitly; neither runs on source().
## =========================================================================
`%||%` <- function(a, b) if (is.null(a)) b else a

.detect_cores_c <- function(cap = 18L) {
  detected <- suppressWarnings(parallel::detectCores())
  if (length(detected) != 1L || !is.finite(detected)) return(1L)
  max(1L, min(as.integer(cap), as.integer(detected) - 2L))
}

run_preflight_gates <- function(n_cores = 1L) {
  if (length(n_cores) != 1L || !is.finite(n_cores) || n_cores < 1L) n_cores <- 1L
  n_cores <- as.integer(n_cores)
  hr <- function(x) cat("\n", strrep("=", 12), " ", x, " ", strrep("=", 12), "\n", sep = "")
  truth <- species_truth(8)

  hr("P0-1/P0-2/P0-3/P0-6: one REF dataset, all six arms")
  df <- sim_phase_c(seed = 1, n = REF$n, T_sp = REF$T_sp, phi = REF$phi,
                     kappa = REF$kappa, rho = REF$rho, omega = REF$omega, k = REF$k, truth = truth)
  stopifnot(nrow(df) == REF$n * REF$T_sp * 2)
  cat("P0-1 nrow OK:", nrow(df), "\n")

  cfg <- as.list(REF); cfg$seed <- 1; cfg$block <- "preflight"
  fits <- setNames(vector("list", length(ARMS)), ARMS)
  scores <- setNames(vector("list", length(ARMS)), ARMS)
  for (a in ARMS) {
    fit <- tryCatch(fit_arm(df, arm = a, d_fit = REF$d_fit), error = function(e) e)
    if (inherits(fit, "condition")) {
      stop(sprintf("P0-6 FAIL [%s]: %s", a, conditionMessage(fit)), call. = FALSE)
    }
    fits[[a]] <- fit
    scores[[a]] <- score_phase_c(
      fit, a, cfg, truth,
      realised_prevalence = attr(df, "realised_prevalence"),
      bias_sharing = attr(df, "bias_sharing")
    )
  }

  a5 <- fits$A5
  source_chr <- as.character(a5$data$source)
  family_by_source <- split(a5$tmb_data$family_id_vec, source_chr)
  clean_family_map <- length(family_by_source) == 2L &&
    all(vapply(family_by_source, function(x) length(unique(x)) == 1L, logical(1))) &&
    length(unique(vapply(family_by_source, function(x) unique(x)[1], integer(1)))) == 2L
  if (!clean_family_map) stop("P0-1 FAIL: family_id_vec does not map cleanly to source", call. = FALSE)
  cat("P0-1 family_id_vec x source:\n")
  print(table(a5$tmb_data$family_id_vec, source_chr))

  dbs <- sum(a5$tmb_data$diag_B_skip %||% 0)
  cat("P0-1 diag_B_skip (A5, expect 0):", dbs, "\n")
  if (dbs != 0L) stop("P0-1 FAIL: A5 diag_B_skip is non-zero", call. = FALSE)

  Sres <- tryCatch(
    extract_Sigma(a5, level = "unit", part = "total", link_residual = "none"),
    error = function(e) e
  )
  if (inherits(Sres, "condition")) {
    stop("P0-2 FAIL: ", conditionMessage(Sres), call. = FALSE)
  }
  R <- Sres$R
  max_off <- max(abs(R[upper.tri(R)]))
  cat(sprintf("P0-2 A5 R: dim=%s max|off-diag|=%.4f any NA=%s\n",
              paste(dim(R), collapse = "x"), max_off, anyNA(R)))
  if (!all(dim(R) == c(REF$T_sp, REF$T_sp)) || anyNA(R) || max_off >= 0.999) {
    stop("P0-2 FAIL: A5 returned a missing or degenerate correlation matrix", call. = FALSE)
  }

  trials_by_source <- split(a5$tmb_data$n_trials, source_chr)
  expected_trials <- c(po = 1, pa = REF$k)
  clean_trials <- all(names(expected_trials) %in% names(trials_by_source)) &&
    all(vapply(names(expected_trials), function(src) {
      identical(unique(as.numeric(trials_by_source[[src]])), expected_trials[[src]])
    }, logical(1)))
  cat("P0-3 n_trials x source:\n")
  print(table(a5$tmb_data$n_trials, source_chr))
  if (!clean_trials) {
    stop("P0-3 FAIL: multi-trial binomial counts did not survive family_var dispatch", call. = FALSE)
  }

  nb <- sum(grepl(":bstar$", fits$A6$X_fix_names))
  cat("P0-6 A6 trait:bstar columns (expect T=8):", nb, "\n")
  if (nb != REF$T_sp) stop("P0-6 FAIL: A6 bias columns do not match T", call. = FALSE)

  hr("P0-4/P0-5: 10-seed A5 null recovery and timing")
  run_null_seed <- function(seed) {
    null_cfg <- as.list(REF)
    null_cfg$kappa <- 0
    null_cfg$seed <- seed
    null_cfg$block <- "preflight-null"
    null_df <- sim_phase_c(
      seed = seed, n = null_cfg$n, T_sp = null_cfg$T_sp, phi = null_cfg$phi,
      kappa = 0, rho = null_cfg$rho, omega = null_cfg$omega, k = null_cfg$k,
      truth = truth
    )
    t0 <- Sys.time()
    fit <- tryCatch(fit_arm(null_df, arm = "A5", d_fit = null_cfg$d_fit), error = function(e) e)
    elapsed <- as.numeric(Sys.time() - t0, units = "secs")
    score_phase_c(
      fit, "A5", null_cfg, truth, elapsed_sec = elapsed,
      realised_prevalence = attr(null_df, "realised_prevalence"),
      bias_sharing = attr(null_df, "bias_sharing")
    )
  }
  seeds <- 1:10
  null_rows <- if (n_cores > 1L && .Platform$OS.type != "windows") {
    parallel::mclapply(seeds, run_null_seed, mc.cores = min(as.integer(n_cores), length(seeds)))
  } else {
    lapply(seeds, run_null_seed)
  }
  null_res <- do.call(rbind, null_rows)
  if (any(!is.na(null_res$fit_error))) {
    stop("P0-4 FAIL: null recovery fit error: ",
         paste(unique(stats::na.omit(null_res$fit_error)), collapse = "; "), call. = FALSE)
  }
  required <- c("D_rmse", "D_bias", "realised_prevalence", "elapsed_sec")
  if (any(!vapply(null_res[required], function(x) all(is.finite(x)), logical(1)))) {
    stop("P0-4 FAIL: null recovery returned a non-finite required metric", call. = FALSE)
  }
  mean_rmse <- mean(null_res$D_rmse)
  mean_bias <- mean(null_res$D_bias)
  bias_mcse <- .mcse_mean(null_res$D_bias)
  pooled_prev <- mean(null_res$realised_prevalence)
  mean_sec <- mean(null_res$elapsed_sec)
  cat(sprintf(
    "P0-4 A5 null: mean D_rmse=%.4f; mean D_bias=%.4f (MCSE=%.4f; 3 MCSE=%.4f); pooled prevalence=%.4f\n",
    mean_rmse, mean_bias, bias_mcse, 3 * bias_mcse, pooled_prev
  ))
  if (mean_rmse >= 0.15 || abs(mean_bias) > 3 * bias_mcse ||
      pooled_prev < 0.25 || pooled_prev > 0.50) {
    stop("P0-4 FAIL: correctly specified A5 null did not clear frozen recovery bounds", call. = FALSE)
  }
  route <- if (mean_sec > 10) "totoro" else "local"
  cat(sprintf("P0-5 timing: mean %.3f s/fit -> route %s\n", mean_sec, route))

  list(
    ref_scores = do.call(rbind, scores),
    null_scores = null_res,
    timing_route = route
  )
}

run_low_high_smoke <- function(seed = 42L, n = 100L, T_sp = 6L) {
  rows <- list(
    modifyList(REF, list(kappa = 0, rho = 0, omega = 1, n = n, T_sp = T_sp, seed = seed)),
    modifyList(REF, list(kappa = 2, rho = 0, omega = 1, n = n, T_sp = T_sp, seed = seed))
  )
  cfg <- .mk_config(rows, "smoke-low-high")
  res <- run_grid_c(cfg, n_cores = 1L, backend = "serial")
  if (nrow(res) != 2L * length(ARMS) || any(!is.na(res$fit_error)) ||
      any(!is.finite(res$D_bias)) || any(!is.finite(res$D_rmse))) {
    stop("SMOKE FAIL: empty, errored, or non-finite result", call. = FALSE)
  }
  paired <- reshape(
    res[, c("kappa", "seed", "arm", "D_bias")],
    idvar = c("seed", "arm"), timevar = "kappa", direction = "wide"
  )
  paired$dD_bias <- paired$D_bias.2 - paired$D_bias.0
  primary_delta <- paired$dD_bias[paired$arm == "A1"]
  if (length(primary_delta) != 1L || !is.finite(primary_delta) || abs(primary_delta) < 0.05) {
    stop("SMOKE NO-GO: A1 high-minus-low D_bias did not move by 0.05", call. = FALSE)
  }
  cat("Paired high-minus-low D_bias (diagnostic only; one seed):\n")
  print(paired[, c("seed", "arm", "D_bias.0", "D_bias.2", "dD_bias")], row.names = FALSE)
  list(results = res, paired = paired)
}

## =========================================================================
## Dispatch (Rscript-only; sourcing this file never runs anything)
## =========================================================================
if (sys.nframe() == 0L) {
  ARGS <- commandArgs(trailingOnly = TRUE)
  if (length(ARGS) == 0L) {
    cat("dev/isdm-bias-campaign.R: no stage given, nothing executed.\n")
    cat("Available stages: preflight, smoke, pilot, g1, g2, g3, g4, g5, g6, counts\n")
    cat("Usage: Rscript dev/isdm-bias-campaign.R <stage> [<stage> ...]\n")
  } else {
    N_CORES <- .detect_cores_c()
    if ("counts" %in% ARGS) print(expected_fit_counts())
    if ("preflight" %in% ARGS) {
      preflight <- run_preflight_gates(n_cores = min(4L, N_CORES))
      saveRDS(preflight, "dev/isdm-bias-preflight-results.rds")
    }
    if ("smoke" %in% ARGS) {
      smoke <- run_low_high_smoke()
      saveRDS(smoke, "dev/isdm-bias-smoke-results.rds")
    }
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
