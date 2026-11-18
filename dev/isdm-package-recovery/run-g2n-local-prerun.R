#!/usr/bin/env Rscript

## Private G2n wrapper.  It delegates exactly one frozen G2i fixture fit to
## the retained runner, then classifies the retained fit through the G2n
## numerical-admission ledger.  It never creates an additional optimizer path.
args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root_arg <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- value("campaign-sha")
seed <- as.integer(value("seed", "86122"))
if (!mode %in% c("validate", "prerun") || is.null(root_arg)) {
  stop("require --mode=validate|prerun and --output=PATH", call. = FALSE)
}

script <- normalizePath(gsub("~+~", " ", sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), fixed = TRUE), mustWork = TRUE)
base <- dirname(script)
legacy <- file.path(base, "run-g2i-recovery-prerun.R")
fixture_file <- file.path(base, "g2h-360cell-fixture.R")
hash <- function(path) unname(tools::md5sum(path))[[1L]]
commit <- function() system2("git", c("-C", shQuote(pkg), "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
source(fixture_file, local = TRUE)

validate_contract <- function() {
  fixture <- g2h_make_fixture(seed = seed)
  g2h_validate_fixture(fixture)
  stopifnot(
    file.exists(legacy),
    file.exists(file.path(base, "2026-08-12-g2m-numerical-admission-protocol.md")),
    file.exists(file.path(base, "2026-08-12-g2n-numerical-admission-decision.md"))
  )
  invisible(fixture)
}
valid_profiles <- function(profiles) {
  identical(names(profiles), paste0("sp", seq_len(6L))) && all(vapply(profiles, function(x) {
    nrow(x) == 5L && identical(x$offset, c(-2, -1, 0, 1, 2)) &&
      all(is.finite(x$nll)) && all(x$convergence == 0L)
  }, logical(1L)))
}
valid_attempts <- function(polish, admission) {
  if (!is.list(polish) || !identical(polish$schema, "G2I_INTERNAL_ISDM_POLISH_V1") ||
      !is.list(polish$raw) || !is.numeric(polish$raw$convergence) ||
      length(polish$raw$convergence) != 1L || !is.finite(polish$raw$convergence)) return(FALSE)
  status <- admission$polish_status
  if (identical(status, "NOT_REQUIRED")) return(!isTRUE(polish$attempted))
  attempts <- polish$candidate_attempts$attempts
  is.list(attempts) && length(attempts) >= 1L && all(vapply(attempts, function(x) {
    is.list(x) && x$method %in% c("nlminb_retry", "covariance_newton") &&
      !is.null(x$accepted)
  }, logical(1L)))
}
manifest <- function(root) {
  files <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE),
                   file.path(root, "g2n-final-provenance-closure.rds"))
  utils::write.csv(data.frame(
    path = sub(paste0("^", root, "/"), "", files),
    md5 = vapply(files, hash, character(1L)),
    stringsAsFactors = FALSE
  ), file.path(root, "g2n-file-manifest.csv"), row.names = FALSE)
  closure_files <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE),
                           file.path(root, "g2n-final-provenance-closure.rds"))
  closure <- list(
    kind = "G2N_LOCAL_PRERUN_FINAL_PROVENANCE_CLOSURE",
    files = stats::setNames(unname(tools::md5sum(closure_files)),
      sub(paste0("^", root, "/"), "", closure_files))
  )
  saveRDS(closure, file.path(root, "g2n-final-provenance-closure.rds"))
  stopifnot(identical(unname(tools::md5sum(file.path(root, names(closure$files)))),
                      unname(closure$files)))
}

if (identical(mode, "validate")) {
  validate_contract()
  cat("G2N local pre-run validation PASS (no fit)\n")
  quit(save = "no")
}

root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg),
                      mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) ||
    (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) ||
    !identical(campaign_sha, commit()) || length(seed) != 1L || is.na(seed) || seed < 1L) {
  stop("fresh private root, exact current --campaign-sha, and positive seed are required", call. = FALSE)
}
fixture <- validate_contract()
dir.create(root, recursive = TRUE)
receipt <- list(
  kind = "G2N_LOCAL_PRERUN", commit = commit(), seed = seed,
  runner_md5 = hash(script), legacy_runner_md5 = hash(legacy),
  fixture_md5 = hash(fixture_file),
  g2m_protocol_md5 = hash(file.path(base, "2026-08-12-g2m-numerical-admission-protocol.md")),
  g2n_decision_md5 = hash(file.path(base, "2026-08-12-g2n-numerical-admission-decision.md")),
  source_gate = "frozen_gbif_only_bias_gate"
)
saveRDS(receipt, file.path(root, "g2n-root-receipt.rds"))
saveRDS(fixture$truth, file.path(root, "g2n-truth.rds"))
legacy_root <- file.path(root, "g2i-delegate")

legacy_args <- c(
  "--vanilla", legacy, "--mode=prerun", paste0("--output=", legacy_root),
  paste0("--pkg=", pkg), paste0("--campaign-sha=", campaign_sha),
  paste0("--seed=", seed)
)
started <- proc.time()[["elapsed"]]
legacy_output <- system2(file.path(R.home("bin"), "Rscript"), legacy_args,
                         stdout = TRUE, stderr = TRUE)
elapsed_s <- proc.time()[["elapsed"]] - started
writeLines(legacy_output, file.path(root, "g2n-legacy-runner.log"))

fit_file <- file.path(legacy_root, "fit.rds")
profiles_file <- file.path(legacy_root, "profiles.rds")
metrics_file <- file.path(legacy_root, "recovery-summary.rds")
legacy_ledger_file <- file.path(legacy_root, "decision-ledger.rds")
fit <- if (file.exists(fit_file)) readRDS(fit_file) else NULL
profiles <- if (file.exists(profiles_file)) readRDS(profiles_file) else NULL
metrics <- if (file.exists(metrics_file)) readRDS(metrics_file) else NULL
legacy_ledger <- if (file.exists(legacy_ledger_file)) readRDS(legacy_ledger_file) else NULL
admission <- if (is.list(fit)) fit$isdm_numerical_admission else NULL
polish <- if (is.list(fit)) fit$isdm_polish_provenance else NULL
profile_ok <- is.list(profiles) && valid_profiles(profiles)
metrics_ok <- is.list(legacy_ledger) && isTRUE(legacy_ledger$recovery_metrics_pass)
restart_ok <- is.list(fit) && nrow(fit$restart_history) == 3L
admission_ok <- is.list(admission) && isTRUE(admission$numerical_admission) &&
  valid_attempts(polish, admission)
classification <- if (restart_ok && profile_ok && metrics_ok && admission_ok)
  "G2N_LOCAL_PRERUN_PASS" else "G2N_LOCAL_PRERUN_HOLD"
ledger <- list(
  classification = classification,
  source_gate_valid = TRUE,
  three_restarts = restart_ok,
  profile_valid = profile_ok,
  recovery_metrics_pass = metrics_ok,
  numerical_admission = admission,
  raw_state = if (is.list(polish)) polish$raw else NULL,
  candidate_provenance = polish,
  legacy_ledger = legacy_ledger,
  elapsed_s = elapsed_s
)
saveRDS(ledger, file.path(root, "g2n-decision-ledger.rds"))
writeLines(paste("#", classification), file.path(root, "g2n-prerun-receipt.md"))
manifest(root)
cat(classification, "\n")
