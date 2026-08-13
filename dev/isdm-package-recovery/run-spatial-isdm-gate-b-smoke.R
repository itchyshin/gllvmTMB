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
  files <- setdiff(files, file.path(root, "file-manifest.csv"))
  utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files),
                              md5 = vapply(files, hash, character(1L))),
                   file.path(root, "file-manifest.csv"), row.names = FALSE)
}
peak_rss_kb <- function() {
  status <- "/proc/self/status"
  if (!file.exists(status)) return(NA_real_)
  line <- grep("VmHWM", readLines(status, warn = FALSE), value = TRUE)
  if (!length(line)) return(NA_real_)
  suppressWarnings(as.numeric(sub(".*:\\s*([0-9]+).*", "\\1", line[[1L]])))
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
                      psi = "indep(0 + trait | cell_id)", shared_mesh_range_rank = TRUE,
                      extractor_truth_map = list(
                        ecological = c(truth = "shared_Sigma", output = "Sigma_spde_slope_intercept"),
                        gbif_bias = c(truth = "bias_Sigma", output = "Sigma_spde_slope_slope"))),
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
if (file.exists(file.path(root, "attempt-started.rds")) ||
    file.exists(file.path(root, "all-attempt-ledger.rds")) ||
    file.exists(file.path(root, "fit.rds"))) {
  stop("this immutable root has already consumed its one Gate-B smoke attempt", call. = FALSE)
}
receipt <- readRDS(file.path(root, "root-receipt.rds"))
if (!identical(receipt$commit, commit()) || !identical(receipt$fixture_md5, hash(fixture_file)) ||
    !identical(receipt$runner_md5, hash(script))) {
  stop("smoke receipt does not match the current committed fixture/runner", call. = FALSE)
}
manifest_table <- utils::read.csv(file.path(root, "file-manifest.csv"), stringsAsFactors = FALSE)
manifest_hash <- function(name) manifest_table$md5[match(name, manifest_table$path)]
if (anyNA(vapply(c("mesh.rds", "truth.rds", "root-receipt.rds"), manifest_hash, character(1L))) ||
    !identical(unname(tools::md5sum(file.path(root, "mesh.rds"))), manifest_hash("mesh.rds")) ||
    !identical(unname(tools::md5sum(file.path(root, "truth.rds"))), manifest_hash("truth.rds")) ||
    !identical(unname(tools::md5sum(file.path(root, "root-receipt.rds"))), manifest_hash("root-receipt.rds"))) {
  stop("saved immutable preflight artifacts do not match their manifest", call. = FALSE)
}
z <- list(fixture = list(truth = readRDS(file.path(root, "truth.rds"))), mesh = readRDS(file.path(root, "mesh.rds")))
fixture_current <- make()
if (!identical(z$fixture$truth, fixture_current$fixture$truth) ||
    !identical(z$mesh, fixture_current$mesh)) {
  stop("rebuilt fixture or mesh differs from the immutable receipt", call. = FALSE)
}
z <- fixture_current
source_map <- receipt$source_map
versions <- list(R = R.version.string, package = as.character(utils::packageVersion("gllvmTMB")),
                 commit = commit())
execute_smoke <- function() {
  ledger <- spatial_isdm_gate_b_new_ledger(
    attempt_id = paste0("paper1-spatial-b2-", spatial_isdm_gate_b_seed),
    source_map = source_map, versions = versions
  )
  finalise <- function() {
    if (!isTRUE(ledger$terminal)) {
      ledger$status <<- "RUNNER_ERROR"
      ledger$fit_error <<- "runner exited before a terminal fit classification"
      ledger$terminal <<- TRUE
      ledger$finished_at <<- as.character(Sys.time())
    }
    spatial_isdm_gate_b_validate_terminal_ledger(ledger)
    saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))
    manifest(root)
    writeLines(c("# SPATIAL_ISDM_GATE_B2_SMOKE", paste("status:", ledger$status),
      paste("fit_elapsed_s:", format(ledger$timing$fit_elapsed_s, scientific = FALSE))),
      file.path(root, "smoke-receipt.md"))
  }
  on.exit(finalise(), add = TRUE)
  saveRDS(list(status = "OPTIMIZER_ENTERED", attempt_id = ledger$attempt_id,
    started_at = ledger$started_at), file.path(root, "attempt-started.rds"))
  warnings <- character()
  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(withCallingHandlers(
    .gll_isdm_fit(z$fixture$rows, z$fixture$X, z$fixture$B, d = 1L,
      mesh = z$mesh, spatial = TRUE,
      control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = TRUE, aghq = FALSE,
        warn_runaway = TRUE), silent = TRUE),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    }), error = function(e) e)
  ledger$timing$fit_elapsed_s <- proc.time()[["elapsed"]] - started
  ledger$warnings <- unique(warnings)
  if (inherits(fit, "error")) {
    ledger$status <- "FIT_ERROR"
    ledger$fit_error <- conditionMessage(fit)
  } else {
    saveRDS(fit, file.path(root, "fit.rds"))
    health <- fit$fit_health %||% list()
    gradient <- fit$tmb_obj$gr(fit$opt$par)
    ledger$status <- "FIT_RETURNED"
    ledger$selected_fit <- 1L
    ledger$objective <- fit$objective$likelihood_nll
    ledger$optimizer_code <- fit$opt$convergence
    ledger$gradient <- gradient
    ledger$gradient_by_block <- list(outer = setNames(as.numeric(gradient), names(fit$opt$par)))
    ledger$pd_hessian <- fit$sd_report$pdHess
    ledger$boundary_flags <- health$boundary_flags %||% character()
    ledger$source_map <- fit$isdm_developer$spatial_source_map
    ledger$field_outputs <- list(ecological = fit$report$Sigma_spde_slope_intercept,
      gbif_bias = fit$report$Sigma_spde_slope_slope, kappa = fit$report$kappa %||% NA_real_)
  }
  ledger$terminal <- TRUE
  ledger$finished_at <- as.character(Sys.time())
  invisible(ledger)
}
ledger <- execute_smoke()
## Telemetry is deliberately downstream of the terminal ledger.  Failure here
## cannot erase the all-attempt evidence.
telemetry <- tryCatch(list(peak_rss_kb = peak_rss_kb()), error = function(e) list(error = conditionMessage(e)))
saveRDS(telemetry, file.path(root, "telemetry.rds"))
if (is.finite(telemetry$peak_rss_kb)) {
  ledger$peak_rss_kb <- telemetry$peak_rss_kb
  saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))
}
manifest(root)
cat(ledger$status, "\n")
