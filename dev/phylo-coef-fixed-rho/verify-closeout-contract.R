files <- c(
  "docs/design/131-response-column-coefficient-foundation.md",
  "docs/design/35-validation-debt-register.md",
  "docs/dev-log/check-log.md",
  "docs/dev-log/after-task/2026-08-27-column-coef-phylo-fixed-rho.md",
  "docs/dev-log/plan-actual/2026-08-27-column-coef-phylo-fixed-rho.md",
  "docs/dev-log/handover/2026-08-27-column-coef-phylo-fixed-rho.md"
)
stopifnot(all(file.exists(files)))

text <- paste(vapply(files, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1L)), collapse = "\n")

required <- c(
  "K_rho = rho K + (1 - rho) diag(K)",
  "fixed-rho",
  "internal",
  "public",
  "estimated rho",
  "phylo_slope",
  "warning-free"
)
for (pattern in required) {
  stopifnot(grepl(pattern, text, fixed = TRUE))
}

forbidden <- c(
  "phylo_coef() is exported",
  "phylo_coef() is public",
  "estimated rho is covered",
  "phylo_slope() is deprecated"
)
for (pattern in forbidden) {
  stopifnot(!grepl(pattern, text, fixed = TRUE))
}

cat("PHYLO_COEF_CLOSEOUT_CONTRACT_OK\n")
