#!/usr/bin/env Rscript
## Profile-route interval-coverage pilot (A2, 2026-07-18).
## Core cells x {Sigma_unit_diag (certificate candidate), Sigma_unit_corr
## (diagnostic)} on the PROFILE route (n_boot = 0). Reuses the verified
## m3_run_cell()/m3_summarise() -- does NOT touch the pilot drivers.
##
## REQUIRES the SOURCE gllvmTMB (has .profile_ci_total_variance): run under
## pkgload::load_all() OR with R_LIBS_USER pointing at a fresh build. A stale
## installed package silently NAs every profile CI, so we FAIL LOUD here.
##
## Modes (deterministic (cell, rep-chunk) sharding for xargs -P):
##   --mode=run --task=K --n-tasks=T [--n-sim=200 --chunks=5 --seed-base=1 --out=DIR]
##   --mode=aggregate [--out=DIR]

suppressWarnings(suppressMessages({
  library(gllvmTMB)
  source("dev/m3-grid.R")
  source("dev/m3-pilot-launch.R")
  source("dev/m3-pilot-report.R")
}))

## Prefer the INSTALLED package (fast; Totoro's Rlib is freshly built from the
## current branch). Only if it is STALE (lacks the profile machinery) fall back
## to load_all() the source -- crucially this avoids every parallel Totoro task
## recompiling src/ (a fresh install has the fn, so this branch never fires there).
if (!exists(".profile_ci_total_variance", asNamespace("gllvmTMB")) &&
  requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  message("[profile-pilot] installed gllvmTMB is stale; load_all() source fallback")
  suppressWarnings(suppressMessages(pkgload::load_all(".", quiet = TRUE)))
}

## --- Preflight: stale-package guard (the A2-smoke root cause) ---------------
if (!exists(".profile_ci_total_variance", asNamespace("gllvmTMB"))) {
  stop(
    "STALE gllvmTMB: namespace lacks .profile_ci_total_variance. ",
    "Build from source (R CMD INSTALL current branch) or run under load_all(). ",
    "A stale package NAs every profile CI silently."
  )
}

