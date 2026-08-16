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
package_commit <- function() {
  out <- suppressWarnings(system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))
  if (length(out) != 1L || !grepl("^[0-9a-f]{40}$", out)) {
    stop("cannot record the package commit for --pkg", call. = FALSE)
  }
  out
}
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
  if (identical(scenario, "disconnected")) {
    ## No cell contributes both source likelihoods: GBIF is x > 0 while
    ## survey is x <= 0.  This is deliberately an attack, not an ordinary fit.
    gbif <- gbif[gbif$cell_id %in% cells[!survey_keep], , drop = FALSE]
  }
  rows <- rbind(gbif, survey)
  row_index <- match(paste(rows$cell_id, rows$trait), paste(grid$cell_id, grid$trait))
  x_rows <- x_vec[row_index]
  b_rows <- ifelse(rows$source == "gbif", b_vec[row_index], NA_real_)
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
  if (identical(fixture$truth$scenario, "disconnected")) {
    shared_cells <- intersect(
      unique(rows$cell_id[rows$source == "gbif"]),
      unique(rows$cell_id[rows$source == "survey"])
    )
    if (length(shared_cells)) stop("disconnected attack retains shared source cells")
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
  target_pass <- isTRUE(eligible) && all(is.finite(unlist(metric[c(
    "max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation",
    "shared_relative_frobenius", "max_abs_psi_variance_error"
  )], use.names = FALSE))) && metric$max_abs_beta_error <= 0.30 &&
    metric$max_abs_gamma_error <= 0.30 && metric$min_map_correlation >= 0.70 &&
    metric$shared_relative_frobenius <= 0.50 && metric$max_abs_psi_variance_error <= 0.20
  list(status = if (eligible) "eligible" else "ineligible", detail = NA_character_,
       fixture = fixture, fit = fit, metrics = metric, target_pass = target_pass,
       warnings = fit_result$warnings, elapsed_s = fit_result$elapsed_s,
       restart_history = fit$restart_history)
}

write_fixture <- function(out, result, seed, scenario, replicate) {
  result_root <- normalizePath(dirname(dirname(out)), mustWork = FALSE)
  final_files <- file.path(result_root, c(
    "summary.csv", "summary.rds", "attack-verdicts.csv", "metric-aggregates.csv",
    "file-manifest.csv"
  ))
  if (any(file.exists(final_files))) {
    stop("refusing to add a fixture to a finalised result root", call. = FALSE)
  }
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(out)) stop("refusing to overwrite retained fixture: ", out, call. = FALSE)
  result$manifest <- list(
    seed = seed, scenario = scenario, replicate = replicate,
    package_commit = package_commit(),
    runner_md5 = hash_file(runner_file), protocol_md5 = hash_file(protocol_file),
    r_version = R.version.string, tmb_version = as.character(utils::packageVersion("TMB")),
    platform = R.version$platform, completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  saveRDS(result, out)
}

expected_fixture_grid <- function() {
  panel <- list(ordinary = 1:20, disconnected = 1:5, weak_overlap = 1:5)
  do.call(rbind, Map(function(scenario, replicates) {
    data.frame(scenario = scenario, replicate = as.integer(replicates),
               seed = vapply(replicates, function(r) seed_for(scenario, r), integer(1)),
               stringsAsFactors = FALSE)
  }, names(panel), unname(panel)))
}

