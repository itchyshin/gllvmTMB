paths <- c(
  "docs/dev-log/check-log.md",
  "docs/dev-log/after-task/2026-08-27-column-coef-phylo-fixed-rho.md"
)
stopifnot(all(file.exists(paths)))
text <- paste(vapply(paths, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1L)), collapse = "\n")

required <- c(
  "PHYLO_COEF_LOCAL_PACKAGE_OK",
  "17,811 passes",
  "No problems found",
  "PHYLO_COEF_R_CMD_CHECK_OK",
  "0 errors, 0 warnings, 3 unchanged notes"
)
for (pattern in required) {
  stopifnot(grepl(pattern, text, fixed = TRUE))
}

status <- system2("git", c("diff", "--check"))
stopifnot(identical(status, 0L))
cat("PHYLO_COEF_LOCAL_PACKAGE_RECEIPT_OK\n")
