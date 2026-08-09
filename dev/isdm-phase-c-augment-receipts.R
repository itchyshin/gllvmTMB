#!/usr/bin/env Rscript

## Append-only retrospective structural receipt augmentation for the original
## Phase C campaign, which amendment 2 supersedes for exact-geometry and global
## attribution claims.
##
## This script reads only provenance, configuration labels, structural status
## labels, and metric finiteness. It does not calculate or inspect scientific
## contrasts or treatment trends. One invocation writes one new immutable
## augmentation receipt and never modifies an original compute/audit artifact.

.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)
.branch <- "claude/experiment-integrated-sdm"
.schema_version <- "phase_c_structural_augmentation_v1"
.blocks <- paste0("G", 1:6)
.arms <- paste0("A", 1:6)
.full_key <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
               "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
.dataset_key <- setdiff(.full_key, "arm")
.null_key <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")
.instrument_files <- c(
  "dev/isdm-bias-harness.R",
  "dev/isdm-bias-campaign.R",
  "dev/isdm-phase-c-analyse-official.R",
  "dev/isdm-phase-c-pilot-decision.R",
  "dev/isdm-phase-c-amendment-2026-08-08.md"
)

.absolute_path <- function(path, must_work = FALSE) {
  path <- path.expand(path)
  if (!grepl("^/", path)) path <- file.path(getwd(), path)
  normalizePath(path, mustWork = must_work)
}

.sha256 <- function(path) {
  if (!file.exists(path)) .stopf("Cannot hash missing file: %s", path)
  exe <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else if (nzchar(Sys.which("shasum"))) "shasum" else ""
  if (!nzchar(exe)) .stopf("Neither sha256sum nor shasum is available")
  args <- if (exe == "shasum") c("-a", "256", path) else path
  out <- system2(exe, args, stdout = TRUE, stderr = TRUE)
  if (length(out) < 1L) .stopf("Could not hash file: %s", path)
  sub("[[:space:]].*$", "", out[[1L]])
}

.sha256_lines <- function(lines) {
  path <- tempfile("phase-c-augmentation-payload-", fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  writeLines(lines, path, useBytes = TRUE)
  .sha256(path)
}

.read_receipt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  at <- regexpr("=", lines, fixed = TRUE)
  if (!length(lines) || any(at < 2L)) .stopf("Malformed receipt: %s", path)
  keys <- substring(lines, 1L, at - 1L)
  values <- substring(lines, at + 1L)
  if (anyDuplicated(keys)) .stopf("Duplicate receipt field: %s", path)
  if (any(grepl("[\r\n]", values))) .stopf("Receipt contains a multiline field: %s", path)
  as.list(stats::setNames(values, keys))
}

.write_receipt <- function(path, fields, fixture = FALSE) {
  path <- .absolute_path(path)
  if (!fixture && file.exists(path)) .stopf("Refusing to overwrite existing augmentation output: %s", path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  values <- vapply(fields, function(x) paste(x, collapse = ","), character(1))
  if (any(grepl("[\r\n]", values))) .stopf("Augmentation receipt fields must be single-line")
  lines <- sprintf("%s=%s", names(values), values)
  if (!fixture) {
    fields$augmentation_payload_sha256 <- .sha256_lines(lines)
    values <- vapply(fields, function(x) paste(x, collapse = ","), character(1))
    lines <- sprintf("%s=%s", names(values), values)
    if (file.exists(path)) .stopf("Refusing to overwrite existing augmentation output: %s", path)
  }
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

.need_fields <- function(x, fields, label) {
  missing <- setdiff(fields, names(x))
  if (length(missing)) .stopf("%s is missing field(s): %s", label, paste(missing, collapse = ", "))
}

.as_num <- function(x, field, label) {
  value <- suppressWarnings(as.numeric(x[[field]]))
  if (length(value) != 1L || !is.finite(value)) .stopf("%s has invalid numeric field %s", label, field)
  value
}

.as_int <- function(x, field, label) {
  value <- .as_num(x, field, label)
  if (value != as.integer(value)) .stopf("%s has non-integer field %s", label, field)
  as.integer(value)
}

.is_false <- function(x) length(x) == 1L && tolower(x) %in% c("false", "0")
.is_true <- function(x) length(x) == 1L && tolower(x) %in% c("true", "1")
.near <- function(x, y, tolerance = 1e-12) is.finite(x) & abs(x - y) <= tolerance
.blank_error <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))
.make_key <- function(x, cols) do.call(paste, c(x[cols], sep = "|"))

