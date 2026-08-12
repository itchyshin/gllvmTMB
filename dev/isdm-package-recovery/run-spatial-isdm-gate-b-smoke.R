#!/usr/bin/env Rscript
## Gate B: exactly one private local spatial smoke, only after its immutable
## fixture receipt has been materialised. No profile, retry, campaign, or
## remote compute is reachable from this runner.

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root_arg <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
sha <- value("campaign-sha")
if (!mode %in% c("validate", "preflight", "smoke") || is.null(root_arg)) {
  stop("require --mode=validate|preflight|smoke and --output=PATH", call. = FALSE)
}
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
fixture_file <- file.path(base, "spatial-isdm-gate-b-smoke-fixture.R")
source(fixture_file, local = TRUE)
hash <- function(path) unname(tools::md5sum(path))[[1L]]
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
make <- function() {
  suppressMessages(devtools::load_all(pkg, quiet = TRUE))
  fixture <- spatial_isdm_gate_b_make_fixture()
  mesh <- make_mesh(fixture$mesh_data, c("lon", "lat"), cutoff = fixture$truth$constants$mesh_cutoff)
  spatial_isdm_gate_b_validate_fixture(fixture, mesh)
  list(fixture = fixture, mesh = mesh)
}
manifest <- function(root) {
  files <- list.files(root, full.names = TRUE, recursive = TRUE)
  utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files),
                              md5 = vapply(files, hash, character(1L))),
                   file.path(root, "file-manifest.csv"), row.names = FALSE)
}
if (identical(mode, "validate")) {
  make(); cat("SPATIAL_ISDM_GATE_B_FIXTURE_VALIDATION_PASS (no fit)\n"); quit(save = "no")
}
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || !identical(sha, commit())) {
  stop("private result root and exact current campaign-sha required", call. = FALSE)
}
if (identical(mode, "preflight")) {
  if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) {
    stop("preflight root must be fresh", call. = FALSE)
  }
  dir.create(root, recursive = TRUE)
  z <- make()
  receipt <- list(kind = "SPATIAL_ISDM_GATE_B_SMOKE", commit = commit(),
    seed = spatial_isdm_gate_b_seed, fixture_md5 = hash(fixture_file), runner_md5 = hash(script),
    source_map = list(shared_ecological = "spatial_latent intercept", gbif_only = "isdm_gbif slope",
                      psi = "indep(0 + trait | cell_id)", shared_mesh_range_rank = TRUE),
    n_rows = nrow(z$fixture$rows), n_mesh = ncol(z$mesh$A_st))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(z$fixture$truth, file.path(root, "truth.rds"))
  saveRDS(z$mesh, file.path(root, "mesh.rds"))
  manifest(root); cat("SPATIAL_ISDM_GATE_B_PREFLIGHT_PASS (no fit)\n"); quit(save = "no")
}
expected <- c("root-receipt.rds", "truth.rds", "mesh.rds", "file-manifest.csv", "time-estimate.md")
if (!dir.exists(root) || !all(file.exists(file.path(root, expected)))) {
  stop("smoke requires its immutable preflight receipt and time estimate", call. = FALSE)
}
receipt <- readRDS(file.path(root, "root-receipt.rds"))
if (!identical(receipt$commit, commit()) || !identical(receipt$fixture_md5, hash(fixture_file)) ||
    !identical(receipt$runner_md5, hash(script))) {
  stop("smoke receipt does not match the current committed fixture/runner", call. = FALSE)
}
z <- make()
started <- proc.time()[["elapsed"]]
fit <- tryCatch(.gll_isdm_fit(z$fixture$rows, z$fixture$X, z$fixture$B, d = 1L,
  mesh = z$mesh, spatial = TRUE,
  control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = TRUE, aghq = FALSE,
                             warn_runaway = TRUE), silent = TRUE), error = function(e) e)
elapsed_s <- proc.time()[["elapsed"]] - started
rss_kb <- suppressWarnings(as.numeric(sub(".*:\\s*([0-9]+).*", "\\1", grep("VmHWM", readLines("/proc/self/status"), value = TRUE))))
if (inherits(fit, "error")) {
  ledger <- list(status = "FIT_ERROR", message = conditionMessage(fit), elapsed_s = elapsed_s, peak_rss_kb = rss_kb)
} else {
  saveRDS(fit, file.path(root, "fit.rds"))
  health <- fit$fit_health %||% list()
  ledger <- list(status = "FIT_RETURNED", elapsed_s = elapsed_s, peak_rss_kb = rss_kb,
    objective = fit$objective$likelihood_nll, optimizer_code = fit$opt$convergence,
    max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), pd_hessian = fit$sd_report$pdHess,
    boundary_flags = health$boundary_flags %||% character(), warnings = fit$warnings %||% character(),
    source_map = fit$isdm_developer$spatial_source_map,
    field_outputs = list(Lambda_spde_slope = fit$report$Lambda_spde_slope,
      Sigma_ecological = fit$report$Sigma_spde_slope_intercept,
      Sigma_gbif_bias = fit$report$Sigma_spde_slope_slope,
      kappa = fit$report$kappa %||% NA_real_))
}
saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))
manifest(root)
writeLines(c("# SPATIAL_ISDM_GATE_B_SMOKE", paste("status:", ledger$status),
             paste("elapsed_s:", format(ledger$elapsed_s, scientific = FALSE))),
           file.path(root, "smoke-receipt.md"))
cat(ledger$status, "\n")
