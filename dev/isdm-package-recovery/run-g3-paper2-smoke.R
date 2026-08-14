#!/usr/bin/env Rscript
## One fresh, immutable Paper-2 G3 smoke. This runner owns no recovery panel,
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

script <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
  mustWork = TRUE
)
base <- dirname(script)
fixture_file <- file.path(base, "g2h-360cell-fixture.R")
packet_file <- file.path(base, "2026-08-13-g3-paper2-smallest-smoke-packet.md")
source(fixture_file, local = TRUE)

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
  if (length(dirty)) {
    stop("G3 preflight/smoke requires a clean committed estimator tree", call. = FALSE)
  }
}
peak_rss_kb <- function() {
  x <- suppressWarnings(system2("ps", c("-o", "rss=", "-p", as.character(Sys.getpid())), stdout = TRUE))
  ans <- suppressWarnings(as.numeric(trimws(x[[1L]])))
  if (is.finite(ans)) ans else NA_real_
}
manifest <- function(root) {
  paths <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE), file.path(root, "file-manifest.csv"))
  utils::write.csv(
    data.frame(path = sub(paste0("^", root, "/"), "", paths), md5 = vapply(paths, hash_file, character(1L))),
    file.path(root, "file-manifest.csv"), row.names = FALSE
  )
}
loaded_dll <- function() {
  dlls <- getLoadedDLLs()
  candidates <- dlls[grepl("gllvmTMB", names(dlls), fixed = TRUE)]
  paths <- unique(vapply(candidates, function(x) x[["path"]], character(1L)))
  paths <- paths[file.exists(paths)]
  if (length(paths) != 1L) stop("require exactly one loaded gllvmTMB DLL", call. = FALSE)
  list(path = paths[[1L]], md5 = hash_file(paths[[1L]]))
}
make <- function() {
  suppressMessages(devtools::load_all(pkg, quiet = TRUE))
  fixture <- g2h_make_fixture(seed = 86302L)
  g2h_validate_fixture(fixture)
  list(fixture = fixture, dll = loaded_dll())
}
coordinate_ids <- function(par) {
  labels <- names(par)
  if (is.null(labels) || length(labels) != length(par) || anyNA(labels) || any(!nzchar(labels))) {
    stop("selected outer vector must have one non-empty block label per coordinate", call. = FALSE)
  }
  paste0(labels, "[", seq_along(par), "]")
}
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || !identical(campaign_sha, commit())) {
  stop("private result root and exact --campaign-sha are required", call. = FALSE)
}
clean_tree()
if (identical(mode, "validate")) {
  z <- make()
  stopifnot(identical(z$fixture$truth$seed, 86302L), nrow(z$fixture$rows) == 8640L)
  cat("G3_P2_SMOKE_RUNNER_VALIDATION_PASS (no fit)\n")
  quit(save = "no")
}
if (identical(mode, "preflight")) {
  if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) {
    stop("preflight root must be empty", call. = FALSE)
  }
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  z <- make()
  receipt <- list(
    schema = "G3_P2_SMOKE_PREFLIGHT_V1", packet = basename(packet_file), commit = commit(),
    seed = 86302L, dimensions = c(S = 6L, C = 360L, r = 3L, b = 1L, d = 1L),
    runner_md5 = hash_file(script), fixture_md5 = hash_file(fixture_file), packet_md5 = hash_file(packet_file),
    source_md5 = c(fit_multi = hash_file(file.path(pkg, "R", "fit-multi.R")),
      isdm_fit = hash_file(file.path(pkg, "R", "isdm-developer-fit.R")),
      tmb = hash_file(file.path(pkg, "src", "gllvmTMB.cpp")), dll = z$dll$md5),
    dll_path = z$dll$path, n_rows = nrow(z$fixture$rows),
    source_map = list(ecological = "rank-one unit latent ecological state", gbif_bias = "GBIF-only fixed bias covariate",
      pa_gbif_bias_structural_zero = TRUE, extractor_truth_map = c(shared = "shared_Sigma", psi = "psi_variance"))
  )
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  saveRDS(z$fixture, file.path(root, "fixture.rds"))
  saveRDS(sessionInfo(), file.path(root, "session-info.rds"))
  writeLines(c("# G3_P2 time estimate", "Expected wall clock: 15–25 minutes.", "Hard elapsed-time limit: 1500 seconds."), file.path(root, "time-estimate.md"))
  manifest(root)
  cat("G3_P2_PREFLIGHT_PASS (no fit)\n")
  quit(save = "no")
}

