## Fail-closed pre-merge closeout gate for the bounded iJSDM diagnostic.

root <- normalizePath(".", mustWork = TRUE)
diag <- file.path(root, "dev", "isdm-requalification", "diagnostic-rescue")
report <- file.path(root, "docs", "dev-log", "after-task",
                    "2026-08-29-isdm-identifiability-diagnostic.md")
check_log <- file.path(root, "docs", "dev-log", "check-log.md")

abort <- function(message) stop(message, call. = FALSE)
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
if (!file.exists(report) || !file.exists(check_log)) abort("closeout files missing")

report_text <- paste(readLines(report, warn = FALSE), collapse = "\n")
log_text <- paste(readLines(check_log, warn = FALSE), collapse = "\n")
required_report <- c(
  "52 planned, 52 started, and 52 terminal",
  "All five preregistered screening signals are `FALSE`",
  "prepare, but do not launch",
  "No public R API, likelihood, formula grammar",
  "codex:isdm-identifiability-diagnostic"
)
if (any(!vapply(required_report, grepl, logical(1L), x = report_text,
                fixed = TRUE))) {
  abort("after-task report lacks a frozen closeout statement")
}
if (!grepl("Integrated-JSDM identifiability diagnostic", log_text,
           fixed = TRUE) ||
    !grepl("52 planned, 52 started, 52 terminal", log_text, fixed = TRUE) ||
    !grepl("The only earned next", log_text, fixed = TRUE)) {
  abort("check log lacks the terminal denominator or next-action boundary")
}

summary <- readRDS(file.path(diag, "evidence", "experiment",
                             "independent-summary.rds"))
if (!identical(summary$denominators$planned, 52L) ||
    !identical(summary$denominators$started, 52L) ||
    !identical(summary$denominators$terminal, 52L) ||
    !identical(summary$denominators$worker, 52L) ||
    !identical(summary$denominators$coordinator, 0L) ||
    any(summary$signals) || !identical(summary$next_action, "MIXED")) {
  abort("retained summary differs from the terminal closeout")
}

review_status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c("--vanilla", file.path(diag, "verify-reviews.R"), "terminal"),
  stdout = TRUE, stderr = TRUE
)
if (!identical(as.integer(attr(review_status, "status") %||% 0L), 0L) ||
    !any(grepl("DIAGNOSTIC_TERMINAL_REVIEWS_VERIFIED", review_status,
               fixed = TRUE))) {
  abort("terminal review verification failed")
}

validator <- "/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R"
validation <- system2(file.path(R.home("bin"), "Rscript"),
                      c("--vanilla", shQuote(validator), shQuote(report)),
                      stdout = TRUE, stderr = TRUE)
if (!identical(as.integer(attr(validation, "status") %||% 0L), 0L) ||
    !any(grepl("after-task structure check passed", validation,
               fixed = TRUE))) {
  abort("after-task validator failed")
}

cat("DIAGNOSTIC_CLOSEOUT_VERIFIED\n")
