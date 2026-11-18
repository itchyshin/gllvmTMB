## Reader-surface scope checks for the trait-axis bridge article.

article <- "vignettes/articles/where-does-the-tree-go.Rmd"
text <- paste(readLines(article, warn = FALSE), collapse = "\n")

must_have <- c(
  "not a fourth covariance mode",
  "Gaussian and long-format only",
  "not a model of species-specific elevation slopes",
  "species-by-species covariance matrix",
  "intervals are deliberately"
)
missing <- must_have[!vapply(must_have, grepl, logical(1), x = text, fixed = TRUE)]
if (length(missing)) {
  stop("Missing required scope language: ", paste(missing, collapse = "; "))
}
if (grepl("isdm_sources|observation =|abundance, occupancy", text)) {
  stop("The tree-axis article reintroduced an out-of-scope integrated-model story.")
}
if (grepl("\\b(FG|FAM|ISDM|RE)-[0-9]", text)) {
  stop("The reader surface contains an internal validation identifier.")
}

cat("SCOPE SCAN PASS\n")