validate_manifest_bundle <- function(res, files) {
  expected <- expected_fixture_grid()
  if (length(res) != nrow(expected) || length(files) != nrow(expected)) {
    stop("result root does not retain the frozen 30-fixture panel", call. = FALSE)
  }
  required <- c("seed", "scenario", "replicate", "package_commit", "runner_md5",
                "protocol_md5", "r_version", "tmb_version", "platform")
  manifests <- lapply(res, function(x) {
    if (is.null(x$manifest) || !all(required %in% names(x$manifest))) {
      stop("fixture manifest is incomplete", call. = FALSE)
    }
    x$manifest
  })
  tab <- do.call(rbind, lapply(manifests, function(m) data.frame(
    scenario = as.character(m$scenario), replicate = as.integer(m$replicate),
    seed = as.integer(m$seed), package_commit = as.character(m$package_commit),
    runner_md5 = as.character(m$runner_md5), protocol_md5 = as.character(m$protocol_md5),
    r_version = as.character(m$r_version), tmb_version = as.character(m$tmb_version),
    platform = as.character(m$platform), stringsAsFactors = FALSE
  )))
  tab <- tab[order(tab$scenario, tab$replicate), , drop = FALSE]
  expected <- expected[order(expected$scenario, expected$replicate), , drop = FALSE]
  rownames(tab) <- NULL
  rownames(expected) <- NULL
  if (!identical(tab[c("scenario", "replicate", "seed")], expected)) {
    stop("fixture manifests do not match the frozen scenario/replicate/seed grid", call. = FALSE)
  }
  provenance <- c("package_commit", "runner_md5", "protocol_md5", "r_version", "tmb_version", "platform")
  if (any(vapply(tab[provenance], function(x) length(unique(x)) != 1L, logical(1)))) {
    stop("fixture manifests have mixed provenance", call. = FALSE)
  }
  if (!identical(unname(tab$runner_md5[[1L]]), hash_file(runner_file)) ||
      !identical(unname(tab$protocol_md5[[1L]]), hash_file(protocol_file))) {
    stop("fixture manifests do not match the current frozen runner/protocol", call. = FALSE)
  }
  tab
}

validate_summary_contract <- function() {
  expected <- expected_fixture_grid()
  make_result <- function(row) list(
    manifest = list(seed = row$seed, scenario = row$scenario, replicate = row$replicate,
                    package_commit = "self-check", runner_md5 = hash_file(runner_file),
                    protocol_md5 = hash_file(protocol_file), r_version = R.version.string,
                    tmb_version = as.character(utils::packageVersion("TMB")),
                    platform = R.version$platform),
    status = "eligible", target_pass = FALSE, warnings = character()
  )
  res <- lapply(seq_len(nrow(expected)), function(i) make_result(expected[i, , drop = FALSE]))
  files <- file.path("fixtures", sprintf("fixture-%02d.rds", seq_along(res)))
  validate_manifest_bundle(res, files)
  bad <- res
  bad[[1L]]$manifest$seed <- 99999L
  rejected <- inherits(try(validate_manifest_bundle(bad, files), silent = TRUE), "try-error")
  if (!rejected) stop("summary self-check did not reject a cross-manifest collision", call. = FALSE)
  aggregate_check <- metric_aggregates(data.frame(
    status = c("eligible", "ineligible"), max_abs_beta_error = c(0.1, 0.3),
    max_abs_gamma_error = c(0.1, 0.3), min_map_correlation = c(0.9, 0.5),
    shared_relative_frobenius = c(0.2, 0.6), max_abs_psi_variance_error = c(0.1, 0.4)
  ))
  if (nrow(aggregate_check) != 10L || !setequal(as.character(aggregate_check$denominator),
                                                c("all_20", "eligible_only"))) {
    stop("summary self-check did not retain both metric denominators", call. = FALSE)
  }
  invisible(TRUE)
}

metric_aggregates <- function(ordinary) {
  metrics <- c("max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation",
               "shared_relative_frobenius", "max_abs_psi_variance_error")
  describe <- function(x, denominator) {
    finite <- x[is.finite(x)]
    data.frame(denominator = denominator, n_rows = length(x), n_finite = length(finite),
               mean = if (length(finite)) mean(finite) else NA_real_,
               median = if (length(finite)) stats::median(finite) else NA_real_,
               p10 = if (length(finite)) stats::quantile(finite, .10, type = 7, names = FALSE) else NA_real_,
               p90 = if (length(finite)) stats::quantile(finite, .90, type = 7, names = FALSE) else NA_real_)
  }
  do.call(rbind, lapply(metrics, function(metric) {
    all_rows <- describe(ordinary[[metric]], "all_20")
    eligible <- describe(ordinary[[metric]][ordinary$status == "eligible"], "eligible_only")
    out <- rbind(all_rows, eligible)
    out$metric <- metric
    out
  }))
}

