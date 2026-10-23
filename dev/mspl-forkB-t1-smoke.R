#!/usr/bin/env Rscript
## Design 125 fork B — T1 hold-out runner (measurement, not a T* freeze).
## Reuses dev/mspl-forkB-l1-ademp.R. Does not rewrite L1/L2 receipts.
## Hard OUT: no public se / vcov / confint; no undraft #1077; tstar NOT-FROZEN.
##
## Usage:
##   Rscript --vanilla dev/mspl-forkB-t1-smoke.R \
##     --n_rep=1 --cell=T1-anchor-n40-T8 --seed_base=20260830 --lib=PATH
##   Rscript --vanilla dev/mspl-forkB-t1-smoke.R \
##     --panel=t1 --n_rep=200 --workers=16 --lib=PATH

args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(flag, default) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^", flag, "="), "", hit[[1L]])
}
has_flag <- function(flag) any(args == flag)

n_rep <- as.integer(parse_arg("--n_rep", "1"))
cell <- parse_arg("--cell", "T1-anchor-n40-T8")
seed_base <- as.integer(parse_arg("--seed_base", "20260830"))
panel <- parse_arg("--panel", "")
pkg <- parse_arg("--pkg", ".")
lib <- parse_arg("--lib", "")
out_dir <- parse_arg("--out", file.path("docs", "dev-log", "research"))
workers <- as.integer(parse_arg("--workers", "1"))

readonly_t1_core_cap <- 16L
readonly_d143_cap <- 150L
if (!is.finite(workers) || workers < 1L) workers <- 1L
if (workers > readonly_t1_core_cap || workers > readonly_d143_cap) {
  stop(
    "workers=", workers, " exceeds the T1 16-core cap / D-143 150-core cap. ",
    "Ask Shinichi before raising."
  )
}

file_args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
this_script <- any(grepl(
  "mspl-forkB-t1-smoke\\.R$",
  vapply(file_args, function(x) {
    p <- sub("^--file=", "", x)
    if (file.exists(p)) normalizePath(p) else p
  }, character(1))
))
run_cli <- isTRUE(this_script) && !has_flag("--sourced")

mspl_forkB_t1_ensure_pkg <- function() {
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
    if (!file.exists(harness)) stop("Cannot find L1 harness at ", harness)
    source(harness, local = FALSE)
  }
}

if (run_cli) {
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1", NOT_CRAN = "true")
  mspl_forkB_t1_ensure_pkg()
}

