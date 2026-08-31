root <- normalizePath(".")
check_dir <- file.path(root, "dev/covariance-teaching/receipts/package-check")
dir.create(check_dir, recursive = TRUE, showWarnings = FALSE)
cat("Package check; no heavy-test flag; separate from the article-fit ledger\n")
stopifnot(!nzchar(Sys.getenv("GLLVMTMB_HEAVY_TESTS")))
result <- devtools::check(args = "--no-manual", quiet = TRUE,
                          document = FALSE, check_dir = check_dir,
                          error_on = "never")
cat("ERRORS", length(result$errors), "WARNINGS", length(result$warnings),
    "NOTES", length(result$notes), "\n")
print(result)
saveRDS(result, file.path(check_dir, "result.rds"))
if (length(result$errors) || length(result$warnings)) {
  stop("Package check has errors or warnings; inspect retained result")
}
cat("PACKAGE_CHECK_VERIFIED\n")
