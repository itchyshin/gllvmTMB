#!/usr/bin/env Rscript

## Private G2e smoke launcher. `validate` is no-fit; `smoke` needs later approval.
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "validate")
root_arg <- arg_value("output", NULL)
pkg <- normalizePath(arg_value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- arg_value("campaign-sha", NULL)
if (!mode %in% c("validate", "smoke")) stop("mode must be validate or smoke", call. = FALSE)
if (is.null(root_arg)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(
  gsub("~+~", " ", sub("^--file=", "", script_arg[[1L]]), fixed = TRUE),
  mustWork = TRUE
)
source(file.path(dirname(runner_file), "g2e-support-fixture.R"), local = TRUE)
protocol_file <- file.path(dirname(runner_file), "2026-08-11-g2e-information-diagnostic-protocol.md")
decision_file <- file.path(dirname(runner_file), "2026-08-11-g2e-information-diagnostic-decision.md")
`%||%` <- function(x, y) if (is.null(x)) y else x
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
package_commit <- function() system2("git", c("-C", shQuote(pkg), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]]
assert_campaign_sha <- function() {
  if (is.null(campaign_sha) || !grepl("^[0-9a-f]{40}$", campaign_sha) || !identical(campaign_sha, package_commit())) {
    stop("--campaign-sha must be the current 40-hex package commit", call. = FALSE)
  }
  campaign_sha
}
validate_smoke_contract <- function() {
  fx <- g2e_make_fixture()
  g2e_validate_fixture(fx)
  stopifnot(identical(g2e_seed, 86101L), identical(fx$truth$support_multiplier, 2))
  cat("G2E smoke-launcher validation PASS (no fit)\n")
  invisible(fx)
}
if (mode == "validate") {
  validate_smoke_contract()
  quit(save = "no", status = 0L)
}

parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || grepl("g2[cd]", basename(root), ignore.case = TRUE)) {
  stop("G2e smoke root must be a fresh non-G2c/non-G2d private result child", call. = FALSE)
}
if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("G2e smoke root must be empty", call. = FALSE)
assert_campaign_sha()
validate_smoke_contract()
dir.create(root, recursive = TRUE, showWarnings = FALSE)
receipt <- list(
  purpose = "one-approved-local-g2e-support-smoke", package_commit = package_commit(), seed = g2e_seed,
  support_multiplier = 2, runner_md5 = hash_file(runner_file), fixture_md5 = hash_file(file.path(dirname(runner_file), "g2e-support-fixture.R")),
  protocol_md5 = hash_file(protocol_file), decision_md5 = hash_file(decision_file),
  created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), r_version = R.version.string
)
saveRDS(receipt, file.path(root, "root-receipt.rds"))
if (!identical(readRDS(file.path(root, "root-receipt.rds")), receipt)) stop("root receipt serialization failed", call. = FALSE)
stage <- function(name) {
  utils::write.table(data.frame(stage = name, recorded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
                     file.path(root, "smoke-stage-ledger.csv"), sep = ",", row.names = FALSE,
                     col.names = !file.exists(file.path(root, "smoke-stage-ledger.csv")), append = file.exists(file.path(root, "smoke-stage-ledger.csv")), quote = TRUE)
}
stage("root_receipt_written")
fx <- g2e_make_fixture()
stage("fixture_constructed")
g2e_validate_fixture(fx)
stage("fixture_validated")
suppressMessages(devtools::load_all(pkg, quiet = TRUE))
stage("optimizer_entered")
set.seed(g2e_seed + 100000L)
fit_res <- tryCatch(.gll_isdm_fit(
  fx$three_visit$rows, fx$three_visit$X, fx$three_visit$B, d = 1L,
  control = gllvmTMBcontrol(n_init = 3L, init_jitter = .25, se = TRUE, aghq = FALSE, warn_runaway = TRUE), silent = TRUE
), error = function(e) structure(list(message = conditionMessage(e)), class = "g2e_fit_error"))
stage("optimizer_returned")
if (inherits(fit_res, "g2e_fit_error")) {
  saveRDS(fx$truth, file.path(root, "truth.rds"))
  saveRDS(fit_res, file.path(root, "fit-error.rds"))
  saveRDS(list(status = "not_computed", reason = "fit_error", detail = fit_res$message), file.path(root, "profile-ledger.rds"))
  saveRDS(list(classification = NA_character_, diagnostic_state = "INVALID_FIT_ERROR", detail = fit_res$message), file.path(root, "decision-ledger.rds"))
  verdict <- "G2E_SMOKE_HOLD"
  writeLines(c("# G2E_SMOKE_HOLD", "", "The approved fit errored; no scientific classification was made.", "diagnostic_state: INVALID_FIT_ERROR", fit_res$message), file.path(root, "smoke-receipt.md"))
} else {
  saveRDS(fx$truth, file.path(root, "truth.rds"))
  saveRDS(fit_res, file.path(root, "fit.rds"))
  stage("fit_retained")
  tryCatch({
  profiles <- lapply(seq_len(6L), function(k) {
    base <- fit_res$tmb_obj$env$parList(fit_res$opt$par)$theta_diag_B
    offsets <- c(-2, -1, 0, 1, 2)
    rows <- lapply(offsets, function(offset) {
      pars <- fit_res$tmb_obj$env$parList(fit_res$opt$par)
      pars$theta_diag_B[[k]] <- base[[k]] + offset
      map <- fit_res$tmb_map
      selector <- factor(seq_along(base)); selector[[k]] <- NA; map$theta_diag_B <- selector
      obj <- TMB::MakeADFun(data = fit_res$tmb_data, parameters = pars, map = map, random = fit_res$random, DLL = fit_res$tmb_obj$env$DLL, silent = TRUE)
      opt <- tryCatch(stats::nlminb(obj$par, obj$fn, obj$gr), error = function(e) e)
      data.frame(offset = offset, nll = if (inherits(opt, "error")) NA_real_ else obj$fn(opt$par), convergence = if (inherits(opt, "error")) NA_integer_ else opt$convergence)
    })
    tab <- do.call(rbind, rows); tab$species <- paste0("sp", k); tab$delta_nll <- tab$nll - tab$nll[tab$offset == 0]
    tab
  })
  names(profiles) <- paste0("sp", 1:6)
  lower <- vapply(profiles, function(x) x$delta_nll[x$offset == -2], numeric(1))
  names(lower) <- names(profiles)
  profile_valid <- vapply(profiles, function(x) {
    nrow(x) == 5L && identical(x$offset, c(-2, -1, 0, 1, 2)) &&
      isTRUE(all(is.finite(x$nll))) && isTRUE(all(is.finite(x$delta_nll))) &&
      isTRUE(all(x$convergence == 0L)) && isTRUE(all.equal(x$delta_nll[x$offset == 0], 0, tolerance = 1e-8))
  }, logical(1))
  fixed <- .gllvmTMB_b_fix_values(fit_res)
  fixed_names <- fit_res$X_fix_names
  gamma_hat <- vapply(paste0("sp", 1:6), function(sp) {
    hit <- grep(paste0("trait", sp, ".*isdm_gbif_b_bias"), fixed_names)
    if (length(hit) != 1L) NA_real_ else fixed[[hit]]
  }, numeric(1))
  gamma_error <- max(abs(gamma_hat - fx$truth$constants$gamma))
  g2d_lower <- c(sp1 = 0.0319798, sp2 = 1.2044196, sp3 = 0.1211327, sp4 = 0.8805146, sp5 = 1.4706107, sp6 = 0.3712282)
  profile_data_valid <- isTRUE(all(profile_valid))
  profile_rule <- profile_data_valid && sum(lower - g2d_lower >= 1) >= 4L
  gamma_rule <- is.finite(gamma_error) && gamma_error < 0.371326
  classification <- if (!profile_data_valid || !is.finite(gamma_error)) NA_character_ else if (profile_rule && gamma_rule) "SUPPORT_RESPONSIVE" else if (!profile_rule && gamma_rule) "PROFILE_LIMITED" else "NONRESPONSIVE"
  gradient <- fit_res$tmb_obj$gr(fit_res$opt$par)
  eligibility <- list(
    three_restarts = is.data.frame(fit_res$restart_history) && nrow(fit_res$restart_history) == 3L,
    one_selected_restart = is.data.frame(fit_res$restart_history) && sum(fit_res$restart_history$selected) == 1L,
    finite_objective = is.finite(fit_res$tmb_obj$fn(fit_res$opt$par)), convergence_zero = identical(fit_res$opt$convergence, 0L),
    pdHess = isTRUE(fit_res$sd_report$pdHess), finite_gradient = all(is.finite(gradient)), max_abs_gradient = max(abs(gradient)),
    profiles_retained = length(profiles) == 6L, profiles_valid = profile_data_valid
  )
  saveRDS(profiles, file.path(root, "profile-ledger.rds"))
  diagnostic_state <- if (profile_data_valid && is.finite(gamma_error)) "CLASSIFIABLE" else "INVALID_PROFILE_OR_GAMMA"
  saveRDS(list(lower_delta_nll = lower, profile_valid = profile_valid, gamma_hat = gamma_hat, gamma_error = gamma_error, profile_rule = profile_rule, gamma_rule = gamma_rule, classification = classification, diagnostic_state = diagnostic_state, eligibility = eligibility), file.path(root, "decision-ledger.rds"))
  smoke_status <- if (all(unlist(eligibility[c("three_restarts", "one_selected_restart", "finite_objective", "convergence_zero", "pdHess", "finite_gradient", "profiles_retained", "profiles_valid")])) && eligibility$max_abs_gradient <= 1e-3) "G2E_SMOKE_COMPLETE" else "G2E_SMOKE_HOLD"
  writeLines(c(paste0("# ", smoke_status), "", if (is.na(classification)) paste0("diagnostic_state: ", diagnostic_state) else paste0("classification: ", classification), paste0("gamma_error: ", gamma_error), paste0("lower_delta_nll: ", paste(format(lower, digits = 8), collapse = ", ")), "This is one local diagnostic, not recovery evidence or campaign admission."), file.path(root, "smoke-receipt.md"))
  TRUE
  }, error = function(e) {
    detail <- conditionMessage(e)
    saveRDS(list(status = "not_computed", reason = "post_fit_error", detail = detail), file.path(root, "profile-ledger.rds"))
    saveRDS(list(classification = NA_character_, diagnostic_state = "INVALID_POST_FIT_ERROR", detail = detail), file.path(root, "decision-ledger.rds"))
    smoke_status <<- "G2E_SMOKE_HOLD"
    verdict <<- "G2E_SMOKE_HOLD"
    writeLines(c("# G2E_SMOKE_HOLD", "", "No scientific classification was made.", "diagnostic_state: INVALID_POST_FIT_ERROR", detail), file.path(root, "smoke-receipt.md"))
    FALSE
  })
}
stage("artifacts_written")
files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)); files <- files[!grepl("file-manifest\\.csv$", files)]
utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files), md5 = vapply(files, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
cat(if (exists("classification") && !is.na(classification)) classification else if (exists("smoke_status")) smoke_status else verdict, "\n")
