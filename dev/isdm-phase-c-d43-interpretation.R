## dev/isdm-phase-c-d43-interpretation.R
##
## Post-analysis D-43 interpretation addendum for the immutable Phase C
## official-analysis-v1 refutation outputs.  This script does not read fits,
## alter thresholds, or overwrite any preregistered result.  It only makes the
## scope of the global R5 interpretation explicit while retaining every input
## R1--R5 cell verdict unchanged.

.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

.sha256 <- function(path) {
  if (!file.exists(path) || file.info(path)$size <= 0L) .stopf("Missing or empty input: %s", path)
  out <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  if (!length(out) || !grepl("^[0-9a-f]{64}\\s", out[[1L]])) .stopf("Could not SHA-256 hash: %s", path)
  sub("\\s.*$", "", out[[1L]])
}

.required_refutation_columns <- c("condition", "status", "omega")
.required_aggregate_columns <- c("condition", "aggregate_verdict", "trigger_rows",
                                 "evaluated_rows", "rule", "overall_h_sink_verdict")
.expected_conditions <- c("R1_flat_curve", "R2_unattributable", "R3_wrong_mechanism",
                          "R4_diagonal_only", "R5_wrong_sign")

.read_checked_csv <- function(path, required, label) {
  hash <- .sha256(path)
  x <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!is.data.frame(x) || !nrow(x) || !all(required %in% names(x))) {
    .stopf("%s lacks required schema: %s", label, path)
  }
  list(data = x, sha256 = hash)
}

.validate_inputs <- function(refutation, aggregate) {
  if (!identical(sort(unique(as.character(refutation$condition))), .expected_conditions)) {
    .stopf("Refutation evidence must contain exactly R1--R5 conditions")
  }
  if (!identical(sort(unique(as.character(aggregate$condition))), .expected_conditions) ||
      length(unique(as.character(aggregate$overall_h_sink_verdict))) != 1L) {
    .stopf("Refutation aggregate must contain exactly R1--R5 and one global verdict")
  }
  if (!identical(unique(as.character(aggregate$overall_h_sink_verdict)), "H_SINK_REFUTED")) {
    .stopf("D-43 addendum expects the immutable v1 H_SINK_REFUTED aggregate")
  }
  r5 <- refutation[refutation$condition == "R5_wrong_sign" &
                    refutation$status == "TRIGGERED", , drop = FALSE]
  if (!nrow(r5) || any(!is.finite(r5$omega))) {
    .stopf("D-43 addendum requires finite omega for at least one R5 trigger")
  }
  r5
}

.d43_global_verdict <- function(r5_triggered, tol = 1e-10) {
  if (any(abs(r5_triggered$omega) > tol)) {
    "H_SINK_REFUTED"
  } else {
    "H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT"
  }
}

.write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "NA")
  if (!file.exists(path) || file.info(path)$size <= 0L) .stopf("Failed to write: %s", path)
}

write_d43_addendum <- function(refutation_path, aggregate_path, out_dir) {
  if (dir.exists(out_dir) || file.exists(out_dir)) .stopf("Refusing to overwrite output: %s", out_dir)
  ref <- .read_checked_csv(refutation_path, .required_refutation_columns, "refutation evidence")
  agg <- .read_checked_csv(aggregate_path, .required_aggregate_columns, "refutation aggregate")
  r5 <- .validate_inputs(ref$data, agg$data)
  verdict <- .d43_global_verdict(r5)

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) .stopf("Could not create output directory: %s", out_dir)
  cells_path <- file.path(out_dir, "01-r1-r5-cell-verdicts-copy.csv")
  addendum_path <- file.path(out_dir, "02-d43-global-interpretation.csv")
  receipt_path <- file.path(out_dir, "03-d43-interpretation.receipt")
  .write_csv(ref$data, cells_path)
  addendum <- data.frame(
    addendum_type = "POST_ANALYSIS_D43_INTERPRETATION_ONLY",
    immutable_input_global_verdict = unique(as.character(agg$data$overall_h_sink_verdict)),
    d43_global_verdict = verdict,
    r5_trigger_rows = nrow(r5),
    r5_trigger_omega_values = paste(sprintf("%.17g", sort(unique(r5$omega))), collapse = ","),
    interpretation = if (identical(verdict, "H_SINK_REFUTED")) {
      "At least one negative R5 trigger occurs in a shared-bias cell (omega > 0)."
    } else {
      "All negative R5 triggers occur in omega=0 controls; retain cell findings, but do not globally refute the shared-bias mechanism."
    },
    stringsAsFactors = FALSE
  )
  .write_csv(addendum, addendum_path)
  copied <- utils::read.csv(cells_path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!identical(ref$data, copied)) .stopf("Copied R1--R5 evidence does not exactly reproduce input")
  receipt <- c(
    "schema_version=phase_c_d43_interpretation_v1",
    "classification=POST_ANALYSIS_NOT_PREREGISTERED_EVIDENCE",
    paste0("refutation_evidence_path=", normalizePath(refutation_path, mustWork = TRUE)),
    paste0("refutation_evidence_sha256=", ref$sha256),
    paste0("refutation_aggregate_path=", normalizePath(aggregate_path, mustWork = TRUE)),
    paste0("refutation_aggregate_sha256=", agg$sha256),
    paste0("cell_verdict_copy_sha256=", .sha256(cells_path)),
    paste0("addendum_sha256=", .sha256(addendum_path)),
    paste0("d43_global_verdict=", verdict),
    paste0("r5_trigger_rows=", nrow(r5)),
    paste0("r5_trigger_omega_values=", paste(sprintf("%.17g", sort(unique(r5$omega))), collapse = ","))
  )
  writeLines(receipt, receipt_path, useBytes = TRUE)
  if (!file.exists(receipt_path) || file.info(receipt_path)$size <= 0L) .stopf("Failed to write receipt")
  invisible(c(cells_path, addendum_path, receipt_path))
}

