#!/usr/bin/env Rscript

## Independent structural verifier for the Phase C G1--G6 campaign.
##
## This file deliberately does not source the official analysis.  It opens no
## campaign RDS until all six result files exist and all six compute receipts
## have cleared their PASS/provenance/hash checks.  The campaign source is
## loaded once into an isolated environment solely to reproduce the runner's
## non-canonical saveRDS() config hash; the expected grid below remains an
## independent reconstruction and must be identical to that source table.
## The verifier calculates no scientific trend or treatment contrast.

.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)
.near <- function(x, y, tolerance = 1e-12) is.finite(x) & abs(x - y) <= tolerance
.blank_error <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))

.sha256 <- function(path) {
  if (!file.exists(path)) .stopf("Cannot hash missing file: %s", path)
  exe <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else if (nzchar(Sys.which("shasum"))) "shasum" else ""
  if (!nzchar(exe)) .stopf("Neither sha256sum nor shasum is available")
  args <- if (exe == "shasum") c("-a", "256", path) else path
  out <- system2(exe, args, stdout = TRUE, stderr = TRUE)
  if (length(out) < 1L) .stopf("Could not hash: %s", path)
  strsplit(out[[1L]], "[[:space:]]+")[[1L]][1L]
}

.object_sha256 <- function(x) {
  path <- tempfile("phase-c-config-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 3)
  .sha256(path)
}

.canonical_config_sha256 <- function(x) {
  piece <- function(value) {
    if (is.integer(value)) out <- sprintf("%d", value)
    else if (is.numeric(value)) out <- formatC(value, digits = 17, format = "g", decimal.mark = ".")
    else if (is.logical(value)) out <- ifelse(value, "TRUE", "FALSE")
    else out <- enc2utf8(as.character(value))
    ifelse(is.na(value), "N", paste0("V", out))
  }
  encode_record <- function(value) {
    value <- enc2utf8(value)
    paste0(nchar(value, type = "bytes"), ":", value, collapse = "")
  }
  types <- vapply(x, function(value) paste(class(value), collapse = "/"), character(1))
  records <- c(
    encode_record(paste0("name=", enc2utf8(names(x)))),
    encode_record(paste0("class=", enc2utf8(types))),
    vapply(seq_len(nrow(x)), function(i) {
      encode_record(vapply(x, function(value) piece(value[[i]]), character(1)))
    }, character(1))
  )
  payload <- charToRaw(paste0(records, collapse = "\n"))
  path <- tempfile("phase-c-canonical-config-", fileext = ".bin")
  on.exit(unlink(path), add = TRUE)
  con <- file(path, open = "wb")
  tryCatch(writeBin(payload, con, useBytes = TRUE), finally = close(con))
  .sha256(path)
}

.absolute_path <- function(path) {
  path <- path.expand(path)
  if (!grepl("^/", path)) path <- file.path(getwd(), path)
  normalizePath(path, mustWork = FALSE)
}

.read_receipt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  at <- regexpr("=", lines, fixed = TRUE)
  if (!length(lines) || any(at < 2L)) .stopf("Malformed receipt: %s", path)
  keys <- substring(lines, 1L, at - 1L)
  vals <- substring(lines, at + 1L)
  if (anyDuplicated(keys)) .stopf("Duplicate receipt field: %s", path)
  as.list(stats::setNames(vals, keys))
}

.need_fields <- function(x, fields, label) {
  missing <- fields[!fields %in% names(x)]
  if (length(missing)) .stopf("%s is missing receipt field(s): %s", label, paste(missing, collapse = ", "))
}

.receipt_num <- function(x, field, label) {
  value <- suppressWarnings(as.numeric(x[[field]]))
  if (length(value) != 1L || !is.finite(value)) .stopf("%s has invalid numeric field %s", label, field)
  value
}

.receipt_int <- function(x, field, label) {
  value <- .receipt_num(x, field, label)
  if (value != as.integer(value)) .stopf("%s has non-integer field %s", label, field)
  as.integer(value)
}

.receipt_false <- function(value, label) {
  if (length(value) != 1L || !tolower(value) %in% c("false", "0")) .stopf("%s must be false", label)
  invisible(TRUE)
}

