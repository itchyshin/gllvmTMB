#!/usr/bin/env Rscript

## Developer-only package-native two-source iSDM PA recovery harness.
## Read 2026-08-10-pa-recovery-protocol.md before running this file.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "fixture")
scenario <- arg_value("scenario", "ordinary")
replicate <- as.integer(arg_value("replicate", "1"))
root <- arg_value("output", NULL)
pkg <- normalizePath(arg_value("pkg", getwd()), mustWork = TRUE)
load_mode <- arg_value("load", "source")
if (!mode %in% c("fixture", "summarize", "validate")) stop("mode must be fixture, summarize, or validate", call. = FALSE)
if (!scenario %in% c("ordinary", "disconnected", "weak_overlap")) stop("unknown scenario", call. = FALSE)
if (is.na(replicate) || replicate < 1L) stop("replicate must be positive", call. = FALSE)
if (is.null(root)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(root, mustWork = FALSE)

if (!load_mode %in% c("source", "installed")) stop("load must be source or installed", call. = FALSE)
if (identical(load_mode, "source")) {
  suppressMessages(devtools::load_all(pkg, quiet = TRUE))
} else {
  suppressMessages(library(gllvmTMB))
  .gll_isdm_fit <- getFromNamespace(".gll_isdm_fit", "gllvmTMB")
  .gllvmTMB_b_fix_values <- getFromNamespace(".gllvmTMB_b_fix_values", "gllvmTMB")
}

`%||%` <- function(x, y) if (is.null(x)) y else x
truth_constants <- list(
  alpha = c(sp1 = -1.40, sp2 = -1.20, sp3 = -1.55),
  beta = c(sp1 = -0.55, sp2 = 0.35, sp3 = 0.70),
  lambda = c(sp1 = 0.70, sp2 = -0.55, sp3 = 0.45),
  psi_sd = c(sp1 = 0.35, sp2 = 0.30, sp3 = 0.40),
  gamma = c(sp1 = 0.45, sp2 = -0.35, sp3 = 0.25),
  gbif_contrast = c(sp1 = 0.30, sp2 = -0.20, sp3 = 0.15)
)

seed_for <- function(scenario, replicate) {
  base <- c(ordinary = 71000L, disconnected = 72000L, weak_overlap = 73000L)[[scenario]]
  as.integer(base + replicate)
}

hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- if (length(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
} else {
  normalizePath("dev/isdm-package-recovery/run-pa-recovery.R", mustWork = TRUE)
}
protocol_file <- file.path(dirname(runner_file), "2026-08-10-pa-recovery-protocol.md")

make_fixture <- function(seed, scenario, n_cell = 120L) {
  set.seed(seed)
  tr <- truth_constants
  species <- names(tr$alpha)
  cells <- paste0("cell_", seq_len(n_cell))
  x <- seq(-1, 1, length.out = n_cell)
  b <- as.numeric(scale(stats::rnorm(n_cell)))
  survey_keep <- rep(TRUE, n_cell)
  if (identical(scenario, "disconnected")) {
    ## Retain each source at different covariate support, while keeping cell IDs
    ## valid for the package route. Their linking scores are deliberately absent.
    survey_keep <- x <= 0
  }
  if (identical(scenario, "weak_overlap")) {
    b <- as.numeric(scale(0.90 * x + sqrt(1 - 0.90^2) * stats::rnorm(n_cell)))
    survey_keep <- abs(x) <= 0.25
  }
  z <- stats::rnorm(n_cell)
  eps <- sapply(tr$psi_sd, function(sd) stats::rnorm(n_cell, sd = sd))
  eta <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") +
    outer(z, tr$lambda) + eps
  a_g <- exp(seq(log(0.8), log(2.0), length.out = n_cell))
  a_s <- exp(seq(log(0.6), log(1.4), length.out = n_cell))
  grid <- expand.grid(cell_id = cells, trait = species, KEEP.OUT.ATTRS = FALSE,
                      stringsAsFactors = FALSE)
  eta_vec <- as.vector(eta)
  gamma_vec <- rep(tr$gamma, each = n_cell)
  contrast_vec <- rep(tr$gbif_contrast, each = n_cell)
  x_vec <- rep(x, times = length(species))
  b_vec <- rep(b, times = length(species))
  support_g <- rep(a_g, times = length(species))
  support_s <- rep(a_s, times = length(species))
  gbif <- transform(grid, source = "gbif", survey_event_id = NA_character_,
                    branch = "count", support = support_g,
                    value = stats::rpois(nrow(grid), support_g * exp(eta_vec + contrast_vec + b_vec * gamma_vec)))
  survey <- transform(grid, source = "survey",
                      survey_event_id = paste0("survey_", cell_id),
                      branch = "pa", support = support_s,
                      value = stats::rbinom(nrow(grid), 1L,
                        1 - exp(-support_s * exp(eta_vec))))
  if (!all(survey_keep)) {
    survey <- survey[survey$cell_id %in% cells[survey_keep], , drop = FALSE]
  }
  rows <- rbind(gbif, survey)
  x_rows <- c(x_vec, x_vec[match(paste(survey$cell_id, survey$trait),
                                  paste(grid$cell_id, grid$trait))])
  b_rows <- c(b_vec, rep(NA_real_, nrow(survey)))
  X <- matrix(x_rows, ncol = 1L, dimnames = list(NULL, "env"))
  B <- matrix(b_rows, ncol = 1L, dimnames = list(NULL, "bias"))
  list(
    rows = rows, X = X, B = B,
    truth = list(seed = seed, scenario = scenario, eta = eta, x = x, b = b,
                 z = z, eps = eps, support_g = a_g, support_s = a_s,
                 shared_Sigma = tcrossprod(tr$lambda),
                 psi_variance = tr$psi_sd^2, constants = tr,
                 survey_cells = cells[survey_keep])
  )
}

validate_fixture <- function(fixture) {
  rows <- fixture$rows
  if (!identical(sort(unique(rows$source)), c("gbif", "survey"))) stop("both sources are required")
  if (!all(rows$branch[rows$source == "gbif"] == "count")) stop("GBIF branch drift")
  if (!all(rows$branch[rows$source == "survey"] == "pa")) stop("survey PA branch drift")
  if (any(!is.na(fixture$B[rows$source == "survey", , drop = FALSE]))) stop("survey B gate drift")
  if (any(!is.finite(fixture$X))) stop("non-finite X")
  for (cell in unique(rows$cell_id)) {
    idx <- rows$cell_id == cell
    if (length(unique(fixture$X[idx, 1L])) != 1L) stop("X differs within cell")
  }
  if (anyDuplicated(rows[rows$source == "survey", c("cell_id", "trait", "survey_event_id")])) {
    stop("survey event XOR drift")
  }
  invisible(TRUE)
}

fit_one <- function(fixture, seed) {
  warnings <- character()
  set.seed(seed + 100000L)
  started <- Sys.time()
  ans <- tryCatch(
    withCallingHandlers(
      .gll_isdm_fit(
        fixture$rows, fixture$X, fixture$B, d = 1L,
        control = gllvmTMBcontrol(n_init = 3L, init_jitter = 0.25,
                                  se = TRUE, aghq = FALSE, warn_runaway = TRUE),
        silent = TRUE
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) structure(list(message = conditionMessage(e)), class = "isdm_fit_error")
  )
  list(value = ans, warnings = unique(warnings), elapsed_s = as.numeric(Sys.time() - started, units = "secs"))
}

coefficient_by_trait <- function(fit, fragment, species) {
  b <- .gllvmTMB_b_fix_values(fit)
  nm <- fit$X_fix_names
  out <- stats::setNames(rep(NA_real_, length(species)), species)
  for (sp in species) {
    idx <- grep(paste0("trait", sp, ".*", fragment), nm)
    if (length(idx) == 1L) out[[sp]] <- b[[idx]]
  }
  out
}

metrics_from_fit <- function(fit, fixture) {
  tr <- fixture$truth$constants
  species <- names(tr$alpha)
  beta_hat <- coefficient_by_trait(fit, "isdm_x_env", species)
  gamma_hat <- coefficient_by_trait(fit, "isdm_gbif_b_bias", species)
  shared <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared",
                                            link_residual = "none"))$Sigma
  unique <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique",
                                            link_residual = "none"))
  eta_hat <- as.numeric(fit$report$eta) - log(fixture$rows$support)
  survey <- fixture$rows$source == "survey"
  map_cor <- vapply(species, function(sp) {
    idx <- survey & fixture$rows$trait == sp
    truth_idx <- match(fixture$rows$cell_id[idx], paste0("cell_", seq_len(nrow(fixture$truth$eta))))
    stats::cor(eta_hat[idx] - mean(eta_hat[idx]),
               fixture$truth$eta[truth_idx, sp] - mean(fixture$truth$eta[truth_idx, sp]))
  }, numeric(1))
  list(
    beta_hat = beta_hat, gamma_hat = gamma_hat,
    shared_Sigma_hat = shared, psi_variance_hat = unique$s, map_correlation = map_cor,
    max_abs_beta_error = max(abs(beta_hat - tr$beta)),
    max_abs_gamma_error = max(abs(gamma_hat - tr$gamma)),
    min_map_correlation = min(map_cor),
    shared_relative_frobenius = norm(shared - fixture$truth$shared_Sigma, "F") /
      norm(fixture$truth$shared_Sigma, "F"),
    max_abs_psi_variance_error = max(abs(unique$s - fixture$truth$psi_variance))
  )
}