.git_value <- function(args, label) {
  out <- suppressWarnings(system2("git", args, stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) .stopf("Could not resolve %s with git", label)
  if (length(out) != 1L || !nzchar(out)) .stopf("Could not resolve %s with git", label)
  out[[1L]]
}

.instrument_id_at <- function(sha) {
  if (!grepl("^[0-9a-f]{40}$", sha)) .stopf("Invalid source SHA: %s", sha)
  resolved <- .git_value(c("rev-parse", "--verify", paste0(sha, "^{commit}")), paste("commit", sha))
  if (!identical(resolved, sha)) .stopf("Source SHA does not resolve exactly: %s", sha)
  blobs <- vapply(.instrument_files, function(path) {
    .git_value(c("rev-parse", paste0(sha, ":", path)), paste0(sha, ":", path))
  }, character(1))
  paste(blobs, collapse = ":")
}

.parse_manifest <- function(value, label) {
  specs <- strsplit(value, ";", fixed = TRUE)[[1L]]
  parsed <- lapply(specs, function(spec) {
    at <- regexpr(":", spec, fixed = TRUE)
    if (at < 2L || at == nchar(spec)) .stopf("Malformed %s entry: %s", label, spec)
    c(block = substring(spec, 1L, at - 1L), sha256 = substring(spec, at + 1L))
  })
  blocks <- vapply(parsed, `[[`, character(1), "block")
  hashes <- vapply(parsed, `[[`, character(1), "sha256")
  if (anyDuplicated(blocks) || !identical(sort(blocks), .blocks) || any(!grepl("^[0-9a-f]{64}$", hashes))) {
    .stopf("%s must contain exactly one SHA-256 for G1--G6", label)
  }
  stats::setNames(hashes, blocks)
}

.ref <- list(kappa = 1, rho = 0.6, omega = 0.5, phi_x = 0.15,
             phi_bias = 0.15, n = 400, T_sp = 8, d_fit = 2, k = 3,
             beta0_shift = 0)

.mk_config <- function(rows, block, beta0_shift) {
  out <- do.call(rbind, lapply(rows, as.data.frame))
  out$stage <- "campaign"
  out$block <- block
  out$beta0_shift <- beta0_shift
  out[, c("stage", "block", "seed", "kappa", "rho", "omega", "phi_x",
          "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift"), drop = FALSE]
}

.expected_config <- function(block, beta0_shift = 0) {
  ref <- .ref
  ref$beta0_shift <- beta0_shift
  rows <- list()
  add <- function(x) rows[[length(rows) + 1L]] <<- x
  if (block == "G1") {
    for (seed in 1:100) add(modifyList(ref, list(kappa = 0, seed = seed)))
    for (kappa in c(0.25, 0.5, 1, 2)) for (rho in c(0, 0.6)) for (omega in c(1, 0.5, 0)) {
      for (seed in 1:100) add(modifyList(ref, list(kappa = kappa, rho = rho, omega = omega, seed = seed)))
    }
  } else if (block == "G2") {
    for (n in c(100, 1600)) for (seed in 1:50) {
      add(modifyList(ref, list(kappa = 0, n = n, seed = seed)))
      add(modifyList(ref, list(n = n, seed = seed)))
    }
  } else if (block == "G3") {
    for (T_sp in c(6, 12)) for (seed in 1:50) {
      add(modifyList(ref, list(kappa = 0, T_sp = T_sp, seed = seed)))
      add(modifyList(ref, list(T_sp = T_sp, seed = seed)))
    }
  } else if (block == "G4") {
    for (d_fit in c(1, 3)) for (seed in 1:50) {
      add(modifyList(ref, list(kappa = 0, d_fit = d_fit, seed = seed)))
      add(modifyList(ref, list(d_fit = d_fit, seed = seed)))
    }
  } else if (block == "G5") {
    for (seed in 1:50) {
      add(modifyList(ref, list(kappa = 0, k = 1, seed = seed)))
      add(modifyList(ref, list(k = 1, seed = seed)))
    }
  } else if (block == "G6") {
    for (phi_bias in c(0, 0.4)) for (seed in 1:50) {
      add(modifyList(ref, list(phi_bias = phi_bias, seed = seed)))
    }
  } else .stopf("Noncanonical block: %s", block)
  .mk_config(rows, block, beta0_shift)
}

.expand_arms <- function(config) {
  out <- config[rep(seq_len(nrow(config)), each = length(.arms)), , drop = FALSE]
  rownames(out) <- NULL
  out$arm <- rep(.arms, times = nrow(config))
  out[, .full_key, drop = FALSE]
}

.expected_rows <- c(G1 = 15000L, G2 = 1200L, G3 = 1200L,
                    G4 = 1200L, G5 = 600L, G6 = 600L)

.validate_original_receipt <- function(receipt, path, result_path, block) {
  label <- paste(block, "original compute receipt")
  required <- c(
    "receipt_type", "status", "stage", "source_sha", "source_branch", "source_dirty",
    "instrument_id", "expected_rows", "actual_rows", "expected_logical_rows",
    "expected_optimizer_calls", "output_path", "output_bytes", "output_sha256",
    "config_sha256", "seed_min", "seed_max", "seed_count", "phi_x", "phi_bias",
    "beta0_shift", "arms", "null_dataset_rows", "unique_key_verdict",
    "a6_null_collapsed_rows", "fit_error_rows", "unlabelled_nonfinite_rows"
  )
  .need_fields(receipt, required, label)
  if (!identical(receipt$receipt_type, paste0(tolower(block), "_compute")) ||
      !identical(receipt$status, "PASS")) .stopf("%s is not PASS", label)
  if (!identical(receipt$stage, tolower(block))) .stopf("%s has noncanonical runner stage", label)
  if (!identical(receipt$source_branch, .branch) || !.is_false(receipt$source_dirty)) {
    .stopf("%s source branch/dirty binding is invalid", label)
  }
  source_id <- .instrument_id_at(receipt$source_sha)
  if (!identical(receipt$instrument_id, source_id)) {
    .stopf("%s source commit/instrument binding mismatch", label)
  }
  normalized_result <- .absolute_path(result_path, must_work = TRUE)
  if (!identical(.absolute_path(receipt$output_path, must_work = TRUE), normalized_result)) {
    .stopf("%s output path mismatch", label)
  }
  if (.as_num(receipt, "output_bytes", label) != as.numeric(file.info(normalized_result)$size) ||
      !identical(receipt$output_sha256, .sha256(normalized_result))) {
    .stopf("%s output size/hash mismatch", label)
  }
  expected <- .expected_rows[[block]]
  for (field in c("expected_rows", "actual_rows", "expected_logical_rows", "expected_optimizer_calls")) {
    if (.as_int(receipt, field, label) != expected) .stopf("%s %s mismatch", label, field)
  }
  if (!grepl("^[0-9a-f]{64}$", receipt$config_sha256)) .stopf("%s has invalid config SHA-256", label)
  if (!identical(receipt$arms, paste(.arms, collapse = ",")) ||
      !identical(receipt$unique_key_verdict, "PASS") ||
      .as_int(receipt, "unlabelled_nonfinite_rows", label) != 0L) {
    .stopf("%s structural manifest is not PASS", label)
  }
  invisible(TRUE)
}

.validate_audit <- function(audit, audit_path, csv, csv_path) {
  label <- "independent compute-audit receipt"
  .need_fields(audit, c(
    "receipt_type", "status", "campaign_source_sha", "source_branch", "source_dirty",
    "instrument_id", "block_count", "campaign_receipt_sha256", "campaign_result_sha256",
    "campaign_independent_config_sha256", "block_csv_sha256", "unlabelled_nonfinite_rows"
  ), label)
  if (!identical(audit$receipt_type, "phase_c_campaign_compute_audit") || !identical(audit$status, "PASS")) {
    .stopf("%s is not PASS", label)
  }
  if (!identical(audit$source_branch, .branch) || !.is_false(audit$source_dirty) ||
      .as_int(audit, "block_count", label) != 6L ||
      .as_int(audit, "unlabelled_nonfinite_rows", label) != 0L) {
    .stopf("%s canonical source/structural fields are invalid", label)
  }
  source_id <- .instrument_id_at(audit$campaign_source_sha)
  if (!identical(audit$instrument_id, source_id)) {
    .stopf("%s source commit/instrument binding mismatch", label)
  }
  if (!identical(audit$block_csv_sha256, .sha256(csv_path))) .stopf("Audit CSV hash mismatch")
  required_csv <- c(
    "block", "expected_rows", "receipt_actual_rows", "result_sha256", "receipt_sha256",
    "config_sha256", "independent_config_sha256", "actual_rows", "fit_error_rows",
    "completed_rows", "unique_full_keys", "exact_six_arms", "exact_null_contract",
    "unlabelled_nonfinite_rows"
  )
  missing <- setdiff(required_csv, names(csv))
  if (length(missing)) .stopf("Audit CSV is missing column(s): %s", paste(missing, collapse = ", "))
  if (nrow(csv) != 6L || anyDuplicated(csv$block) || !identical(sort(as.character(csv$block)), .blocks)) {
    .stopf("Audit CSV must contain exactly one row for G1--G6")
  }
  list(
    receipt_hashes = .parse_manifest(audit$campaign_receipt_sha256, "campaign receipt manifest"),
    result_hashes = .parse_manifest(audit$campaign_result_sha256, "campaign result manifest"),
    config_hashes = .parse_manifest(audit$campaign_independent_config_sha256, "independent config manifest")
  )
}

.coerce_flag <- function(x, label) {
  if (is.logical(x)) return(x)
  if ((is.numeric(x) || is.integer(x)) && all(is.na(x) | x %in% c(0, 1))) return(as.logical(x))
  .stopf("%s must be logical or 0/1", label)
}

.validate_result <- function(x, block, receipt, audit_row) {
  label <- paste(block, "raw result")
  required <- c(
    .full_key, "elapsed_sec", "realised_prevalence", "bias_sharing", "fit_error",
    "convergence", "pdHess", "diag_B_skip", "oracle_collapsed", "estimand",
    "D_bias", "D_rmse", "D_max", "D_z", "rank_d_D_bias", "rank_d_D_rmse",
    "signflip", "diag_rmse", "psi_rmse", "lambda_proc_rmse", "beta_bias",
    "beta_rmse", "n_heywood_psi", "n_heywood_loading"
  )
  if (!is.data.frame(x)) .stopf("%s is not a data.frame", label)
  missing <- setdiff(required, names(x))
  if (length(missing)) .stopf("%s is missing column(s): %s", label, paste(missing, collapse = ", "))
  if (nrow(x) != .expected_rows[[block]]) .stopf("%s has unexplained missing/excess rows", label)
  if (!identical(unique(as.character(x$stage)), "campaign") ||
      !identical(unique(as.character(x$block)), block)) .stopf("%s has noncanonical stage/block", label)
  config_cols <- c("seed", "kappa", "rho", "omega", "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  for (field in config_cols) {
    if (!is.numeric(x[[field]]) || any(!is.finite(x[[field]]))) .stopf("%s has invalid config field %s", label, field)
  }
  expected <- .expand_arms(.expected_config(block, beta0_shift = 0))
  actual_key <- .make_key(x, .full_key)
  expected_key <- .make_key(expected, .full_key)
  if (anyDuplicated(actual_key)) .stopf("%s contains duplicate full keys", label)
  if (!setequal(actual_key, expected_key)) .stopf("%s differs from the canonical full-key grid", label)
  by_dataset <- split(as.character(x$arm), .make_key(x, .dataset_key))
  if (any(vapply(by_dataset, function(a) !identical(sort(a), .arms), logical(1)))) {
    .stopf("%s does not contain exactly six arms per dataset", label)
  }
  completed <- .blank_error(x$fit_error)
  pd <- .coerce_flag(x$pdHess, paste(label, "pdHess"))
  collapsed <- .coerce_flag(x$oracle_collapsed, paste(label, "oracle_collapsed"))
  if (any(completed & is.na(pd)) || any(completed & is.na(collapsed))) {
    .stopf("%s has missing structural labels on completed rows", label)
  }
  estimand <- as.character(x$estimand)
  rank <- completed & block == "G5" & x$arm == "A2"
  total <- completed & !rank
  if (any(rank & estimand != "loadings_only_rank_d") || any(total & estimand != "total_sigma")) {
    .stopf("%s has invalid structural estimand labels", label)
  }
  total_required <- c(
    "elapsed_sec", "realised_prevalence", "bias_sharing", "convergence", "diag_B_skip",
    "D_bias", "D_rmse", "D_max", "D_z", "signflip", "diag_rmse", "psi_rmse",
    "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi", "n_heywood_loading"
  )
  rank_required <- c(
    "elapsed_sec", "realised_prevalence", "bias_sharing", "convergence", "diag_B_skip",
    "rank_d_D_bias", "rank_d_D_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
    "n_heywood_loading"
  )
  bad <- rep(FALSE, nrow(x))
  for (field in total_required) bad <- bad | (total & !is.finite(x[[field]]))
  for (field in rank_required) bad <- bad | (rank & !is.finite(x[[field]]))
  nonfinite_rows <- sum(bad)
  if (nonfinite_rows) .stopf("%s has %d unexplained nonfinite completed row(s)", label, nonfinite_rows)
  if (any(rank & (x$diag_B_skip <= 0 | is.finite(x$D_bias) | is.finite(x$D_rmse))) ||
      any(completed & !rank & (is.finite(x$rank_d_D_bias) | is.finite(x$rank_d_D_rmse)))) {
    .stopf("%s has invalid rank-d/total-Sigma structural missingness", label)
  }
  null_a6 <- .near(x$kappa, 0) & x$arm == "A6"
  if (any(!collapsed[null_a6], na.rm = TRUE) || any(collapsed[completed & !null_a6], na.rm = TRUE)) {
    .stopf("%s has invalid A6 null-collapse labels", label)
  }
  fit_errors <- sum(!completed)
  if (fit_errors != .as_int(receipt, "fit_error_rows", paste(block, "receipt")) ||
      fit_errors != as.integer(audit_row$fit_error_rows)) .stopf("%s fit-error count mismatch", label)
  if (.as_int(receipt, "actual_rows", paste(block, "receipt")) != nrow(x) ||
      as.integer(audit_row$actual_rows) != nrow(x) ||
      as.integer(audit_row$unique_full_keys) != nrow(x)) .stopf("%s row/unique-key audit mismatch", label)
  if (!.is_true(as.character(audit_row$exact_six_arms)) ||
      !.is_true(as.character(audit_row$exact_null_contract)) ||
      as.integer(audit_row$unlabelled_nonfinite_rows) != 0L) .stopf("%s audit structural verdict is not PASS", label)
  list(
    data = x, completed = completed, fit_errors = fit_errors,
    exclusions = fit_errors, nonfinite_rows = nonfinite_rows,
    a6_null_collapses = sum(null_a6 & collapsed, na.rm = TRUE),
    seed_list = paste(sort(unique(x$seed)), collapse = ",")
  )
}

.null_pairing <- function(x, null_source) {
  biased <- x[! .near(x$kappa, 0), , drop = FALSE]
  null <- null_source[.near(null_source$kappa, 0), , drop = FALSE]
  null_keys <- .make_key(null, .null_key)
  if (anyDuplicated(null_keys)) .stopf("Null source contains duplicate null keys")
  pair_keys <- .make_key(biased, .null_key)
  match_count <- vapply(pair_keys, function(key) sum(null_keys == key), integer(1))
  mismatch <- sum(match_count != 1L)
  if (mismatch) .stopf("Exact one-null pairing fails for %d logical row(s)", mismatch)
  list(
    null_rows = nrow(null), unique_null_keys = length(unique(null_keys)),
    null_pair_candidates = nrow(biased), null_pair_count = sum(match_count == 1L),
    null_pair_mismatch_count = mismatch
  )
}

.usage <- function() {
  cat(paste0(
    "Retrospective Phase C structural receipt augmenter\n\n",
    "Usage:\n",
    "  Rscript --vanilla dev/isdm-phase-c-augment-receipts.R \\\n",
    "    --block=G1 --result=/path/g1.rds --receipt=/path/g1-compute.receipt \\\n",
    "    --audit-receipt=/path/phase-c-compute-audit.receipt \\\n",
    "    --audit-csv=/path/phase-c-compute-audit-blocks.csv \\\n",
    "    --output=/new/path/g1-structural-augmentation.receipt\n\n",
    "G6 additionally requires --g1-result=FILE and --g1-receipt=FILE so its\n",
    "cross-block null pairing is independently reconstructed.\n\n",
    "Options:\n",
    "  --self-test   Run only synthetic structural fixtures under /private/tmp.\n",
    "  --help        Show this help.\n"
  ))
}

.parse_args <- function(args) {
  if (any(args %in% c("--help", "-h"))) return(list(help = TRUE))
  if (identical(args, "--self-test")) return(list(self_test = TRUE))
  out <- list(help = FALSE, self_test = FALSE)
  allowed <- c("block", "result", "receipt", "audit-receipt", "audit-csv", "output",
               "g1-result", "g1-receipt")
  for (arg in args) {
    if (!grepl("^--[^=]+=.+$", arg)) .stopf("Options must use --name=value: %s", arg)
    at <- regexpr("=", arg, fixed = TRUE)
    name <- substring(arg, 3L, at - 1L)
    value <- substring(arg, at + 1L)
    if (!name %in% allowed) .stopf("Unknown option: --%s", name)
    key <- gsub("-", "_", name)
    if (!is.null(out[[key]])) .stopf("Duplicate option: --%s", name)
    out[[key]] <- value
  }
  required <- gsub("-", "_", c("block", "result", "receipt", "audit-receipt", "audit-csv", "output"))
  missing <- required[!vapply(required, function(key) !is.null(out[[key]]) && nzchar(out[[key]]), logical(1))]
  if (length(missing)) .stopf("Missing required option(s): %s", paste(missing, collapse = ", "))
  out$block <- toupper(out$block)
  if (!out$block %in% .blocks) .stopf("Noncanonical block: %s", out$block)
  if (out$block == "G6" && (is.null(out$g1_result) || is.null(out$g1_receipt))) {
    .stopf("G6 requires --g1-result= and --g1-receipt=")
  }
  if (out$block != "G6" && (!is.null(out$g1_result) || !is.null(out$g1_receipt))) {
    .stopf("--g1-result/--g1-receipt are accepted only for G6")
  }
  out
}

.load_authenticated <- function(result_path, receipt_path, block, audit_csv, audit_info,
                                result_manifest, receipt_manifest) {
  result_path <- .absolute_path(result_path, must_work = TRUE)
  receipt_path <- .absolute_path(receipt_path, must_work = TRUE)
  receipt <- .read_receipt(receipt_path)
  .validate_original_receipt(receipt, receipt_path, result_path, block)
  result_sha <- .sha256(result_path)
  receipt_sha <- .sha256(receipt_path)
  row <- audit_csv[as.character(audit_csv$block) == block, , drop = FALSE]
  if (nrow(row) != 1L) .stopf("Audit CSV row missing/duplicated for %s", block)
  if (!identical(result_sha, unname(result_manifest[[block]])) ||
      !identical(result_sha, as.character(row$result_sha256)) ||
      !identical(receipt_sha, unname(receipt_manifest[[block]])) ||
      !identical(receipt_sha, as.character(row$receipt_sha256))) {
    .stopf("%s source/hash mismatch across raw, original receipt, and audit", block)
  }
  if (!identical(receipt$config_sha256, as.character(row$config_sha256))) {
    .stopf("%s config hash mismatch between original receipt and audit CSV", block)
  }
  if (!identical(as.character(row$independent_config_sha256),
                 unname(audit_info$config_hashes[[block]]))) {
    .stopf("%s independent config hash mismatch between audit receipt and CSV", block)
  }
  expected <- .expected_rows[[block]]
  count_fields <- c("expected_rows", "receipt_actual_rows", "actual_rows", "unique_full_keys")
  counts <- suppressWarnings(as.integer(unlist(row[count_fields], use.names = FALSE)))
  completed <- suppressWarnings(as.integer(row$completed_rows))
  fit_errors <- suppressWarnings(as.integer(row$fit_error_rows))
  if (anyNA(c(counts, completed, fit_errors)) || any(counts != expected) ||
      completed + fit_errors != expected) {
    .stopf("%s audit CSV row/count contract mismatch", block)
  }
  x <- readRDS(result_path)
  validated <- .validate_result(x, block, receipt, row)
  c(validated, list(
    receipt = receipt, audit_row = row, result_path = result_path,
    receipt_path = receipt_path, result_sha256 = result_sha,
    receipt_sha256 = receipt_sha
  ))
}

.augment <- function(opt) {
  input_fields <- c("result", "receipt", "audit_receipt", "audit_csv")
  for (field in input_fields) {
    if (!file.exists(opt[[field]])) .stopf("Required input is missing: %s", opt[[field]])
  }
  output <- .absolute_path(opt$output)
  if (file.exists(output)) .stopf("Refusing to overwrite existing augmentation output: %s", output)
  supplied_inputs <- c(opt$result, opt$receipt, opt$audit_receipt, opt$audit_csv,
                       opt$g1_result %||% character(), opt$g1_receipt %||% character())
  normalized_inputs <- vapply(supplied_inputs, .absolute_path, character(1), must_work = TRUE)
  if (anyDuplicated(normalized_inputs)) .stopf("Input paths must be distinct")
  if (output %in% normalized_inputs) .stopf("Augmentation output cannot overwrite an input")

  audit_path <- .absolute_path(opt$audit_receipt, must_work = TRUE)
  csv_path <- .absolute_path(opt$audit_csv, must_work = TRUE)
  audit <- .read_receipt(audit_path)
  audit_csv <- utils::read.csv(
    csv_path, stringsAsFactors = FALSE, check.names = FALSE,
    colClasses = "character"
  )
  manifests <- .validate_audit(audit, audit_path, audit_csv, csv_path)
  primary <- .load_authenticated(
    opt$result, opt$receipt, opt$block, audit_csv, manifests,
    manifests$result_hashes, manifests$receipt_hashes
  )
  if (!identical(primary$receipt$source_sha, audit$campaign_source_sha) ||
      !identical(primary$receipt$instrument_id, audit$instrument_id)) {
    .stopf("Original receipt and audit source/instrument mismatch")
  }
  g1 <- NULL
  null_source <- primary$data
  if (opt$block == "G6") {
    g1 <- .load_authenticated(
      opt$g1_result, opt$g1_receipt, "G1", audit_csv, manifests,
      manifests$result_hashes, manifests$receipt_hashes
    )
    if (!identical(g1$receipt$source_sha, primary$receipt$source_sha) ||
        !identical(g1$receipt$instrument_id, primary$receipt$instrument_id)) {
      .stopf("G6 and G1 source/instrument mismatch")
    }
    null_source <- g1$data
  }
  pairing <- .null_pairing(primary$data, null_source)

  expected_null_rows <- if (opt$block %in% c("G1", "G2", "G3", "G4")) 100L else if (opt$block == "G5") 50L else 0L
  if (.as_int(primary$receipt, "null_dataset_rows", paste(opt$block, "receipt")) != expected_null_rows ||
      .as_int(primary$receipt, "a6_null_collapsed_rows", paste(opt$block, "receipt")) != primary$a6_null_collapses) {
    .stopf("%s receipt null/A6 counts mismatch raw structural evidence", opt$block)
  }
  observed_phi_x <- paste(sort(unique(primary$data$phi_x)), collapse = ",")
  observed_phi_bias <- paste(sort(unique(primary$data$phi_bias)), collapse = ",")
  if (!identical(primary$receipt$phi_x, observed_phi_x) ||
      !identical(primary$receipt$phi_bias, observed_phi_bias) ||
      !identical(primary$receipt$beta0_shift, "0") ||
      !identical(primary$receipt$arms, paste(.arms, collapse = ","))) {
    .stopf("%s receipt configuration manifest mismatch raw structural evidence", opt$block)
  }
  if (.as_int(primary$receipt, "seed_min", paste(opt$block, "receipt")) != min(primary$data$seed) ||
      .as_int(primary$receipt, "seed_max", paste(opt$block, "receipt")) != max(primary$data$seed) ||
      .as_int(primary$receipt, "seed_count", paste(opt$block, "receipt")) != length(unique(primary$data$seed))) {
    .stopf("%s receipt seed manifest mismatch raw structural evidence", opt$block)
  }

  fields <- list(
    receipt_class = "retrospective_structural_augmentation",
    status = "PASS",
    schema_version = .schema_version,
    augmentation_tool_path = normalizePath("dev/isdm-phase-c-augment-receipts.R", mustWork = TRUE),
    augmentation_tool_sha256 = .sha256("dev/isdm-phase-c-augment-receipts.R"),
    augmentation_checkout_sha = .git_value(c("rev-parse", "HEAD"), "augmentation checkout SHA"),
    schema_version_temporality = "prospective_for_augmentation_only",
    augmentation_temporality = "created_after_campaign_outcomes",
    augmentation_existed_before_outcomes = "false",
    stage = "campaign",
    block = opt$block,
    observed_seed_list = primary$seed_list,
    config_sha256 = primary$receipt$config_sha256,
    independent_config_sha256 = as.character(primary$audit_row$independent_config_sha256),
    raw_sha256 = primary$result_sha256,
    raw_path = primary$result_path,
    raw_bytes = as.numeric(file.info(primary$result_path)$size),
    original_receipt_sha256 = primary$receipt_sha256,
    original_receipt_path = primary$receipt_path,
    audit_receipt_sha256 = .sha256(audit_path),
    audit_receipt_path = audit_path,
    audit_csv_sha256 = .sha256(csv_path),
    audit_csv_path = csv_path,
    source_sha = primary$receipt$source_sha,
    source_branch = primary$receipt$source_branch,
    instrument_id = primary$receipt$instrument_id,
    phi_x = observed_phi_x,
    phi_bias = observed_phi_bias,
    beta0_shift = "0",
    arms = paste(.arms, collapse = ","),
    expected_logical_rows = .expected_rows[[opt$block]],
    actual_logical_rows = nrow(primary$data),
    expected_optimizer_calls = .as_int(primary$receipt, "expected_optimizer_calls", paste(opt$block, "receipt")),
    actual_logical_fit_attempts = nrow(primary$data),
    actual_optimizer_calls = "NOT_RECONSTRUCTABLE",
    unique_full_key_verdict = "PASS",
    unique_full_key_count = length(unique(.make_key(primary$data, .full_key))),
    null_source_block = if (opt$block == "G6") "G1" else opt$block,
    null_rows = pairing$null_rows,
    unique_null_key_count = pairing$unique_null_keys,
    null_pair_candidate_count = pairing$null_pair_candidates,
    null_pair_count = pairing$null_pair_count,
    null_pair_mismatch_count = pairing$null_pair_mismatch_count,
    a6_null_collapse_count = primary$a6_null_collapses,
    fit_error_count = primary$fit_errors,
    exclusion_count = primary$exclusions,
    unlabelled_nonfinite_count = primary$nonfinite_rows,
    original_output_path = .absolute_path(primary$receipt$output_path, must_work = TRUE),
    original_output_sha256 = primary$receipt$output_sha256,
    augmentation_output_path = output,
    structural_scope = "labels_keys_finiteness_and_provenance_only",
    scientific_outcome_values_inspected = "false",
    optimizer_control_beyond_source_or_command_default = "NOT_RECONSTRUCTABLE",
    exact_package_session_snapshot_if_absent = "NOT_RECONSTRUCTABLE",
    original_outcome_firewall_replaced = "false"
  )
  if (opt$block == "G6") {
    fields$g1_raw_path <- g1$result_path
    fields$g1_raw_sha256 <- g1$result_sha256
    fields$g1_original_receipt_path <- g1$receipt_path
    fields$g1_original_receipt_sha256 <- g1$receipt_sha256
    fields$g1_external_a6_null_collapse_count <- g1$a6_null_collapses
  }
  .write_receipt(output, fields)
  final_hash <- .sha256(output)
  cat(sprintf("Phase C %s retrospective structural augmentation: PASS\noutput=%s\noutput_sha256=%s\n",
              opt$block, output, final_hash))
  invisible(list(path = output, sha256 = final_hash))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.synthetic_results <- function(block) {
  x <- .expand_arms(.expected_config(block, beta0_shift = 0))
  n <- nrow(x)
  x$elapsed_sec <- 0.1
  x$realised_prevalence <- 0.4
  x$bias_sharing <- 0.2
  x$fit_error <- NA_character_
  x$convergence <- 0
  x$pdHess <- TRUE
  rank <- block == "G5" & x$arm == "A2"
  x$diag_B_skip <- ifelse(rank, 1, 0)
  x$oracle_collapsed <- .near(x$kappa, 0) & x$arm == "A6"
  x$estimand <- ifelse(rank, "loadings_only_rank_d", "total_sigma")
  for (field in c("D_bias", "D_rmse", "D_max", "D_z", "signflip", "diag_rmse",
                  "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
                  "n_heywood_psi", "n_heywood_loading")) x[[field]] <- rep(0.1, n)
  x$rank_d_D_bias <- ifelse(rank, 0.1, NA_real_)
  x$rank_d_D_rmse <- ifelse(rank, 0.1, NA_real_)
  if (any(rank)) for (field in c("D_bias", "D_rmse", "D_max", "D_z", "signflip",
                                     "diag_rmse", "psi_rmse", "n_heywood_psi")) x[[field]][rank] <- NA_real_
  if (block == "G2") {
    error_row <- which(x$kappa > 0 & x$arm == "A1")[[1L]]
    x$fit_error[[error_row]] <- "synthetic retained fit error"
    for (field in c("elapsed_sec", "convergence", "pdHess", "estimand", "D_bias", "D_rmse",
                    "D_max", "D_z", "rank_d_D_bias", "rank_d_D_rmse", "signflip",
                    "diag_rmse", "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
                    "n_heywood_psi", "n_heywood_loading")) x[[field]][error_row] <- NA
  }
  x
}

.fixture_original <- function(root, block, data, source_sha, instrument_id) {
  result <- file.path(root, paste0(tolower(block), ".rds"))
  saveRDS(data, result, version = 3)
  receipt <- file.path(root, paste0(tolower(block), "-compute.receipt"))
  null_rows <- sum(.near(data$kappa, 0)) / length(.arms)
  fields <- list(
    receipt_type = paste0(tolower(block), "_compute"), status = "PASS", stage = tolower(block),
    source_sha = source_sha, source_branch = .branch, source_dirty = "false",
    instrument_id = instrument_id, expected_rows = nrow(data), actual_rows = nrow(data),
    expected_logical_rows = nrow(data), expected_optimizer_calls = nrow(data),
    output_path = normalizePath(result), output_bytes = file.info(result)$size,
    output_sha256 = .sha256(result), config_sha256 = paste(rep(substr(block, 2, 2), 64L), collapse = ""),
    seed_min = min(data$seed), seed_max = max(data$seed), seed_count = length(unique(data$seed)),
    phi_x = paste(sort(unique(data$phi_x)), collapse = ","),
    phi_bias = paste(sort(unique(data$phi_bias)), collapse = ","), beta0_shift = "0",
    arms = paste(.arms, collapse = ","), null_dataset_rows = null_rows,
    unique_key_verdict = "PASS",
    a6_null_collapsed_rows = sum(.near(data$kappa, 0) & data$arm == "A6" & data$oracle_collapsed),
    fit_error_rows = sum(!.blank_error(data$fit_error)), unlabelled_nonfinite_rows = 0
  )
  .write_receipt(receipt, fields, fixture = TRUE)
  list(result = result, receipt = receipt, fields = fields)
}

.expect_error <- function(expr, pattern, label) {
  error <- try(force(expr), silent = TRUE)
  if (!inherits(error, "try-error") || !grepl(pattern, as.character(error), fixed = TRUE)) {
    .stopf("Synthetic negative failed (%s): %s", label, as.character(error))
  }
  invisible(TRUE)
}

.self_test <- function() {
  root <- tempfile("phase-c-receipt-augmentation-self-test-", tmpdir = "/private/tmp")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  source_sha <- .git_value(c("rev-parse", "HEAD"), "self-test source SHA")
  instrument_id <- .instrument_id_at(source_sha)
  fixtures <- stats::setNames(lapply(.blocks, function(block) {
    .fixture_original(root, block, .synthetic_results(block), source_sha, instrument_id)
  }), .blocks)
  g1 <- fixtures$G1
  g6 <- fixtures$G6
  dummy <- paste(rep("a", 64L), collapse = "")
  csv <- do.call(rbind, lapply(.blocks, function(block) {
    fixture <- fixtures[[block]]
    result <- readRDS(fixture$result)
    fit_errors <- sum(!.blank_error(result$fit_error))
    data.frame(
      block = block, expected_rows = .expected_rows[[block]], receipt_actual_rows = .expected_rows[[block]],
      result_sha256 = .sha256(fixture$result), receipt_sha256 = .sha256(fixture$receipt),
      config_sha256 = fixture$fields$config_sha256,
      independent_config_sha256 = dummy, actual_rows = .expected_rows[[block]],
      fit_error_rows = fit_errors, completed_rows = .expected_rows[[block]] - fit_errors,
      unique_full_keys = .expected_rows[[block]], exact_six_arms = TRUE,
      exact_null_contract = TRUE, unlabelled_nonfinite_rows = 0L,
      stringsAsFactors = FALSE
    )
  }))
  csv_path <- file.path(root, "phase-c-compute-audit-blocks.csv")
  utils::write.csv(csv, csv_path, row.names = FALSE, na = "NA")
  manifest <- function(field) paste(sprintf("%s:%s", csv$block, csv[[field]]), collapse = ";")
  audit_path <- file.path(root, "phase-c-compute-audit.receipt")
  audit_fields <- list(
    receipt_type = "phase_c_campaign_compute_audit", status = "PASS",
    campaign_source_sha = source_sha, source_branch = .branch, source_dirty = "false",
    instrument_id = instrument_id, block_count = 6L,
    campaign_receipt_sha256 = manifest("receipt_sha256"),
    campaign_result_sha256 = manifest("result_sha256"),
    campaign_independent_config_sha256 = manifest("independent_config_sha256"),
    block_csv_sha256 = .sha256(csv_path), unlabelled_nonfinite_rows = 0L
  )
  .write_receipt(audit_path, audit_fields, fixture = TRUE)
  opts <- stats::setNames(lapply(.blocks, function(block) {
    fixture <- fixtures[[block]]
    out <- list(
      block = block, result = fixture$result, receipt = fixture$receipt,
      audit_receipt = audit_path, audit_csv = csv_path,
      output = file.path(root, paste0(tolower(block), "-augmentation.receipt"))
    )
    if (block == "G6") {
      out$g1_result <- g1$result
      out$g1_receipt <- g1$receipt
    }
    out
  }), .blocks)
  for (block in .blocks) {
    .augment(opts[[block]])
    augmented <- .read_receipt(opts[[block]]$output)
    if (!identical(augmented$receipt_class, "retrospective_structural_augmentation") ||
        !identical(augmented$schema_version, .schema_version) ||
        !identical(augmented$block, block) || !identical(augmented$stage, "campaign") ||
        !identical(augmented$null_pair_mismatch_count, "0") ||
        !identical(augmented$actual_optimizer_calls, "NOT_RECONSTRUCTABLE")) {
      .stopf("Synthetic %s PASS receipt omitted required augmentation fields", block)
    }
  }
  if (!identical(.read_receipt(opts$G2$output)$fit_error_count, "1") ||
      !identical(.read_receipt(opts$G2$output)$exclusion_count, "1")) {
    .stopf("Synthetic retained fit error was not preserved in G2 counts")
  }
  opt <- opts$G6
  .expect_error(.augment(opt), "Refusing to overwrite", "overwrite refusal")

  tampered_result <- file.path(root, "g6-tampered.rds")
  tampered <- readRDS(g6$result)
  tampered$seed[[1L]] <- 999
  saveRDS(tampered, tampered_result, version = 3)
  tampered_opt <- opt
  tampered_opt$result <- tampered_result
  tampered_opt$output <- file.path(root, "tampered-augmentation.receipt")
  .expect_error(.augment(tampered_opt), "output path mismatch", "raw tamper/path binding")

  mismatched_receipt <- file.path(root, "g6-mismatched-compute.receipt")
  mismatch_lines <- readLines(g6$receipt, warn = FALSE)
  mismatch_lines[startsWith(mismatch_lines, "config_sha256=")] <- paste0("config_sha256=", dummy)
  writeLines(mismatch_lines, mismatched_receipt, useBytes = TRUE)
  mismatch_opt <- opt
  mismatch_opt$receipt <- mismatched_receipt
  mismatch_opt$output <- file.path(root, "mismatch-augmentation.receipt")
  .expect_error(.augment(mismatch_opt), "source/hash mismatch", "receipt/audit mismatch")

  tampered_audit <- file.path(root, "tampered-audit.receipt")
  audit_lines <- readLines(audit_path, warn = FALSE)
  audit_lines[startsWith(audit_lines, "block_csv_sha256=")] <- paste0("block_csv_sha256=", dummy)
  writeLines(audit_lines, tampered_audit, useBytes = TRUE)
  audit_opt <- opt
  audit_opt$audit_receipt <- tampered_audit
  audit_opt$output <- file.path(root, "audit-tamper-augmentation.receipt")
  .expect_error(.augment(audit_opt), "Audit CSV hash mismatch", "audit tamper")

  g3_data <- readRDS(fixtures$G3$result)
  g3_receipt <- .read_receipt(fixtures$G3$receipt)
  g3_row <- csv[csv$block == "G3", , drop = FALSE]
  duplicate <- g3_data
  duplicate[2L, .full_key] <- duplicate[1L, .full_key]
  .expect_error(.validate_result(duplicate, "G3", g3_receipt, g3_row),
                "duplicate full keys", "duplicate full-key refusal")
  missing <- g3_data[-1L, , drop = FALSE]
  .expect_error(.validate_result(missing, "G3", g3_receipt, g3_row),
                "unexplained missing/excess rows", "missing-row refusal")
  nonfinite <- g3_data
  nonfinite$D_bias[[1L]] <- NA_real_
  .expect_error(.validate_result(nonfinite, "G3", g3_receipt, g3_row),
                "unexplained nonfinite", "nonfinite-row refusal")
  wrong_stage <- g3_data
  wrong_stage$stage <- "G3"
  .expect_error(.validate_result(wrong_stage, "G3", g3_receipt, g3_row),
                "noncanonical stage/block", "stage refusal")
  cat("Phase C retrospective structural augmentation synthetic self-test: PASS\n")
  invisible(TRUE)
}

.main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opt <- .parse_args(args)
  if (isTRUE(opt$help)) return(.usage())
  if (isTRUE(opt$self_test)) return(.self_test())
  .augment(opt)
}

if (sys.nframe() == 0L) .main()
