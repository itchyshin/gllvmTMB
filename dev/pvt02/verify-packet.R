args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, file.exists(args))
text <- paste(readLines(args, warn = FALSE), collapse = "\n")
must_have <- c(
  "n_units = 400", "unique = TRUE", "d = 2", "n_sim = 5000",
  "50001:55000", "coverage `>= 0.94`", "coverage - 2 * MCSE >= 0.94",
  "ci_failed", "Totoro/DRAC"
)
stopifnot(all(vapply(must_have, grepl, logical(1), x = text, fixed = TRUE)))
cat("PVT02_PACKET_PASS\n")