.git_value <- function(args, label) {
  out <- suppressWarnings(system2("git", args, stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) .stopf("Could not resolve %s with git", label)
  if (length(out) != 1L || !nzchar(out)) .stopf("Could not resolve %s with git", label)
  out[[1L]]
}

.instrument_files <- c(
  "dev/isdm-bias-harness.R",
  "dev/isdm-bias-campaign.R",
  "dev/isdm-phase-c-analyse-official.R",
  "dev/isdm-phase-c-pilot-decision.R",
  "dev/isdm-phase-c-amendment-2026-08-08.md"
)

.instrument_id_at <- function(sha) {
  if (!grepl("^[0-9a-f]{40}$", sha)) .stopf("Invalid source SHA: %s", sha)
  resolved <- .git_value(c("rev-parse", "--verify", paste0(sha, "^{commit}")), paste0("commit ", sha))
  if (!identical(resolved, sha)) .stopf("Source SHA does not resolve to the named commit: %s", sha)
  blobs <- vapply(.instrument_files, function(path) {
    .git_value(c("rev-parse", paste0(sha, ":", path)), paste0(sha, ":", path))
  }, character(1))
  paste(blobs, collapse = ":")
}

.current_instrument_id <- function() {
  missing <- .instrument_files[!file.exists(.instrument_files)]
  if (length(missing)) .stopf("Missing instrument file(s): %s", paste(missing, collapse = ", "))
  out <- system2("git", c("hash-object", .instrument_files), stdout = TRUE, stderr = TRUE)
  if (length(out) != length(.instrument_files)) .stopf("Could not hash current instrument files")
  paste(out, collapse = ":")
}

.make_key <- function(x, cols) do.call(paste, c(x[cols], sep = "|"))

.arms <- paste0("A", 1:6)
.branch <- "claude/experiment-integrated-sdm"
.full_key <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
               "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
.dataset_key <- setdiff(.full_key, "arm")
.null_key <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")

## Independent reconstruction of the preregistered configuration grid.
.ref <- list(kappa = 1, rho = 0.6, omega = 0.5, phi_x = 0.15,
             phi_bias = 0.15, n = 400, T_sp = 8, d_fit = 2, k = 3,
             beta0_shift = 0)

.mk_config <- function(rows, block, beta0_shift) {
  df <- do.call(rbind, lapply(rows, as.data.frame))
  df$stage <- "campaign"
  df$block <- block
  df$beta0_shift <- beta0_shift
  df[, c("stage", "block", "seed", "kappa", "rho", "omega", "phi_x",
         "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift"), drop = FALSE]
}

.expected_config <- function(block, beta0_shift, g1_seeds = 100L) {
  ref <- .ref
  ref$beta0_shift <- beta0_shift
  rows <- list()
  add <- function(x) rows[[length(rows) + 1L]] <<- x
  if (block == "G1") {
    for (s in seq_len(g1_seeds)) add(modifyList(ref, list(kappa = 0, seed = s)))
    for (kappa in c(0.25, 0.5, 1, 2)) for (rho in c(0, 0.6)) for (omega in c(1, 0.5, 0)) {
      for (s in seq_len(g1_seeds)) add(modifyList(ref, list(kappa = kappa, rho = rho, omega = omega, seed = s)))
    }
  } else if (block == "G2") {
    for (n in c(100, 1600)) for (s in 1:50) {
      add(modifyList(ref, list(kappa = 0, n = n, seed = s)))
      add(modifyList(ref, list(n = n, seed = s)))
    }
  } else if (block == "G3") {
    for (T_sp in c(6, 12)) for (s in 1:50) {
      add(modifyList(ref, list(kappa = 0, T_sp = T_sp, seed = s)))
      add(modifyList(ref, list(T_sp = T_sp, seed = s)))
    }
  } else if (block == "G4") {
    for (d_fit in c(1, 3)) for (s in 1:50) {
      add(modifyList(ref, list(kappa = 0, d_fit = d_fit, seed = s)))
      add(modifyList(ref, list(d_fit = d_fit, seed = s)))
    }
  } else if (block == "G5") {
    for (s in 1:50) {
      add(modifyList(ref, list(kappa = 0, k = 1, seed = s)))
      add(modifyList(ref, list(k = 1, seed = s)))
    }
  } else if (block == "G6") {
    for (phi_bias in c(0, 0.4)) for (s in 1:50) {
      add(modifyList(ref, list(phi_bias = phi_bias, seed = s)))
    }
  } else .stopf("Unknown block: %s", block)
  .mk_config(rows, block, beta0_shift)
}

.source_builder_configs <- function(beta0_shift, g1_seeds = 100L) {
  env <- new.env(parent = baseenv())
  env$modifyList <- utils::modifyList
  env$source <- local({
    target <- env
    function(file, local = FALSE, ...) sys.source(file, envir = target)
  })
  sys.source("dev/isdm-bias-campaign.R", envir = env)
  blocks <- paste0("G", 1:6)
  out <- setNames(vector("list", length(blocks)), blocks)
  out$G1 <- get("build_config_g1", envir = env)(seq_len(g1_seeds), beta0_shift = beta0_shift)
  for (block in blocks[-1L]) {
    out[[block]] <- get(paste0("build_config_", tolower(block)), envir = env)(
      seeds = 1:50, beta0_shift = beta0_shift
    )
  }
  out
}

.expand_arms <- function(config) {
  out <- config[rep(seq_len(nrow(config)), each = length(.arms)), , drop = FALSE]
  rownames(out) <- NULL
  out$arm <- rep(.arms, times = nrow(config))
  out[, .full_key, drop = FALSE]
}

.parse_named <- function(spec, label) {
  at <- regexpr("=", spec, fixed = TRUE)
  if (at < 2L || at == nchar(spec)) .stopf("%s must be BLOCK=FILE: %s", label, spec)
  block <- toupper(substring(spec, 1L, at - 1L))
  path <- substring(spec, at + 1L)
  if (!block %in% paste0("G", 1:6)) .stopf("Unknown %s block: %s", label, block)
  c(block = block, path = path)
}

.usage <- function() {
  cat(paste0(
    "Independent Phase C structural campaign verifier\n\n",
    "Usage:\n",
    "  Rscript dev/isdm-phase-c-verify-campaign.R \\\n",
    "    --result G1=/path/g1.rds ... --result G6=/path/g6.rds \\\n",
    "    --receipt G1=/path/g1-compute.receipt ... --receipt G6=... \\\n",
    "    --preflight-receipt=/path/preflight.receipt \\\n",
    "    --pilot=/path/pilot-v2-results.rds \\\n",
    "    --pilot-compute-receipt=/path/pilot-v2-compute.receipt \\\n",
    "    --pilot-decision-receipt=/path/pilot-decision.receipt \\\n",
    "    --out-dir=/external/new-audit-directory\n\n",
    "Options:\n",
    "  --calibration-receipt=FILE   Required only for a non-zero frozen shift.\n",
    "  --self-test                  Build and audit a synthetic /private/tmp fixture.\n",
    "  --help                       Show this help.\n"
  ))
}

.parse_args <- function(args) {
  if (any(args %in% c("--help", "-h"))) return(list(help = TRUE))
  if (identical(args, "--self-test")) return(list(self_test = TRUE))
  out <- list(results = character(), receipts = character(), help = FALSE, self_test = FALSE)
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (arg %in% c("--result", "--receipt")) {
      i <- i + 1L
      if (i > length(args)) .stopf("%s requires BLOCK=FILE", arg)
      spec <- args[[i]]
      target <- if (arg == "--result") "results" else "receipts"
    } else if (startsWith(arg, "--result=")) {
      spec <- substring(arg, nchar("--result=") + 1L); target <- "results"
    } else if (startsWith(arg, "--receipt=")) {
      spec <- substring(arg, nchar("--receipt=") + 1L); target <- "receipts"
    } else {
      known <- c("preflight-receipt", "pilot", "pilot-compute-receipt",
                 "pilot-decision-receipt", "calibration-receipt", "out-dir")
      hit <- known[vapply(known, function(x) startsWith(arg, paste0("--", x, "=")), logical(1))]
      if (length(hit) != 1L) .stopf("Unknown or malformed argument: %s", arg)
      out[[gsub("-", "_", hit)]] <- substring(arg, nchar(hit) + 4L)
      i <- i + 1L
      next
    }
    parsed <- .parse_named(spec, target)
    block <- parsed[["block"]]
    if (block %in% names(out[[target]])) .stopf("Duplicate %s assignment: %s", target, block)
    out[[target]][[block]] <- parsed[["path"]]
    i <- i + 1L
  }
  required_blocks <- paste0("G", 1:6)
  if (!identical(sort(names(out$results)), required_blocks) ||
      !identical(sort(names(out$receipts)), required_blocks)) {
    .stopf("Exactly G1--G6 result and receipt assignments are required")
  }
  required <- c("preflight_receipt", "pilot", "pilot_compute_receipt",
                "pilot_decision_receipt", "out_dir")
  missing <- required[!vapply(required, function(x) !is.null(out[[x]]) && nzchar(out[[x]]), logical(1))]
  if (length(missing)) .stopf("Missing required option(s): %s", paste(missing, collapse = ", "))
  out
}

.assert_all_inputs_exist <- function(opt) {
  paths <- c(unname(opt$results), unname(opt$receipts), opt$preflight_receipt,
             opt$pilot, opt$pilot_compute_receipt, opt$pilot_decision_receipt)
  if (!is.null(opt$calibration_receipt)) paths <- c(paths, opt$calibration_receipt)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) .stopf("Outcome firewall closed: required file(s) missing: %s", paste(missing, collapse = ", "))
  if (anyDuplicated(normalizePath(unname(opt$results), mustWork = TRUE))) .stopf("One campaign result was assigned to multiple blocks")
  if (anyDuplicated(normalizePath(unname(opt$receipts), mustWork = TRUE))) .stopf("One campaign receipt was assigned to multiple blocks")
  invisible(TRUE)
}

