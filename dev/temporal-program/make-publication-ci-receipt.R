args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: make-publication-ci-receipt.R RUN_ID OUTPUT_RDS", call. = FALSE)
}

run_id <- suppressWarnings(as.numeric(args[[1L]]))
output <- path.expand(args[[2L]])
if (!is.finite(run_id) || file.exists(output)) {
  stop("run id must be finite and output must not already exist", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required to record a CI receipt", call. = FALSE)
}

raw <- system2(
  "gh",
  c("run", "view", format(run_id, scientific = FALSE), "--json",
    paste(c("conclusion", "event", "headSha", "url", "workflowName", "jobs"), collapse = ",")),
  stdout = TRUE,
  stderr = TRUE
)
if (!is.null(attr(raw, "status"))) {
  stop("GitHub Actions receipt query failed", call. = FALSE)
}
run <- jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = TRUE)
if (!identical(run$workflowName, "R-CMD-check") ||
    !identical(run$event, "workflow_dispatch")) {
  stop("CI run is not the manual R-CMD-check workflow", call. = FALSE)
}

patterns <- c(ubuntu = "ubuntu", macos = "macos", windows = "windows")
platforms <- vapply(patterns, function(pattern) {
  index <- grepl(pattern, run$jobs$name, ignore.case = TRUE)
  if (sum(index) != 1L) {
    stop("CI run lacks one exact platform job: ", pattern, call. = FALSE)
  }
  as.character(run$jobs$conclusion[index])
}, character(1L))
if (!identical(run$conclusion, "success") || any(platforms != "success")) {
  stop("CI run is not three-platform green", call. = FALSE)
}

head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (!identical(run$headSha, head)) {
  stop("CI run is not bound to current HEAD", call. = FALSE)
}
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
saveRDS(
  list(
    schema = "temporal-program-publication-ci-receipt-v1",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    run_id = run_id,
    run_url = run$url,
    head_sha = run$headSha,
    workflow_name = run$workflowName,
    event = run$event,
    platforms = platforms
  ),
  output,
  version = 3
)
cat("TEMPORAL_PROGRAM_PUBLICATION_CI_RECEIPT_WRITTEN\n")
