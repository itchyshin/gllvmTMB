#!/usr/bin/env Rscript

## Private G2f smoke launcher.  `validate` performs no package loading or fit.
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
if (!mode %in% c("validate", "smoke", "reconcile")) stop("mode must be validate, smoke, or reconcile", call. = FALSE)
if (is.null(root_arg)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(runner_file), "g2f-pa-replication-fixture.R"), local = TRUE)
protocol_file <- file.path(dirname(runner_file), "2026-08-11-g2f-pa-replication-protocol.md")
decision_file <- file.path(dirname(runner_file), "2026-08-11-g2f-pa-replication-decision.md")
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
package_commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]]
assert_campaign_sha <- function() {
  if (is.null(campaign_sha) || !grepl("^[0-9a-f]{40}$", campaign_sha) || !identical(campaign_sha, package_commit())) {
    stop("--campaign-sha must be the current 40-hex package commit", call. = FALSE)
  }
  campaign_sha
}
validate_smoke_contract <- function() {
  fx <- g2f_make_fixture()
  g2f_validate_fixture(fx)
  oracle <- g2f_information_oracle(fx)
  stopifnot(
    identical(g2f_seed, 86101L), identical(fx$truth$n_visit, 6L),
    identical(oracle$pa_information_ratio, 2),
    all(is.finite(oracle$gbif_information_eta))
  )
  cat("G2F smoke-launcher validation PASS (no fit)\n")
  invisible(fx)
}
if (mode == "validate") {
  validate_smoke_contract()
  quit(save = "no", status = 0L)
}

## This no-fit route closes an interrupted post-fit root without fabricating a
## profile result. It is deliberately narrower than a retry: it may only add
## failure placeholders to a root that retained the exact fit but no ledgers.
if (mode == "reconcile") {
  parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
  if (!startsWith(root, paste0(parent, "/")) || !grepl("^g2f", basename(root), ignore.case = TRUE)) {
    stop("G2f reconciliation root must be a G2f private result child", call. = FALSE)
  }
  required <- file.path(root, c("root-receipt.rds", "truth.rds", "fit.rds", "smoke-stage-ledger.csv"))
  if (!all(file.exists(required)) || file.exists(file.path(root, "decision-ledger.rds")) || file.exists(file.path(root, "profile-ledger.rds"))) {
    stop("reconcile requires a retained unclosed post-fit root", call. = FALSE)
  }
  original_receipt <- readRDS(file.path(root, "root-receipt.rds"))
  if (!identical(original_receipt$purpose, "one-approved-local-g2f-pa-replication-smoke") ||
      !identical(original_receipt$seed, 86101L) || !identical(original_receipt$n_visit, 6L)) {
    stop("root receipt is not the frozen G2f smoke contract", call. = FALSE)
  }
  detail <- "process terminated after fit_retained and before profile/decision/manifest closure; retained fit is not classified"
  saveRDS(list(status = "not_computed", reason = "unclosed_post_fit_termination", detail = detail), file.path(root, "profile-ledger.rds"))
  saveRDS(list(classification = NA_character_, diagnostic_state = "INVALID_UNCLOSED_POST_FIT", detail = detail), file.path(root, "decision-ledger.rds"))
  reconciliation <- list(kind = "G2F_POST_FIT_RECONCILIATION", original_runner_md5 = original_receipt$runner_md5,
    reconciliation_runner_md5 = hash_file(runner_file), reconciled_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), detail = detail)
  saveRDS(reconciliation, file.path(root, "post-fit-reconciliation.rds"))
  utils::write.table(data.frame(stage = "reconciled_invalid_post_fit", recorded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
    file.path(root, "smoke-stage-ledger.csv"), sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE, quote = TRUE)
  writeLines(c("# G2F_SMOKE_HOLD", "", "No scientific classification was made.", "diagnostic_state: INVALID_UNCLOSED_POST_FIT", detail), file.path(root, "smoke-receipt.md"))
  files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE))
  files <- files[!grepl("file-manifest\\.csv$", files)]
  utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files), md5 = vapply(files, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
  cat("G2F_SMOKE_HOLD\n")
  quit(save = "no", status = 0L)
}

parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || grepl("g2c|g2d|g2e", basename(root), ignore.case = TRUE)) {
  stop("G2f smoke root must be a fresh non-G2c/non-G2d/non-G2e private result child", call. = FALSE)
}
if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("G2f smoke root must be empty", call. = FALSE)
assert_campaign_sha()
validate_smoke_contract()
dir.create(root, recursive = TRUE, showWarnings = FALSE)
receipt <- list(
  purpose = "one-approved-local-g2f-pa-replication-smoke", package_commit = package_commit(),
  seed = g2f_seed, n_visit = 6L, runner_md5 = hash_file(runner_file),
  fixture_md5 = hash_file(file.path(dirname(runner_file), "g2f-pa-replication-fixture.R")),
  protocol_md5 = hash_file(protocol_file), decision_md5 = hash_file(decision_file),
  created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), r_version = R.version.string
)
saveRDS(receipt, file.path(root, "root-receipt.rds"))
if (!identical(readRDS(file.path(root, "root-receipt.rds")), receipt)) stop("root receipt serialization failed", call. = FALSE)
stage <- function(name) {
  path <- file.path(root, "smoke-stage-ledger.csv")
  utils::write.table(data.frame(stage = name, recorded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
    path, sep = ",", row.names = FALSE, col.names = !file.exists(path), append = file.exists(path), quote = TRUE)
}
stage("root_receipt_written")
fx <- g2f_make_fixture()
stage("fixture_constructed")
g2f_validate_fixture(fx)
stage("fixture_validated")
suppressMessages(devtools::load_all(pkg, quiet = TRUE))
stage("optimizer_entered")
set.seed(g2f_seed + 100000L)
fit_res <- tryCatch(.gll_isdm_fit(
  fx$six_visit$rows, fx$six_visit$X, fx$six_visit$B, d = 1L,
  control = gllvmTMBcontrol(n_init = 3L, init_jitter = .25, se = TRUE, aghq = FALSE, warn_runaway = TRUE),
  silent = TRUE
), error = function(e) structure(list(message = conditionMessage(e)), class = "g2f_fit_error"))
stage("optimizer_returned")
if (inherits(fit_res, "g2f_fit_error")) {
  saveRDS(fx$truth, file.path(root, "truth.rds"))
  saveRDS(fit_res, file.path(root, "fit-error.rds"))
  saveRDS(list(status = "not_computed", reason = "fit_error", detail = fit_res$message), file.path(root, "profile-ledger.rds"))
  saveRDS(list(classification = NA_character_, diagnostic_state = "INVALID_FIT_ERROR", detail = fit_res$message), file.path(root, "decision-ledger.rds"))
  smoke_status <- "G2F_SMOKE_HOLD"
  writeLines(c("# G2F_SMOKE_HOLD", "", "The approved fit errored; no scientific classification was made.", "diagnostic_state: INVALID_FIT_ERROR", fit_res$message), file.path(root, "smoke-receipt.md"))
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
        selector <- factor(seq_along(base)); selector[[k]] <- NA
        map$theta_diag_B <- selector
        obj <- TMB::MakeADFun(data = fit_res$tmb_data, parameters = pars, map = map,
          random = fit_res$random, DLL = fit_res$tmb_obj$env$DLL, silent = TRUE)
        opt <- tryCatch(stats::nlminb(obj$par, obj$fn, obj$gr), error = function(e) e)
        data.frame(offset = offset, nll = if (inherits(opt, "error")) NA_real_ else obj$fn(opt$par),
          convergence = if (inherits(opt, "error")) NA_integer_ else opt$convergence)
      })
      tab <- do.call(rbind, rows)
      tab$species <- paste0("sp", k)
      tab$delta_nll <- tab$nll - tab$nll[tab$offset == 0]
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
    gamma_hat <- vapply(paste0("sp", 1:6), function(sp) {
      hit <- grep(paste0("trait", sp, ".*isdm_gbif_b_bias"), fit_res$X_fix_names)
      if (length(hit) != 1L) NA_real_ else fixed[[hit]]
    }, numeric(1))
    gamma_error <- max(abs(gamma_hat - fx$truth$constants$gamma))
    g2d_lower <- c(sp1 = 0.0319798, sp2 = 1.2044196, sp3 = 0.1211327, sp4 = 0.8805146, sp5 = 1.4706107, sp6 = 0.3712282)
    profile_data_valid <- isTRUE(all(profile_valid))
    profile_rule <- profile_data_valid && sum(lower - g2d_lower >= 1) >= 4L
    gamma_rule <- is.finite(gamma_error) && gamma_error < 0.371326
    classification <- if (!profile_data_valid || !is.finite(gamma_error)) NA_character_ else if (profile_rule && gamma_rule) "REPLICATION_RESPONSIVE" else if (!profile_rule && gamma_rule) "PROFILE_LIMITED" else "NONRESPONSIVE"
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
    saveRDS(list(lower_delta_nll = lower, profile_valid = profile_valid, gamma_hat = gamma_hat,
      gamma_error = gamma_error, profile_rule = profile_rule, gamma_rule = gamma_rule,
      classification = classification, diagnostic_state = diagnostic_state, eligibility = eligibility),
      file.path(root, "decision-ledger.rds"))
    smoke_status <- if (all(unlist(eligibility[c("three_restarts", "one_selected_restart", "finite_objective", "convergence_zero", "pdHess", "finite_gradient", "profiles_retained", "profiles_valid")])) && eligibility$max_abs_gradient <= 1e-3) "G2F_SMOKE_COMPLETE" else "G2F_SMOKE_HOLD"
    writeLines(c(paste0("# ", smoke_status), "", if (is.na(classification)) paste0("diagnostic_state: ", diagnostic_state) else paste0("classification: ", classification), paste0("gamma_error: ", gamma_error), paste0("lower_delta_nll: ", paste(format(lower, digits = 8), collapse = ", ")), "This is one local diagnostic, not recovery evidence or campaign admission."), file.path(root, "smoke-receipt.md"))
  }, error = function(e) {
    detail <- conditionMessage(e)
    saveRDS(list(status = "not_computed", reason = "post_fit_error", detail = detail), file.path(root, "profile-ledger.rds"))
    saveRDS(list(classification = NA_character_, diagnostic_state = "INVALID_POST_FIT_ERROR", detail = detail), file.path(root, "decision-ledger.rds"))
    smoke_status <<- "G2F_SMOKE_HOLD"
    writeLines(c("# G2F_SMOKE_HOLD", "", "No scientific classification was made.", "diagnostic_state: INVALID_POST_FIT_ERROR", detail), file.path(root, "smoke-receipt.md"))
  })
}
stage("artifacts_written")
files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE))
files <- files[!grepl("file-manifest\\.csv$", files)]
utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files), md5 = vapply(files, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
cat(if (exists("classification") && !is.na(classification)) classification else smoke_status, "\n")
