#!/usr/bin/env Rscript
## Local-only Design 125 L2 smoke (fork B).  Hard OUT: no Totoro.
## Thin wrapper: reuses dev/mspl-forkB-l1-ademp.R.  Does not rewrite L1.
##
## Usage:
##   Rscript --vanilla dev/mspl-forkB-l2-smoke.R --n_rep=1 --cell=L1-neartail-n40-T4 --seed_base=20260821
##   Rscript --vanilla dev/mspl-forkB-l2-smoke.R --n_rep=1 --cell=L1-anchor-n80-T8 --seed_base=20260819
##   Rscript --vanilla dev/mspl-forkB-l2-smoke.R --panel=k3
##
## --panel=k3 runs the frozen L2 grid (new cells only; Seed A is inherited).
## --rerun-seed-a is a rematch hatch for 20260818 — never official L2 history.
## Writes L2 paths only.  Never overwrites 2026-08-18-mspl-forkB-l1-smoke.md.

args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(flag, default) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^", flag, "="), "", hit[[1L]])
}
has_flag <- function(flag) any(args == flag)

n_rep <- as.integer(parse_arg("--n_rep", "1"))
cell <- parse_arg("--cell", "L1-anchor-n80-T8")
seed_base <- as.integer(parse_arg("--seed_base", "20260819"))
panel <- parse_arg("--panel", "")
pkg <- parse_arg("--pkg", ".")
lib <- parse_arg("--lib", "")
out_dir <- parse_arg("--out", file.path("docs", "dev-log", "research"))

file_args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
this_script <- any(grepl(
  "mspl-forkB-l2-smoke\\.R$",
  vapply(file_args, function(x) {
    p <- sub("^--file=", "", x)
    if (file.exists(p)) normalizePath(p) else p
  }, character(1))
))
run_cli <- isTRUE(this_script) && !has_flag("--sourced")

mspl_forkB_l2_ensure_pkg <- function() {
  if (nzchar(lib)) {
    .libPaths(c(lib, .libPaths()))
    if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
      stop("gllvmTMB is not installed in --lib=", lib)
    }
    library(gllvmTMB)
  } else if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required unless --lib= is supplied.")
  } else {
    pkgload::load_all(pkg, compile = FALSE, quiet = TRUE)
  }
  script_dir <- if (length(file_args) && this_script) {
    dirname(normalizePath(sub("^--file=", "", file_args[[1L]])))
  } else {
    file.path(getwd(), "dev")
  }
  harness <- file.path(script_dir, "mspl-forkB-l1-ademp.R")
  if (!exists("mspl_forkB_l1_run_cell", mode = "function")) {
    if (!file.exists(harness)) {
      stop("Cannot find L1 harness at ", harness)
    }
    source(harness, local = FALSE)
  }
}

if (run_cli) {
  Sys.setenv(OMP_NUM_THREADS = "1", NOT_CRAN = "true")
  mspl_forkB_l2_ensure_pkg()
}

mspl_forkB_mcse <- function(p, n) {
  if (!is.finite(p) || !is.finite(n) || n <= 0) return(NA_real_)
  sqrt(p * (1 - p) / n)
}

mspl_forkB_l2_grid <- function() {
  data.frame(
    role = c("Seed B", "Seed C", "Near-tail"),
    cell_id = c("L1-anchor-n80-T8", "L1-anchor-n80-T8", "L1-neartail-n40-T4"),
    seed_base = c(20260819L, 20260820L, 20260821L),
    n_rep = c(50L, 50L, 50L),
    inherit = FALSE,
    stringsAsFactors = FALSE
  )
}

