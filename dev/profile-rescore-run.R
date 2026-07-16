#!/usr/bin/env Rscript
## =============================================================================
## Sigma_unit_diag coverage RE-SCORE runner (profile_total / wald_t_logsd).
##
## Companion to the grid2000 bootstrap column: re-measures the SAME core cells
## on the two doctrine routes built 2026-07-16 (Route A genuine chi-square_1
## profile on V_t = the certificate candidate; Route B log-SD delta-Wald =
## diagnostic). Bootstrap is co-computed as the in-run baseline. Shards over
## rep-ranges via m3_run_cell(rep_index_start/end); each shard streams its
## result to disk (never batch-write at the end).
##
## Modes:
##   --mode=shard  --shard=I --n-shards=N   run rep-shard I of every cell
##   --mode=aggregate                       rbind all shard rds -> m3_summarise
##
## Discipline: Totoro <=100 cores, OPENBLAS_NUM_THREADS=1, results LOCAL, never
## GitHub artifacts (D-50). Certificate defaults NOT-DONE (D-43).
## =============================================================================
## Load the INSTALLED package by default (each shard just loads the pre-compiled
## namespace -- 96 parallel shards must NOT each recompile TMB). Set
## RESCORE_LOAD_ALL=1 for local iteration against the source tree. Internals are
## reached via `gllvmTMB:::` in both cases.
suppressMessages({
  if (nzchar(Sys.getenv("RESCORE_LOAD_ALL"))) {
    pkgload::load_all(".", quiet = TRUE, export_all = TRUE)
  } else {
    library(gllvmTMB)
  }
  source("dev/m3-grid.R")
})
options(warn = 1)

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (length(hit) == 0L) return(default)
  sub(paste0("^", flag, "="), "", hit[[1L]])
}

mode <- arg_value("--mode", "shard")
shard <- as.integer(arg_value("--shard", "1"))
n_shards <- as.integer(arg_value("--n-shards", "1"))
n_sim <- as.integer(arg_value("--n-sim", "2000"))
n_boot <- as.integer(arg_value("--n-boot", "100"))
seed_base <- as.integer(arg_value("--seed-base", "1"))
out_dir <- arg_value("--out-dir", "~/gllvm_work/profile_rescore")
out_dir <- path.expand(out_dir)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

## Core-2 cells: gaussian + binomial x d in {1,2}, at both n_units the grid used.
## (nbinom2 + ordinal stay FENCED -- never re-scored here.)
default_cells <- expand.grid(
  family = c("gaussian", "binomial"),
  d = c(1L, 2L),
  n_units = c(50L, 150L),
  stringsAsFactors = FALSE
)

if (mode == "aggregate") {
  files <- list.files(out_dir, pattern = "^shard-.*\\.rds$", full.names = TRUE)
  if (length(files) == 0L) stop("No shard rds in ", out_dir)
  grid <- do.call(rbind, lapply(files, readRDS))
  summ <- m3_summarise(grid)
  saveRDS(grid, file.path(out_dir, "rescore-collected.rds"))
  saveRDS(summ, file.path(out_dir, "rescore-summary.rds"))
  sig <- summ[summ$target == "Sigma_unit_diag", ]
  keep <- intersect(
    c("family", "d", "n_units", "ci_method", "coverage", "n_reps",
      "coverage_certificate", "certificate_gate_status", "miss_below", "miss_above"),
    names(sig)
  )
  cat("\n== RE-SCORE coverage by (cell, ci_method) ==\n")
  print(sig[order(sig$family, sig$d, sig$ci_method), keep], row.names = FALSE)
  cat(sprintf("\n[rescore] %d shard files -> %s\n", length(files), out_dir))
  quit(status = 0)
}

## --- shard mode: run rep-shard `shard` of every cell -------------------------
rng <- m3_shard_rep_range(n_sim, shard = shard, n_shards = n_shards)
cat(sprintf("[rescore] shard %d/%d: reps %d-%d of %d; %d cells; n_boot=%d\n",
            shard, n_shards, rng[["start"]], rng[["end"]], n_sim,
            nrow(default_cells), n_boot))

for (i in seq_len(nrow(default_cells))) {
  fam <- default_cells$family[i]
  d <- default_cells$d[i]
  nu <- default_cells$n_units[i]
  t0 <- Sys.time()
  g <- tryCatch(
    m3_run_cell(
      fam, d, n_reps = n_sim,
      rep_index_start = rng[["start"]], rep_index_end = rng[["end"]],
      seed_base = seed_base, n_units = nu, n_traits = M3_DEFAULT_N_TRAITS,
      targets = c("psi", "Sigma_unit_diag"), n_boot = n_boot,
      sigma_extra_methods = c("profile_total", "wald_t_logsd"),
      verbose = FALSE
    ),
    error = function(e) {
      cat(sprintf("[rescore] %s d%d n%d shard %d ERROR: %s\n",
                  fam, d, nu, shard, conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(g)) {
    g$n_units_cell <- nu
    f <- file.path(out_dir, sprintf("shard-%s-d%d-n%d-s%03d.rds", fam, d, nu, shard))
    saveRDS(g, f)
    cat(sprintf("[rescore] %s d%d n%d shard %d done in %.0fs, rows=%d -> %s\n",
                fam, d, nu, shard,
                as.numeric(difftime(Sys.time(), t0, units = "secs")),
                nrow(g), basename(f)))
  }
}
cat(sprintf("[rescore] shard %d/%d complete\n", shard, n_shards))