## --- CLI --------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
getarg <- function(key, default = NULL) {
  m <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (length(m)) sub(paste0("^--", key, "="), "", m[1]) else default
}
mode <- getarg("mode", "run")
out <- getarg("out", "dev/profile-pilot-results")
nsim <- as.integer(getarg("n-sim", "200"))
CHUNKS <- as.integer(getarg("chunks", "5"))
seed_base <- as.integer(getarg("seed-base", "1"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

## Optional scope overrides (A3 uses these to confirm gaussian at high n_sim,
## diag-only, without re-running binomial). Comma-separated.
fam_ovr <- getarg("families")
ns_ovr <- getarg("ns")
sig_ovr <- getarg("signals")
tgt_ovr <- getarg("targets")
TARGETS <- if (is.null(tgt_ovr)) {
  c("Sigma_unit_diag", "Sigma_unit_corr")
} else {
  strsplit(tgt_ovr, ",")[[1]]
}
## PF-5 discriminating test: co-compute >1 interval construction on the SAME
## fits (profile vs log-SD-Wald vs bootstrap) to separate construction from
## estimator. Defaults keep A2/A3 behaviour (profile only, no bootstrap).
NBOOT <- as.integer(getarg("n-boot", "0"))
EXTRA <- strsplit(getarg("extra-methods", "profile_total"), ",")[[1]]

## --- Core grid: gaussian + binomial_probit, d{1,2} x n{50,150} --------------
## signal {0.2, 0.5} are the CORE (signal>0) coverage cells; 0.0 is the
## signal-zero (psi=0 boundary) diagnostic. nbinom2 fenced (not here); ordinal
## excluded (not here); Lane C off-limits.
FAMILIES <- c("gaussian", "binomial_probit")
DS <- c(1L, 2L)
NS <- c(50L, 150L)
SIGNALS <- c(0.0, 0.2, 0.5)
grid <- expand.grid(
  family = FAMILIES, d = DS, n = NS, signal = SIGNALS,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
grid$cell_id <- sprintf(
  "%s-d%d-n%d-sig%s", grid$family, grid$d, grid$n,
  sub("\\.", "p", formatC(grid$signal, format = "f", digits = 1))
)
grid$lambda_scale <- mapply(pilot_signal_to_lambda_scale, grid$signal, grid$d)
if (!is.null(fam_ovr)) grid <- grid[grid$family %in% strsplit(fam_ovr, ",")[[1]], ]
if (!is.null(ns_ovr)) grid <- grid[grid$n %in% as.integer(strsplit(ns_ovr, ",")[[1]]), ]
if (!is.null(sig_ovr)) grid <- grid[grid$signal %in% as.numeric(strsplit(sig_ovr, ",")[[1]]), ]
grid <- grid[order(grid$family, grid$d, grid$n, grid$signal), ]
rownames(grid) <- NULL
n_cells <- nrow(grid)
if (n_cells == 0L) stop("scope overrides left zero cells")

if (identical(mode, "run")) {
  task <- as.integer(getarg("task"))
  n_tasks <- as.integer(getarg("n-tasks"))
  stopifnot(!is.na(task), !is.na(n_tasks), task >= 1L, task <= n_tasks)
  ## Enumerate (cell, rep-chunk) work units; this task strides over them.
  units <- expand.grid(cell = seq_len(n_cells), chunk = seq_len(CHUNKS))
  mine <- units[seq.int(task, nrow(units), by = n_tasks), , drop = FALSE]
  reps_per_chunk <- as.integer(ceiling(nsim / CHUNKS))
  for (u in seq_len(nrow(mine))) {
    ci <- mine$cell[u]
    ch <- mine$chunk[u]
    g <- grid[ci, ]
    ## Deterministic, disjoint per (cell, chunk) seed.
    sd <- seed_base + ci * 100000L + ch * 1000L
    t0 <- Sys.time()
    r <- tryCatch(
      m3_run_cell(
        family = g$family, d = g$d, n_reps = reps_per_chunk, seed_base = sd,
        n_units = g$n, n_traits = PILOT_N_TRAITS, lambda_scale = g$lambda_scale,
        targets = TARGETS, sigma_extra_methods = EXTRA,
        n_boot = NBOOT, ci_level = 0.95, verbose = FALSE
      ),
      error = function(e) {
        cat(sprintf("[ERR] %s chunk %d: %s\n", g$cell_id, ch, conditionMessage(e)))
        NULL
      }
    )
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!is.null(r)) {
      ## Disjoint rep ids across chunks of the same cell, so aggregate rbind
      ## gives n_sim = CHUNKS * reps_per_chunk distinct reps (not colliding
      ## 1..reps_per_chunk five times) -- keeps n_sim honest and lets A3's
      ## rep-clustered MCSE (MF4) cluster on the right unit.
      r$rep <- r$rep + (ch - 1L) * reps_per_chunk
      saveRDS(r, file.path(out, sprintf("%s__chunk%02d.rds", g$cell_id, ch)))
      cat(sprintf("[ok] %s chunk %d/%d (%d reps, %.0fs)\n", g$cell_id, ch, CHUNKS, reps_per_chunk, el))
    }
  }
} else if (identical(mode, "aggregate")) {
  files <- list.files(out, pattern = "__chunk[0-9]+\\.rds$", full.names = TRUE)
  if (!length(files)) stop("no chunk rds under ", out)
  cell_of <- sub("__chunk[0-9]+\\.rds$", "", basename(files))
  cells <- unique(cell_of)
  rows <- lapply(cells, function(cid) {
    df <- do.call(rbind, lapply(files[cell_of == cid], readRDS))
    s <- m3_summarise(df)
    cert <- s[!is.na(s$coverage_certificate), , drop = FALSE]
    ## Sigma_unit_corr coverage (diagnostic): mean covered over profile_corr rows.
    cr <- df[df$target == "Sigma_unit_corr" & !is.na(df$covered), , drop = FALSE]
    diagr <- df[df$target == "Sigma_unit_diag" & df$ci_method == "profile_total", , drop = FALSE]
    data.frame(
      cell_id = cid,
      family = df$family[1],
      d = df$d[1],
      n_units = df$n_units[1],
      lambda_scale = df$lambda_scale[1],
      n_sim = length(unique(df$rep)),
      cov_diag = if (nrow(cert)) cert$coverage_certificate[1] else NA_real_,
      diag_ci_failed_rate = if (nrow(diagr)) mean(diagr$ci_failed, na.rm = TRUE) else NA_real_,
      cov_corr = if (nrow(cr)) mean(cr$covered) else NA_real_,
      corr_n_eff = nrow(cr),
      stringsAsFactors = FALSE
    )
  })
  agg <- do.call(rbind, rows)
  agg <- agg[order(agg$family, agg$d, agg$n_units), ]
  saveRDS(agg, file.path(out, "AGGREGATE.rds"))
  cat("=== PROFILE-ROUTE PILOT AGGREGATE (MEASURED, NOT certified) ===\n")
  print(agg, row.names = FALSE)
} else {
  stop("unknown --mode=", mode)
}