.verify_common_receipt <- function(x, type, label, current_id) {
  .need_fields(x, c("receipt_type", "status", "source_sha", "source_branch",
                    "source_dirty", "instrument_id"), label)
  if (!identical(x$receipt_type, type) || !identical(x$status, "PASS")) .stopf("%s is not a PASS %s", label, type)
  if (!identical(x$source_branch, .branch)) .stopf("%s does not identify Lane C", label)
  .receipt_false(x$source_dirty, paste0(label, " source_dirty"))
  source_id <- .instrument_id_at(x$source_sha)
  if (!identical(x$instrument_id, source_id) || !identical(x$instrument_id, current_id)) {
    .stopf("%s instrument ID does not match its source commit and current frozen files", label)
  }
  invisible(TRUE)
}

.verify_file_binding <- function(receipt, path, label) {
  .need_fields(receipt, c("output_path", "output_bytes", "output_sha256"), label)
  norm <- normalizePath(path, mustWork = TRUE)
  if (!identical(normalizePath(receipt$output_path, mustWork = TRUE), norm)) .stopf("%s output_path mismatch", label)
  bytes <- as.numeric(file.info(norm)$size)
  if (.receipt_num(receipt, "output_bytes", label) != bytes) .stopf("%s output byte count mismatch", label)
  if (!identical(receipt$output_sha256, .sha256(norm))) .stopf("%s output hash mismatch", label)
  invisible(TRUE)
}

.parse_part_manifest <- function(receipt, result_path, label) {
  .need_fields(receipt, c("resume_parts_dir", "resume_part_count", "resume_part_hashes"), label)
  parts_dir <- normalizePath(receipt$resume_parts_dir, mustWork = TRUE)
  expected_dir <- normalizePath(paste0(result_path, ".parts"), mustWork = TRUE)
  if (!identical(parts_dir, expected_dir)) .stopf("%s resume-parts directory mismatch", label)
  specs <- if (nzchar(receipt$resume_part_hashes)) strsplit(receipt$resume_part_hashes, ";", fixed = TRUE)[[1L]] else character()
  parsed <- lapply(specs, function(spec) {
    at <- regexpr(":", spec, fixed = TRUE)
    if (at < 2L) .stopf("Malformed part-hash entry in %s", label)
    c(name = substring(spec, 1L, at - 1L), hash = substring(spec, at + 1L))
  })
  names_seen <- if (length(parsed)) vapply(parsed, `[[`, character(1), "name") else character()
  hashes <- if (length(parsed)) vapply(parsed, `[[`, character(1), "hash") else character()
  count <- .receipt_int(receipt, "resume_part_count", label)
  if (count < 1L || count != length(names_seen) || anyDuplicated(names_seen)) .stopf("%s part-count/manifest mismatch", label)
  actual <- sort(list.files(parts_dir, pattern = "[.]rds$", full.names = FALSE))
  if (!identical(sort(names_seen), actual)) .stopf("%s part manifest does not match directory contents", label)
  paths <- file.path(parts_dir, names_seen)
  actual_hashes <- vapply(paths, .sha256, character(1))
  if (!identical(unname(actual_hashes), unname(hashes))) .stopf("%s part hash mismatch", label)
  stats::setNames(paths, names_seen)
}

.authenticate_receipt_sources <- function(opt) {
  current_id <- .current_instrument_id()
  preflight <- .read_receipt(opt$preflight_receipt)
  pilot_compute <- .read_receipt(opt$pilot_compute_receipt)
  decision <- .read_receipt(opt$pilot_decision_receipt)
  .verify_common_receipt(preflight, "preflight_compute", "preflight receipt", current_id)
  .verify_common_receipt(pilot_compute, "pilot_compute", "pilot compute receipt", current_id)
  .verify_common_receipt(decision, "pilot_decision", "pilot decision receipt", current_id)
  early_shas <- unique(c(preflight$source_sha, pilot_compute$source_sha, decision$source_sha))
  if (length(early_shas) != 1L) .stopf("Preflight, pilot compute, and pilot decision source SHAs differ")
  blocks <- paste0("G", 1:6)
  campaign <- stats::setNames(lapply(blocks, function(block) {
    label <- paste(block, "compute receipt")
    receipt <- .read_receipt(opt$receipts[[block]])
    .verify_common_receipt(receipt, paste0(tolower(block), "_compute"), label, current_id)
    receipt
  }), blocks)
  campaign_shas <- unique(vapply(campaign, `[[`, character(1), "source_sha"))
  instruments <- unique(vapply(campaign, `[[`, character(1), "instrument_id"))
  if (length(campaign_shas) != 1L || length(instruments) != 1L) {
    .stopf("G1--G6 source SHA or instrument ID differs")
  }
  list(current_id = current_id, preflight = preflight, pilot_compute = pilot_compute,
       decision = decision, campaign = campaign, campaign_source_sha = campaign_shas,
       instrument_id = instruments)
}

