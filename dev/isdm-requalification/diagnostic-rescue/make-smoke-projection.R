args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: make-smoke-projection.R SMOKE_PLAN_RDS SMOKE_OUTPUT EXPERIMENT_PLAN_RDS OUTPUT_RDS")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                     value = TRUE)[[1L]])
root <- dirname(normalizePath(script))
source(file.path(root, "record.R"), local = TRUE)
source(file.path(root, "contract.R"), local = TRUE)
smoke <- readRDS(args[[1L]])
experiment <- readRDS(args[[3L]])
isdm_diag_validate_smoke_plan(smoke)
isdm_diag_validate_plan(experiment)
records <- diagnostic_terminal_dispositions(smoke, args[[2L]])
if (any(vapply(records, `[[`, character(1L), "status") != "fit_returned")) {
  stop("smoke projection requires four returned fits")
}
runtime <- vapply(records, `[[`, numeric(1L), "runtime_s")
if (any(!is.finite(runtime)) || any(runtime < 0)) stop("smoke runtimes invalid")
non_i <- which(smoke$slice == "nonspatial")
sp_i <- which(smoke$slice == "spatial")
non_base <- runtime[[non_i]]
non_scale <- (experiment$n_cells[experiment$slice == "nonspatial"] /
                smoke$n_cells[[non_i]]) *
  (experiment$n_sources[experiment$slice == "nonspatial"] /
     smoke$n_sources[[non_i]])
non_core_s <- sum(non_base * non_scale)
spatial_group_s <- sum(runtime[sp_i])
spatial_plan <- experiment[experiment$slice == "spatial", , drop = FALSE]
spatial_groups <- spatial_plan[spatial_plan$variant == "default", , drop = FALSE]
spatial_scale <- spatial_groups$n_sources / smoke$n_sources[[sp_i[[1L]]]]
spatial_core_s <- sum(spatial_group_s * spatial_scale)
terminal <- readRDS(file.path(args[[2L]], "launch-terminal.rds"))
observed_wall_s <- as.numeric(terminal$runtime_s)
## Twofold scheduling/heterogeneity margin over scaled aggregate core time.
projected_wall_s <- max(observed_wall_s,
                        2 * (non_core_s + spatial_core_s) / 16)
receipt <- list(
  schema = "isdm-diagnostic-smoke-projection-v1",
  created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  smoke_tasks = 4L, workers = 16L,
  observed_wall_s = observed_wall_s,
  scaled_nonspatial_core_s = non_core_s,
  scaled_spatial_core_s = spatial_core_s,
  safety_multiplier = 2,
  projected_wall_s = projected_wall_s
)
diagnostic_atomic_save(receipt, args[[4L]])
cat("DIAGNOSTIC_SMOKE_PROJECTION_WRITTEN\n")
