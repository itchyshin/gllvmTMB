baseline <- "da6398a9d8df78c04dc4645dfa3fd4c3bd8d75e3"
read_base <- function(path) system2("git", c("show", paste0(baseline, ":", path)), stdout = TRUE)
chunks <- function(lines) {
  starts <- grep("^```\\{r([ ,}]|$)", lines)
  out <- list()
  for (i in starts) {
    end <- i + which(grepl("^```[[:space:]]*$", lines[(i + 1):length(lines)]))[1]
    if (grepl("eval[[:space:]]*=[[:space:]]*FALSE", lines[i])) next
    code <- paste(lines[(i + 1):(end - 1)], collapse = "\n")
    out[[length(out) + 1L]] <- parse(text = code, keep.source = FALSE)
  }
  out
}
for (article in c("covariance-correlation", "cross-family-correlations", "spatial-models")) {
  path <- paste0("vignettes/articles/", article, ".Rmd")
  before <- chunks(read_base(path))
  after <- chunks(readLines(path))
  stopifnot(identical(before, after))
  cat(article, ": evaluated R expressions identical\n")
}
path <- "R/extract-correlations.R"
before <- read_base(path)
after <- readLines(path)
# Exact approved diagnostic-label replacement, no other code normalization.
before <- sub("The observation-scale nominal summary", "The residual-augmented model-scale nominal summary", before, fixed = TRUE)
stopifnot(identical(parse(text = before, keep.source = FALSE), parse(text = after, keep.source = FALSE)))
# No numerical implementation, API, test, fixture or configuration changes.
changed <- system2("git", c("diff", "--name-only", baseline), stdout = TRUE)
allowed <- c(path, "man/extract_cross_correlations.Rd", paste0("vignettes/articles/", c("covariance-correlation", "cross-family-correlations", "spatial-models"), ".Rmd"), "docs/dev-log/check-log.md", "docs/dev-log/after-task/2026-08-31-covariance-teaching.md")
stopifnot(all(changed %in% allowed | startsWith(changed, "dev/covariance-teaching/")))
L1 <- rbind(c(1, 0), c(.5, 1), c(.5, .5))
L2 <- rbind(c(sqrt(2), 0), c(1/(2*sqrt(2)), 1), c(1/(2*sqrt(2)), 5/8))
S1 <- tcrossprod(L1); S2 <- tcrossprod(L2)
stopifnot(max(abs(S1[lower.tri(S1)] - S2[lower.tri(S2)])) < 1e-14,
          !isTRUE(all.equal(diag(S1), diag(S2))),
          all(3-diag(S1) > 0), all(3-diag(S2) > 0),
          max(abs(S1 + diag(3-diag(S1)) - S2 - diag(3-diag(S2)))) < 1e-14)
cat("Spatial counterexample: same total covariance, different shared covariance and positive diagonals\n")
cat("INVARIANTS_VERIFIED\n")
