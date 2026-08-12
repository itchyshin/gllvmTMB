#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- value("campaign-sha")
seed <- as.integer(value("seed", "86122"))
if (!mode %in% c("validate", "prerun") || is.null(root)) {
  stop("require --mode=validate|prerun and --output=PATH", call. = FALSE)
}

script <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
  mustWork = TRUE
)
base <- dirname(script)
source(file.path(base, "g2h-360cell-fixture.R"), local = TRUE)
hash <- function(path) unname(tools::md5sum(path))[[1L]]
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (length(seed) != 1L || is.na(seed) || seed < 1L) stop("--seed must be one positive integer", call. = FALSE)
check_fixture <- function() {
  fixture <- g2h_make_fixture(seed = seed)
  g2h_validate_fixture(fixture)
  fixture
}
profile_theta_diag <- function(fit) {
  base_theta <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
  species <- paste0("sp", seq_len(6L)); offsets <- c(-2, -1, 0, 1, 2)
  if (!identical(length(base_theta), 6L)) stop("expected six theta_diag_B coordinates")
  profiles <- lapply(seq_along(base_theta), function(k) {
    rows <- lapply(offsets, function(offset) {
      parameters <- fit$tmb_obj$env$parList(fit$opt$par)
      parameters$theta_diag_B[k] <- base_theta[k] + offset
      map <- fit$tmb_map
      fixed <- factor(seq_along(base_theta)); fixed[k] <- NA
      map$theta_diag_B <- fixed
      objective <- TMB::MakeADFun(
        data = fit$tmb_data, parameters = parameters, map = map,
        random = fit$random, DLL = fit$tmb_obj$env$DLL, silent = TRUE
      )
      started <- proc.time()[["elapsed"]]
      optimized <- tryCatch(nlminb(objective$par, objective$fn, objective$gr),
                            error = function(e) e)
      data.frame(
        coordinate = k, species = species[[k]], offset = offset,
        nll = if (inherits(optimized, "error")) NA_real_ else objective$fn(optimized$par),
        convergence = if (inherits(optimized, "error")) NA_integer_ else optimized$convergence,
        elapsed_s = proc.time()[["elapsed"]] - started,
        stringsAsFactors = FALSE
      )
    })
    out <- do.call(rbind, rows)
    out$delta_nll <- out$nll - out$nll[out$offset == 0]
    out
  })
  names(profiles) <- species
  profiles
}
coefficient_by_trait <- function(fit, fragment, species) {
  values <- .gllvmTMB_b_fix_values(fit); names_x <- fit$X_fix_names
  out <- stats::setNames(rep(NA_real_, length(species)), species)
  for (sp in species) {
    index <- grep(paste0("trait", sp, ".*", fragment), names_x)
    if (length(index) == 1L) out[[sp]] <- values[[index]]
  }
  out
}
metrics_from_fit <- function(fit, fixture) {
  truth <- fixture$truth; constants <- truth$constants; species <- names(constants$alpha)
  beta_hat <- coefficient_by_trait(fit, "isdm_x_env", species)
  gamma_hat <- coefficient_by_trait(fit, "isdm_gbif_b_bias", species)
  shared <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "shared", link_residual = "none"
  ))$Sigma
  psi <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "unique", link_residual = "none"
  ))$s
  eta_hat <- as.numeric(fit$report$eta) - log(fixture$rows$support)
  survey <- fixture$rows$source == "survey" & fixture$rows$visit == 1L
  map_correlation <- vapply(species, function(sp) {
    rows <- survey & fixture$rows$trait == sp
    cells <- as.integer(sub("cell_", "", fixture$rows$cell_id[rows]))
    stats::cor(eta_hat[rows] - mean(eta_hat[rows]),
               truth$eta[cells, sp] - mean(truth$eta[cells, sp]))
  }, numeric(1L))
  list(
    max_abs_beta_error = max(abs(beta_hat - constants$beta)),
    max_abs_gamma_error = max(abs(gamma_hat - constants$gamma)),
    min_map_correlation = min(map_correlation),
    shared_relative_frobenius = norm(shared - truth$shared_Sigma, "F") /
      norm(truth$shared_Sigma, "F"),
    max_abs_psi_variance_error = max(abs(psi - truth$psi_variance)),
    beta_hat = beta_hat, gamma_hat = gamma_hat,
    map_correlation = map_correlation, shared_Sigma_hat = shared,
    psi_variance_hat = psi
  )
}
recovery_pass <- function(metrics) {
  is.list(metrics) && all(vapply(metrics[c(
    "max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation",
    "shared_relative_frobenius", "max_abs_psi_variance_error"
  )], function(x) is.numeric(x) && length(x) == 1L && is.finite(x), logical(1L))) &&
    metrics$max_abs_beta_error <= .30 &&
    metrics$max_abs_gamma_error <= .30 &&
    metrics$min_map_correlation >= .70 &&
    metrics$shared_relative_frobenius <= .50 &&
    metrics$max_abs_psi_variance_error <= .20
}
valid_profiles <- function(profiles) {
  identical(names(profiles), paste0("sp", seq_len(6L))) && all(vapply(profiles, function(x) {
    nrow(x) == 5L && identical(x$offset, c(-2, -1, 0, 1, 2)) &&
      all(is.finite(x$nll)) && all(x$convergence == 0L)
  }, logical(1L)))
}
valid_polish <- function(x) {
  is.list(x) && identical(x$schema, "G2I_INTERNAL_ISDM_POLISH_V1") &&
    isTRUE(x$eligible) && isTRUE(x$attempted) && isTRUE(x$accepted) &&
    isTRUE(x$map_identical) && is.list(x$raw) && is.list(x$candidate) &&
    is.numeric(x$raw$max_gradient) && length(x$raw$max_gradient) == 1L &&
    is.numeric(x$candidate$max_gradient) && length(x$candidate$max_gradient) == 1L &&
    is.finite(x$raw$max_gradient) && is.finite(x$candidate$max_gradient) &&
    x$raw$max_gradient > 1e-3 && x$raw$max_gradient < 1e-2 &&
    x$candidate$max_gradient <= 1e-3 &&
    identical(x$raw$boundary_flags, "near_zero_sd_B") &&
    identical(x$candidate$boundary_flags, "near_zero_sd_B")
}
if (identical(mode, "validate")) {
  check_fixture()
  stopifnot(file.exists(file.path(base, "2026-08-11-g2i-recovery-prerun-decision.md")))
  cat("G2I recovery pre-run validation PASS (no fit)\n")
  quit(save = "no")
}

