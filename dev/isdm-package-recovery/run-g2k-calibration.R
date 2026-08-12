#!/usr/bin/env Rscript

## G2k campaign coordinator.  It never fits: workers delegate one seed each to
## the frozen G2i estimator runner, and this coordinator binds/aggregates them.
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) { x <- grep(paste0("^--", name, "="), args, value = TRUE); if (!length(x)) default else sub(paste0("^--", name, "="), "", x[[1L]]) }
mode <- arg("mode", "validate")
root <- arg("output")
pkg <- normalizePath(arg("pkg", getwd()), mustWork = TRUE)
sha <- arg("campaign-sha")
seeds <- 86201L:86350L
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
source(file.path(base, "g2l-eligible-seeds.R"), local = TRUE)
hash <- function(x) unname(tools::md5sum(x))[[1L]]
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (!mode %in% c("validate", "init", "summarize") || (mode != "validate" && is.null(root))) stop("require --mode=validate|init|summarize and --output for non-validation", call. = FALSE)
if (identical(mode, "validate")) {
  screen <- g2l_screen_eligible_seeds()
  seeds <- screen$eligible_seeds
  stopifnot(length(seeds) == 150L, !any(seeds %in% c(86121L, 86122L)),
            identical(seeds, g2l_screen_eligible_seeds()$eligible_seeds))
  stopifnot(file.exists(file.path(base, "run-g2i-recovery-prerun.R")), file.exists(file.path(base, "2026-08-11-g2j-calibration-campaign-specification.md")))
  cat("G2K calibration coordinator validation PASS (no fit)\n"); quit(save = "no")
}
screen <- g2l_screen_eligible_seeds()
seeds <- screen$eligible_seeds
root <- normalizePath(if (grepl("^/", root)) root else file.path(getwd(), root), mustWork = FALSE)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) || !identical(sha, commit())) stop("fresh private root and exact --campaign-sha are required", call. = FALSE)
if (identical(mode, "init")) {
  if (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("campaign root must be fresh", call. = FALSE)
  dir.create(file.path(root, "seeds"), recursive = TRUE)
  saveRDS(list(kind = "G2K_CALIBRATION_CAMPAIGN", commit = commit(), seeds = seeds,
               runner_md5 = hash(script), worker_md5 = hash(file.path(base, "run-g2i-recovery-prerun.R")),
               specification_md5 = hash(file.path(base, "2026-08-11-g2j-calibration-campaign-specification.md")),
               candidate_seeds = screen$candidate_seeds, rejected_seeds = screen$rejected_seeds,
               screening_rule = "g2h_validate_fixture before fitting"), file.path(root, "campaign-receipt.rds"))
  utils::write.csv(data.frame(seed = seeds, attempt = 1L, stringsAsFactors = FALSE), file.path(root, "seed-grid.csv"), row.names = FALSE)
  writeLines("# G2K_CAMPAIGN_INITIALIZED\nNo fit was run.", file.path(root, "receipt.md")); cat("G2K_CAMPAIGN_INITIALIZED\n"); quit(save = "no")
}
receipt <- readRDS(file.path(root, "campaign-receipt.rds"))
if (!identical(receipt$commit, commit()) || !identical(receipt$seeds, seeds)) stop("campaign receipt drift", call. = FALSE)
paths <- file.path(root, "seeds", sprintf("seed-%05d", seeds), "decision-ledger.rds")
present <- file.exists(paths)
rows <- lapply(seq_along(seeds), function(i) {
  if (!present[[i]]) return(data.frame(seed = seeds[[i]], started = FALSE, classification = "NOT_STARTED", gradient = NA_real_, psi_error = NA_real_, recovery_pass = FALSE))
  x <- readRDS(paths[[i]]); m <- x$recovery_metrics
  data.frame(seed = seeds[[i]], started = TRUE, classification = x$classification, gradient = x$final_gradient,
             psi_error = if (is.list(m)) m$max_abs_psi_variance_error else NA_real_, recovery_pass = isTRUE(x$recovery_metrics_pass))
})
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(root, "all-attempt-summary.csv"), row.names = FALSE)
saveRDS(list(kind = "G2K_ALL_ATTEMPT_SUMMARY", n_requested = length(seeds), n_started = sum(out$started), n_missing = sum(!out$started),
             n_joint_pass = sum(out$classification == "PRE_RUN_RECOVERY_PASS", na.rm = TRUE),
             n_recovery_metric_pass = sum(out$recovery_pass, na.rm = TRUE), max_cores = 150L), file.path(root, "campaign-summary.rds"))
writeLines(paste0("# G2K_CAMPAIGN_SUMMARIZED\nstarted=", sum(out$started), "\nmissing=", sum(!out$started)), file.path(root, "summary-receipt.md")); cat("G2K_CAMPAIGN_SUMMARIZED\n")
