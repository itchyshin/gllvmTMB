#!/usr/bin/env Rscript
## One fresh, immutable Paper-1 G3 smoke.  This runner owns no recovery panel,
## profile, retry, remote compute, or public output.

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root_arg <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- value("campaign-sha")
if (!mode %in% c("validate", "preflight", "smoke") || is.null(root_arg)) {
  stop("require --mode=validate|preflight|smoke and --output=PATH", call. = FALSE)
}
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
fixture_file <- file.path(base, "spatial-isdm-gate-b-smoke-fixture.R")
packet_file <- file.path(base, "2026-08-13-g3-paper1-smallest-smoke-packet.md")
source(fixture_file, local = TRUE)
## Deliberately do not edit or reuse the historical B2 fixture: the same frozen
## DGP function is evaluated once with the newly packet-pinned seed.
spatial_isdm_gate_b_seed <- 86301L
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
hash_object <- function(x) {
  path <- tempfile("g3-object-hash-")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 3)
  hash_file(path)
}
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
clean_tree <- function() {
  dirty <- system2("git", c("-C", pkg, "status", "--porcelain", "--untracked-files=no"), stdout = TRUE)
  if (length(dirty)) stop("G3 preflight/smoke requires a clean committed estimator tree", call. = FALSE)
}
peak_rss_kb <- function() {
  x <- suppressWarnings(system2("ps", c("-o", "rss=", "-p", as.character(Sys.getpid())), stdout = TRUE))
  ans <- suppressWarnings(as.numeric(trimws(x[[1L]])))
  if (is.finite(ans)) ans else NA_real_
}
make <- function() {
  suppressMessages(devtools::load_all(pkg, quiet = TRUE))
  fixture <- spatial_isdm_gate_b_make_fixture(seed = 86301L)
  mesh <- make_mesh(fixture$mesh_data, c("lon", "lat"), cutoff = fixture$truth$constants$mesh_cutoff)
  spatial_isdm_gate_b_validate_fixture(fixture, mesh)
  list(fixture = fixture, mesh = mesh)
}
manifest <- function(root) {
  paths <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE), file.path(root, "file-manifest.csv"))
  utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", paths),
    md5 = vapply(paths, hash_file, character(1L))), file.path(root, "file-manifest.csv"), row.names = FALSE)
}
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || !identical(campaign_sha, commit())) {
  stop("private result root and exact --campaign-sha are required", call. = FALSE)
}
clean_tree()
if (identical(mode, "validate")) {
  z <- make()
  stopifnot(identical(z$fixture$truth$seed, 86301L), nrow(z$fixture$rows) == 4320L)
  cat("G3_P1_SMOKE_RUNNER_VALIDATION_PASS (no fit)\n")
  quit(save = "no")
}
if (identical(mode, "preflight")) {
  if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("preflight root must be empty", call. = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  z <- make()
  receipt <- list(schema = "G3_P1_SMOKE_PREFLIGHT_V1", packet = basename(packet_file),
    commit = commit(), seed = 86301L, dimensions = c(S = 3L, C = 360L, r = 3L, b = 1L, d = 1L),
    runner_md5 = hash_file(script), fixture_md5 = hash_file(fixture_file), packet_md5 = hash_file(packet_file),
    source_md5 = c(fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
      isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")), tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")),
    dll = NA_character_), n_rows = nrow(z$fixture$rows), n_mesh = ncol(z$mesh$A_st),
    source_map = list(ecological = "spatial_latent intercept", gbif_bias = "isdm_gbif slope",
      pa_gbif_bias_structural_zero = TRUE, truth_outputs = c(ecological = "shared_Sigma", gbif_bias = "bias_Sigma")))
  saveRDS(receipt, file.path(root, "root-receipt.rds")); saveRDS(z$fixture, file.path(root, "fixture.rds")); saveRDS(z$mesh, file.path(root, "mesh.rds")); saveRDS(sessionInfo(), file.path(root, "session-info.rds"))
  writeLines(c("# G3_P1 time estimate", "Expected wall clock: 10–15 minutes.", "Hard elapsed-time limit: 900 seconds."), file.path(root, "time-estimate.md"))
  manifest(root); cat("G3_P1_PREFLIGHT_PASS (no fit)\n"); quit(save = "no")
}
needed <- c("root-receipt.rds", "fixture.rds", "mesh.rds", "session-info.rds", "file-manifest.csv", "time-estimate.md")
if (!dir.exists(root) || !all(file.exists(file.path(root, needed))) || file.exists(file.path(root, "all-attempt-ledger.rds"))) stop("smoke requires one untouched immutable preflight", call. = FALSE)
receipt <- readRDS(file.path(root, "root-receipt.rds"))
if (!identical(receipt$commit, commit()) || !identical(receipt$runner_md5, hash_file(script)) || !identical(receipt$fixture_md5, hash_file(fixture_file)) || !identical(receipt$packet_md5, hash_file(packet_file))) stop("preflight receipt drift", call. = FALSE)
z <- make()
if (!identical(z$fixture, readRDS(file.path(root, "fixture.rds"))) || !identical(z$mesh, readRDS(file.path(root, "mesh.rds")))) stop("fixture/mesh rebuild differs from receipt", call. = FALSE)
loaded <- getLoadedDLLs()[["gllvmTMB"]]
receipt$source_md5[["dll"]] <- if (!is.null(loaded) && file.exists(loaded[["path"]])) hash_file(loaded[["path"]]) else NA_character_
signature <- list(objective = hash_object(list(commit = commit(), dll = receipt$source_md5[["dll"]])),
  gradient = hash_object(list(functions = c("fn", "gr", "he"))), parameter_order = "deferred_from_selected_fit",
  map = "deferred_from_selected_fit", data = hash_object(z$fixture$rows), random = "spatial_latent",
  bounds = "unbounded_outer_parameters", scale = "frozen_P1", controls = "nlminb_ninit1_aghqFALSE",
  starts = "n_init1_init_jitter0", selection = "only_start", source_gate = "G3_P1_S3_C360_R3_V1")