root <- normalizePath(if (grepl("^/", root)) root else file.path(getwd(), root),
                      mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"),
                        mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) ||
    (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) ||
    !identical(campaign_sha, commit())) {
  stop("fresh root and exact current --campaign-sha are required", call. = FALSE)
}
dir.create(root, recursive = TRUE)
fixture <- check_fixture()
receipt <- list(
  kind = "G2I_RECOVERY_PRERUN", commit = commit(), seed = seed,
  runner_md5 = hash(script), fixture_md5 = hash(file.path(base, "g2h-360cell-fixture.R")),
  contract_md5 = hash(file.path(base, "2026-08-11-g2i-polish-contract.md")),
  decision_md5 = hash(file.path(base, "2026-08-11-g2i-recovery-prerun-decision.md"))
)
saveRDS(receipt, file.path(root, "root-receipt.rds"))
saveRDS(fixture$truth, file.path(root, "truth.rds"))
stage <- function(x) write(x, file = file.path(root, "stage.txt"), append = TRUE)
stage("fixture_validated")
suppressMessages(devtools::load_all(pkg, quiet = TRUE))
stage("fit_entered")
set.seed(seed + 100000L)
fit_started <- proc.time()[["elapsed"]]
fit <- tryCatch(.gll_isdm_fit(
  fixture$rows, fixture$X, fixture$B, d = 1L,
  control = gllvmTMBcontrol(
    n_init = 3L, init_jitter = .25, se = TRUE, aghq = FALSE,
    warn_runaway = TRUE
  ), silent = TRUE
), error = function(e) e)
fit_elapsed_s <- proc.time()[["elapsed"]] - fit_started
stage("fit_returned")