is_eligible <- function(fit) {
  rh <- fit$restart_history
  is.data.frame(rh) && nrow(rh) == 3L && sum(rh$selected) == 1L &&
    isTRUE(fit$opt$convergence == 0L) && isTRUE(fit$sd_report$pdHess) &&
    is.finite(fit$objective$likelihood_nll)
}

fixture_result <- function(seed, scenario, replicate) {
  fixture <- make_fixture(seed, scenario)
  validate_fixture(fixture)
  fit_result <- fit_one(fixture, seed)
  if (inherits(fit_result$value, "isdm_fit_error")) {
    return(list(status = "error", detail = fit_result$value$message, fixture = fixture,
                warnings = fit_result$warnings, elapsed_s = fit_result$elapsed_s))
  }
  fit <- fit_result$value
  eligible <- is_eligible(fit)
  metric <- tryCatch(metrics_from_fit(fit, fixture), error = function(e) structure(list(message = conditionMessage(e)), class = "metric_error"))
  if (inherits(metric, "metric_error")) {
    return(list(status = "metric_error", detail = metric$message, fixture = fixture, fit = fit,
                warnings = fit_result$warnings, elapsed_s = fit_result$elapsed_s,
                restart_history = fit$restart_history))
  }
  target_pass <- eligible && metric$max_abs_beta_error <= 0.30 &&
    metric$max_abs_gamma_error <= 0.30 && metric$min_map_correlation >= 0.70 &&
    metric$shared_relative_frobenius <= 0.50 && metric$max_abs_psi_variance_error <= 0.20
  list(status = if (eligible) "eligible" else "ineligible", detail = NA_character_,
       fixture = fixture, fit = fit, metrics = metric, target_pass = target_pass,
       warnings = fit_result$warnings, elapsed_s = fit_result$elapsed_s,
       restart_history = fit$restart_history)
}

