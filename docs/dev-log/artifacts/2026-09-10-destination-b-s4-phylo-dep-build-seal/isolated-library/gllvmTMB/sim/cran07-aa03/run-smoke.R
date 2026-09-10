#!/usr/bin/env Rscript
# The in-archive half of the AA-03 one-attempt smoke receipt.

args <- commandArgs(trailingOnly = TRUE)
value <- function(flag) {
  hit <- match(flag, args)
  if (is.na(hit) || hit == length(args)) {
    stop("Required: ", flag, " VALUE", call. = FALSE)
  }
  args[[hit + 1L]]
}
if (length(args) != 8L || !identical(args[c(1L, 3L, 5L, 7L)],
                                      c("--output", "--source-archive",
                                        "--source-archive-sha", "--library"))) {
  stop("Usage: run-smoke.R --output DIR --source-archive FILE --source-archive-sha SHA --library DIR",
       call. = FALSE)
}

script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                            value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
repo <- normalizePath(file.path(dirname(normalizePath(script_arg, mustWork = TRUE)),
                                "../../.."), mustWork = TRUE)
output <- normalizePath(value("--output"), mustWork = TRUE)
archive <- normalizePath(value("--source-archive"), mustWork = TRUE)
archive_sha <- value("--source-archive-sha")
library_dir <- normalizePath(value("--library"), mustWork = TRUE)
if (!grepl("^[0-9a-f]{64}$", archive_sha) ||
    startsWith(output, paste0(repo, .Platform$file.sep))) {
  stop("AA-03 smoke receipt inputs are invalid.", call. = FALSE)
}
.libPaths(c(library_dir, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
loaded <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
if (!startsWith(loaded, paste0(library_dir, .Platform$file.sep))) {
  stop("AA-03 smoke did not load the archive-installed package.", call. = FALSE)
}

core_dir <- file.path(repo, "inst", "sim", "cran07-core")
v3_dir <- file.path(repo, "inst", "sim", "cran07-v3")
v4_dir <- file.path(repo, "inst", "sim", "cran07-v4")
for (f in c(file.path(core_dir, c("schema.R", "campaign.R", "attempt-runner.R", "batch.R")),
            file.path(v3_dir, c("campaign-v3.R", "gates-v3.R")),
            file.path(v4_dir, c("campaign-v4.R", "schema-v4.R",
                                "attempt-runner-v4.R", "gates-v4.R",
                                "summary-v4.R")))) {
  source(f, local = .GlobalEnv)
}
registry <- cran07_v4_read_campaign_registry("cran07-core-recovery-v4", repo)
cell <- registry[registry$cell_id == "g_latent_n240", , drop = FALSE]
if (nrow(cell) != 1L || cell$n_unit != 240L || cell$n_traits != 3L ||
    cell$rank != 1L || cell$mode != "latent" || cell$truth_profile != "base_latent") {
  stop("AA-03 smoke registry identity is not exact.", call. = FALSE)
}
result <- cran07_v4_run_attempt(cell, replicate = 1L,
  campaign_id = "cran07-core-recovery-v4",
  registry_sha256 = attr(registry, "sha256"),
  source_archive_sha256 = archive_sha, stage = "smoke")
if (!identical(result$attempt$cell_id, "g_latent_n240") ||
    !identical(result$attempt$seed,
               cran07_seed(cell$cell_number, 1L,
                           cran07_v4_seed_offset("cran07-core-recovery-v4", "smoke")))) {
  stop("AA-03 smoke did not retain the frozen cell and seed identity.", call. = FALSE)
}
saveRDS(result, file.path(output, "attempt.rds"), version = 3)
receipt <- data.frame(
  source_archive = basename(archive), source_archive_sha256 = archive_sha,
  package_path = loaded, package_version = as.character(utils::packageVersion("gllvmTMB")),
  cell_id = result$attempt$cell_id, seed = result$attempt$seed,
  status = result$attempt$status, elapsed_seconds = result$attempt$elapsed_seconds,
  estimand_rows = if (is.null(result$estimands)) 0L else nrow(result$estimands),
  stringsAsFactors = FALSE)
utils::write.csv(receipt, file.path(output, "smoke-receipt.csv"), row.names = FALSE)
if (!identical(result$attempt$status, "usable") || is.null(result$estimands) ||
    !nrow(result$estimands) || any(!is.finite(result$estimands$estimate))) {
  stop("AA-03 smoke result is non-usable or has incomplete estimands.", call. = FALSE)
}
cat("aa03_attempt=PASS\n")