if (inherits(fit, "error")) {
  saveRDS(list(reason = "fit_error", detail = conditionMessage(fit)),
          file.path(root, "profiles.rds"))
  saveRDS(list(
    classification = "PRE_RUN_RECOVERY_HOLD", diagnostic_state = "INVALID_FIT_ERROR",
    fit_elapsed_s = fit_elapsed_s, profile_elapsed_s = NA_real_
  ), file.path(root, "decision-ledger.rds"))
  status <- "G2I_RECOVERY_PRERUN_HOLD"
} else {
  saveRDS(fit, file.path(root, "fit.rds"))
  stage("fit_retained")
  profile_started <- proc.time()[["elapsed"]]
  profiles <- tryCatch(profile_theta_diag(fit), error = function(e) e)
  profile_elapsed_s <- proc.time()[["elapsed"]] - profile_started
  profile_ok <- !inherits(profiles, "error") && valid_profiles(profiles)
  metrics <- if (profile_ok) tryCatch(metrics_from_fit(fit, fixture),
                                      error = function(e) e) else NULL
  metrics_ok <- !inherits(metrics, "error") && recovery_pass(metrics)
  polish <- fit$isdm_polish_provenance
  final_gradient <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
  admission_ok <- nrow(fit$restart_history) == 3L && profile_ok &&
    valid_polish(polish) && is.finite(final_gradient) && final_gradient <= 1e-3
  saveRDS(profiles, file.path(root, "profiles.rds"))
  saveRDS(metrics, file.path(root, "recovery-summary.rds"))
  saveRDS(list(
    classification = if (admission_ok && metrics_ok) "PRE_RUN_RECOVERY_PASS" else
      "PRE_RUN_RECOVERY_HOLD",
    diagnostic_state = if (profile_ok) "VALID" else "INVALID_PROFILE",
    three_restarts = nrow(fit$restart_history) == 3L,
    profile_valid = profile_ok, polish = polish,
    final_gradient = final_gradient, recovery_metrics_pass = metrics_ok,
    recovery_metrics = if (inherits(metrics, "error")) list(error = conditionMessage(metrics)) else metrics,
    fit_elapsed_s = fit_elapsed_s, profile_elapsed_s = profile_elapsed_s
  ), file.path(root, "decision-ledger.rds"))
  status <- if (admission_ok && metrics_ok) "G2I_RECOVERY_PRERUN_PASS" else
    "G2I_RECOVERY_PRERUN_HOLD"
}
stage("artifacts_written")
files <- list.files(root, full.names = TRUE)
utils::write.csv(data.frame(path = basename(files), md5 = vapply(files, hash, character(1L))),
                 file.path(root, "file-manifest.csv"), row.names = FALSE)
writeLines(paste("#", status), file.path(root, "prerun-receipt.md"))
closure_files <- c("root-receipt.rds", "truth.rds", "fit.rds", "profiles.rds",
                   "recovery-summary.rds", "decision-ledger.rds", "stage.txt",
                   "file-manifest.csv", "prerun-receipt.md")
closure_files <- closure_files[file.exists(file.path(root, closure_files))]
closure <- list(
  kind = "G2I_RECOVERY_PRERUN_FINAL_PROVENANCE_CLOSURE",
  convention = "Hashes every completed pre-run artifact; excludes only itself.",
  files = stats::setNames(unname(tools::md5sum(file.path(root, closure_files))), closure_files)
)
saveRDS(closure, file.path(root, "final-provenance-closure.rds"))
stopifnot(identical(unname(tools::md5sum(file.path(root, names(closure$files)))),
                    unname(closure$files)))
cat(status, "\n")