.verify_receipt_bundle <- function(opt, configs, builder_configs, authentication) {
  preflight <- authentication$preflight
  pilot_compute <- authentication$pilot_compute
  decision <- authentication$decision
  preflight_hash <- .sha256(opt$preflight_receipt)
  pilot_compute_hash <- .sha256(opt$pilot_compute_receipt)
  decision_hash <- .sha256(opt$pilot_decision_receipt)
  .need_fields(pilot_compute, "predecessor_receipt_hashes", "pilot compute receipt")
  if (!grepl(paste0("preflight:", preflight_hash), pilot_compute$predecessor_receipt_hashes, fixed = TRUE)) {
    .stopf("Pilot compute receipt is not bound to the supplied preflight receipt")
  }
  .need_fields(decision, c("preflight_receipt_sha256", "pilot_compute_receipt_sha256",
                           "pilot_sha256", "g1_seeds", "beta0_shift",
                           "projected_3mcse_s100"), "pilot decision receipt")
  if (!identical(decision$preflight_receipt_sha256, preflight_hash) ||
      !identical(decision$pilot_compute_receipt_sha256, pilot_compute_hash)) {
    .stopf("Pilot decision predecessor hashes do not match")
  }
  .verify_file_binding(pilot_compute, opt$pilot, "pilot compute receipt")
  if (!identical(decision$pilot_sha256, .sha256(opt$pilot))) .stopf("Pilot decision result hash mismatch")
  g1_seeds <- .receipt_int(decision, "g1_seeds", "pilot decision receipt")
  if (g1_seeds != 100L || .receipt_num(decision, "projected_3mcse_s100", "pilot decision receipt") > 0.05) {
    .stopf("Frozen S100 decision is absent or inconsistent with the precision rule")
  }
  beta0 <- .receipt_num(decision, "beta0_shift", "pilot decision receipt")
  if (!.near(beta0, 0)) .stopf("This campaign was frozen at beta0_shift = 0; got %s", beta0)
  if (!is.null(opt$calibration_receipt)) .stopf("A calibration receipt is incompatible with the frozen zero shift")

  blocks <- paste0("G", 1:6)
  campaign <- authentication$campaign
  part_paths <- setNames(vector("list", 6L), blocks)
  rows <- vector("list", 6L)
  for (i in seq_along(blocks)) {
    block <- blocks[[i]]; label <- paste(block, "compute receipt")
    if (!identical(configs[[block]], builder_configs[[block]])) {
      .stopf("%s independent grid differs from the frozen source builder", label)
    }
    receipt <- campaign[[block]]
    .need_fields(receipt, c("stage", "expected_rows", "actual_rows", "expected_logical_rows",
                            "expected_optimizer_calls", "config_sha256", "seed_min", "seed_max",
                            "seed_count", "phi_x", "phi_bias", "beta0_shift", "arms",
                            "null_dataset_rows", "unique_key_verdict", "a6_null_collapsed_rows",
                            "fit_error_rows", "unlabelled_nonfinite_rows",
                            "predecessor_receipt_hashes", "cores", "started_utc", "ended_utc",
                            "host", "r_version"), label)
    if (!identical(tolower(receipt$stage), tolower(block))) .stopf("%s stage mismatch", label)
    if (.receipt_int(receipt, "cores", label) < 1L || .receipt_int(receipt, "cores", label) > 150L) .stopf("%s violates the Totoro core cap", label)
    expected_rows <- nrow(configs[[block]]) * 6L
    for (field in c("expected_rows", "actual_rows", "expected_logical_rows", "expected_optimizer_calls")) {
      if (.receipt_int(receipt, field, label) != expected_rows) .stopf("%s %s mismatch", label, field)
    }
    if (!identical(receipt$config_sha256, .object_sha256(builder_configs[[block]]))) {
      .stopf("%s source-builder serialization hash mismatch", label)
    }
    if (!identical(receipt$unique_key_verdict, "PASS")) .stopf("%s unique-key verdict is not PASS", label)
    if (.receipt_int(receipt, "unlabelled_nonfinite_rows", label) != 0L) .stopf("%s reports unlabelled non-finite rows", label)
    if (!identical(receipt$arms, paste(.arms, collapse = ","))) .stopf("%s arm manifest mismatch", label)
    if (!.near(.receipt_num(receipt, "phi_x", label), 0.15)) .stopf("%s phi_x is not frozen at 0.15", label)
    expected_phi_bias <- paste(sort(unique(configs[[block]]$phi_bias)), collapse = ",")
    if (!identical(receipt$phi_bias, expected_phi_bias)) .stopf("%s phi_bias manifest mismatch", label)
    if (!.near(.receipt_num(receipt, "beta0_shift", label), beta0)) .stopf("%s beta0 shift mismatch", label)
    if (.receipt_int(receipt, "seed_min", label) != min(configs[[block]]$seed) ||
        .receipt_int(receipt, "seed_max", label) != max(configs[[block]]$seed) ||
        .receipt_int(receipt, "seed_count", label) != length(unique(configs[[block]]$seed))) {
      .stopf("%s seed manifest mismatch", label)
    }
    null_rows <- sum(.near(configs[[block]]$kappa, 0))
    if (.receipt_int(receipt, "null_dataset_rows", label) != null_rows ||
        .receipt_int(receipt, "a6_null_collapsed_rows", label) != null_rows) {
      .stopf("%s null/A6-collapse manifest mismatch", label)
    }
    required_predecessors <- c(paste0("preflight:", preflight_hash), paste0("pilot_decision:", decision_hash))
    if (!all(vapply(required_predecessors, grepl, logical(1), x = receipt$predecessor_receipt_hashes, fixed = TRUE))) {
      .stopf("%s predecessor receipt hash mismatch", label)
    }
    .verify_file_binding(receipt, opt$results[[block]], label)
    part_paths[[block]] <- .parse_part_manifest(receipt, opt$results[[block]], label)
    rows[[i]] <- data.frame(
      block = block, expected_rows = expected_rows,
      receipt_actual_rows = .receipt_int(receipt, "actual_rows", label),
      result_bytes = as.numeric(file.info(opt$results[[block]])$size),
      result_sha256 = .sha256(opt$results[[block]]),
      receipt_bytes = as.numeric(file.info(opt$receipts[[block]])$size),
      receipt_sha256 = .sha256(opt$receipts[[block]]),
      config_sha256 = receipt$config_sha256,
      independent_config_sha256 = .canonical_config_sha256(configs[[block]]),
      part_count = length(part_paths[[block]]),
      part_bytes = sum(file.info(part_paths[[block]])$size),
      part_sha256 = paste(sprintf("%s:%s", basename(part_paths[[block]]),
                                  vapply(part_paths[[block]], .sha256, character(1))), collapse = ";"),
      receipt_fit_error_rows = .receipt_int(receipt, "fit_error_rows", label),
      stringsAsFactors = FALSE
    )
  }
  if (.receipt_int(campaign$G1, "seed_count", "G1 compute receipt") != 100L ||
      .receipt_int(campaign$G1, "g1_seeds", "G1 compute receipt") != 100L) .stopf("G1 is not bound to frozen S100")
  g1_hash <- .sha256(opt$receipts[["G1"]])
  if (!grepl(paste0("g1:", g1_hash), campaign$G6$predecessor_receipt_hashes, fixed = TRUE)) {
    .stopf("G6 is not bound to the supplied G1 receipt")
  }
  list(preflight = preflight, pilot_compute = pilot_compute, decision = decision,
       campaign = campaign, part_paths = part_paths, block_audit = do.call(rbind, rows),
       beta0_shift = beta0, g1_seeds = g1_seeds,
       campaign_source_sha = authentication$campaign_source_sha,
       instrument_id = authentication$instrument_id, preflight_hash = preflight_hash,
       pilot_compute_hash = pilot_compute_hash, decision_hash = decision_hash)
}

.coerce_flag <- function(x, label) {
  if (is.logical(x)) return(x)
  if ((is.numeric(x) || is.integer(x)) && all(is.na(x) | x %in% c(0, 1))) return(as.logical(x))
  .stopf("%s must be logical or 0/1", label)
}

.assert_same_frame <- function(a, b, label) {
  if (!identical(names(a), names(b))) .stopf("%s column names differ", label)
  ka <- .make_key(a, .full_key); kb <- .make_key(b, .full_key)
  if (anyDuplicated(ka) || anyDuplicated(kb) || !setequal(ka, kb)) .stopf("%s full keys differ", label)
  a <- a[order(ka), , drop = FALSE]; b <- b[order(kb), , drop = FALSE]
  rownames(a) <- rownames(b) <- NULL
  if (!isTRUE(all.equal(a, b, tolerance = 0, check.attributes = FALSE))) .stopf("%s result contents differ", label)
}