needed <- c("root-receipt.rds", "fixture.rds", "session-info.rds", "file-manifest.csv", "time-estimate.md")
if (!dir.exists(root) || !all(file.exists(file.path(root, needed))) || file.exists(file.path(root, "all-attempt-ledger.rds"))) {
  stop("smoke requires one untouched immutable preflight", call. = FALSE)
}

main <- function() {
  receipt <- readRDS(file.path(root, "root-receipt.rds"))
  z <- make()
  ledger <- list(
    schema = "G3_P2_SMOKE_ALL_ATTEMPT_V1", attempt_id = "paper2-g3-smoke-86302",
    status = "ATTEMPT_STARTED", terminal = FALSE, receipt = receipt, signature = NULL,
    raw_starts = list(n_init = 1L, init_jitter = 0), selected = NA_integer_, raw = NULL,
    g3 = NULL, warnings = character(), error = NA_character_,
    timing = list(fit_elapsed_s = NA_real_, total_elapsed_s = NA_real_), peak_rss_kb = NA_real_
  )
  warnings <- character()
  started <- proc.time()[["elapsed"]]
  finalise <- function() {
    if (!isTRUE(ledger$terminal)) {
      ledger$status <<- "RUNNER_ERROR"
      ledger$error <<- "runner ended before terminal record"
      ledger$terminal <<- TRUE
    }
    ledger$warnings <<- unique(warnings)
    ledger$timing$total_elapsed_s <<- proc.time()[["elapsed"]] - started
    ledger$peak_rss_kb <<- peak_rss_kb()
    saveRDS(ledger, file.path(root, "all-attempt-ledger.rds"))
    manifest(root)
  }
  on.exit(finalise(), add = TRUE)
  setTimeLimit(elapsed = 1500, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf, transient = FALSE), add = TRUE)
  tryCatch({
    if (!identical(receipt$commit, commit()) || !identical(receipt$runner_md5, hash_file(script)) ||
        !identical(receipt$fixture_md5, hash_file(fixture_file)) || !identical(receipt$packet_md5, hash_file(packet_file)) ||
        !identical(receipt$source_md5[["dll"]], z$dll$md5) || !identical(receipt$dll_path, z$dll$path)) {
      ledger$status <- "INVALID_PROVENANCE"
      ledger$error <- "preflight receipt drift"
      ledger$terminal <- TRUE
      return(invisible(NULL))
    }
    if (!identical(z$fixture, readRDS(file.path(root, "fixture.rds")))) {
      ledger$status <- "INVALID_PROVENANCE"
      ledger$error <- "fixture rebuild differs from receipt"
      ledger$terminal <- TRUE
      return(invisible(NULL))
    }
    saveRDS(list(status = "OPTIMIZER_ENTERED", started_at = as.character(Sys.time())), file.path(root, "attempt-started.rds"))
    fit_started <- proc.time()[["elapsed"]]
    fit <- tryCatch(withCallingHandlers(
      .gll_isdm_fit(z$fixture$rows, z$fixture$X, z$fixture$B, d = 1L,
        control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = TRUE, aghq = FALSE, warn_runaway = TRUE),
        silent = TRUE),
      warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
    ), error = function(e) e)
    ledger$timing$fit_elapsed_s <- proc.time()[["elapsed"]] - fit_started
    if (inherits(fit, "error")) {
      ledger$status <- "FIT_ERROR"
      ledger$error <- conditionMessage(fit)
      ledger$terminal <- TRUE
      return(invisible(NULL))
    }
    saveRDS(fit, file.path(root, "fit.rds"))
    health <- fit$fit_health %||% list()
    raw_par <- fit$opt$par
    ids <- coordinate_ids(raw_par)
    par <- stats::setNames(as.numeric(raw_par), ids)
    gradient <- stats::setNames(as.numeric(fit$tmb_obj$gr(raw_par)), ids)
    signature <- list(
      objective = hash_object(list(value = fit$objective$likelihood_nll, dll = z$dll$md5)),
      gradient = hash_object(gradient), parameter_order = hash_object(list(block_labels = names(raw_par), coordinate_ids = ids)),
      map = hash_object(fit$tmb_map), data = hash_object(fit$tmb_data), random = hash_object(fit$random),
      bounds = hash_object(list(lower = rep(-Inf, length(par)), upper = rep(Inf, length(par)))), scale = "frozen_P2",
      controls = "nlminb_ninit1_aghqFALSE", starts = "n_init1_init_jitter0", selection = "only_start",
      source_gate = "G3_P2_S6_C360_R3_V1"
    )
    ledger$signature <- signature
    raw <- list(
      objective = fit$objective$likelihood_nll, gradient = gradient, parameter_vector = par,
      raw_block_labels = names(raw_par), coordinate_ids = ids, lower = stats::setNames(rep(-Inf, length(par)), ids),
      upper = stats::setNames(rep(Inf, length(par)), ids), optimizer = "nlminb", convergence = as.integer(fit$opt$convergence),
      pd_hessian = isTRUE(fit$sd_report$pdHess), boundary_flags = health$boundary_flags %||% character(),
      hessian = NULL, hessian_available = NA, condition = NA_real_
    )
    raw_hessian <- tryCatch(fit$tmb_obj$he(raw_par), error = function(e) e)
    if (inherits(raw_hessian, "error")) {
      raw$hessian_available <- FALSE
      raw$hessian_error <- conditionMessage(raw_hessian)
      ledger$raw <- raw
      ledger$status <- "G3_HESSIAN_UNAVAILABLE"
      ledger$error <- conditionMessage(raw_hessian)
      ledger$terminal <- TRUE
      return(invisible(NULL))
    }
    dimnames(raw_hessian) <- list(ids, ids)
    raw$hessian <- raw_hessian
    raw$hessian_available <- TRUE
    raw$condition <- tryCatch(kappa(raw_hessian, exact = TRUE), error = function(e) Inf)
    raw$tie_count <- as.integer(sum(abs(gradient) == max(abs(gradient))))
    raw$feasible <- TRUE
    ledger$raw <- raw
    raw_state <- list(
      optimizer = "nlminb", convergence = raw$convergence, pd_hessian = raw$pd_hessian,
      boundary_flags = raw$boundary_flags, tie_count = raw$tie_count, is_isdm = TRUE, aghq = FALSE,
      ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE, source_gate = "G3_P2_S6_C360_R3_V1"
    )
    ledger$g3 <- .gllvmTMB_isdm_g3_full_vector_trials(fit$tmb_obj, par, raw$lower, raw$upper, signature, raw_state)
    ledger$status <- if (identical(ledger$g3$status, "TRIALS_EVALUATED") &&
        any(vapply(ledger$g3$trials, function(x) identical(x$status, "ACCEPTED"), logical(1L)))) {
      "G3_ACCEPTED"
    } else "G3_NOT_ADMITTED"
    ledger$terminal <- TRUE
  }, error = function(e) {
    ledger$status <<- "RUNNER_ERROR"
    ledger$error <<- conditionMessage(e)
    ledger$terminal <<- TRUE
  })
  cat(ledger$status, "\n")
}
main()