mspl_forkB_l2_seed_a_inherited <- function() {
  list(
    role = "Seed A (inherit)",
    cell_id = "L1-anchor-n80-T8",
    seed_base = 20260818L,
    n_rep = 50L,
    inherit = TRUE,
    status = "INHERITED-L1",
    estimand = "E1",
    tape = "Q_0",
    design_125_fork = "B",
    public_confint = "refused",
    calibrated = FALSE,
    coverage_claim = "none",
    metrics = list(
      n_rep = 50L,
      n_returned = 50L,
      n_refused = 0L,
      n_available = 50L,
      n_cover = 44L,
      availability = 1,
      refusal = 0,
      cov_ret = 0.88,
      cov_eff = 0.88,
      wilson_ret_lower = 0.7620,
      wilson_ret_upper = 0.9438,
      wilson_eff_lower = 0.7620,
      wilson_eff_upper = 0.9438,
      mcse_ret = mspl_forkB_mcse(0.88, 50),
      mcse_eff = mspl_forkB_mcse(0.88, 50)
    ),
    source = "docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md (#1128)"
  )
}

mspl_forkB_l2_attach_mcse <- function(res) {
  if (identical(res$status, "blocked-on-L0")) return(res)
  m <- res$metrics
  m$mcse_ret <- mspl_forkB_mcse(m$cov_ret, m$n_returned)
  m$mcse_eff <- mspl_forkB_mcse(m$cov_eff, m$n_rep)
  res$metrics <- m
  res$role <- if (is.null(res$role)) NA_character_ else res$role
  res$l1_status_echo <- res$status
  ## L2 records dual coverage; do not re-brand L1-PASS/FAIL as an L2 freeze.
  res$status <- "L2-RECORDED"
  res$public_confint <- "refused"
  res$calibrated <- FALSE
  res$coverage_claim <- "none"
  res
}

mspl_forkB_l2_guard_seed_a <- function(seed_base, rerun_seed_a = FALSE) {
  if (identical(as.integer(seed_base), 20260818L) && !isTRUE(rerun_seed_a)) {
    stop(
      "Seed A 20260818 / L1-anchor-n80-T8 is inherited official L1 ",
      "(cov_eff 0.880, #1128). Do not rerun as new L2 history. ",
      "Pass --rerun-seed-a only for a mechanical rematch."
    )
  }
  invisible(TRUE)
}

mspl_forkB_l2_run_cell <- function(cell_id, n_rep, seed_base, role = NA_character_,
                                   rerun_seed_a = FALSE) {
  mspl_forkB_l2_guard_seed_a(seed_base, rerun_seed_a)
  res <- mspl_forkB_l1_run_cell(
    cell_id = cell_id, n_rep = n_rep, seed_base = seed_base
  )
  res$role <- role
  mspl_forkB_l2_attach_mcse(res)
}

mspl_forkB_l2_smoke_ok <- function(res) {
  if (identical(res$status, "blocked-on-L0")) return(FALSE)
  if (is.null(res$rows) || !nrow(res$rows)) return(FALSE)
  row <- res$rows[1, , drop = FALSE]
  if (isTRUE(row$returned[[1L]])) {
    return(
      is.finite(row$lo[[1L]]) && is.finite(row$hi[[1L]]) &&
        isTRUE(row$lo[[1L]] < row$hi[[1L]]) &&
        identical(as.character(row$tape[[1L]]), "Q_0") &&
        identical(as.character(row$design_125_fork[[1L]]), "B")
    )
  }
  identical(as.character(row$status[[1L]]), "refused") &&
    as.character(row$reason[[1L]]) %in% c("R-SAT", "R-NAVL")
}

summarise_cell <- function(res) {
  m <- res$metrics
  sprintf(
    paste0(
      "- %s | %s | seed %s | n_rep=%s | avail=%.4f | refuse=%.4f | ",
      "cov_ret=%.4f (MCSE %.4f) Wilson [%.4f, %.4f] | ",
      "cov_eff=%.4f (MCSE %.4f) Wilson [%.4f, %.4f] | ",
      "n_ret/n_ref/n_cov=%d/%d/%d | %s"
    ),
    if (is.null(res$role) || is.na(res$role)) res$cell_id else res$role,
    res$cell_id,
    res$seed_base,
    res$n_rep,
    m$availability, m$refusal,
    m$cov_ret, m$mcse_ret, m$wilson_ret_lower, m$wilson_ret_upper,
    m$cov_eff, m$mcse_eff, m$wilson_eff_lower, m$wilson_eff_upper,
    m$n_returned, m$n_refused, m$n_cover,
    res$status
  )
}