.validate_block_results <- function(x, block, expected, receipt, parts, instrument_id) {
  label <- paste(block, "result")
  if (!is.data.frame(x)) .stopf("%s is not a data.frame", label)
  required <- c(.full_key, "elapsed_sec", "realised_prevalence", "bias_sharing",
                "fit_error", "convergence", "pdHess", "diag_B_skip",
                "oracle_collapsed", "estimand", "D_bias", "D_rmse", "D_max",
                "D_z", "rank_d_D_bias", "rank_d_D_rmse", "signflip", "diag_rmse",
                "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
                "n_heywood_psi", "n_heywood_loading")
  missing <- setdiff(required, names(x))
  if (length(missing)) .stopf("%s missing column(s): %s", label, paste(missing, collapse = ", "))
  if (nrow(x) != nrow(expected)) .stopf("%s row count mismatch", label)
  if (!identical(unique(as.character(x$stage)), "campaign") ||
      !identical(unique(as.character(x$block)), block)) .stopf("%s stage/block collision", label)
  for (nm in c("kappa", "rho", "omega", "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift", "seed")) {
    if (!is.numeric(x[[nm]]) || any(!is.finite(x[[nm]]))) .stopf("%s has invalid config column %s", label, nm)
  }
  if (any(!.near(x$phi_x, 0.15))) .stopf("%s violates phi_x freeze", label)
  actual_key <- .make_key(x, .full_key); expected_key <- .make_key(expected, .full_key)
  if (anyDuplicated(actual_key) || !setequal(actual_key, expected_key)) .stopf("%s does not equal the preregistered full grid", label)
  by_dataset <- split(as.character(x$arm), .make_key(x, .dataset_key))
  if (any(vapply(by_dataset, function(a) !identical(sort(a), .arms), logical(1)))) .stopf("%s violates exact six-arm coverage", label)
  completed <- .blank_error(x$fit_error)
  x$pdHess <- .coerce_flag(x$pdHess, paste(label, "pdHess"))
  x$oracle_collapsed <- .coerce_flag(x$oracle_collapsed, paste(label, "oracle_collapsed"))
  if (any(completed & is.na(x$pdHess)) || any(completed & is.na(x$oracle_collapsed))) .stopf("%s has unlabelled structural flags", label)
  estimand <- as.character(x$estimand)
  rank <- completed & block == "G5" & x$arm == "A2"
  total <- completed & !rank
  if (any(rank & estimand != "loadings_only_rank_d") || any(total & estimand != "total_sigma")) .stopf("%s violates G5/A2 estimand separation", label)
  total_required <- c("elapsed_sec", "realised_prevalence", "bias_sharing", "convergence",
                      "diag_B_skip", "D_bias", "D_rmse", "D_max", "D_z", "signflip",
                      "diag_rmse", "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
                      "n_heywood_psi", "n_heywood_loading")
  rank_required <- c("elapsed_sec", "realised_prevalence", "bias_sharing", "convergence",
                     "diag_B_skip", "rank_d_D_bias", "rank_d_D_rmse", "lambda_proc_rmse",
                     "beta_bias", "beta_rmse", "n_heywood_loading")
  for (nm in total_required) if (any(total & !is.finite(x[[nm]]))) .stopf("%s has completed total-Sigma rows with non-finite %s", label, nm)
  for (nm in rank_required) if (any(rank & !is.finite(x[[nm]]))) .stopf("%s has completed rank-d rows with non-finite %s", label, nm)
  if (any(rank & (x$diag_B_skip <= 0 | is.finite(x$D_bias) | is.finite(x$D_rmse)))) .stopf("%s leaks G5/A2 into total-Sigma metrics", label)
  nonrank <- completed & !rank
  if (any(nonrank & (is.finite(x$rank_d_D_bias) | is.finite(x$rank_d_D_rmse)))) .stopf("%s leaks rank-d metrics outside G5/A2", label)
  fit_errors <- sum(!completed)
  if (fit_errors != .receipt_int(receipt, "fit_error_rows", paste(block, "receipt"))) .stopf("%s fit-error count differs from receipt", label)
  a6_null <- .near(x$kappa, 0) & x$arm == "A6"
  if (any(!x$oracle_collapsed[a6_null]) || any(x$oracle_collapsed[completed & !a6_null])) .stopf("%s A6 null-collapse labels are wrong", label)

  part_results <- vector("list", length(parts))
  for (i in seq_along(parts)) {
    part <- readRDS(parts[[i]])
    if (!is.list(part) || !is.data.frame(part$results) ||
        !identical(part$instrument_id, instrument_id) ||
        !identical(part$config_sha256, receipt$config_sha256)) .stopf("%s has malformed/incompatible part %s", label, basename(parts[[i]]))
    if (nrow(part$results) %% 6L != 0L) .stopf("%s contains a partial six-arm dataset", basename(parts[[i]]))
    part_results[[i]] <- part$results
  }
  combined <- do.call(rbind, part_results); rownames(combined) <- NULL
  if (nrow(combined) != nrow(x)) .stopf("%s parts do not total the final row count", label)
  .assert_same_frame(combined, x, paste(block, "part/final"))
  list(results = x, fit_errors = fit_errors, completed = sum(completed), part_rows = nrow(combined))
}

.assert_a5_a6_null_identity <- function(all) {
  null <- all[.near(all$kappa, 0) & all$arm %in% c("A5", "A6"), , drop = FALSE]
  a5 <- null[null$arm == "A5", , drop = FALSE]
  a6 <- null[null$arm == "A6", , drop = FALSE]
  key <- c("stage", "block", "seed", "n", "T_sp", "d_fit", "k", "beta0_shift")
  idx <- match(.make_key(a5, key), .make_key(a6, key))
  if (nrow(a5) != nrow(a6) || anyNA(idx)) .stopf("A5/A6 null rows do not pair exactly")
  a6 <- a6[idx, , drop = FALSE]
  c5 <- .blank_error(a5$fit_error); c6 <- .blank_error(a6$fit_error)
  if (!identical(c5, c6)) .stopf("A5/A6 null completion states differ")
  fields <- c("convergence", "pdHess", "diag_B_skip", "estimand", "D_bias", "D_rmse",
              "D_max", "D_z", "signflip", "diag_rmse", "psi_rmse",
              "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi",
              "n_heywood_loading")
  for (field in fields) {
    if (!isTRUE(all.equal(a5[[field]][c5], a6[[field]][c5], tolerance = 0, check.attributes = FALSE))) {
      .stopf("A5/A6 null identity fails for %s", field)
    }
  }
  invisible(TRUE)
}

.write_receipt <- function(path, fields) {
  vals <- vapply(fields, function(x) paste(x, collapse = ","), character(1))
  if (any(grepl("[\r\n]", vals))) .stopf("Audit receipt fields must be single-line")
  writeLines(sprintf("%s=%s", names(vals), vals), path)
}