## Hold-out DGP: L1 vectors plus declared far_tail (proposal 2026-08-18).
mspl_forkB_t1_dgp <- function(n_site = 40L, n_trait = 8L, seed = 1L,
                              prevalence = "anchor") {
  set.seed(as.integer(seed))
  n_site <- as.integer(n_site)
  n_trait <- as.integer(n_trait)
  site <- factor(rep(sprintf("s%03d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  Lambda <- rep_len(c(0.9, -0.6, 0.45, 0.7), n_trait)
  beta <- switch(
    match.arg(prevalence, c("anchor", "near_tail", "far_tail")),
    anchor = rep_len(c(0.0, 0.25, -0.25, 0.1), n_trait),
    near_tail = rep_len(c(-1.6, -1.4, -1.8, -1.5), n_trait),
    far_tail = rep_len(c(-2.4, -2.2, -2.6, -2.3), n_trait)
  )
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * Lambda[as.integer(trait)]
  y <- stats::rbinom(length(eta), 1L, stats::plogis(eta))
  data <- data.frame(site = site, trait = trait, y = y)
  list(
    data = data, beta = beta, Lambda = Lambda,
    n_site = n_site, n_trait = n_trait,
    prevalence = prevalence, seed = as.integer(seed), pi_mean = mean(y)
  )
}

mspl_forkB_t1_grid <- function() {
  data.frame(
    cell_id = c(
      "T1-anchor-n40-T8", "T1-anchor-n160-T8",
      "T1-neartail-n80-T8", "T1-fartail-n40-T4"
    ),
    n_site = c(40L, 160L, 80L, 40L),
    n_trait = c(8L, 8L, 8L, 4L),
    prevalence = c("anchor", "anchor", "near_tail", "far_tail"),
    seed_base = c(20260830L, 20260831L, 20260832L, 20260833L),
    n_rep_default = c(200L, 200L, 200L, 200L),
    role = c("hold-out-nT", "n-expansion", "prev-x-n", "far-tail"),
    tstar_rule = c("RECORD", "RECORD", "RECORD", "RECORD-ONLY"),
    stringsAsFactors = FALSE
  )
}

mspl_forkB_mcse <- function(p, n) {
  if (!is.finite(p) || !is.finite(n) || n <= 0) return(NA_real_)
  sqrt(p * (1 - p) / n)
}

mspl_forkB_t1_one_rep <- function(i, cell, seed_base) {
  fixture <- mspl_forkB_t1_dgp(
    n_site = cell$n_site[[1L]],
    n_trait = cell$n_trait[[1L]],
    seed = as.integer(seed_base) + as.integer(i),
    prevalence = cell$prevalence[[1L]]
  )
  fit <- try(mspl_forkB_l1_fit(fixture$data), silent = TRUE)
  probe <- if (inherits(fit, "try-error")) {
    fit
  } else {
    try(mspl_forkB_l1_profile(fit, which = 1L), silent = TRUE)
  }
  klass <- mspl_forkB_classify(fit, probe, fixture, which = 1L)
  tape <- if (is.list(probe) && !inherits(probe, "try-error")) {
    probe$tape
  } else {
    NA_character_
  }
  fork <- if (is.list(probe) && !inherits(probe, "try-error")) {
    probe$design_125_fork
  } else {
    NA_character_
  }
  data.frame(
    cell_id = cell$cell_id[[1L]],
    rep = as.integer(i),
    seed = fixture$seed,
    pi_mean = fixture$pi_mean,
    status = klass$status,
    reason = if (is.na(klass$reason)) NA_character_ else klass$reason,
    available = klass$available,
    returned = klass$returned,
    covered = klass$covered,
    lo = klass$lo,
    hi = klass$hi,
    truth = klass$truth,
    tape = if (is.na(tape)) NA_character_ else tape,
    design_125_fork = if (is.na(fork)) NA_character_ else fork,
    stringsAsFactors = FALSE
  )
}

mspl_forkB_t1_candidates <- function(metrics, tstar_rule) {
  record_only <- identical(as.character(tstar_rule), "RECORD-ONLY")
  list(
    tstar_status = "NOT-FROZEN",
    record_only = record_only,
    C_L1_wilson_upper_ge_080 = is.finite(metrics$wilson_eff_upper) &&
      metrics$wilson_eff_upper >= 0.80,
    C_lo80_wilson_lower_ge_080 = is.finite(metrics$wilson_eff_lower) &&
      metrics$wilson_eff_lower >= 0.80,
    C_avail_ge_095 = is.finite(metrics$availability) &&
      metrics$availability >= 0.95,
    C_ref_le_010 = is.finite(metrics$refusal) && metrics$refusal <= 0.10
  )
}

mspl_forkB_t1_run_cell <- function(cell_id, n_rep, seed_base, workers = 1L) {
  if (!mspl_forkB_l0_ready()) {
    return(list(
      status = "blocked-on-L0",
      cell_id = cell_id,
      n_rep = as.integer(n_rep),
      seed_base = as.integer(seed_base),
      reason = paste(
        "L0 plumbing is not on the loaded gllvmTMB:",
        ".gllvmTMB_mspl_profile_feasibility() has no tape= argument,",
        "so fork B (tape = \"Q_0\") is not measurable."
      ),
      public_confint = "refused",
      calibrated = FALSE,
      coverage_claim = "none",
      tstar_status = "NOT-FROZEN"
    ))
  }
  grid <- mspl_forkB_t1_grid()
  cell <- grid[grid$cell_id == cell_id, , drop = FALSE]
  if (nrow(cell) != 1L) stop("Unknown T1 cell_id: ", cell_id)
  n_rep <- as.integer(n_rep)
  idx <- seq_len(n_rep)
  if (as.integer(workers) > 1L && n_rep > 1L) {
    raw <- parallel::mclapply(
      idx,
      function(i) mspl_forkB_t1_one_rep(i, cell, seed_base),
      mc.cores = as.integer(workers),
      mc.preschedule = TRUE
    )
    bad <- vapply(raw, inherits, logical(1), what = "try-error")
    if (any(bad)) {
      stop("Worker error in ", cell_id, ": ", raw[[which(bad)[[1L]]]])
    }
    tab <- do.call(rbind, raw)
  } else {
    tab <- do.call(rbind, lapply(idx, function(i) {
      mspl_forkB_t1_one_rep(i, cell, seed_base)
    }))
  }
  if (is.null(tab) || !nrow(tab)) {
    stop("Empty T1 cell: ", cell_id)
  }
  metrics <- mspl_forkB_l1_metrics(tab)
  metrics$mcse_ret <- mspl_forkB_mcse(metrics$cov_ret, metrics$n_returned)
  metrics$mcse_eff <- mspl_forkB_mcse(metrics$cov_eff, metrics$n_rep)
  candidates <- mspl_forkB_t1_candidates(metrics, cell$tstar_rule[[1L]])
  list(
    status = "T1-RECORDED",
    cell_id = cell_id,
    n_rep = n_rep,
    seed_base = as.integer(seed_base),
    role = cell$role[[1L]],
    tstar_rule = cell$tstar_rule[[1L]],
    estimand = "E1",
    tape = "Q_0",
    design_125_fork = "B",
    rows = tab,
    metrics = metrics,
    candidates = candidates,
    public_confint = "refused",
    calibrated = FALSE,
    coverage_claim = "none",
    tstar_status = "NOT-FROZEN"
  )
}

mspl_forkB_t1_smoke_ok <- function(res) {
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
      "n_ret/n_ref/n_cov=%d/%d/%d | %s | tstar=%s"
    ),
    if (is.null(res$role) || is.na(res$role)) res$cell_id else res$role,
    res$cell_id,
    res$seed_base,
    res$n_rep,
    m$availability, m$refusal,
    m$cov_ret, m$mcse_ret, m$wilson_ret_lower, m$wilson_ret_upper,
    m$cov_eff, m$mcse_eff, m$wilson_eff_lower, m$wilson_eff_upper,
    m$n_returned, m$n_refused, m$n_cover,
    res$status,
    res$tstar_status
  )
}

if (isTRUE(run_cli)) {
  t0 <- proc.time()[["elapsed"]]
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (identical(panel, "t1")) {
    grid <- mspl_forkB_t1_grid()
    cells <- vector("list", nrow(grid))
    for (i in seq_len(nrow(grid))) {
      cat(sprintf(
        "T1 panel cell %s %s seed %s n_rep=%s workers=%s\n",
        grid$role[[i]], grid$cell_id[[i]], grid$seed_base[[i]],
        n_rep, workers
      ))
      cells[[i]] <- mspl_forkB_t1_run_cell(
        cell_id = grid$cell_id[[i]],
        n_rep = n_rep,
        seed_base = grid$seed_base[[i]],
        workers = workers
      )
      if (identical(cells[[i]]$status, "blocked-on-L0")) {
        stop(cells[[i]]$reason)
      }
      if (is.null(cells[[i]]$rows) || !nrow(cells[[i]]$rows)) {
        stop("Empty T1 cell: ", grid$cell_id[[i]])
      }
    }
    elapsed <- proc.time()[["elapsed"]] - t0
    out <- list(
      status = "T1-RECORDED",
      design_125_fork = "B",
      tape = "Q_0",
      estimand = "E1",
      public_confint = "refused",
      calibrated = FALSE,
      coverage_claim = "none",
      tstar_status = "NOT-FROZEN",
      workers = as.integer(workers),
      cells = cells,
      elapsed_s = elapsed
    )
    md <- c(
      "# T1 Totoro receipt — Design 125 fork B (NOT a T* freeze)",
      "",
      sprintf("**Date:** %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
      "**Status:** T1-RECORDED (not calibrated; not a public claim)",
      "**calibrated:** FALSE",
      "**public_confint:** refused",
      "**coverage_claim:** none",
      "**tstar_status:** NOT-FROZEN",
      sprintf("**workers:** %s", workers),
      sprintf("**Elapsed_s:** %.1f", elapsed),
      "",
      "## Numbers (honest; not a public claim)",
      "",
      vapply(cells, summarise_cell, character(1)),
      ""
    )
    cat(paste(md, collapse = "\n"))
    if (!has_flag("--no-write")) {
      out_md <- file.path(out_dir, "2026-08-18-mspl-forkB-t1-panel.md")
      out_rds <- file.path(out_dir, "2026-08-18-mspl-forkB-t1-panel.rds")
      writeLines(md, out_md)
      saveRDS(out, out_rds)
      cat(sprintf("Wrote %s\n", out_md))
    }
  } else {
    res <- mspl_forkB_t1_run_cell(cell, n_rep, seed_base, workers = 1L)
    elapsed <- proc.time()[["elapsed"]] - t0
    if (identical(res$status, "blocked-on-L0")) {
      cat(res$reason, "\n")
      quit(status = 2, save = "no")
    }
    ok <- mspl_forkB_t1_smoke_ok(res)
    cat(summarise_cell(res), "\n")
    cat(sprintf("elapsed_s: %.1f smoke_ok: %s\n", elapsed, ok))
    print(res$rows)
    if (!has_flag("--no-write")) {
      stamp <- sprintf("%s-%s-n%s", cell, seed_base, n_rep)
      rds <- file.path(out_dir, paste0("2026-08-18-mspl-forkB-t1-k2-", stamp, ".rds"))
      saveRDS(res, rds)
      cat(sprintf("Wrote %s bytes=%s\n", rds, file.info(rds)$size))
    }
    if (!isTRUE(ok)) quit(status = 2, save = "no")
  }
}
