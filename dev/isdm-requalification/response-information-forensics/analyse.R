args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("usage: Rscript analyse.R <scientific-plan.rds> <archive-dir> <manifest> <out-dir>", call. = FALSE)
plan_path <- args[[1L]]; archive_dir <- args[[2L]]; manifest_path <- args[[3L]]; out_dir <- args[[4L]]
source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
source("dev/isdm-requalification/response-information/recompute.R", local = TRUE)
source("dev/isdm-requalification/response-information-forensics/forensics.R", local = TRUE)
plan <- readRDS(plan_path); isdm_respinfo_validate_plan(plan)
manifest <- isdm_forensics_read_manifest(manifest_path)
focal_rel <- sprintf("attempts/task-%06d.rds", ISDM_FORENSICS_FOCAL_IDS)
focal_manifest <- manifest[match(focal_rel, manifest$path), , drop = FALSE]
if (anyNA(focal_manifest$hash)) stop("focal hashes are absent from manifest", call. = FALSE)
for (i in seq_len(nrow(focal_manifest))) {
  observed <- isdm_forensics_sha256(file.path(archive_dir, focal_manifest$path[[i]]))
  if (!identical(observed, focal_manifest$hash[[i]])) stop("focal receipt hash does not match manifest", call. = FALSE)
}
paths <- file.path(archive_dir, sprintf("attempts/task-%06d.rds", plan$task_id))
if (any(!file.exists(paths))) stop("archive is missing planned receipts", call. = FALSE)
records <- lapply(paths, readRDS)
if (!all(vapply(records, function(x) identical(x$status, "fit_returned"), logical(1L)))) stop("forensic audit requires returned records", call. = FALSE)
fits <- do.call(rbind, lapply(records, isdm_forensics_fit_row))
fits <- fits[order(fits$dataset_id, fits$variant), , drop = FALSE]
pairs <- isdm_forensics_pair_table(fits)
focal <- isdm_forensics_focal_table(fits, pairs)
mechanism <- isdm_forensics_mechanism(fits, focal)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(fits, file.path(out_dir, "fit-diagnostics.csv"), row.names = FALSE)
write.csv(pairs, file.path(out_dir, "pair-diagnostics.csv"), row.names = FALSE)
write.csv(focal, file.path(out_dir, "focal-diagnostics.csv"), row.names = FALSE)
writeLines(c(
  paste("schema", ISDM_FORENSICS_SCHEMA, sep = ","),
  paste("focal_hashes", paste(focal_manifest$hash, collapse = ";"), sep = ","),
  paste("mechanism", mechanism$label, sep = ","),
  paste("decision", mechanism$decision, sep = ","),
  paste("reason", gsub(",", ";", mechanism$reason, fixed = TRUE), sep = ",")
), file.path(out_dir, "receipt.csv"))
cat("forensic analysis completed\n")
