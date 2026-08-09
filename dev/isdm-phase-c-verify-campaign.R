#!/usr/bin/env Rscript

## Independent structural verifier for the Phase C G1--G6 campaign.
##
## This file deliberately does not source the official analysis.  It opens no
## campaign RDS until all six result files exist and all six compute receipts
## have cleared their PASS/provenance/hash checks.  The campaign source is
## loaded once into an isolated environment to reproduce the runner's portable
## canonical-object config hash; the expected grid below remains an independent
## reconstruction and must be identical to that source table.  The runner's raw
## saveRDS() hash is retained as provenance but is not compared across R builds.
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

.config_rds_sha256 <- function(x) {
  path <- tempfile("phase-c-config-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 3)
  .sha256(path)
}

.canonical_config_payload <- function(x) {
  token <- function(tag, value = "") {
    value <- enc2utf8(value)
    paste0(tag, nchar(value, type = "bytes"), ":", value)
  }
  encode_names <- function(value, path) {
    nm <- names(value)
    if (is.null(nm)) return(token("names-null:"))
    if (length(nm) != length(value) || anyNA(nm)) {
      .stopf("Canonical configuration has malformed names at %s", path)
    }
    paste0(token("names:", as.character(length(nm))),
           paste0(vapply(nm, function(z) token("name:", z), character(1)),
                  collapse = ""))
  }
  encode_atomic <- function(value, path) {
    attrs <- attributes(value)
    if (length(setdiff(names(attrs), "names"))) {
      .stopf("Canonical configuration has unsupported atomic attributes at %s", path)
    }
    type <- typeof(value)
    if (!type %in% c("logical", "integer", "double", "character", "raw")) {
      .stopf("Canonical configuration has unsupported atomic type %s at %s", type, path)
    }
    element <- switch(type,
      logical = function(z) {
        if (is.na(z)) "NA" else if (z) "TRUE" else "FALSE"
      },
      integer = function(z) if (is.na(z)) "NA" else sprintf("%d", z),
      double = function(z) {
        if (is.na(z) && !is.nan(z)) return("NA")
        if (is.nan(z)) return("NaN")
        if (is.infinite(z)) return(if (z > 0) "+Inf" else "-Inf")
        sprintf("%a", z)
      },
      character = function(z) {
        if (is.na(z)) return("NA")
        if (identical(Encoding(z), "bytes")) {
          .stopf("Canonical configuration has bytes-encoded text at %s", path)
        }
        paste0("UTF8:", token("text:", z))
      },
      raw = function(z) paste0(format(z), collapse = "")
    )
    values <- vapply(seq_along(value), function(i) {
      token("element:", element(value[[i]]))
    }, character(1))
    paste0(token("atomic-type:", type), token("length:", as.character(length(value))),
           encode_names(value, path), paste0(values, collapse = ""))
  }
  encode <- function(value, path = "$") {
    if (is.null(value)) return(token("null:"))
    if (is.data.frame(value)) {
      attrs <- attributes(value)
      if (!identical(class(value), "data.frame") ||
          length(setdiff(names(attrs), c("names", "row.names", "class")))) {
        .stopf("Canonical configuration has unsupported data-frame class/attributes at %s", path)
      }
      nm <- names(value)
      if (is.null(nm) || length(nm) != ncol(value) || anyNA(nm)) {
        .stopf("Canonical configuration has malformed column names at %s", path)
      }
      rows <- row.names(value)
      header <- paste0(token("data-frame:"),
                       token("nrow:", as.character(nrow(value))),
                       token("ncol:", as.character(ncol(value))),
                       token("row-names-count:", as.character(length(rows))),
                       paste0(vapply(rows, function(z) token("row-name:", z), character(1)),
                              collapse = ""))
      columns <- vapply(seq_along(value), function(i) {
        paste0(token("column-name:", nm[[i]]),
               token("column-value:", encode(value[[i]], paste0(path, "[[", i, "]]"))))
      }, character(1))
      return(paste0(header, paste0(columns, collapse = "")))
    }
    if (is.list(value)) {
      attrs <- attributes(value)
      if (length(setdiff(names(attrs), "names"))) {
        .stopf("Canonical configuration has unsupported list attributes at %s", path)
      }
      items <- vapply(seq_along(value), function(i) {
        token("item:", encode(value[[i]], paste0(path, "[[", i, "]]")))
      }, character(1))
      return(paste0(token("list:"), token("length:", as.character(length(value))),
                    encode_names(value, path), paste0(items, collapse = "")))
    }
    if (is.atomic(value)) return(encode_atomic(value, path))
    .stopf("Canonical configuration has unsupported object type %s at %s",
           typeof(value), path)
  }
  enc2utf8(paste0("phase-c-canonical-object-v1:", encode(x)))
}

.canonical_config_sha256 <- function(x) {
  payload <- charToRaw(.canonical_config_payload(x))
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

.receipt_true <- function(value, label) {
  if (length(value) != 1L || !tolower(value) %in% c("true", "1")) .stopf("%s must be true", label)
  invisible(TRUE)
}

.require_sha256 <- function(value, label) {
  if (length(value) != 1L || is.na(value) ||
      !grepl("^[0-9a-f]{64}$", value)) {
    .stopf("%s is not a lowercase SHA-256 value", label)
  }
  invisible(TRUE)
}

.manifest <- function(value, label, allow_empty = FALSE) {
  if (length(value) != 1L || is.na(value)) .stopf("%s is malformed", label)
  if (!nzchar(value)) {
    if (allow_empty) return(character())
    .stopf("%s is empty", label)
  }
  specs <- strsplit(value, ";", fixed = TRUE)[[1L]]
  parsed <- lapply(specs, function(spec) {
    at <- regexpr(":", spec, fixed = TRUE)
    if (at < 2L || at == nchar(spec)) .stopf("Malformed entry in %s", label)
    c(name = substring(spec, 1L, at - 1L), value = substring(spec, at + 1L))
  })
  keys <- vapply(parsed, `[[`, character(1), "name")
  values <- vapply(parsed, `[[`, character(1), "value")
  if (anyDuplicated(keys)) .stopf("%s has duplicate names", label)
  stats::setNames(values, keys)
}

.exact_manifest <- function(value, expected, label, allow_empty = FALSE) {
  actual <- .manifest(value, label, allow_empty = allow_empty)
  if (!identical(actual, expected)) .stopf("%s mismatch", label)
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
  "dev/isdm-phase-c-amendment-2026-08-08.md",
  "dev/isdm-phase-c-amendment-2-2026-08-09.md",
  "dev/isdm-phase-c-amendment-3-2026-08-09.md",
  "dev/isdm-phase-c-amendment-4-2026-08-09.md"
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

.verify_instrument_manifest <- function(receipt, label) {
  .need_fields(receipt, c("instrument_file_paths", "instrument_file_sha256"), label)
  paths <- strsplit(receipt$instrument_file_paths, ";", fixed = TRUE)[[1L]]
  if (length(paths) != length(.instrument_files) ||
      any(!startsWith(paths, "/")) || anyDuplicated(paths) ||
      !identical(basename(paths), basename(.instrument_files))) {
    .stopf("%s instrument-file path manifest mismatch", label)
  }
  expected_hashes <- stats::setNames(
    vapply(.instrument_files, .sha256, character(1)), basename(.instrument_files)
  )
  .exact_manifest(receipt$instrument_file_sha256, expected_hashes,
                  paste(label, "instrument-file SHA-256 manifest"))
  invisible(TRUE)
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
  attr(out, "pilot") <- get("build_config_pilot", envir = env)(
    seeds = 1:10, beta0_shift = beta0_shift
  )
  attr(out, "preflight") <- get("build_preflight_contract_c", envir = env)()
  out
}

.expected_pilot_config <- function(beta0_shift) {
  out <- .expected_config("G1", beta0_shift = beta0_shift, g1_seeds = 10L)
  out$stage <- "pilot_v2"
  out
}

.expected_preflight_contract <- function() {
  geometry_cases <- expand.grid(
    phi_bias = c(0, 0.15, 0.4),
    rho = c(-1, -0.8, 0, 0.6, 0.8, 1),
    omega = c(0, 0.5, 1),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  geometry_cases$seed <- 7300L + seq_len(nrow(geometry_cases))
  list(
    schema_version = "phase_c_preflight_contract_v1",
    geometry_cases = geometry_cases,
    geometry_n = 100L, geometry_T_sp = 12L, geometry_phi_x = .ref$phi_x,
    geometry_kappa = 1, geometry_k = .ref$k, geometry_tolerance = 1e-9,
    crn_probe = list(
      seed = 991L, n = 100L, T_sp = 12L,
      base = c(phi_bias = 0.15, kappa = 1, rho = 0.6, omega = 0.5),
      treatment = c(phi_bias = 0.15, kappa = 2, rho = -0.8, omega = 0),
      phi_bias_pair = c(0, 0.4)
    ),
    rank_probe = list(accepted_n = 16L, accepted_H_columns = 2L,
                      rejected_n = 5L, rejected_H_columns = 3L),
    ref_fit = c(as.list(.ref), list(seed = 1L, stage = "preflight", block = "preflight")),
    phi_stream_probe = list(seed = 7L, n = 100L, T_sp = 8L,
                            phi_x = 0.15, phi_bias = c(0, 0.4),
                            kappa = 1, rho = 0.6, omega = 0.5, k = 3L),
    null_collapse_probe = list(seed = 11L, fit_seed = 500011L,
                               n = 100L, T_sp = 8L,
                               phi_x = 0.15, phi_bias = 0.15,
                               kappa = 0, rho = 0.6, omega = 0.5, k = 3L),
    null_recovery_seeds = 1:10,
    smoke = list(seed = 42L, n = 100L, T_sp = 6L,
                 kappa = c(0, 2), rho = 0, omega = 1,
                 phi_x = .ref$phi_x, phi_bias = .ref$phi_bias, k = .ref$k),
    seed_inventory = sort(unique(c(1:10, 11L, 42L, 991L, 7301:7354, 500011L))),
    seed_inventory_roles = paste(
      "result=1:10,42;phi_stream=7;null_collapse_data=11;",
      "crn=991;geometry=7301:7354;null_collapse_fit=500011", sep = ""
    ),
    expected_result_rows = 28L,
    expected_model_fit_attempts = 30L
  )
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

.verify_common_receipt <- function(x, type, label, current_id,
                                   source_id_resolver = .instrument_id_at,
                                   compute = FALSE) {
  .need_fields(x, c("receipt_type", "status", "source_sha", "source_branch",
                    "source_dirty", "instrument_id"), label)
  if (!identical(x$receipt_type, type) || !identical(x$status, "PASS")) .stopf("%s is not a PASS %s", label, type)
  if (!identical(x$source_branch, .branch)) .stopf("%s does not identify Lane C", label)
  .receipt_false(x$source_dirty, paste0(label, " source_dirty"))
  source_id <- source_id_resolver(x$source_sha)
  if (!identical(x$instrument_id, source_id) || !identical(x$instrument_id, current_id)) {
    .stopf("%s instrument ID does not match its source commit and current frozen files", label)
  }
  if (compute) {
    .need_fields(x, "schema_version", label)
    if (!identical(x$schema_version, "phase_c_compute_v2")) {
      .stopf("%s schema_version is not phase_c_compute_v2", label)
    }
    .verify_instrument_manifest(x, label)
  }
  invisible(TRUE)
}

.verify_compute_envelope <- function(x, stage, block, label,
                                     expected_logical_rows,
                                     expected_fit_attempts,
                                     expected_predecessor_paths,
                                     expected_predecessor_hashes,
                                     expected_config_sha256 = "") {
  fields <- c(
    "schema_version", "stage", "block", "command", "host", "r_version",
    "session_platform", "package_versions", "optimizer_control_mode",
    "optimizer_control", "cores", "backend", "started_utc", "ended_utc",
    "expected_rows", "actual_rows", "expected_logical_rows",
    "actual_logical_rows", "expected_optimizer_calls",
    "actual_optimizer_calls", "expected_model_fit_attempts",
    "actual_model_fit_attempts", "input_config_sha256",
    "config_rds_sha256", "input_config_rds_sha256",
    "input_predecessor_paths", "input_predecessor_sha256",
    "predecessor_receipt_paths", "predecessor_receipt_hashes"
  )
  .need_fields(x, fields, label)
  if (!identical(x$stage, stage) || !identical(x$block, block)) {
    .stopf("%s stage/block mismatch; expected %s/%s", label, stage, block)
  }
  nonblank <- c("command", "host", "r_version", "session_platform",
                "package_versions", "optimizer_control", "started_utc", "ended_utc")
  if (any(!nzchar(trimws(vapply(x[nonblank], as.character, character(1)))))) {
    .stopf("%s has blank command/session/optimizer fields", label)
  }
  if (!x$optimizer_control_mode %in% c("default", "explicit")) {
    .stopf("%s optimizer_control_mode is invalid", label)
  }
  if (identical(x$optimizer_control_mode, "default") &&
      !identical(x$optimizer_control, "gllvmTMBcontrol() package defaults")) {
    .stopf("%s default optimizer control is not explicit", label)
  }
  if (!x$backend %in% c("serial", "mclapply")) .stopf("%s backend is invalid", label)
  if (.receipt_int(x, "cores", label) < 1L || .receipt_int(x, "cores", label) > 150L) {
    .stopf("%s violates the Totoro core cap", label)
  }
  logical_fields <- c("expected_rows", "actual_rows", "expected_logical_rows",
                      "actual_logical_rows")
  for (field in logical_fields) {
    if (.receipt_int(x, field, label) != expected_logical_rows) {
      .stopf("%s %s mismatch", label, field)
    }
  }
  fit_fields <- c("expected_optimizer_calls", "expected_model_fit_attempts",
                  "actual_model_fit_attempts")
  for (field in fit_fields) {
    if (.receipt_int(x, field, label) != expected_fit_attempts) {
      .stopf("%s %s mismatch", label, field)
    }
  }
  if (!identical(
    x$actual_optimizer_calls,
    "NOT_INSTRUMENTED_MODEL_FRONTEND_ATTEMPTS_RECORDED_SEPARATELY"
  )) {
    .stopf("%s actual_optimizer_calls must carry the frozen non-instrumented sentinel", label)
  }
  if (!identical(x$input_config_sha256, expected_config_sha256)) {
    .stopf("%s input configuration hash mismatch", label)
  }
  .require_sha256(x$config_rds_sha256,
                  paste(label, "raw configuration RDS hash"))
  .require_sha256(x$input_config_rds_sha256,
                  paste(label, "input raw configuration RDS hash"))
  if (!identical(x$input_config_rds_sha256, x$config_rds_sha256)) {
    .stopf("%s duplicated raw configuration RDS hashes disagree", label)
  }
  if (!identical(x$input_predecessor_paths, x$predecessor_receipt_paths) ||
      !identical(x$input_predecessor_sha256, x$predecessor_receipt_hashes)) {
    .stopf("%s duplicated predecessor fields disagree", label)
  }
  .exact_manifest(x$predecessor_receipt_paths, expected_predecessor_paths,
                  paste(label, "predecessor path manifest"), allow_empty = TRUE)
  .exact_manifest(x$predecessor_receipt_hashes, expected_predecessor_hashes,
                  paste(label, "predecessor hash manifest"), allow_empty = TRUE)
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
  .need_fields(receipt, c("resume_parts_dir", "resume_part_count",
                          "resume_part_paths", "resume_part_hashes"), label)
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
  receipt_paths <- if (nzchar(receipt$resume_part_paths)) {
    strsplit(receipt$resume_part_paths, ";", fixed = TRUE)[[1L]]
  } else character()
  if (!identical(receipt_paths, normalizePath(paths, mustWork = TRUE))) {
    .stopf("%s exact resume-part path manifest mismatch", label)
  }
  actual_hashes <- vapply(paths, .sha256, character(1))
  if (!identical(unname(actual_hashes), unname(hashes))) .stopf("%s part hash mismatch", label)
  stats::setNames(paths, names_seen)
}

.verify_seed_manifest <- function(receipt, seeds, label) {
  .need_fields(receipt, c("seed_min", "seed_max", "seed_count", "seed_list"), label)
  seeds <- sort(unique(as.integer(seeds)))
  if (.receipt_int(receipt, "seed_min", label) != min(seeds) ||
      .receipt_int(receipt, "seed_max", label) != max(seeds) ||
      .receipt_int(receipt, "seed_count", label) != length(seeds) ||
      !identical(receipt$seed_list, paste(seeds, collapse = ","))) {
    .stopf("%s full seed manifest mismatch", label)
  }
  invisible(TRUE)
}

.verify_grid_accounting <- function(receipt, config, label,
                                    external_null = FALSE) {
  fields <- c(
    "unique_key_verdict", "unique_logical_rows", "null_dataset_rows",
    "null_logical_rows", "null_key_unique_rows",
    "null_key_duplicate_rows", "paired_biased_logical_rows_in_output",
    "paired_biased_logical_rows", "unpaired_biased_logical_rows",
    "pair_source", "a6_logical_rows", "a6_null_collapsed_rows",
    "fit_error_rows", "nonfinite_total_sigma_rows",
    "nonfinite_rank_d_rows", "unlabelled_nonfinite_rows"
  )
  .need_fields(receipt, fields, label)
  rows <- nrow(config) * length(.arms)
  null_datasets <- sum(config$kappa == 0)
  null_rows <- null_datasets * length(.arms)
  biased_rows <- rows - null_rows
  if (!identical(receipt$unique_key_verdict, "PASS") ||
      .receipt_int(receipt, "unique_logical_rows", label) != rows ||
      .receipt_int(receipt, "null_dataset_rows", label) != null_datasets ||
      .receipt_int(receipt, "null_logical_rows", label) != null_rows ||
      .receipt_int(receipt, "null_key_unique_rows", label) != null_rows ||
      .receipt_int(receipt, "null_key_duplicate_rows", label) != 0L ||
      .receipt_int(receipt, "paired_biased_logical_rows_in_output", label) !=
        (if (external_null) 0L else biased_rows) ||
      .receipt_int(receipt, "paired_biased_logical_rows", label) != biased_rows ||
      .receipt_int(receipt, "unpaired_biased_logical_rows", label) != 0L ||
      !identical(receipt$pair_source,
                 if (external_null) "G1 predecessor null" else "same output") ||
      .receipt_int(receipt, "a6_logical_rows", label) != nrow(config) ||
      .receipt_int(receipt, "a6_null_collapsed_rows", label) != null_datasets ||
      .receipt_int(receipt, "nonfinite_total_sigma_rows", label) != 0L ||
      .receipt_int(receipt, "nonfinite_rank_d_rows", label) != 0L ||
      .receipt_int(receipt, "unlabelled_nonfinite_rows", label) != 0L) {
    .stopf("%s logical/null/model-fit accounting mismatch", label)
  }
  invisible(TRUE)
}

.authenticate_receipt_sources <- function(opt,
                                          source_id_resolver = .instrument_id_at) {
  current_id <- .current_instrument_id()
  preflight <- .read_receipt(opt$preflight_receipt)
  pilot_compute <- .read_receipt(opt$pilot_compute_receipt)
  decision <- .read_receipt(opt$pilot_decision_receipt)
  .verify_common_receipt(preflight, "preflight_compute", "preflight receipt", current_id,
                         source_id_resolver = source_id_resolver, compute = TRUE)
  .verify_common_receipt(pilot_compute, "pilot_compute", "pilot compute receipt", current_id,
                         source_id_resolver = source_id_resolver, compute = TRUE)
  .verify_common_receipt(decision, "pilot_decision", "pilot decision receipt", current_id,
                         source_id_resolver = source_id_resolver)
  if (!identical(preflight$stage, "preflight") ||
      !identical(preflight$block, "preflight")) {
    .stopf("preflight receipt stage/block mismatch; expected preflight/preflight")
  }
  if (!identical(pilot_compute$stage, "pilot_v2") ||
      !identical(pilot_compute$block, "G1")) {
    .stopf("pilot compute receipt stage/block mismatch; expected pilot_v2/G1")
  }
  early_shas <- unique(c(preflight$source_sha, pilot_compute$source_sha, decision$source_sha))
  if (length(early_shas) != 1L) .stopf("Preflight, pilot compute, and pilot decision source SHAs differ")
  blocks <- paste0("G", 1:6)
  campaign <- stats::setNames(lapply(blocks, function(block) {
    label <- paste(block, "compute receipt")
    receipt <- .read_receipt(opt$receipts[[block]])
    .verify_common_receipt(receipt, paste0(tolower(block), "_compute"), label, current_id,
                           source_id_resolver = source_id_resolver, compute = TRUE)
    if (!identical(receipt$stage, "campaign") || !identical(receipt$block, block)) {
      .stopf("%s stage/block mismatch; expected campaign/%s", label, block)
    }
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
  preflight_contract <- .expected_preflight_contract()
  builder_preflight <- attr(builder_configs, "preflight", exact = TRUE)
  if (!is.list(builder_preflight) || !identical(preflight_contract, builder_preflight)) {
    .stopf("Preflight independent contract differs from the frozen source builder")
  }
  preflight_config_hash <- .canonical_config_sha256(builder_preflight)
  .verify_compute_envelope(
    preflight, "preflight", "preflight", "preflight receipt",
    expected_logical_rows = 28L, expected_fit_attempts = 30L,
    expected_predecessor_paths = character(),
    expected_predecessor_hashes = character(),
    expected_config_sha256 = preflight_config_hash
  )
  .need_fields(preflight, c("config_sha256", "config_rds_sha256", "unique_key_verdict",
                            "unique_logical_rows"), "preflight receipt")
  if (!identical(preflight$config_sha256, preflight_config_hash) ||
      !identical(preflight$unique_key_verdict, "PASS") ||
      .receipt_int(preflight, "unique_logical_rows", "preflight receipt") != 28L) {
    .stopf("preflight receipt configuration/logical manifest mismatch")
  }
  .verify_seed_manifest(preflight, preflight_contract$seed_inventory,
                        "preflight receipt")
  .need_fields(preflight, "seed_inventory_roles", "preflight receipt")
  if (!identical(preflight$seed_inventory_roles,
                 preflight_contract$seed_inventory_roles)) {
    .stopf("preflight receipt seed inventory roles mismatch")
  }
  if (.receipt_int(preflight, "resume_part_count", "preflight receipt") != 0L ||
      nzchar(preflight$resume_parts_dir) || nzchar(preflight$resume_part_paths) ||
      nzchar(preflight$resume_part_hashes)) {
    .stopf("preflight receipt unexpectedly names resume parts")
  }
  .verify_file_binding(preflight, preflight$output_path, "preflight receipt")

  .need_fields(decision, c("preflight_receipt_sha256", "pilot_compute_receipt_sha256",
                           "pilot_path", "pilot_sha256", "g1_seeds", "beta0_shift",
                           "projected_3mcse_s100"), "pilot decision receipt")
  if (!identical(decision$preflight_receipt_sha256, preflight_hash) ||
      !identical(decision$pilot_compute_receipt_sha256, pilot_compute_hash)) {
    .stopf("Pilot decision predecessor hashes do not match")
  }
  if (!identical(normalizePath(decision$pilot_path, mustWork = TRUE),
                 normalizePath(opt$pilot, mustWork = TRUE))) {
    .stopf("Pilot decision exact pilot path mismatch")
  }
  if (!identical(decision$pilot_sha256, .sha256(opt$pilot))) .stopf("Pilot decision result hash mismatch")
  g1_seeds <- .receipt_int(decision, "g1_seeds", "pilot decision receipt")
  if (g1_seeds != 100L || .receipt_num(decision, "projected_3mcse_s100", "pilot decision receipt") > 0.05) {
    .stopf("Frozen S100 decision is absent or inconsistent with the precision rule")
  }
  beta0 <- .receipt_num(decision, "beta0_shift", "pilot decision receipt")
  if (!.near(beta0, 0)) .stopf("This campaign was frozen at beta0_shift = 0; got %s", beta0)
  if (!is.null(opt$calibration_receipt)) .stopf("A calibration receipt is incompatible with the frozen zero shift")

  pilot_config <- .expected_pilot_config(beta0)
  builder_pilot <- attr(builder_configs, "pilot", exact = TRUE)
  if (!is.data.frame(builder_pilot) || !identical(pilot_config, builder_pilot)) {
    .stopf("Pilot independent grid differs from the frozen source builder")
  }
  pilot_config_hash <- .canonical_config_sha256(builder_pilot)
  pilot_paths <- c(preflight = normalizePath(opt$preflight_receipt, mustWork = TRUE))
  pilot_hashes <- c(preflight = preflight_hash)
  .verify_compute_envelope(
    pilot_compute, "pilot_v2", "G1", "pilot compute receipt",
    expected_logical_rows = nrow(pilot_config) * length(.arms),
    expected_fit_attempts = nrow(pilot_config) * length(.arms),
    expected_predecessor_paths = pilot_paths,
    expected_predecessor_hashes = pilot_hashes,
    expected_config_sha256 = pilot_config_hash
  )
  .need_fields(pilot_compute, c("config_sha256", "config_rds_sha256", "phi_x", "phi_bias",
                                "beta0_shift", "arms"), "pilot compute receipt")
  if (!identical(pilot_compute$config_sha256, pilot_config_hash) ||
      !identical(pilot_compute$arms, paste(.arms, collapse = ",")) ||
      !.near(.receipt_num(pilot_compute, "phi_x", "pilot compute receipt"), 0.15) ||
      !identical(pilot_compute$phi_bias,
                 paste(sort(unique(pilot_config$phi_bias)), collapse = ",")) ||
      !.near(.receipt_num(pilot_compute, "beta0_shift", "pilot compute receipt"), beta0)) {
    .stopf("Pilot compute receipt configuration manifest mismatch")
  }
  .verify_seed_manifest(pilot_compute, pilot_config$seed, "pilot compute receipt")
  .verify_grid_accounting(pilot_compute, pilot_config, "pilot compute receipt")
  .verify_file_binding(pilot_compute, opt$pilot, "pilot compute receipt")
  pilot_part_paths <- .parse_part_manifest(pilot_compute, opt$pilot,
                                           "pilot compute receipt")

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
    expected_rows <- nrow(configs[[block]]) * 6L
    predecessors_paths <- c(
      preflight = normalizePath(opt$preflight_receipt, mustWork = TRUE),
      pilot_decision = normalizePath(opt$pilot_decision_receipt, mustWork = TRUE)
    )
    predecessors_hashes <- c(preflight = preflight_hash,
                             pilot_decision = decision_hash)
    if (block == "G6") {
      predecessors_paths <- c(predecessors_paths,
                              g1 = normalizePath(opt$receipts[["G1"]], mustWork = TRUE))
      predecessors_hashes <- c(predecessors_hashes,
                               g1 = .sha256(opt$receipts[["G1"]]))
    }
    builder_hash <- .canonical_config_sha256(builder_configs[[block]])
    .verify_compute_envelope(
      receipt, "campaign", block, label,
      expected_logical_rows = expected_rows,
      expected_fit_attempts = expected_rows,
      expected_predecessor_paths = predecessors_paths,
      expected_predecessor_hashes = predecessors_hashes,
      expected_config_sha256 = builder_hash
    )
    .need_fields(receipt, c("config_sha256", "config_rds_sha256", "phi_x", "phi_bias",
                            "beta0_shift", "arms", "g1_seeds"), label)
    if (!identical(receipt$config_sha256, builder_hash)) {
      .stopf("%s source-builder canonical hash mismatch", label)
    }
    if (!identical(receipt$arms, paste(.arms, collapse = ","))) .stopf("%s arm manifest mismatch", label)
    if (!.near(.receipt_num(receipt, "phi_x", label), 0.15)) .stopf("%s phi_x is not frozen at 0.15", label)
    expected_phi_bias <- paste(sort(unique(configs[[block]]$phi_bias)), collapse = ",")
    if (!identical(receipt$phi_bias, expected_phi_bias)) .stopf("%s phi_bias manifest mismatch", label)
    if (!.near(.receipt_num(receipt, "beta0_shift", label), beta0)) .stopf("%s beta0 shift mismatch", label)
    .verify_seed_manifest(receipt, configs[[block]]$seed, label)
    .verify_grid_accounting(receipt, configs[[block]], label,
                            external_null = identical(block, "G6"))
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
      config_rds_sha256 = receipt$config_rds_sha256,
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
  list(preflight = preflight, pilot_compute = pilot_compute, decision = decision,
       campaign = campaign, pilot_part_paths = pilot_part_paths,
       part_paths = part_paths, block_audit = do.call(rbind, rows),
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

.validate_bias_geometry <- function(x, label, tolerance = 1e-9) {
  fields <- c(
    "bias_sharing", "theoretical_bias_rho", "theoretical_bias_sharing",
    "theoretical_bias_variance", "realised_bias_rho_mean",
    "realised_bias_rho_max_abs_error", "realised_bias_sharing_mean",
    "realised_bias_sharing_max_abs_error", "realised_bias_variance_mean",
    "realised_bias_variance_max_abs_error"
  )
  for (field in fields) {
    if (!is.numeric(x[[field]])) .stopf("%s has non-numeric geometry column %s", label, field)
  }
  target_rho <- x$rho
  target_sharing <- x$rho^2 + (1 - x$rho^2) * x$omega
  target_variance <- x$kappa^2
  exact <- function(actual, expected) {
    length(actual) == length(expected) && !anyNA(actual) &&
      all(is.finite(actual)) && all(actual == expected)
  }
  if (!exact(x$theoretical_bias_rho, target_rho) ||
      !exact(x$theoretical_bias_sharing, target_sharing) ||
      !exact(x$bias_sharing, target_sharing) ||
      !exact(x$theoretical_bias_variance, target_variance)) {
    .stopf("%s theoretical bias geometry does not exactly match its configuration", label)
  }

  positive <- x$kappa > 0
  positive_means <- c(
    rho = max(abs(x$realised_bias_rho_mean[positive] - target_rho[positive])),
    sharing = max(abs(x$realised_bias_sharing_mean[positive] - target_sharing[positive])),
    variance = max(abs(x$realised_bias_variance_mean[positive] - target_variance[positive]))
  )
  positive_errors <- c(
    x$realised_bias_rho_max_abs_error[positive],
    x$realised_bias_sharing_max_abs_error[positive],
    x$realised_bias_variance_max_abs_error[positive]
  )
  if (any(positive) &&
      (any(!is.finite(positive_means)) || any(positive_means > tolerance) ||
       any(!is.finite(positive_errors)) || any(positive_errors < 0) ||
       any(positive_errors > tolerance))) {
    .stopf("%s realised positive-kappa geometry exceeds %.1e", label, tolerance)
  }

  null <- !positive
  if (any(null) &&
      (any(!is.na(x$realised_bias_rho_mean[null])) ||
       any(!is.na(x$realised_bias_rho_max_abs_error[null])) ||
       any(!is.na(x$realised_bias_sharing_mean[null])) ||
       any(!is.na(x$realised_bias_sharing_max_abs_error[null])) ||
       any(is.na(x$realised_bias_variance_mean[null])) ||
       any(is.na(x$realised_bias_variance_max_abs_error[null])) ||
       any(x$realised_bias_variance_mean[null] != 0) ||
       any(x$realised_bias_variance_max_abs_error[null] != 0))) {
    .stopf("%s null geometry violates the undefined-correlation/zero-variance contract", label)
  }
  invisible(TRUE)
}

.validate_block_results <- function(x, block, expected, receipt, parts, instrument_id) {
  label <- paste(block, "result")
  if (!is.data.frame(x)) .stopf("%s is not a data.frame", label)
  required <- c(.full_key, "elapsed_sec", "realised_prevalence", "bias_sharing",
                "theoretical_bias_rho", "theoretical_bias_sharing",
                "theoretical_bias_variance", "realised_bias_rho_mean",
                "realised_bias_rho_max_abs_error", "realised_bias_sharing_mean",
                "realised_bias_sharing_max_abs_error", "realised_bias_variance_mean",
                "realised_bias_variance_max_abs_error", "fit_attempted",
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
  x$fit_attempted <- .coerce_flag(x$fit_attempted, paste(label, "fit_attempted"))
  if (anyNA(x$fit_attempted) || any(!x$fit_attempted)) {
    .stopf("%s contains a DGP/pre-fit failure; only attempted model-fit errors may be retained", label)
  }
  .validate_bias_geometry(x, label)
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
  fit_errors <- sum(!is.na(x$fit_error))
  if (fit_errors != .receipt_int(receipt, "fit_error_rows", paste(block, "receipt"))) .stopf("%s fit-error count differs from receipt", label)
  a6_null <- .near(x$kappa, 0) & x$arm == "A6"
  if (any(!x$oracle_collapsed[a6_null]) || any(x$oracle_collapsed[completed & !a6_null])) .stopf("%s A6 null-collapse labels are wrong", label)

  part_results <- vector("list", length(parts))
  for (i in seq_along(parts)) {
    part <- readRDS(parts[[i]])
    if (!is.list(part) || !is.data.frame(part$results) ||
        !identical(part$instrument_id, instrument_id) ||
        !identical(part$config_sha256, receipt$config_sha256) ||
        !identical(part$config_rds_sha256, receipt$config_rds_sha256)) {
      .stopf("%s has malformed/incompatible part %s", label, basename(parts[[i]]))
    }
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
    "The runner's portable canonical-object configuration hash is checked against the immutable source builder and an independent reconstruction. The raw saveRDS configuration hash is retained separately as same-run provenance and is not reconstructed across R versions or hosts.",
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
    campaign_config_rds_sha256 = paste(
      sprintf("%s:%s", block_audit$block, block_audit$config_rds_sha256),
      collapse = ";"
    ),
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

.audit_campaign <- function(opt, builder_loader = .source_builder_configs,
                            source_id_resolver = .instrument_id_at) {
  out_dir <- .absolute_path(opt$out_dir)
  targets <- file.path(out_dir, c("phase-c-compute-audit-blocks.csv", "phase-c-compute-audit.md", "phase-c-compute-audit.receipt"))
  if (any(file.exists(targets))) .stopf("Refusing to overwrite existing audit output(s): %s", paste(basename(targets[file.exists(targets)]), collapse = ", "))
  started <- Sys.time()
  .assert_all_inputs_exist(opt)
  ## Authenticate every source commit and current instrument file before the
  ## source builder is evaluated. All remaining provenance/config/file/part
  ## checks are then cleared before the first campaign readRDS() call.
  authentication <- .authenticate_receipt_sources(
    opt, source_id_resolver = source_id_resolver
  )
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
  x$bias_sharing <- x$rho^2 + (1 - x$rho^2) * x$omega
  x$theoretical_bias_rho <- x$rho
  x$theoretical_bias_sharing <- x$bias_sharing
  x$theoretical_bias_variance <- x$kappa^2
  null <- .near(x$kappa, 0)
  x$realised_bias_rho_mean <- ifelse(null, NA_real_, x$rho)
  x$realised_bias_rho_max_abs_error <- ifelse(null, NA_real_, 5e-12)
  x$realised_bias_sharing_mean <- ifelse(null, NA_real_, x$bias_sharing)
  x$realised_bias_sharing_max_abs_error <- ifelse(null, NA_real_, 6e-12)
  x$realised_bias_variance_mean <- ifelse(null, 0, x$kappa^2)
  x$realised_bias_variance_max_abs_error <- ifelse(null, 0, 4e-12)
  x$fit_attempted <- TRUE
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

.fixture_instrument_fields <- function(source_sha, instrument_id) {
  list(
    source_sha = source_sha, source_branch = .branch, source_dirty = FALSE,
    instrument_id = instrument_id,
    instrument_file_paths = paste(normalizePath(.instrument_files), collapse = ";"),
    instrument_file_sha256 = paste(sprintf(
      "%s:%s", basename(.instrument_files),
      vapply(.instrument_files, .sha256, character(1))
    ), collapse = ";")
  )
}

.fixture_compute_fields <- function(type, stage, block, output, config, results,
                                    part_paths = character(), predecessor_paths = character(),
                                    predecessor_hashes = character(),
                                    expected_fit_attempts = nrow(results),
                                    g1_seeds = "") {
  config_hash <- if (is.null(config)) "" else .canonical_config_sha256(config)
  config_rds_hash <- if (is.null(config)) "" else .config_rds_sha256(config)
  part_hashes <- if (length(part_paths)) paste(sprintf(
    "%s:%s", basename(part_paths), vapply(part_paths, .sha256, character(1))
  ), collapse = ";") else ""
  fields <- list(
    receipt_type = type, status = "PASS", schema_version = "phase_c_compute_v2",
    stage = stage, block = block,
    command = "Rscript --vanilla synthetic", host = "synthetic",
    r_version = R.version.string, session_platform = R.version$platform,
    package_versions = "gllvmTMB=synthetic", optimizer_control_mode = "default",
    optimizer_control = "gllvmTMBcontrol() package defaults", cores = 2,
    backend = "mclapply", started_utc = "synthetic", ended_utc = "synthetic",
    expected_rows = nrow(results), actual_rows = nrow(results),
    expected_logical_rows = nrow(results), actual_logical_rows = nrow(results),
    expected_optimizer_calls = expected_fit_attempts,
    actual_optimizer_calls =
      "NOT_INSTRUMENTED_MODEL_FRONTEND_ATTEMPTS_RECORDED_SEPARATELY",
    expected_model_fit_attempts = expected_fit_attempts,
    actual_model_fit_attempts = expected_fit_attempts,
    input_config_sha256 = config_hash,
    input_config_rds_sha256 = config_rds_hash,
    config_rds_sha256 = config_rds_hash,
    input_predecessor_paths = paste(sprintf("%s:%s", names(predecessor_paths),
                                            predecessor_paths), collapse = ";"),
    input_predecessor_sha256 = paste(sprintf("%s:%s", names(predecessor_hashes),
                                             predecessor_hashes), collapse = ";"),
    output_path = normalizePath(output), output_bytes = file.info(output)$size,
    output_sha256 = .sha256(output),
    resume_parts_dir = if (length(part_paths)) normalizePath(dirname(part_paths[[1L]])) else "",
    resume_part_count = length(part_paths),
    resume_part_paths = if (length(part_paths)) paste(normalizePath(part_paths), collapse = ";") else "",
    resume_part_hashes = part_hashes,
    predecessor_receipt_paths = paste(sprintf("%s:%s", names(predecessor_paths),
                                              predecessor_paths), collapse = ";"),
    predecessor_receipt_hashes = paste(sprintf("%s:%s", names(predecessor_hashes),
                                               predecessor_hashes), collapse = ";"),
    g1_seeds = g1_seeds
  )
  if (!is.null(config)) {
    null_datasets <- sum(config$kappa == 0)
    null_rows <- null_datasets * length(.arms)
    biased_rows <- nrow(results) - null_rows
    external_null <- identical(block, "G6") && identical(stage, "campaign")
    fields <- c(fields, list(
      config_sha256 = config_hash,
      seed_min = min(config$seed), seed_max = max(config$seed),
      seed_count = length(unique(config$seed)),
      seed_list = paste(sort(unique(config$seed)), collapse = ","),
      phi_x = paste(sort(unique(config$phi_x)), collapse = ","),
      phi_bias = paste(sort(unique(config$phi_bias)), collapse = ","),
      beta0_shift = paste(unique(config$beta0_shift), collapse = ","),
      arms = paste(.arms, collapse = ","), null_dataset_rows = null_datasets,
      unique_key_verdict = "PASS", unique_logical_rows = nrow(results),
      null_logical_rows = null_rows, null_key_unique_rows = null_rows,
      null_key_duplicate_rows = 0,
      paired_biased_logical_rows_in_output = if (external_null) 0 else biased_rows,
      paired_biased_logical_rows = biased_rows, unpaired_biased_logical_rows = 0,
      pair_source = if (external_null) "G1 predecessor null" else "same output",
      a6_logical_rows = nrow(config), a6_null_collapsed_rows = null_datasets,
      fit_error_rows = sum(!is.na(results$fit_error)),
      nonfinite_total_sigma_rows = 0, nonfinite_rank_d_rows = 0,
      unlabelled_nonfinite_rows = 0
    ))
  }
  fields
}

.self_test <- function() {
  root <- tempfile("phase-c-audit-self-test-", tmpdir = "/private/tmp")
  dir.create(root, recursive = TRUE)
  source_sha <- .git_value(c("rev-parse", "HEAD"), "self-test source SHA")
  instrument_id <- .current_instrument_id()
  source_id_resolver <- function(sha) {
    if (!identical(sha, source_sha)) .stopf("Synthetic source SHA mismatch")
    instrument_id
  }
  compute_common <- .fixture_instrument_fields(source_sha, instrument_id)
  decision_common <- compute_common[c("source_sha", "source_branch", "source_dirty",
                                      "instrument_id")]
  configs <- setNames(lapply(paste0("G", 1:6), .expected_config, beta0_shift = 0, g1_seeds = 100L), paste0("G", 1:6))
  global_before_builder <- ls(.GlobalEnv, all.names = TRUE)
  builder_configs <- .source_builder_configs(beta0_shift = 0, g1_seeds = 100L)
  global_added_by_builder <- setdiff(ls(.GlobalEnv, all.names = TRUE), global_before_builder)
  if (length(global_added_by_builder)) {
    .stopf("Synthetic self-test source-builder isolation leaked global binding(s): %s",
           paste(global_added_by_builder, collapse = ", "))
  }
  if (!identical(.expected_preflight_contract(),
                 attr(builder_configs, "preflight", exact = TRUE)) ||
      !identical(.expected_pilot_config(0),
                 attr(builder_configs, "pilot", exact = TRUE))) {
    .stopf("Synthetic self-test independent preflight/pilot contracts differ from source")
  }

  preflight_out <- file.path(root, "preflight.rds")
  saveRDS(list(structural = TRUE), preflight_out)
  preflight_receipt <- file.path(root, "preflight.receipt")
  preflight_contract <- attr(builder_configs, "preflight", exact = TRUE)
  preflight_rows <- data.frame(row = seq_len(28L))
  preflight_fields <- .fixture_compute_fields(
    "preflight_compute", "preflight", "preflight", preflight_out,
    config = NULL, results = preflight_rows, expected_fit_attempts = 30L
  )
  preflight_fields$input_config_sha256 <- .canonical_config_sha256(preflight_contract)
  preflight_fields$config_sha256 <- .canonical_config_sha256(preflight_contract)
  preflight_fields$input_config_rds_sha256 <- .config_rds_sha256(preflight_contract)
  preflight_fields$config_rds_sha256 <- .config_rds_sha256(preflight_contract)
  preflight_fields$seed_min <- min(preflight_contract$seed_inventory)
  preflight_fields$seed_max <- max(preflight_contract$seed_inventory)
  preflight_fields$seed_count <- length(preflight_contract$seed_inventory)
  preflight_fields$seed_list <- paste(preflight_contract$seed_inventory, collapse = ",")
  preflight_fields$seed_inventory_roles <- preflight_contract$seed_inventory_roles
  preflight_fields$unique_key_verdict <- "PASS"
  preflight_fields$unique_logical_rows <- 28
  .write_fixture_receipt(preflight_receipt, c(preflight_fields, compute_common))

  pilot_config <- attr(builder_configs, "pilot", exact = TRUE)
  pilot_x <- .synthetic_results(pilot_config, "G1")
  pilot <- file.path(root, "pilot-v2-results.rds")
  pilot_parts_dir <- paste0(pilot, ".parts")
  dir.create(pilot_parts_dir)
  pilot_part <- file.path(pilot_parts_dir, "part-00001.rds")
  pilot_hash <- .canonical_config_sha256(pilot_config)
  pilot_rds_hash <- .config_rds_sha256(pilot_config)
  saveRDS(list(instrument_id = instrument_id, config_sha256 = pilot_hash,
               config_rds_sha256 = pilot_rds_hash,
               created_utc = "synthetic", results = pilot_x), pilot_part)
  saveRDS(pilot_x, pilot)
  pilot_compute <- file.path(root, "pilot-v2-compute.receipt")
  pilot_predecessor_paths <- c(
    preflight = normalizePath(preflight_receipt, mustWork = TRUE)
  )
  pilot_predecessor_hashes <- c(preflight = .sha256(preflight_receipt))
  .write_fixture_receipt(pilot_compute, c(.fixture_compute_fields(
    "pilot_compute", "pilot_v2", "G1", pilot, pilot_config, pilot_x,
    part_paths = pilot_part, predecessor_paths = pilot_predecessor_paths,
    predecessor_hashes = pilot_predecessor_hashes
  ), compute_common))

  decision <- file.path(root, "pilot-decision.receipt")
  .write_fixture_receipt(decision, c(
    list(receipt_type = "pilot_decision", status = "PASS"), decision_common,
    list(
      preflight_receipt_sha256 = .sha256(preflight_receipt),
      pilot_compute_receipt_sha256 = .sha256(pilot_compute),
      pilot_path = normalizePath(pilot), pilot_sha256 = .sha256(pilot),
      g1_seeds = 100, beta0_shift = 0, projected_3mcse_s100 = 0.01
    )
  ))

  canonical_hashes <- vapply(configs, .canonical_config_sha256, character(1))
  builder_canonical_hashes <- vapply(builder_configs, .canonical_config_sha256, character(1))
  if (!identical(canonical_hashes, builder_canonical_hashes)) {
    .stopf("Synthetic self-test canonical hashes differ for identical grids")
  }
  if (!identical(
    .canonical_config_sha256(.expected_preflight_contract()),
    .canonical_config_sha256(attr(builder_configs, "preflight", exact = TRUE))
  )) {
    .stopf("Synthetic self-test canonical hashes differ for nested preflight objects")
  }
  value_mutation <- configs$G1
  value_mutation$rho[[1L]] <- value_mutation$rho[[1L]] + 0.01
  type_mutation <- configs$G1
  type_mutation$seed <- as.numeric(type_mutation$seed)
  name_mutation <- configs$G1
  names(name_mutation)[names(name_mutation) == "rho"] <- "rho_changed"
  nested_name_mutation <- .expected_preflight_contract()
  names(nested_name_mutation$crn_probe)[[1L]] <- "seed_changed"
  if (identical(.canonical_config_sha256(value_mutation), canonical_hashes[["G1"]]) ||
      identical(.canonical_config_sha256(type_mutation), canonical_hashes[["G1"]]) ||
      identical(.canonical_config_sha256(name_mutation), canonical_hashes[["G1"]]) ||
      identical(
        .canonical_config_sha256(nested_name_mutation),
        .canonical_config_sha256(.expected_preflight_contract())
      )) {
    .stopf("Synthetic self-test canonical hash did not detect a value/type/name mutation")
  }
  unsupported <- configs$G1
  unsupported$stage <- factor(unsupported$stage)
  if (!inherits(try(.canonical_config_sha256(unsupported), silent = TRUE), "try-error")) {
    .stopf("Synthetic self-test canonical encoder did not fail closed on a factor")
  }
  results <- receipts <- character()
  for (block in paste0("G", 1:6)) {
    result <- file.path(root, paste0(tolower(block), ".rds"))
    x <- .synthetic_results(configs[[block]], block)
    parts_dir <- paste0(result, ".parts"); dir.create(parts_dir)
    part <- file.path(parts_dir, "part-00001.rds")
    builder_hash <- .canonical_config_sha256(builder_configs[[block]])
    builder_rds_hash <- .config_rds_sha256(builder_configs[[block]])
    saveRDS(list(instrument_id = instrument_id, config_sha256 = builder_hash,
                 config_rds_sha256 = builder_rds_hash,
                 created_utc = "synthetic", results = x), part)
    saveRDS(x, result)
    receipt <- file.path(root, paste0(tolower(block), "-compute.receipt"))
    predecessor_paths <- c(
      preflight = normalizePath(preflight_receipt, mustWork = TRUE),
      pilot_decision = normalizePath(decision, mustWork = TRUE)
    )
    predecessor_hashes <- c(
      preflight = .sha256(preflight_receipt), pilot_decision = .sha256(decision)
    )
    if (block == "G6") {
      predecessor_paths <- c(
        predecessor_paths, g1 = normalizePath(receipts[["G1"]], mustWork = TRUE)
      )
      predecessor_hashes <- c(predecessor_hashes, g1 = .sha256(receipts[["G1"]]))
    }
    .write_fixture_receipt(receipt, c(.fixture_compute_fields(
      paste0(tolower(block), "_compute"), "campaign", block,
      result, configs[[block]], x, part_paths = part,
      predecessor_paths = predecessor_paths,
      predecessor_hashes = predecessor_hashes,
      g1_seeds = if (block == "G1") 100 else ""
    ), compute_common))
    results[[block]] <- result; receipts[[block]] <- receipt
  }
  opt <- list(results = results, receipts = receipts, preflight_receipt = preflight_receipt,
              pilot = pilot, pilot_compute_receipt = pilot_compute,
              pilot_decision_receipt = decision, calibration_receipt = NULL,
              out_dir = file.path(root, "audit"))
  out <- .audit_campaign(opt, source_id_resolver = source_id_resolver)
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
  overwrite_refused <- inherits(try(.audit_campaign(
    opt, source_id_resolver = source_id_resolver
  ), silent = TRUE), "try-error")
  if (!overwrite_refused) .stopf("Synthetic self-test did not refuse overwrite")
  missing_opt <- opt; missing_opt$out_dir <- file.path(root, "missing-audit"); missing_opt$receipts[["G6"]] <- file.path(root, "absent-g6.receipt")
  missing_refused <- inherits(try(.audit_campaign(
    missing_opt, source_id_resolver = source_id_resolver
  ), silent = TRUE), "try-error")
  if (!missing_refused) .stopf("Synthetic self-test opened an incomplete six-receipt bundle")
  tampered_receipt <- file.path(root, "g2-tampered-compute.receipt")
  tampered_lines <- readLines(receipts[["G2"]], warn = FALSE)
  tampered_lines[startsWith(tampered_lines, "input_config_sha256=")] <- paste0(
    "input_config_sha256=", paste(rep("0", 64L), collapse = "")
  )
  writeLines(tampered_lines, tampered_receipt, useBytes = TRUE)
  tampered_opt <- opt
  tampered_opt$out_dir <- file.path(root, "tampered-audit")
  tampered_opt$receipts[["G2"]] <- tampered_receipt
  tampered_error <- try(.audit_campaign(
    tampered_opt, source_id_resolver = source_id_resolver
  ), silent = TRUE)
  if (!inherits(tampered_error, "try-error") ||
      !grepl("input configuration hash mismatch", as.character(tampered_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not reject a tampered canonical configuration hash")
  }
  tampered_rds_receipt <- file.path(root, "g2-tampered-rds-compute.receipt")
  tampered_rds_lines <- readLines(receipts[["G2"]], warn = FALSE)
  tampered_rds_lines[startsWith(tampered_rds_lines, "config_rds_sha256=")] <-
    "config_rds_sha256=not-a-sha256"
  writeLines(tampered_rds_lines, tampered_rds_receipt, useBytes = TRUE)
  tampered_rds_opt <- opt
  tampered_rds_opt$out_dir <- file.path(root, "tampered-rds-audit")
  tampered_rds_opt$receipts[["G2"]] <- tampered_rds_receipt
  tampered_rds_error <- try(.audit_campaign(
    tampered_rds_opt, source_id_resolver = source_id_resolver
  ), silent = TRUE)
  if (!inherits(tampered_rds_error, "try-error") ||
      !grepl("raw configuration RDS hash", as.character(tampered_rds_error),
             fixed = TRUE)) {
    .stopf("Synthetic self-test did not reject a malformed raw RDS provenance hash: %s",
           paste(as.character(tampered_rds_error), collapse = " | "))
  }
  divergent_rds_receipt <- file.path(root, "g2-divergent-rds-compute.receipt")
  divergent_rds_lines <- readLines(receipts[["G2"]], warn = FALSE)
  divergent_rds_lines[startsWith(divergent_rds_lines, "input_config_rds_sha256=")] <-
    paste0("input_config_rds_sha256=", paste(rep("0", 64L), collapse = ""))
  writeLines(divergent_rds_lines, divergent_rds_receipt, useBytes = TRUE)
  divergent_rds_opt <- opt
  divergent_rds_opt$out_dir <- file.path(root, "divergent-rds-audit")
  divergent_rds_opt$receipts[["G2"]] <- divergent_rds_receipt
  divergent_rds_error <- try(.audit_campaign(
    divergent_rds_opt, source_id_resolver = source_id_resolver
  ), silent = TRUE)
  if (!inherits(divergent_rds_error, "try-error") ||
      !grepl("duplicated raw configuration RDS hashes disagree",
             as.character(divergent_rds_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not reject divergent raw RDS provenance hashes")
  }
  divergent_configs <- configs
  divergent_configs$G3$rho[[1L]] <- divergent_configs$G3$rho[[1L]] + 0.01
  divergent_error <- try(.verify_receipt_bundle(
    opt, divergent_configs, builder_configs,
    .authenticate_receipt_sources(opt, source_id_resolver = source_id_resolver)
  ), silent = TRUE)
  if (!inherits(divergent_error, "try-error")) {
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
    .audit_campaign(unauthenticated_opt, builder_loader = injected_loader,
                    source_id_resolver = source_id_resolver), silent = TRUE
  )
  if (!inherits(unauthenticated_error, "try-error") || loader_called ||
      !grepl("instrument ID does not match", as.character(unauthenticated_error), fixed = TRUE)) {
    .stopf("Synthetic self-test did not authenticate sources before invoking the builder loader")
  }

  receipt_negative <- function(block, field, value, needle) {
    path <- file.path(root, sprintf("%s-%s-negative.receipt", tolower(block), field))
    lines <- readLines(receipts[[block]], warn = FALSE)
    hit <- startsWith(lines, paste0(field, "="))
    if (sum(hit) != 1L) .stopf("Synthetic negative fixture cannot find %s", field)
    lines[hit] <- paste0(field, "=", value)
    writeLines(lines, path, useBytes = TRUE)
    bad <- opt
    bad$receipts[[block]] <- path
    bad$out_dir <- file.path(root, paste0("negative-", field))
    loader_called <- FALSE
    loader <- function(...) {
      loader_called <<- TRUE
      builder_configs
    }
    err <- try(.audit_campaign(
      bad, builder_loader = loader, source_id_resolver = source_id_resolver
    ), silent = TRUE)
    if (!inherits(err, "try-error") || loader_called ||
        !grepl(needle, as.character(err), fixed = TRUE)) {
      .stopf("Synthetic self-test did not reject %s tampering before source loading", field)
    }
  }
  receipt_negative("G2", "schema_version", "phase_c_compute_v1", "schema_version")
  receipt_negative("G3", "stage", "pilot_v2", "stage/block mismatch")
  receipt_negative("G4", "block", "G1", "stage/block mismatch")

  validate_negative <- function(name, mutate, needle) {
    x <- .synthetic_results(configs$G1, "G1")
    x <- mutate(x)
    err <- try(.validate_block_results(
      x, "G1", .expand_arms(configs$G1), .read_receipt(receipts[["G1"]]),
      c(part = file.path(paste0(results[["G1"]], ".parts"), "part-00001.rds")),
      instrument_id
    ), silent = TRUE)
    if (!inherits(err, "try-error") ||
        !grepl(needle, as.character(err), fixed = TRUE)) {
      .stopf("Synthetic self-test did not reject %s", name)
    }
  }
  validate_negative("theoretical geometry tampering", function(x) {
    x$theoretical_bias_rho[[1L]] <- x$theoretical_bias_rho[[1L]] + 0.01
    x
  }, "theoretical bias geometry")
  validate_negative("positive-kappa geometry error", function(x) {
    i <- which(x$kappa > 0)[[1L]]
    x$realised_bias_rho_max_abs_error[[i]] <- 1e-6
    x
  }, "realised positive-kappa geometry")
  validate_negative("null correlation defined as zero", function(x) {
    i <- which(x$kappa == 0)[[1L]]
    x$realised_bias_rho_mean[[i]] <- 0
    x
  }, "undefined-correlation/zero-variance")
  validate_negative("null variance recorded as NA", function(x) {
    i <- which(x$kappa == 0)[[1L]]
    x$realised_bias_variance_mean[[i]] <- NA_real_
    x
  }, "undefined-correlation/zero-variance")
  validate_negative("pre-fit failure retention", function(x) {
    x$fit_attempted[[1L]] <- FALSE
    x$fit_error[[1L]] <- "synthetic DGP failure"
    x
  }, "DGP/pre-fit failure")
  part_negative <- function(field, value) {
    original <- file.path(paste0(results[["G1"]], ".parts"), "part-00001.rds")
    part <- readRDS(original)
    part[[field]] <- value
    path <- file.path(root, paste0("part-negative-", field, ".rds"))
    saveRDS(part, path)
    err <- try(.validate_block_results(
      .synthetic_results(configs$G1, "G1"), "G1", .expand_arms(configs$G1),
      .read_receipt(receipts[["G1"]]), c(part = path), instrument_id
    ), silent = TRUE)
    if (!inherits(err, "try-error") ||
        !grepl("malformed/incompatible part", as.character(err), fixed = TRUE)) {
      .stopf("Synthetic self-test did not reject part %s mismatch", field)
    }
  }
  part_negative("config_sha256", paste(rep("0", 64L), collapse = ""))
  part_negative("config_rds_sha256", paste(rep("0", 64L), collapse = ""))
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