setTimeLimit(elapsed = 900, transient = TRUE); on.exit(setTimeLimit(elapsed = Inf, transient = FALSE), add = TRUE)
warnings <- character(); started <- proc.time()[["elapsed"]]
ledger <- list(schema = "G3_P1_SMOKE_ALL_ATTEMPT_V1", attempt_id = "paper1-g3-smoke-86301", status = "ATTEMPT_STARTED", terminal = FALSE,
  receipt = receipt, signature = signature, raw_starts = list(n_init = 1L, init_jitter = 0), selected = NA_integer_, raw = NULL, g3 = NULL,
  warnings = character(), error = NA_character_, timing = list(fit_elapsed_s = NA_real_), peak_rss_kb = NA_real_)
on.exit({ if (!ledger$terminal) { ledger$status <<- "RUNNER_ERROR"; ledger$error <<- "runner ended before terminal record"; ledger$terminal <<- TRUE }; ledger$warnings <<- unique(warnings); ledger$peak_rss_kb <<- peak_rss_kb(); saveRDS(ledger, file.path(root, "all-attempt-ledger.rds")); manifest(root) }, add = TRUE)
saveRDS(list(status = "OPTIMIZER_ENTERED", started_at = as.character(Sys.time())), file.path(root, "attempt-started.rds"))
fit <- tryCatch(withCallingHandlers(.gll_isdm_fit(z$fixture$rows, z$fixture$X, z$fixture$B, d = 1L, mesh = z$mesh, spatial = TRUE,
  control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = TRUE, aghq = FALSE, warn_runaway = TRUE), silent = TRUE),
  warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }), error = function(e) e)
ledger$timing$fit_elapsed_s <- proc.time()[["elapsed"]] - started
if (inherits(fit, "error")) { ledger$status <- "FIT_ERROR"; ledger$error <- conditionMessage(fit) } else {
  saveRDS(fit, file.path(root, "fit.rds")); par <- fit$opt$par; names(par) <- names(fit$opt$par)
  health <- fit$fit_health %||% list(); gradient <- stats::setNames(as.numeric(fit$tmb_obj$gr(par)), names(par))
  signature$parameter_order <- hash_object(names(par)); signature$map <- hash_object(fit$tmb_map); signature$data <- hash_object(fit$tmb_data)
  ledger$signature <- signature; ledger$raw <- list(objective = fit$objective$likelihood_nll, gradient = gradient, parameter_vector = par,
    parameter_names = names(par), hessian = fit$tmb_obj$he(par), lower = stats::setNames(rep(-Inf, length(par)), names(par)), upper = stats::setNames(rep(Inf, length(par)), names(par)),
    optimizer = "nlminb", convergence = as.integer(fit$opt$convergence), pd_hessian = isTRUE(fit$sd_report$pdHess), boundary_flags = health$boundary_flags %||% character(), tie_count = as.integer(sum(abs(gradient) == max(abs(gradient)))), feasible = TRUE)
  raw_state <- list(optimizer = "nlminb", convergence = as.integer(fit$opt$convergence), pd_hessian = isTRUE(fit$sd_report$pdHess), boundary_flags = health$boundary_flags %||% character(), tie_count = ledger$raw$tie_count,
    is_isdm = TRUE, aghq = FALSE, ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE, source_gate = "G3_P1_S3_C360_R3_V1")
  ledger$g3 <- .gllvmTMB_isdm_g3_full_vector_trials(fit$tmb_obj, par, ledger$raw$lower, ledger$raw$upper, signature, raw_state)
  ledger$status <- if (identical(ledger$g3$status, "TRIALS_EVALUATED") && any(vapply(ledger$g3$trials, function(x) identical(x$status, "ACCEPTED"), logical(1L)))) "G3_ACCEPTED" else "G3_NOT_ADMITTED"
}
ledger$terminal <- TRUE; ledger$warnings <- unique(warnings); ledger$peak_rss_kb <- peak_rss_kb(); saveRDS(ledger, file.path(root, "all-attempt-ledger.rds")); manifest(root)
cat(ledger$status, "\n")
