## Reader-surface scope checks for the trait-axis bridge article.

article <- "vignettes/articles/where-does-the-tree-go.Rmd"
text <- paste(readLines(article, warn = FALSE), collapse = "\n")

must_have <- c(
  "Gaussian only",
  "not a trait-level `Sigma`",
  "not establish abundance, occupancy, or detectability",
  "No tree on sources"
)
missing <- must_have[!vapply(must_have, grepl, logical(1), x = text, fixed = TRUE)]
if (length(missing)) {
  stop("Missing required scope language: ", paste(missing, collapse = "; "))
}
if (grepl("observation = ~ 0 \\+ observer", text)) {
  stop("The article reintroduced the obsolete survey 0 + workaround.")
}
if (grepl("\\b(FG|FAM|ISDM|RE)-[0-9]", text)) {
  stop("The reader surface contains an internal validation identifier.")
}

cat("SCOPE SCAN PASS\n")
