args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !args[[1L]] %in% c("plan", "terminal")) {
  stop("usage: verify-reviews.R plan|terminal")
}
root <- file.path("dev", "isdm-requalification", "diagnostic-rescue", "reviews")
phase <- args[[1L]]
roles <- if (phase == "plan") c("curie", "gauss", "rose") else
  c("fisher", "gauss", "rose")
paths <- file.path(root, paste0(phase, "-", roles, ".md"))
if (!all(file.exists(paths))) stop("missing review: ", paths[!file.exists(paths)][1L])
text <- lapply(paths, readLines, warn = FALSE)
if (!all(vapply(text, function(x) any(grepl("Verdict: [*]*PASS", x)), logical(1L)))) {
  stop("a review does not record PASS")
}
if (any(vapply(text, function(x) any(grepl("unresolved.*block", x,
                                           ignore.case = TRUE)), logical(1L)))) {
  stop("a review records an unresolved blocking finding")
}
cat(if (phase == "plan") "DIAGNOSTIC_PLAN_REVIEWS_VERIFIED\n" else
      "DIAGNOSTIC_TERMINAL_REVIEWS_VERIFIED\n")

