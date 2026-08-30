args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: make-ci-receipt.R RUN_ID OUTPUT_RDS")
run_id <- as.numeric(args[[1L]]); output <- path.expand(args[[2L]])
if (!is.finite(run_id) || file.exists(output)) stop("invalid run id or existing output")
raw <- system2("gh", c("run", "view", format(run_id, scientific = FALSE),
                        "--json", "conclusion,headSha,url,jobs"),
               stdout = TRUE, stderr = TRUE)
if (!is.null(attr(raw, "status")) || !requireNamespace("jsonlite", quietly = TRUE))
  stop("GitHub Actions receipt query failed")
run <- jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = TRUE)
patterns <- c(ubuntu = "ubuntu", macos = "macos", windows = "windows")
conclusions <- vapply(patterns, function(pattern) {
  idx <- grepl(pattern, run$jobs$name, ignore.case = TRUE)
  if (sum(idx) != 1L) stop("CI run lacks one exact platform job: ", pattern)
  as.character(run$jobs$conclusion[idx])
}, character(1L))
if (!identical(run$conclusion, "success") || any(conclusions != "success"))
  stop("CI run is not three-platform green")
head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (!identical(run$headSha, head)) stop("CI run is not bound to current HEAD")
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
saveRDS(list(schema = "isdm-diagnostic-ci-receipt-v1",
             created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
             run_id = run_id, run_url = run$url, head_sha = run$headSha,
             platforms = conclusions), output, version = 3)
cat("DIAGNOSTIC_CI_RECEIPT_WRITTEN\n")
