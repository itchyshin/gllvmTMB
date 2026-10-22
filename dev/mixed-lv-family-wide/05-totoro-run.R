args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: 05-totoro-run.R OUTPUT_DIR N_WORKERS CAMPAIGN_KIND")
}

output_dir <- normalizePath(args[[1L]], mustWork = TRUE)
n_workers <- as.integer(args[[2L]])
campaign_kind <- match.arg(args[[3L]], c("pure_recovery", "calibration"))
if (!is.finite(n_workers) || n_workers < 1L || n_workers > 150L) {
  stop("N_WORKERS must be between 1 and 150")
}

source("dev/mixed-lv-family-wide/00-manifest.R")
source("dev/mixed-lv-family-wide/01-run.R")

head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
mixed_lv_validate_source_identity(head, mixed_lv_observe_source_manifest())
mixed_lv_load_package(".")
Sys.setenv(GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED = "true")

grid <- mixed_lv_task_grid(campaign_kind)
worker_ids <- seq_len(n_workers)
results <- parallel::mclapply(
  worker_ids,
  function(worker_id) mixed_lv_run_worker(
    campaign_kind = campaign_kind,
    worker_id = worker_id,
    n_workers = n_workers,
    output_dir = output_dir
  ),
  mc.preschedule = TRUE,
  mc.set.seed = FALSE,
  mc.cores = n_workers
)

saveRDS(results, file.path(output_dir, "worker-supervisor-result.rds"))
failed <- vapply(results, inherits, logical(1L), what = "try-error")
if (any(failed)) {
  writeLines(vapply(results[failed], as.character, character(1L)),
    file.path(output_dir, "worker-supervisor-failures.txt"))
  stop(sum(failed), " worker process(es) failed outside retained fit handling")
}

counts <- vapply(results, `[[`, integer(1L), "n_tasks")
stopifnot(sum(counts) == nrow(grid), max(counts) - min(counts) <= 1L)
print(data.frame(worker_id = worker_ids, n_tasks = counts))