summarize_root <- function(root) {
  protected <- file.path(root, c("summary.csv", "summary.rds", "attack-verdicts.csv",
                                 "metric-aggregates.csv", "file-manifest.csv"))
  if (any(file.exists(protected))) stop("refusing to overwrite an immutable root summary", call. = FALSE)
  files <- sort(list.files(file.path(root, "fixtures"), pattern = "\\.rds$", full.names = TRUE))
  if (!length(files)) stop("no fixture RDS files found", call. = FALSE)
  res <- lapply(files, readRDS)
  provenance <- validate_manifest_bundle(res, files)
  rows <- lapply(res, function(x) {
    m <- x$metrics %||% list()
    data.frame(seed = x$manifest$seed, scenario = x$manifest$scenario,
               replicate = x$manifest$replicate, status = x$status,
               target_pass = isTRUE(x$target_pass),
               warning_count = length(x$warnings %||% character()),
               max_abs_beta_error = m$max_abs_beta_error %||% NA_real_,
               max_abs_gamma_error = m$max_abs_gamma_error %||% NA_real_,
               min_map_correlation = m$min_map_correlation %||% NA_real_,
               shared_relative_frobenius = m$shared_relative_frobenius %||% NA_real_,
               max_abs_psi_variance_error = m$max_abs_psi_variance_error %||% NA_real_)
  })
  tab <- do.call(rbind, rows)
  expected <- split(expected_fixture_grid()$seed, expected_fixture_grid()$scenario)
  complete_panel <- vapply(names(expected), function(s) {
    got <- tab$seed[tab$scenario == s]
    identical(sort(got), expected[[s]]) && length(got) == length(expected[[s]])
  }, logical(1))
  ordinary <- tab[tab$scenario == "ordinary", , drop = FALSE]
  ordinary_complete <- complete_panel[["ordinary"]]
  attack_names <- c("disconnected", "weak_overlap")
  attack_degraded <- vapply(attack_names, function(s) {
    attack <- tab[tab$scenario == s, , drop = FALSE]
    isTRUE(complete_panel[[s]]) && all(!attack$target_pass)
  }, logical(1))
  complete <- all(complete_panel)
  pass <- complete && all(attack_degraded) && sum(ordinary$target_pass) >= 18L
  verdict <- if (pass) "G2_PACKAGE_PA_PASS" else "G2_PACKAGE_PA_HOLD"
  attack_verdicts <- data.frame(
    scenario = attack_names,
    complete = unname(complete_panel[attack_names]),
    all_fixture_target_fail = unname(attack_degraded),
    outcome = ifelse(!unname(complete_panel[attack_names]), "ATTACK_PANEL_INCOMPLETE",
                     ifelse(unname(attack_degraded), "ATTACK_DEGRADATION_RETAINED",
                            "ATTACK_NOT_DEGRADING_HOLD")),
    stringsAsFactors = FALSE
  )
  aggregates <- metric_aggregates(ordinary)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(tab, file.path(root, "summary.csv"), row.names = FALSE)
  utils::write.csv(attack_verdicts, file.path(root, "attack-verdicts.csv"), row.names = FALSE)
  utils::write.csv(aggregates, file.path(root, "metric-aggregates.csv"), row.names = FALSE)
  saveRDS(list(complete = complete, ordinary_complete = ordinary_complete,
               attack_complete = complete_panel[names(complete_panel) != "ordinary"], verdict = verdict,
               attack_degraded = attack_degraded, provenance = provenance,
               all_rows = tab, metric_aggregates = aggregates,
               ordinary_passes = sum(ordinary$target_pass), ordinary_required = 20L),
          file.path(root, "summary.rds"))
  retained <- sort(c(files, file.path(root, "summary.csv", "summary.rds", "attack-verdicts.csv",
                                      "metric-aggregates.csv")))
  utils::write.csv(data.frame(path = basename(retained), md5 = vapply(retained, hash_file, character(1))),
                   file.path(root, "file-manifest.csv"), row.names = FALSE)
  cat(sprintf("%s | ordinary pass %d/%d | ordinary retained %d/%d\\n",
              verdict, sum(ordinary$target_pass), 20L, nrow(ordinary), 20L))
}

if (identical(mode, "summarize")) {
  summarize_root(root)
} else if (identical(mode, "validate")) {
  validate_fixture(make_fixture(seed_for(scenario, replicate), scenario))
  validate_summary_contract()
  cat("fixture and summary-contract validation PASS\n")
} else {
  seed <- seed_for(scenario, replicate)
  out <- file.path(root, "fixtures", sprintf("%s-replicate-%02d.rds", scenario, replicate))
  result <- fixture_result(seed, scenario, replicate)
  write_fixture(out, result, seed, scenario, replicate)
  cat(sprintf("retained %s (%s)\\n", out, result$status))
}
