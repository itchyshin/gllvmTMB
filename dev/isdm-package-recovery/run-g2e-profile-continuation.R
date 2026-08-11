#!/usr/bin/env Rscript

## Resume profiles from a retained G2e smoke fit.  This never calls .gll_isdm_fit().
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "validate")
root_arg <- arg_value("output", NULL)
pkg <- normalizePath(arg_value("pkg", getwd()), mustWork = TRUE)
if (!mode %in% c("validate", "continue")) stop("mode must be validate or continue", call. = FALSE)
if (is.null(root_arg)) stop("--output=<retained smoke root> is required", call. = FALSE)
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg), mustWork = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(runner_file), "g2e-support-fixture.R"), local = TRUE)
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
if (mode == "validate") {
  stopifnot(identical(g2e_seed, 86101L), identical(g2e_support_multiplier, 2))
  cat("G2E profile-continuation validation PASS (no fit)\n")
  quit(save = "no", status = 0L)
}
required <- file.path(root, c("root-receipt.rds", "fit.rds", "truth.rds", "smoke-stage-ledger.csv"))
if (!all(file.exists(required) & file.info(required)$size > 0L)) stop("retained G2e fit root is incomplete", call. = FALSE)
if (file.exists(file.path(root, "file-manifest.csv"))) stop("root is already closed", call. = FALSE)
suppressMessages(devtools::load_all(pkg, quiet = TRUE))
fit <- readRDS(file.path(root, "fit.rds"))
stage <- function(name) utils::write.table(
  data.frame(stage = name, recorded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
  file.path(root, "smoke-stage-ledger.csv"), sep = ",", row.names = FALSE,
  col.names = FALSE, append = TRUE, quote = TRUE
)
stage("profile_continuation_entered")
profiles <- lapply(seq_len(6L), function(k) {
  base <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
  offsets <- c(-2, -1, 0, 1, 2)
  rows <- lapply(offsets, function(offset) {
    pars <- fit$tmb_obj$env$parList(fit$opt$par)
    pars$theta_diag_B[[k]] <- base[[k]] + offset
    map <- fit$tmb_map; selector <- factor(seq_along(base)); selector[[k]] <- NA; map$theta_diag_B <- selector
    obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = pars, map = map, random = fit$random, DLL = fit$tmb_obj$env$DLL, silent = TRUE)
    opt <- tryCatch(stats::nlminb(obj$par, obj$fn, obj$gr), error = function(e) e)
    data.frame(offset = offset, nll = if (inherits(opt, "error")) NA_real_ else obj$fn(opt$par), convergence = if (inherits(opt, "error")) NA_integer_ else opt$convergence)
  })
  tab <- do.call(rbind, rows); tab$species <- paste0("sp", k); tab$delta_nll <- tab$nll - tab$nll[tab$offset == 0]
  tab
})
names(profiles) <- paste0("sp", 1:6)
lower <- vapply(profiles, function(x) x$delta_nll[x$offset == -2], numeric(1)); names(lower) <- names(profiles)
profile_valid <- vapply(profiles, function(x) nrow(x) == 5L && identical(x$offset, c(-2, -1, 0, 1, 2)) && isTRUE(all(is.finite(x$nll))) && isTRUE(all(is.finite(x$delta_nll))) && isTRUE(all(x$convergence == 0L)) && isTRUE(all.equal(x$delta_nll[x$offset == 0], 0, tolerance = 1e-8)), logical(1))
fixed <- .gllvmTMB_b_fix_values(fit); fixed_names <- fit$X_fix_names
gamma_hat <- vapply(paste0("sp", 1:6), function(sp) { hit <- grep(paste0("trait", sp, ".*isdm_gbif_b_bias"), fixed_names); if (length(hit) == 1L) fixed[[hit]] else NA_real_ }, numeric(1))
gamma_error <- max(abs(gamma_hat - g2e_truth_constants()$gamma))
g2d_lower <- c(sp1 = 0.0319798, sp2 = 1.2044196, sp3 = 0.1211327, sp4 = 0.8805146, sp5 = 1.4706107, sp6 = 0.3712282)
profile_data_valid <- isTRUE(all(profile_valid))
profile_rule <- profile_data_valid && sum(lower - g2d_lower >= 1) >= 4L
gamma_rule <- is.finite(gamma_error) && gamma_error < 0.371326
classification <- if (!profile_data_valid || !is.finite(gamma_error)) NA_character_ else if (profile_rule && gamma_rule) "SUPPORT_RESPONSIVE" else if (!profile_rule && gamma_rule) "PROFILE_LIMITED" else "NONRESPONSIVE"
gradient <- fit$tmb_obj$gr(fit$opt$par)
eligibility <- list(three_restarts = is.data.frame(fit$restart_history) && nrow(fit$restart_history) == 3L, one_selected_restart = is.data.frame(fit$restart_history) && sum(fit$restart_history$selected) == 1L, finite_objective = is.finite(fit$tmb_obj$fn(fit$opt$par)), convergence_zero = identical(fit$opt$convergence, 0L), pdHess = isTRUE(fit$sd_report$pdHess), finite_gradient = all(is.finite(gradient)), max_abs_gradient = max(abs(gradient)), profiles_retained = length(profiles) == 6L, profiles_valid = profile_data_valid)
state <- if (profile_data_valid && is.finite(gamma_error)) "CLASSIFIABLE" else "INVALID_PROFILE_OR_GAMMA"
saveRDS(profiles, file.path(root, "profile-ledger.rds"))
saveRDS(list(lower_delta_nll = lower, profile_valid = profile_valid, gamma_hat = gamma_hat, gamma_error = gamma_error, profile_rule = profile_rule, gamma_rule = gamma_rule, classification = classification, diagnostic_state = state, eligibility = eligibility, continuation_runner_md5 = hash_file(runner_file)), file.path(root, "decision-ledger.rds"))
smoke_status <- if (all(unlist(eligibility[c("three_restarts", "one_selected_restart", "finite_objective", "convergence_zero", "pdHess", "finite_gradient", "profiles_retained", "profiles_valid")])) && eligibility$max_abs_gradient <= 1e-3) "G2E_SMOKE_COMPLETE" else "G2E_SMOKE_HOLD"
writeLines(c(paste0("# ", smoke_status), "", if (is.na(classification)) paste0("diagnostic_state: ", state) else paste0("classification: ", classification), paste0("gamma_error: ", gamma_error), paste0("lower_delta_nll: ", paste(format(lower, digits = 8), collapse = ", ")), "Profiles were resumed from the retained approved three-restart fit; no additional main fit ran.", "This is one local diagnostic, not recovery evidence or campaign admission."), file.path(root, "smoke-receipt.md"))
stage("profile_continuation_closed")
files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)); files <- files[!grepl("file-manifest\\.csv$", files)]
utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", files), md5 = vapply(files, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
cat(if (is.na(classification)) smoke_status else classification, "\n")