.write_fixture <- function(dir, omegas) {
  ref <- data.frame(
    condition = rep(.expected_conditions, each = 1L),
    status = c("NOT_TRIGGERED", "NOT_TRIGGERED", "NOT_TRIGGERED", "NOT_TRIGGERED", "TRIGGERED"),
    omega = c(1, 1, 1, 1, omegas), stringsAsFactors = FALSE
  )
  agg <- data.frame(condition = .expected_conditions, aggregate_verdict = "NOT_TRIGGERED",
                    trigger_rows = 0L, evaluated_rows = 1L, rule = "fixture",
                    overall_h_sink_verdict = "H_SINK_REFUTED", stringsAsFactors = FALSE)
  rp <- file.path(dir, "08-refutation-evidence.csv"); ap <- file.path(dir, "12-refutation-aggregate.csv")
  .write_csv(ref, rp); .write_csv(agg, ap); c(rp, ap)
}

self_test <- function() {
  root <- tempfile("isdm-phase-c-d43-", tmpdir = "/private/tmp")
  dir.create(root, recursive = TRUE)
  p <- .write_fixture(root, 0)
  out <- file.path(root, "out-control")
  write_d43_addendum(p[[1]], p[[2]], out)
  a <- utils::read.csv(file.path(out, "02-d43-global-interpretation.csv"), stringsAsFactors = FALSE)
  stopifnot(identical(a$d43_global_verdict, "H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT"))
  stopifnot(inherits(try(write_d43_addendum(p[[1]], p[[2]], out), silent = TRUE), "try-error"))
  p2dir <- file.path(root, "shared"); dir.create(p2dir); p2 <- .write_fixture(p2dir, 0.5)
  out2 <- file.path(root, "out-shared"); write_d43_addendum(p2[[1]], p2[[2]], out2)
  a2 <- utils::read.csv(file.path(out2, "02-d43-global-interpretation.csv"), stringsAsFactors = FALSE)
  stopifnot(identical(a2$d43_global_verdict, "H_SINK_REFUTED"))
  bad <- utils::read.csv(p[[1]], stringsAsFactors = FALSE); bad$omega <- NULL
  bad_path <- file.path(root, "bad.csv"); .write_csv(bad, bad_path)
  stopifnot(inherits(try(write_d43_addendum(bad_path, p[[2]], file.path(root, "out-bad")), silent = TRUE), "try-error"))
  cat("D43_INTERPRETATION_SELF_TEST_PASS\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (identical(args, "--self-test")) {
    self_test()
  } else if (identical(args, "--help")) {
    cat("Usage: Rscript dev/isdm-phase-c-d43-interpretation.R --refutation-evidence=CSV --refutation-aggregate=CSV --out-dir=DIR\\n")
  } else {
    vals <- setNames(sub("^[^=]+=", "", args), sub("=.*$", "", args))
    required <- c("--refutation-evidence", "--refutation-aggregate", "--out-dir")
    if (!identical(sort(names(vals)), sort(required)) || any(!nzchar(vals))) .stopf("Use --help for required arguments")
    write_d43_addendum(vals[["--refutation-evidence"]], vals[["--refutation-aggregate"]], vals[["--out-dir"]])
    cat("D43_INTERPRETATION_ADDENDUM_PASS\\n")
  }
}
