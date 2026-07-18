#!/usr/bin/env Rscript
## Aggregate cross-family coverage shards -> per-cell coverage tables.
## Combines raw covered/ci_failed rows across shards (converged reps only) and
## sums per-shard non-converged counts, then re-summarises with the harness's
## own .xfc_summarise_series so coverage = covered/converged, ci_failed = MISS,
## with rep-clustered MCSE + the 2*MCSE-lower-band-vs-0.94 gate. MEASURED, NOT
## certified -- awaiting D-43 panel.
args    <- commandArgs(trailingOnly = TRUE)
res_dir <- if (length(args) >= 1) args[1] else "pilot-results"
Sys.unsetenv("XFC_MAIN")
suppressMessages(source("dev/cross-family-coverage.R"))   # defines the .xfc_* helpers; no main

files <- list.files(res_dir, pattern = "\\.rds$", full.names = TRUE)
files <- files[basename(files) != "AGGREGATED.rds"]
cat(sprintf("aggregating %d shard files from %s\n", length(files), res_dir))
if (!length(files)) stop("no shard .rds found")

shards <- lapply(files, readRDS)
all_results <- unlist(lapply(shards, function(s) s$results), recursive = FALSE)
cell_ids <- vapply(all_results, function(x) as.integer(x$meta$cell_id), integer(1))
by_cell  <- split(all_results, cell_ids)

agg_one <- function(cell_list, estimand) {
  raw_field <- paste0("raw_", estimand)
  sum_field <- paste0("summary_", estimand)
  raws <- lapply(cell_list, function(x) x[[raw_field]])
  raws <- raws[!vapply(raws, is.null, logical(1))]
  if (!length(raws)) return(NULL)
  raw  <- do.call(rbind, raws)
  nnc  <- sum(vapply(cell_list, function(x) {
    s <- x[[sum_field]]; if (is.null(s)) 0L else as.integer(s$n_nonconverged[1L]) }, integer(1)))
  meta <- cell_list[[1L]]$meta
  if (estimand == "multiple_r") {
    s <- .xfc_summarise_series(raw$covered, raw$ci_failed, nnc)
    cbind(data.frame(cell_id = meta$cell_id, partner = meta$partner, N = meta$N,
                     estimand = "multiple_r", contrast = NA_character_,
                     truth = meta$target_multiple_r, stringsAsFactors = FALSE), s)
  } else {
    per <- lapply(split(raw, raw$contrast), function(mk) {
      s <- .xfc_summarise_series(mk$covered, mk$ci_failed, nnc)
      cbind(data.frame(cell_id = meta$cell_id, partner = meta$partner, N = meta$N,
                       estimand = "contrast_r", contrast = as.character(mk$contrast[1L]),
                       truth = mk$truth[1L], stringsAsFactors = FALSE), s)
    })
    do.call(rbind, per)
  }
}

mr <- do.call(rbind, lapply(by_cell, agg_one, estimand = "multiple_r"))
cr <- do.call(rbind, lapply(by_cell, agg_one, estimand = "contrast_r"))

show_cols_mr <- c("partner","N","truth","n_converged","n_nonconverged","coverage",
                  "mcse","lower_2mcse","gate_pass","coverage_worstcase",
                  "gate_pass_worstcase","ci_failed_rate","power_vs_nominal")
show_cols_cr <- c("partner","N","contrast","truth","n_converged","coverage",
                  "mcse","lower_2mcse","gate_pass")
cat("\n===== AGGREGATED multiple_r COVERAGE (MEASURED, NOT certified -- awaiting D-43) =====\n")
if (!is.null(mr)) print(mr[order(mr$partner, mr$N, mr$truth), show_cols_mr], row.names = FALSE)
cat("\n===== AGGREGATED contrast_r COVERAGE (MEASURED, NOT certified -- awaiting D-43) =====\n")
if (!is.null(cr)) print(cr[order(cr$partner, cr$N, cr$contrast), show_cols_cr], row.names = FALSE)

meta0 <- shards[[1L]]
saveRDS(list(multiple_r = mr, contrast_r = cr, n_shard_files = length(files),
             n_sim = meta0$N_sim, n_boot = meta0$n_boot, seed_base = meta0$seed_base,
             when = Sys.time(), note = "MEASURED, NOT certified -- awaiting D-43 panel"),
        file.path(res_dir, "AGGREGATED.rds"))
cat(sprintf("\n[wrote %s]  MEASURED, NOT certified -- awaiting D-43 panel\n",
            file.path(res_dir, "AGGREGATED.rds")))
