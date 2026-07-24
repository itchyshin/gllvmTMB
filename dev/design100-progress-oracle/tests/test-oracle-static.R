# Static contract checks for the private Design-100 oracle worker (worktree-local).

.d100_static_root <- function() {
  argument <- commandArgs(trailingOnly = FALSE)
  script <- sub("^--file=", "", argument[grepl("^--file=", argument)])
  if (length(script) != 1L) {
    stop("Run this static test with Rscript.", call. = FALSE)
  }
  normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)
}

.d100_expect_contains <- function(text, values, file) {
  missing <- values[!vapply(values, grepl, logical(1), x = text, fixed = TRUE)]
  if (length(missing)) {
    stop(
      sprintf("%s is missing required contract token(s): %s", file,
              paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
}

.d100_expect_absent <- function(text, patterns, file) {
  found <- patterns[vapply(patterns, grepl, logical(1), x = text,
                          perl = TRUE, ignore.case = TRUE)]
  if (length(found)) {
    stop(
      sprintf("%s contains prohibited dependency token(s): %s", file,
              paste(found, collapse = ", ")),
      call. = FALSE
    )
  }
}

root <- .d100_static_root()
oracle_file <- file.path(root, "R", "independent-oracle.R")
worker_file <- file.path(root, "scripts", "oracle-worker.R")
records_file <- file.path(root, "R", "records.R")
oracle_text <- paste(readLines(oracle_file, warn = FALSE), collapse = "\n")
worker_text <- paste(readLines(worker_file, warn = FALSE), collapse = "\n")
records_text <- paste(readLines(records_file, warn = FALSE), collapse = "\n")

.d100_expect_contains(
  oracle_text,
  c(
    "d100_oracle_task_input",
    "coordinate_hash",
    "pattern_code",
    "backend",
    "component",
    "lockEnvironment",
    "d100_oracle_direct_original_u_boundary",
    "original_u",
    "d100_oracle_component_plan",
    "record_type = \"declarative_component_plan\"",
    "is_terminal = FALSE",
    "d100_oracle_aggregate_pattern",
    "component_terminals",
    "d100_oracle_emit_progress",
    "record_type = \"declarative_progress_plan\"",
    "phase = phase",
    "boundary = boundary",
    "\"cubature\"",
    "\"before\"",
    "\"after\"",
    "status = \"not_executed\"",
    "status, \"PROGRESS_COMPLETE\"",
    "cannot construct a component terminal",
    "d100_oracle_execution_guard"
  ),
  oracle_file
)

.d100_expect_absent(
  paste(oracle_text, worker_text),
  c(
    "design[-_ ]?99",
    "\\bd99\\b",
    "aghq",
    "\\bagh\\b",
    "adaptive[ -]?gauss",
    "conditional[_ ]?hessian"
  ),
  "Design-100 oracle sources"
)

.d100_expect_contains(
  worker_text,
  c(
    "--plan", "--execute", "execution is unavailable",
    "record_type = \"declarative_plan\"",
    "status = \"not_executed\"",
    "declarative_progress",
    "component_plan"
  ),
  worker_file
)

.d100_expect_contains(
  records_text,
  c(
    "d100_run_label",
    "d100-liveness-v1",
    "d100_validate_liveness_event",
    "d100_with_task_lock",
    "Refusing concurrent or stale Design-100 task writer",
    "Malformed existing Design-100 progress record",
    "Malformed existing Design-100 progress history",
    "d100_validate_progress_series(events, launch)"
  ),
  records_file
)

.d100_expect_absent(
  oracle_text,
  c("is\\.numeric\\(original_u\\)", "is\\.finite\\(original_u\\)"),
  oracle_file
)

message("Design-100 oracle static contract: OK")