write_fixture <- function(out, result, seed, scenario, replicate) {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(out)) stop("refusing to overwrite retained fixture: ", out, call. = FALSE)
  result$manifest <- list(
    seed = seed, scenario = scenario, replicate = replicate,
    package_commit = tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA_character_),
    runner_md5 = hash_file(runner_file), protocol_md5 = hash_file(protocol_file),
    r_version = R.version.string, tmb_version = as.character(utils::packageVersion("TMB")),
    platform = R.version$platform, completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  saveRDS(result, out)
}

summarize_root <- function(root) {
  files <- sort(list.files(file.path(root, "fixtures"), pattern = "\\.rds$", full.names = TRUE))
  if (!length(files)) stop("no fixture RDS files found", call. = FALSE)
  res <- lapply(files, readRDS)
  rows <- lapply(res, function(x) {
    m <- x$metrics %||% list()
    data.frame(seed = x$manifest$seed, scenario = x$manifest$scenario,
               replicate = x$manifest$replicate, status = x$status,
               target_pass = x$target_pass %||% FALSE,
               max_abs_beta_error = m$max_abs_beta_error %||% NA_real_,
               max_abs_gamma_error = m$max_abs_gamma_error %||% NA_real_,
               min_map_correlation = m$min_map_correlation %||% NA_real_,
               shared_relative_frobenius = m$shared_relative_frobenius %||% NA_real_,
               max_abs_psi_variance_error = m$max_abs_psi_variance_error %||% NA_real_)
  })
  tab <- do.call(rbind, rows)
  ordinary <- tab[tab$scenario == "ordinary", , drop = FALSE]
  required <- 20L
  complete <- nrow(ordinary) == required && identical(sort(ordinary$seed), 71001:71020)
  pass <- complete && sum(ordinary$target_pass) >= 18L
  verdict <- if (pass) "G2_PACKAGE_PA_PASS" else "G2_PACKAGE_PA_HOLD"
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(tab, file.path(root, "summary.csv"), row.names = FALSE)
  saveRDS(list(complete = complete, verdict = verdict, all_rows = tab,
               ordinary_passes = sum(ordinary$target_pass), ordinary_required = required),
          file.path(root, "summary.rds"))
  cat(sprintf("%s | ordinary pass %d/%d | ordinary retained %d/%d\\n",
              verdict, sum(ordinary$target_pass), required, nrow(ordinary), required))
}

if (identical(mode, "summarize")) {
  summarize_root(root)
} else if (identical(mode, "validate")) {
  validate_fixture(make_fixture(seed_for(scenario, replicate), scenario))
  cat("fixture validation PASS\n")
} else {
  seed <- seed_for(scenario, replicate)
  out <- file.path(root, "fixtures", sprintf("%s-replicate-%02d.rds", scenario, replicate))
  result <- fixture_result(seed, scenario, replicate)
  write_fixture(out, result, seed, scenario, replicate)
  cat(sprintf("retained %s (%s)\\n", out, result$status))
}
