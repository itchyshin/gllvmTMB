#!/usr/bin/env Rscript
# Approved AA-03 production batch: one frozen n=240 Gaussian latent cell.
# It deliberately reuses v4's manifest and gates, but writes a separate packet.

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) stop("Required: ", flag, " VALUE", call. = FALSE)
  args[[hit + 1L]]
}
if (length(args) != 8L || !identical(args[c(1L, 3L, 5L, 7L)],
  c("--output", "--source-archive", "--source-archive-sha", "--library"))) {
  stop("Usage: run-production.R --output DIR --source-archive FILE --source-archive-sha SHA --library DIR", call. = FALSE)
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
repo <- normalizePath(file.path(dirname(normalizePath(script_arg, mustWork = TRUE)), "../../.."), mustWork = TRUE)
output <- normalizePath(value("--output"), mustWork = TRUE)
archive <- normalizePath(value("--source-archive"), mustWork = TRUE)
archive_sha <- value("--source-archive-sha")
library_dir <- normalizePath(value("--library"), mustWork = TRUE)
if (!grepl("^[0-9a-f]{64}$", archive_sha) || startsWith(output, paste0(repo, .Platform$file.sep))) {
  stop("AA-03 production inputs are invalid.", call. = FALSE)
}
workers_raw <- trimws(Sys.getenv("NWORKERS", "150"))
workers <- suppressWarnings(as.integer(workers_raw))
available_raw <- trimws(Sys.getenv("TOTORO_NPROC", ""))
if (!nzchar(available_raw)) available_raw <- trimws(system2("nproc", stdout = TRUE)[1L])
available <- suppressWarnings(as.integer(available_raw))
if (is.na(workers) || workers < 1L || workers > 150L || is.na(available) || workers > available - 4L) {
  stop("NWORKERS must be in 1..150 and leave four host cores free (workers=",
       workers_raw, ", nproc=", available_raw, ").", call. = FALSE)
}
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
           VECLIB_MAXIMUM_THREADS = "1", BLIS_NUM_THREADS = "1")
.libPaths(c(library_dir, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
loaded <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
if (!startsWith(loaded, paste0(library_dir, .Platform$file.sep))) stop("Archive-installed package was not loaded.", call. = FALSE)

for (f in c(
  file.path(repo, "inst", "sim", "cran07-core", c("schema.R", "campaign.R", "attempt-runner.R", "batch.R")),
  file.path(repo, "inst", "sim", "cran07-v3", c("campaign-v3.R", "gates-v3.R")),
  file.path(repo, "inst", "sim", "cran07-v4", c("campaign-v4.R", "schema-v4.R", "attempt-runner-v4.R", "gates-v4.R", "summary-v4.R"))
)) source(f, local = .GlobalEnv)

campaign <- "cran07-core-recovery-v4"
registry <- cran07_v4_read_campaign_registry(campaign, repo)
cell <- registry[registry$cell_id == "g_latent_n240", , drop = FALSE]
if (nrow(cell) != 1L || cell$n_unit != 240L || cell$n_traits != 3L || cell$rank != 1L || cell$mode != "latent") {
  stop("AA-03 production registry identity is not exact.", call. = FALSE)
}
manifest <- cran07_v4_manifest(registry, campaign, "production", archive_sha, "g_latent_n240")
cran07_v4_validate_manifest(manifest, registry, campaign, "production", archive_sha, "g_latent_n240")
utils::write.csv(manifest, file.path(output, "manifest.csv"), row.names = FALSE)
dir.create(file.path(output, "receipts"), showWarnings = FALSE)
pilot_gate <- list(production_authorized = TRUE, source_archive_sha256 = archive_sha,
  admitted_cells = data.frame(campaign_id = campaign, cell_id = "g_latent_n240", stringsAsFactors = FALSE))
saveRDS(pilot_gate, file.path(output, "receipts", "aa03-authority.rds"), version = 3)

run_one <- function(i) {
  key <- manifest[i, , drop = FALSE]
  path <- cran07_attempt_path(output, key$cell_id, key$replicate)
  answer <- tryCatch(
    cran07_v4_run_attempt(cell, key$replicate, campaign, attr(registry, "sha256"), archive_sha, "production"),
    error = function(e) list(error_class = class(e)[1L], error_message = conditionMessage(e)))
  if (is.null(answer$attempt)) {
    utils::write.csv(data.frame(replicate = key$replicate, error_class = answer$error_class,
      error_message = answer$error_message, stringsAsFactors = FALSE),
      file.path(output, sprintf("worker-error-%04d.csv", key$replicate)), row.names = FALSE)
    return(FALSE)
  }
  cran07_v4_write_attempt(answer, path)
  TRUE
}
ok <- unlist(parallel::mclapply(seq_len(nrow(manifest)), run_one, mc.cores = workers,
                                mc.preschedule = FALSE, mc.set.seed = FALSE, mc.cleanup = TRUE), use.names = FALSE)
if (length(ok) != nrow(manifest) || !all(ok)) {
  stop("AA-03 production has worker errors; retained files are incomplete and HOLD.", call. = FALSE)
}
summary <- cran07_v4_summarize(output, manifest, registry, campaign, "production", archive_sha, pilot_gate)
saveRDS(summary, file.path(output, "receipts", "summary.rds"), version = 3)
utils::write.csv(summary$v4_gate, file.path(output, "receipts", "cell-gate.csv"), row.names = FALSE)
receipt <- data.frame(source_archive = basename(archive), source_archive_sha256 = archive_sha,
  package_path = loaded, package_version = as.character(utils::packageVersion("gllvmTMB")),
  cell_id = "g_latent_n240", attempts = nrow(manifest), workers = workers,
  all_attempts_retained = summary$v4_identity$complete,
  cell_pass = summary$v4_gate$cell_pass[[1L]], stringsAsFactors = FALSE)
utils::write.csv(receipt, file.path(output, "receipts", "production-receipt.csv"), row.names = FALSE)
if (!isTRUE(summary$v4_gate$cell_pass[[1L]])) quit(save = "no", status = 3L)
cat("aa03_production=PASS\n")
