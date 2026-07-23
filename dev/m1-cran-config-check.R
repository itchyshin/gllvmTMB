# M1 — CRAN-configuration check at the exact head.
#
# WHY THIS EXISTS SEPARATELY FROM THE DURABLE RUNNER.
# devtools::check()'s defaults set NOT_CRAN=true and disable incoming
# feasibility, so the durable runner's "0 errors | 0 warnings | 0 notes" is an
# artefact of what it SKIPS, not a CRAN verdict. This is the only real CRAN
# evidence in the programme. Do not substitute one for the other.
#
# Emits M1_FINAL_RECEIPT_CHECK_* fields. A missing or unparseable field is
# CANNOT VERIFY -- never PASS. Never grep reporter prose for failure markers.
#
# The bar is an ALLOWLIST, not "zero notes": a first submission legitimately
# carries "New submission". Asserting zero notes would be a self-granted
# waiver of a real CRAN behaviour.
#
# Usage:  Rscript --no-init-file dev/m1-cran-config-check.R
# Writes: <outdir>/cran-config-result.rds  (the full result object)

wt <- normalizePath(".", mustWork = TRUE)
outdir <- Sys.getenv("M1_OUTDIR", unset = file.path(wt, "dev"))
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

sha <- system("git rev-parse HEAD", intern = TRUE)
cat("M1_FINAL_RECEIPT_CHECK_SOURCE_SHA=", sha, "\n", sep = "")
cat("M1_FINAL_RECEIPT_CHECK_STARTED=",
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "\n", sep = "")

res <- devtools::check(
  pkg            = wt,
  document       = FALSE,
  args           = "--as-cran",
  env_vars       = c(NOT_CRAN = "false"),
  incoming       = TRUE,
  remote         = TRUE,
  force_suggests = TRUE,
  manual         = TRUE,
  error_on       = "never",
  quiet          = FALSE
)

saveRDS(res, file.path(outdir, "cran-config-result.rds"))

# Structured counts, taken from the result object -- not from the log text.
cat("M1_FINAL_RECEIPT_CHECK_ERRORS=",   length(res$errors),   "\n", sep = "")
cat("M1_FINAL_RECEIPT_CHECK_WARNINGS=", length(res$warnings), "\n", sep = "")
cat("M1_FINAL_RECEIPT_CHECK_NOTES=",    length(res$notes),    "\n", sep = "")

cat("---- ERRORS ----\n");   if (length(res$errors))   cat(res$errors,   sep = "\n----\n")
cat("---- WARNINGS ----\n"); if (length(res$warnings)) cat(res$warnings, sep = "\n----\n")
cat("---- NOTES ----\n");    if (length(res$notes))    cat(res$notes,    sep = "\n----\n")

allow <- c("New submission", "installed size", "sub-directories of 1Mb or more")
unexpected <- Filter(
  function(n) !any(vapply(allow, grepl, logical(1), x = n, fixed = TRUE)),
  res$notes
)
cat("M1_FINAL_RECEIPT_CHECK_UNEXPECTED_NOTES=", length(unexpected), "\n", sep = "")
if (length(unexpected)) {
  cat("---- UNEXPECTED NOTES (each needs a maintainer decision) ----\n")
  cat(unexpected, sep = "\n----\n")
}

# Guard against the source moving under a long check.
end_sha <- system("git rev-parse HEAD", intern = TRUE)
cat("M1_FINAL_RECEIPT_CHECK_END_SHA=", end_sha, "\n", sep = "")
cat("M1_FINAL_RECEIPT_CHECK_SHA_STABLE=", identical(sha, end_sha), "\n", sep = "")
cat("M1_FINAL_RECEIPT_CHECK_FINISHED=",
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "\n", sep = "")
