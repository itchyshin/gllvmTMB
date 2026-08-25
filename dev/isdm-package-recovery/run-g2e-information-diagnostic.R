#!/usr/bin/env Rscript

## Developer-only G2e no-fit preflight.  It deliberately does not fit a model.
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "validate")
root <- arg_value("output", NULL)
pkg <- normalizePath(arg_value("pkg", getwd()), mustWork = TRUE)
if (!mode %in% c("validate", "preflight")) stop("mode must be validate or preflight", call. = FALSE)
if (is.null(root)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(if (grepl("^/", root)) root else file.path(getwd(), root), mustWork = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(
  gsub("~+~", " ", sub("^--file=", "", script_arg[[1L]]), fixed = TRUE),
  mustWork = TRUE
)
source(file.path(dirname(runner_file), "g2e-support-fixture.R"), local = TRUE)
protocol_file <- file.path(dirname(runner_file), "2026-08-11-g2e-information-diagnostic-protocol.md")
decision_file <- file.path(dirname(runner_file), "2026-08-11-g2e-information-diagnostic-decision.md")
smoke_runner_file <- file.path(dirname(runner_file), "run-g2e-information-smoke.R")
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
package_commit <- function() system2("git", c("-C", shQuote(pkg), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]]
validate <- function() {
  fx <- g2e_make_fixture()
  g2e_validate_fixture(fx)
  info <- g2e_expected_information(fx)
  if (!all(is.finite(info$gamma_poisson_information)) || any(info$gamma_poisson_information <= 0)) stop("G2e gamma information is invalid", call. = FALSE)
  if (any(!is.finite(info$survey_probability)) || any(info$survey_probability <= 0 | info$survey_probability >= 1)) stop("G2e PA probabilities are invalid", call. = FALSE)
  list(fixture = fx, information = info)
}
if (mode == "validate") {
  validate()
  cat("G2E fixture/support/source-gate/oracle validation PASS (no fit)\n")
} else {
  parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
  if (!startsWith(root, paste0(parent, "/")) || grepl("g2[cd]", basename(root), ignore.case = TRUE)) stop("G2e root must be a fresh non-G2c/non-G2d private result child", call. = FALSE)
  if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("G2e preflight root must be empty", call. = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  checked <- validate()
  receipt <- list(kind = "G2E_PREFLIGHT_SENTINEL", package_commit = package_commit(), support_multiplier = 2, seed = g2e_seed,
                  runner_md5 = hash_file(runner_file), fixture_md5 = hash_file(file.path(dirname(runner_file), "g2e-support-fixture.R")),
                  smoke_runner_md5 = hash_file(smoke_runner_file), protocol_md5 = hash_file(protocol_file), decision_md5 = hash_file(decision_file))
  saveRDS(receipt, file.path(root, "root-receipt.rds"))
  if (!identical(readRDS(file.path(root, "root-receipt.rds")), receipt)) stop("root receipt serialization failed", call. = FALSE)
  saveRDS(receipt, file.path(root, "preflight-sentinel.rds"))
  if (!identical(readRDS(file.path(root, "preflight-sentinel.rds")), receipt)) stop("preflight serialization failed", call. = FALSE)
  saveRDS(checked$fixture$truth, file.path(root, "truth.rds"))
  saveRDS(checked$information, file.path(root, "information-oracle.rds"))
  retained <- file.path(root, c("root-receipt.rds", "preflight-sentinel.rds", "truth.rds", "information-oracle.rds"))
  utils::write.csv(data.frame(path = basename(retained), md5 = vapply(retained, hash_file, character(1))), file.path(root, "preflight-file-manifest.csv"), row.names = FALSE)
  writeLines(c("# G2E_PREFLIGHT_PASS", "", "No optimiser, profile, smoke, or campaign ran.", "The root retains the support-multiplier truth and analytic information oracle."), file.path(root, "preflight-receipt.md"))
  cat("G2E_PREFLIGHT_PASS (no fit)\n")
}
