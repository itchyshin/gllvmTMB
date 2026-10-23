#!/usr/bin/env Rscript
## Local-only Design 125 L1 smoke (fork B).  Hard OUT: no Totoro.
##
## Usage:
##   Rscript --vanilla dev/mspl-forkB-l1-smoke.R
##   Rscript --vanilla dev/mspl-forkB-l1-smoke.R --n_rep=50 --cell=L1-anchor-n80-T8
##   Rscript --vanilla dev/mspl-forkB-l1-smoke.R --n_rep=1 --cell=L1-anchor-n40-T4
##
## Optional --pkg=PATH load_all()s that tree first (L0 worktree for a
## local measurement before L0 is on main).  Does not commit that tree.

args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(flag, default) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^", flag, "="), "", hit[[1L]])
}
has_flag <- function(flag) any(args == flag)

n_rep <- as.integer(parse_arg("--n_rep", "50"))
cell <- parse_arg("--cell", "L1-anchor-n80-T8")
seed_base <- as.integer(parse_arg("--seed_base", "20260818"))
pkg <- parse_arg("--pkg", ".")
out_dir <- parse_arg(
  "--out",
  file.path("docs", "dev-log", "research")
)

Sys.setenv(OMP_NUM_THREADS = "1", NOT_CRAN = "true")
if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("pkgload is required to load the local source tree.")
}
pkgload::load_all(pkg, compile = FALSE, quiet = TRUE)
## Harness lives on this L1 tree even when --pkg points at the L0 worktree.
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[[1L]])))
} else {
  file.path(getwd(), "dev")
}
source(file.path(script_dir, "mspl-forkB-l1-ademp.R"), local = FALSE)

t0 <- proc.time()[["elapsed"]]
res <- mspl_forkB_l1_run_cell(
  cell_id = cell, n_rep = n_rep, seed_base = seed_base
)
elapsed <- proc.time()[["elapsed"]] - t0

receipt_lines <- function(res, elapsed) {
  c(
    "# L1 local smoke receipt — Design 125 fork B",
    "",
    sprintf("**Date:** %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    sprintf("**Cell:** %s", res$cell_id),
    sprintf("**n_rep:** %s", res$n_rep),
    sprintf("**Elapsed_s:** %.1f", elapsed),
    sprintf("**Status:** %s", res$status),
    "**calibrated:** FALSE",
    "**public_confint:** refused",
    "**coverage_claim:** none",
    "**Totoro:** not run",
    ""
  )
}

if (identical(res$status, "blocked-on-L0")) {
  md <- c(
    receipt_lines(res, elapsed),
    "## Blocked on L0",
    "",
    res$reason,
    "",
    "Harness path: `dev/mspl-forkB-l1-ademp.R`.",
    "Re-run after L0 (`tape = \"Q_0\"`) is on the loaded package.",
    ""
  )
  cat(paste(md, collapse = "\n"))
} else {
  m <- res$metrics
  g <- res$gate
  md <- c(
    receipt_lines(res, elapsed),
    "## Numbers (honest; not a public claim)",
    "",
    sprintf("- availability: %.4f (need >= 0.90) → %s",
            m$availability, m$l1_availability_ge_090),
    sprintf("- refusal: %.4f (need <= 0.15) → %s",
            m$refusal, m$l1_refusal_le_015),
    sprintf("- cov_ret: %.4f  Wilson [%.4f, %.4f]",
            m$cov_ret, m$wilson_ret_lower, m$wilson_ret_upper),
    sprintf("- cov_eff: %.4f  Wilson [%.4f, %.4f] (not entirely below 0.80 → %s)",
            m$cov_eff, m$wilson_eff_lower, m$wilson_eff_upper,
            m$l1_wilson_eff_not_below_080),
    sprintf("- n_returned / n_refused / n_cover: %d / %d / %d",
            m$n_returned, m$n_refused, m$n_cover),
    sprintf("- L1 gate: %s", if (isTRUE(g$pass)) "PASS" else "FAIL"),
    "",
    "E1 only (first-trait intercept). E2 is out: the probe still requires `b_fix`.",
    ""
  )
  cat(paste(md, collapse = "\n"))
}

if (!has_flag("--no-write")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_md <- file.path(out_dir, "2026-08-18-mspl-forkB-l1-smoke.md")
  out_rds <- file.path(out_dir, "2026-08-18-mspl-forkB-l1-smoke.rds")
  writeLines(md, out_md)
  saveRDS(res, out_rds)
  cat(sprintf("Wrote %s\n", out_md))
}