if (isTRUE(run_cli)) {
  t0 <- proc.time()[["elapsed"]]
  if (identical(panel, "k3")) {
    grid <- mspl_forkB_l2_grid()
    cells <- vector("list", nrow(grid))
    for (i in seq_len(nrow(grid))) {
      cat(sprintf(
        "L2 panel cell %s %s seed %s n_rep=%s\n",
        grid$role[[i]], grid$cell_id[[i]], grid$seed_base[[i]], grid$n_rep[[i]]
      ))
      cells[[i]] <- mspl_forkB_l2_run_cell(
        cell_id = grid$cell_id[[i]],
        n_rep = grid$n_rep[[i]],
        seed_base = grid$seed_base[[i]],
        role = grid$role[[i]],
        rerun_seed_a = has_flag("--rerun-seed-a")
      )
      if (identical(cells[[i]]$status, "blocked-on-L0")) {
        stop(cells[[i]]$reason)
      }
      if (is.null(cells[[i]]$rows) || !nrow(cells[[i]]$rows)) {
        stop("Empty L2 cell: ", grid$role[[i]])
      }
    }
    elapsed <- proc.time()[["elapsed"]] - t0
    out <- list(
      status = "L2-RECORDED",
      design_125_fork = "B",
      tape = "Q_0",
      estimand = "E1",
      public_confint = "refused",
      calibrated = FALSE,
      coverage_claim = "none",
      inherited = mspl_forkB_l2_seed_a_inherited(),
      cells = cells,
      elapsed_s = elapsed
    )
    md <- c(
      "# L2 local smoke receipt — Design 125 fork B",
      "",
      sprintf("**Date:** %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
      "**Status:** L2-RECORDED (not calibrated; not a public claim)",
      "**calibrated:** FALSE",
      "**public_confint:** refused",
      "**coverage_claim:** none",
      "**Totoro:** not run",
      sprintf("**Elapsed_s:** %.1f", elapsed),
      "",
      "## Numbers (honest; not a public claim)",
      "",
      summarise_cell(out$inherited),
      vapply(cells, summarise_cell, character(1)),
      ""
    )
    cat(paste(md, collapse = "\n"))
    if (!has_flag("--no-write")) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      out_md <- file.path(out_dir, "2026-08-18-mspl-forkB-l2-smoke.md")
      out_rds <- file.path(out_dir, "2026-08-18-mspl-forkB-l2-smoke.rds")
      writeLines(md, out_md)
      saveRDS(out, out_rds)
      cat(sprintf("Wrote %s\n", out_md))
    }
  } else {
    res <- mspl_forkB_l2_run_cell(
      cell, n_rep, seed_base,
      rerun_seed_a = has_flag("--rerun-seed-a")
    )
    elapsed <- proc.time()[["elapsed"]] - t0
    if (identical(res$status, "blocked-on-L0")) {
      cat(res$reason, "\n")
    } else {
      cat(summarise_cell(res), "\n")
      cat(sprintf("elapsed_s: %.1f smoke_ok: %s\n", elapsed, mspl_forkB_l2_smoke_ok(res)))
      print(res$rows)
    }
    if (!has_flag("--no-write") && n_rep <= 2L) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      stamp <- sprintf("%s-%s-n%s", cell, seed_base, n_rep)
      saveRDS(res, file.path(out_dir, paste0("2026-08-18-mspl-forkB-l2-k2-", stamp, ".rds")))
    }
  }
}