.write_audit <- function(opt, bundle, block_audit, started, ended) {
  out_dir <- .absolute_path(opt$out_dir)
  repo <- normalizePath(getwd(), mustWork = TRUE)
  if (identical(out_dir, repo) || startsWith(out_dir, paste0(repo, "/"))) .stopf("Audit output directory must be external to the repository")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  targets <- file.path(out_dir, c("phase-c-compute-audit-blocks.csv",
                                  "phase-c-compute-audit.md",
                                  "phase-c-compute-audit.receipt"))
  if (any(file.exists(targets))) .stopf("Refusing to overwrite existing audit output(s): %s", paste(basename(targets[file.exists(targets)]), collapse = ", "))
  utils::write.csv(block_audit, targets[[1L]], row.names = FALSE, na = "NA")
  total_expected <- sum(block_audit$expected_rows)
  total_actual <- sum(block_audit$actual_rows)
  total_errors <- sum(block_audit$fit_error_rows)
  md <- c(
    "# Phase C independent compute audit",
    "",
    "**Verdict: PASS.** All six PASS compute receipts cleared before any campaign RDS was opened. The raw files then matched the preregistered G1--G6 grids, exact pairing contract, retained-failure contract, and immutable part manifests.",
    "",
    sprintf("- campaign source SHA: `%s`", bundle$campaign_source_sha),
    sprintf("- branch: `%s`", .branch),
    sprintf("- instrument ID: `%s`", bundle$instrument_id),
    sprintf("- frozen G1 seeds: %d", bundle$g1_seeds),
    sprintf("- frozen beta0 shift: %.17g", bundle$beta0_shift),
    sprintf("- expected / actual campaign rows: %d / %d", total_expected, total_actual),
    sprintf("- retained fit-error rows: %d", total_errors),
    sprintf("- resumable parts verified: %d", sum(block_audit$part_count)),
    sprintf("- audit host: `%s`", Sys.info()[["nodename"]]),
    sprintf("- R: `%s`", R.version.string),
    sprintf("- started / ended UTC: `%s` / `%s`", format(started, tz = "UTC", usetz = TRUE), format(ended, tz = "UTC", usetz = TRUE)),
    "",
    "## Structural checks supplied by this audit",
    "",
    "The original per-block compute receipts do not enumerate every preregistered treatment axis, exact cross-block null-pair count, full six-arm key set, A5/A6-null field identity, G5/A2 separation, or part-to-final content identity. This audit reconstructs those contracts independently and records them without rewriting or rerunning any fit.",
    "",
    "The runner's raw saveRDS configuration hash is checked against the immutable source builder. Because that byte hash preserves non-canonical R object representation, the independently reconstructed value-identical grid is also recorded under a canonical length-prefixed UTF-8/LF SHA-256.",
    "",
    "## Limits",
    "",
    "This is a structural and provenance audit, not a scientific analysis. It does not inspect treatment trends, estimate Monte Carlo uncertainty, validate ecological interpretation, prove optimiser adequacy, or show that a thrown fit would have failed identically under a new retry. Exact scheduled rows and part manifests rule out unexplained missing or duplicated configurations in the audited artifacts; they do not preserve the files beyond the recorded hashes.",
    "",
    "## Session",
    "",
    "```text",
    capture.output(sessionInfo()),
    "```"
  )
  writeLines(md, targets[[2L]])
  session_text <- paste(capture.output(sessionInfo()), collapse = " | ")
  audit_sha <- tryCatch(.git_value(c("rev-parse", "HEAD"), "audit HEAD"), error = function(e) "UNRESOLVED")
  audit_branch <- tryCatch(.git_value(c("branch", "--show-current"), "audit branch"), error = function(e) "UNRESOLVED")
  audit_dirty <- length(system2("git", c("status", "--porcelain"), stdout = TRUE)) > 0L
  fields <- list(
    receipt_type = "phase_c_campaign_compute_audit", status = "PASS",
    campaign_source_sha = bundle$campaign_source_sha, source_branch = .branch,
    source_dirty = "false", instrument_id = bundle$instrument_id,
    audit_source_sha = audit_sha, audit_source_branch = audit_branch,
    audit_source_dirty = audit_dirty,
    verifier_path = normalizePath(sys.frame(1)$ofile %||% "dev/isdm-phase-c-verify-campaign.R", mustWork = FALSE),
    verifier_sha256 = .sha256("dev/isdm-phase-c-verify-campaign.R"),
    host = Sys.info()[["nodename"]], r_version = R.version.string,
    session_info = session_text,
    started_utc = format(started, tz = "UTC", usetz = TRUE),
    ended_utc = format(ended, tz = "UTC", usetz = TRUE),
    g1_seeds = bundle$g1_seeds, beta0_shift = bundle$beta0_shift,
    expected_rows = total_expected, actual_rows = total_actual,
    fit_error_rows = total_errors, unlabelled_nonfinite_rows = 0,
    block_count = nrow(block_audit), resume_part_count = sum(block_audit$part_count),
    preflight_receipt_sha256 = bundle$preflight_hash,
    pilot_compute_receipt_sha256 = bundle$pilot_compute_hash,
    pilot_decision_receipt_sha256 = bundle$decision_hash,
    campaign_receipt_sha256 = paste(sprintf("%s:%s", block_audit$block, block_audit$receipt_sha256), collapse = ";"),
    campaign_result_sha256 = paste(sprintf("%s:%s", block_audit$block, block_audit$result_sha256), collapse = ";"),
    campaign_independent_config_sha256 = paste(
      sprintf("%s:%s", block_audit$block, block_audit$independent_config_sha256),
      collapse = ";"
    ),
    block_csv_sha256 = .sha256(targets[[1L]]), markdown_sha256 = .sha256(targets[[2L]])
  )
  .write_receipt(targets[[3L]], fields)
  list(paths = targets, receipt_sha256 = .sha256(targets[[3L]]))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.audit_campaign <- function(opt, builder_loader = .source_builder_configs) {
  out_dir <- .absolute_path(opt$out_dir)
  targets <- file.path(out_dir, c("phase-c-compute-audit-blocks.csv", "phase-c-compute-audit.md", "phase-c-compute-audit.receipt"))
  if (any(file.exists(targets))) .stopf("Refusing to overwrite existing audit output(s): %s", paste(basename(targets[file.exists(targets)]), collapse = ", "))
  started <- Sys.time()
  .assert_all_inputs_exist(opt)
  ## Authenticate every source commit and current instrument file before the
  ## source builder is evaluated. All remaining provenance/config/file/part
  ## checks are then cleared before the first campaign readRDS() call.
  authentication <- .authenticate_receipt_sources(opt)
  beta0 <- .receipt_num(authentication$decision, "beta0_shift", "pilot decision receipt")
  configs <- setNames(lapply(paste0("G", 1:6), .expected_config, beta0_shift = beta0, g1_seeds = 100L), paste0("G", 1:6))
  builder_configs <- builder_loader(beta0_shift = beta0, g1_seeds = 100L)
  bundle <- .verify_receipt_bundle(opt, configs, builder_configs, authentication)

  blocks <- paste0("G", 1:6)
  validated <- setNames(vector("list", 6L), blocks)
  for (block in blocks) {
    expected <- .expand_arms(configs[[block]])
    validated[[block]] <- .validate_block_results(
      readRDS(opt$results[[block]]), block, expected,
      bundle$campaign[[block]], bundle$part_paths[[block]], bundle$instrument_id
    )
  }
  all <- do.call(rbind, lapply(validated, `[[`, "results")); rownames(all) <- NULL
  if (anyDuplicated(.make_key(all, .full_key))) .stopf("Full campaign keys are not unique")
  null <- all[.near(all$kappa, 0), , drop = FALSE]
  expected_null_keys <- unique(.make_key(all, .null_key))
  counts <- table(factor(.make_key(null, .null_key), levels = expected_null_keys))
  if (any(counts != 1L)) .stopf("Exact one-null contract fails for %d pairing key(s)", sum(counts != 1L))
  .assert_a5_a6_null_identity(all)
  if (!setequal(unique(all$phi_bias[all$block == "G6"]), c(0, 0.4)) ||
      any(!.near(all$phi_x[all$block == "G6"], 0.15))) .stopf("G6 does not isolate phi_bias from phi_x")

  block_audit <- bundle$block_audit
  block_audit$actual_rows <- vapply(validated, function(z) nrow(z$results), integer(1))
  block_audit$fit_error_rows <- vapply(validated, `[[`, integer(1), "fit_errors")
  block_audit$completed_rows <- vapply(validated, `[[`, integer(1), "completed")
  block_audit$part_rows <- vapply(validated, `[[`, integer(1), "part_rows")
  block_audit$unique_full_keys <- vapply(validated, function(z) length(unique(.make_key(z$results, .full_key))), integer(1))
  block_audit$exact_six_arms <- TRUE
  block_audit$exact_null_contract <- TRUE
  block_audit$a5_a6_null_identity <- ifelse(
    block_audit$block == "G6",
    "NOT_APPLICABLE_G6_REUSES_G1_NULL", "PASS"
  )
  block_audit$unlabelled_nonfinite_rows <- 0L
  ended <- Sys.time()
  .write_audit(opt, bundle, block_audit, started, ended)
}

.synthetic_results <- function(config, block) {
  x <- .expand_arms(config)
  n <- nrow(x)
  x$elapsed_sec <- 1
  x$realised_prevalence <- 0.33
  x$bias_sharing <- 0.5
  x$fit_error <- NA_character_
  x$convergence <- 0
  x$pdHess <- TRUE
  rank <- block == "G5" & x$arm == "A2"
  x$diag_B_skip <- ifelse(rank, 1, 0)
  x$oracle_collapsed <- .near(x$kappa, 0) & x$arm == "A6"
  x$estimand <- ifelse(rank, "loadings_only_rank_d", "total_sigma")
  total_value <- rep(0.1, n)
  for (nm in c("D_bias", "D_rmse", "D_max", "D_z", "signflip", "diag_rmse",
               "psi_rmse", "lambda_proc_rmse", "beta_bias", "beta_rmse",
               "n_heywood_psi", "n_heywood_loading")) x[[nm]] <- total_value
  x$rank_d_D_bias <- ifelse(rank, 0.1, NA_real_)
  x$rank_d_D_rmse <- ifelse(rank, 0.1, NA_real_)
  for (nm in c("D_bias", "D_rmse", "D_max", "D_z", "signflip", "diag_rmse", "psi_rmse", "n_heywood_psi")) x[[nm]][rank] <- NA_real_
  if (block == "G2") {
    err <- which(x$kappa > 0 & x$arm == "A1")[[1L]]
    x$fit_error[err] <- "synthetic retained fit error"
    metric <- c("elapsed_sec", "convergence", "pdHess", "estimand", "D_bias", "D_rmse", "D_max", "D_z",
                "rank_d_D_bias", "rank_d_D_rmse", "signflip", "diag_rmse", "psi_rmse",
                "lambda_proc_rmse", "beta_bias", "beta_rmse", "n_heywood_psi", "n_heywood_loading")
    for (nm in metric) x[[nm]][err] <- NA
  }
  x
}

.write_fixture_receipt <- function(path, fields) .write_receipt(path, fields)

.self_test <- function() {
  root <- tempfile("phase-c-audit-self-test-", tmpdir = "/private/tmp")
  dir.create(root, recursive = TRUE)
  source_sha <- .git_value(c("rev-parse", "HEAD"), "self-test source SHA")
  instrument_id <- .instrument_id_at(source_sha)
  preflight_out <- file.path(root, "preflight.rds"); saveRDS(list(structural = TRUE), preflight_out)
  preflight_receipt <- file.path(root, "preflight.receipt")
  common <- list(source_sha = source_sha, source_branch = .branch, source_dirty = FALSE, instrument_id = instrument_id)
  .write_fixture_receipt(preflight_receipt, c(list(receipt_type = "preflight_compute", status = "PASS"), common,
    list(output_path = normalizePath(preflight_out), output_bytes = file.info(preflight_out)$size, output_sha256 = .sha256(preflight_out))))
  pilot <- file.path(root, "pilot-v2-results.rds"); saveRDS(data.frame(synthetic = TRUE), pilot)
  pilot_compute <- file.path(root, "pilot-v2-compute.receipt")
  .write_fixture_receipt(pilot_compute, c(list(receipt_type = "pilot_compute", status = "PASS"), common,
    list(output_path = normalizePath(pilot), output_bytes = file.info(pilot)$size, output_sha256 = .sha256(pilot),
         predecessor_receipt_hashes = paste0("preflight:", .sha256(preflight_receipt)))))
  decision <- file.path(root, "pilot-decision.receipt")
  .write_fixture_receipt(decision, c(list(receipt_type = "pilot_decision", status = "PASS"), common,
    list(preflight_receipt_sha256 = .sha256(preflight_receipt), pilot_compute_receipt_sha256 = .sha256(pilot_compute),
         pilot_sha256 = .sha256(pilot), g1_seeds = 100, beta0_shift = 0, projected_3mcse_s100 = 0.01)))
  configs <- setNames(lapply(paste0("G", 1:6), .expected_config, beta0_shift = 0, g1_seeds = 100L), paste0("G", 1:6))
  global_before_builder <- ls(.GlobalEnv, all.names = TRUE)
  builder_configs <- .source_builder_configs(beta0_shift = 0, g1_seeds = 100L)
  global_added_by_builder <- setdiff(ls(.GlobalEnv, all.names = TRUE), global_before_builder)
  if (length(global_added_by_builder)) {
    .stopf("Synthetic self-test source-builder isolation leaked global binding(s): %s",
           paste(global_added_by_builder, collapse = ", "))
  }
  canonical_hashes <- vapply(configs, .canonical_config_sha256, character(1))
  builder_canonical_hashes <- vapply(builder_configs, .canonical_config_sha256, character(1))
  if (!identical(canonical_hashes, builder_canonical_hashes)) {
    .stopf("Synthetic self-test canonical hashes differ for identical grids")
  }
  value_mutation <- configs$G1
  value_mutation$rho[[1L]] <- value_mutation$rho[[1L]] + 0.01
  type_mutation <- configs$G1
  type_mutation$stage <- factor(type_mutation$stage)
  if (identical(.canonical_config_sha256(value_mutation), canonical_hashes[["G1"]]) ||
      identical(.canonical_config_sha256(type_mutation), canonical_hashes[["G1"]])) {
    .stopf("Synthetic self-test canonical hash did not detect a value/type mutation")
  }
  results <- receipts <- character()
  for (block in paste0("G", 1:6)) {
    result <- file.path(root, paste0(tolower(block), ".rds"))
    x <- .synthetic_results(configs[[block]], block)
    parts_dir <- paste0(result, ".parts"); dir.create(parts_dir)
    part <- file.path(parts_dir, "part-00001.rds")
    builder_hash <- .object_sha256(builder_configs[[block]])
    saveRDS(list(instrument_id = instrument_id, config_sha256 = builder_hash,
                 created_utc = "synthetic", results = x), part)
    saveRDS(x, result)
    receipt <- file.path(root, paste0(tolower(block), "-compute.receipt"))
    predecessors <- paste0("preflight:", .sha256(preflight_receipt), ";pilot_decision:", .sha256(decision))
    if (block == "G6") predecessors <- paste0(predecessors, ";g1:", .sha256(receipts[["G1"]]))
    null_rows <- sum(.near(configs[[block]]$kappa, 0))
    fit_errors <- sum(!.blank_error(x$fit_error))
    .write_fixture_receipt(receipt, c(list(receipt_type = paste0(tolower(block), "_compute"), status = "PASS", stage = tolower(block)), common,
      list(cores = 2, host = "synthetic", r_version = R.version.string, started_utc = "synthetic", ended_utc = "synthetic",
           expected_rows = nrow(x), actual_rows = nrow(x), expected_logical_rows = nrow(x), expected_optimizer_calls = nrow(x),
           output_path = normalizePath(result), output_bytes = file.info(result)$size, output_sha256 = .sha256(result),
           resume_parts_dir = normalizePath(parts_dir), resume_part_count = 1,
           resume_part_hashes = paste0(basename(part), ":", .sha256(part)), predecessor_receipt_hashes = predecessors,
           g1_seeds = if (block == "G1") 100 else "", config_sha256 = builder_hash,
           seed_min = min(configs[[block]]$seed), seed_max = max(configs[[block]]$seed), seed_count = length(unique(configs[[block]]$seed)),
           phi_x = paste(sort(unique(configs[[block]]$phi_x)), collapse = ","),
           phi_bias = paste(sort(unique(configs[[block]]$phi_bias)), collapse = ","), beta0_shift = 0,
           arms = paste(.arms, collapse = ","), null_dataset_rows = null_rows,
           unique_key_verdict = "PASS", a6_null_collapsed_rows = null_rows,
           fit_error_rows = fit_errors, unlabelled_nonfinite_rows = 0)))
    results[[block]] <- result; receipts[[block]] <- receipt
  }
  opt <- list(results = results, receipts = receipts, preflight_receipt = preflight_receipt,
              pilot = pilot, pilot_compute_receipt = pilot_compute,
              pilot_decision_receipt = decision, calibration_receipt = NULL,
              out_dir = file.path(root, "audit"))
  out <- .audit_campaign(opt)
  if (!all(file.exists(out$paths))) .stopf("Synthetic self-test did not write every audit artifact")
  audit_csv <- utils::read.csv(out$paths[[1L]], stringsAsFactors = FALSE)
  csv_hashes <- stats::setNames(audit_csv$independent_config_sha256, audit_csv$block)
  if (!identical(csv_hashes[names(canonical_hashes)], canonical_hashes)) {
    .stopf("Synthetic self-test audit CSV did not emit the canonical configuration hashes")
  }
  audit_receipt <- .read_receipt(out$paths[[3L]])
  receipt_specs <- strsplit(audit_receipt$campaign_independent_config_sha256, ";", fixed = TRUE)[[1L]]
  receipt_hashes <- stats::setNames(
    sub("^[^:]+:", "", receipt_specs), sub(":.*$", "", receipt_specs)
  )
  if (!identical(receipt_hashes[names(canonical_hashes)], canonical_hashes)) {
    .stopf("Synthetic self-test audit receipt did not emit the canonical configuration hashes")
  }
  overwrite_refused <- inherits(try(.audit_campaign(opt), silent = TRUE), "try-error")
  if (!overwrite_refused) .stopf("Synthetic self-test did not refuse overwrite")
  missing_opt <- opt; missing_opt$out_dir <- file.path(root, "missing-audit"); missing_opt$receipts[["G6"]] <- file.path(root, "absent-g6.receipt")
  missing_refused <- inherits(try(.audit_campaign(missing_opt), silent = TRUE), "try-error")
  if (!missing_refused) .stopf("Synthetic self-test opened an incomplete six-receipt bundle")
  tampered_receipt <- file.path(root, "g2-tampered-compute.receipt")
  tampered_lines <- readLines(receipts[["G2"]], warn = FALSE)
  tampered_lines[startsWith(tampered_lines, "config_sha256=")] <- paste0(
    "config_sha256=", paste(rep("0", 64L), collapse = "")
  )
  writeLines(tampered_lines, tampered_receipt, useBytes = TRUE)
  tampered_opt <- opt
  tampered_opt$out_dir <- file.path(root, "tampered-audit")
  tampered_opt$receipts[["G2"]] <- tampered_receipt
  tampered_error <- try(.audit_campaign(tampered_opt), silent = TRUE)
  if (!inherits(tampered_error, "try-error") ||
      !grepl("source-builder serialization hash mismatch", as.character(tampered_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not reject a tampered raw configuration hash")
  }
  divergent_configs <- configs
  divergent_configs$G3$rho[[1L]] <- divergent_configs$G3$rho[[1L]] + 0.01
  divergent_error <- try(.verify_receipt_bundle(
    opt, divergent_configs, builder_configs, .authenticate_receipt_sources(opt)
  ), silent = TRUE)
  if (!inherits(divergent_error, "try-error") ||
      !grepl("independent grid differs from the frozen source builder", as.character(divergent_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not reject an independently reconstructed grid mutation")
  }
  unauthenticated_receipt <- file.path(root, "g4-unauthenticated-compute.receipt")
  unauthenticated_lines <- readLines(receipts[["G4"]], warn = FALSE)
  unauthenticated_lines[startsWith(unauthenticated_lines, "instrument_id=")] <- paste0(
    "instrument_id=", paste(rep("0", 40L * length(.instrument_files)), collapse = "")
  )
  writeLines(unauthenticated_lines, unauthenticated_receipt, useBytes = TRUE)
  unauthenticated_opt <- opt
  unauthenticated_opt$out_dir <- file.path(root, "unauthenticated-audit")
  unauthenticated_opt$receipts[["G4"]] <- unauthenticated_receipt
  loader_called <- FALSE
  injected_loader <- function(...) {
    loader_called <<- TRUE
    .stopf("Synthetic injected builder loader was called")
  }
  unauthenticated_error <- try(
    .audit_campaign(unauthenticated_opt, builder_loader = injected_loader), silent = TRUE
  )
  if (!inherits(unauthenticated_error, "try-error") || loader_called ||
      !grepl("instrument ID does not match", as.character(unauthenticated_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not authenticate sources before invoking the builder loader")
  }
  cat("Phase C independent campaign verifier synthetic self-test: PASS\n")
  cat("Fixture:", root, "\n")
  invisible(out)
}

if (sys.nframe() == 0L) {
  opt <- .parse_args(commandArgs(trailingOnly = TRUE))
  if (isTRUE(opt$help)) { .usage(); quit(status = 0L) }
  if (isTRUE(opt$self_test)) { .self_test(); quit(status = 0L) }
  out <- .audit_campaign(opt)
  cat("Phase C independent campaign compute audit: PASS\n")
  cat("Receipt SHA-256:", out$receipt_sha256, "\n")
  cat("Outputs:\n", paste0("  ", out$paths, collapse = "\n"), "\n", sep = "")
}
