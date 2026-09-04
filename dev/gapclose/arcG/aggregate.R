#!/usr/bin/env Rscript
## Aggregate arcG per-seed RDS into CSV summaries (coverage-design §10.1).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: Rscript aggregate.R <raw_dir> <summary_dir>")
raw_dir <- args[[1]]
summary_dir <- args[[2]]
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(raw_dir, pattern = "^cell[0-9]+_seed[0-9]+\\.rds$", full.names = TRUE)
cat("files:", length(files), "\n")

extract_cov <- function(cov_list, alpha) {
  nm <- paste0("nominal_", alpha)
  if (is.null(cov_list) || is.null(cov_list[[nm]])) return(NA_real_)
  cov_list[[nm]]$coverage
}

rows <- lapply(files, function(f) {
  r <- readRDS(f)
  data.frame(
    cell = if (!is.null(r$cell)) r$cell else NA_character_,
    cell_id = if (!is.null(r$cell_id)) r$cell_id else NA_integer_,
    n_sites = if (!is.null(r$n_sites)) r$n_sites else NA_integer_,
    n_traits = if (!is.null(r$n_traits)) r$n_traits else NA_integer_,
    d = if (!is.null(r$d)) r$d else NA_integer_,
    seed = if (!is.null(r$seed)) r$seed else NA_integer_,
    status = if (!is.null(r$status)) r$status else NA_character_,
    runtime = if (!is.null(r$runtime)) r$runtime else NA_real_,
    converged = if (!is.null(r$converged)) r$converged else NA_integer_,
    pdHess = if (!is.null(r$pdHess)) r$pdHess else NA,
    cov90 = extract_cov(r$coverage, 0.90),
    cov95 = extract_cov(r$coverage, 0.95),
    stringsAsFactors = FALSE
  )
})
df <- do.call(rbind, rows)
write.csv(df, file.path(summary_dir, "per_seed_summary.csv"), row.names = FALSE)

cell_summary <- do.call(rbind, lapply(split(df, df$cell_id), function(sub) {
  data.frame(
    cell_id = sub$cell_id[1],
    cell = sub$cell[1],
    n_sites = sub$n_sites[1],
    n_traits = sub$n_traits[1],
    d = sub$d[1],
    n_seeds = nrow(sub),
    n_ok = sum(sub$status == "ok", na.rm = TRUE),
    frac_converged = mean(sub$converged == 0, na.rm = TRUE),
    frac_pdHess = mean(sub$pdHess == TRUE, na.rm = TRUE),
    mean_cov90 = mean(sub$cov90, na.rm = TRUE),
    mean_cov95 = mean(sub$cov95, na.rm = TRUE),
    median_runtime_s = stats::median(sub$runtime, na.rm = TRUE),
    sum_runtime_s = sum(sub$runtime, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
cell_summary <- cell_summary[order(cell_summary$cell_id), ]
write.csv(cell_summary, file.path(summary_dir, "per_cell_summary.csv"), row.names = FALSE)

core_seconds <- sum(df$runtime, na.rm = TRUE)
meta <- data.frame(
  n_files = length(files),
  n_rows = nrow(df),
  core_seconds = core_seconds,
  core_hours = core_seconds / 3600,
  mean_runtime_s = mean(df$runtime, na.rm = TRUE),
  pooled_cov90 = mean(df$cov90, na.rm = TRUE),
  pooled_cov95 = mean(df$cov95, na.rm = TRUE),
  stringsAsFactors = FALSE
)
write.csv(meta, file.path(summary_dir, "campaign_meta.csv"), row.names = FALSE)
cat("wrote summaries; core_hours=", meta$core_hours, "\n")
print(cell_summary)
