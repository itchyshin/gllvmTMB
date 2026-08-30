#!/usr/bin/env Rscript
## No-fit article check. The saved M1 is used only for public extraction/plots.
library(gllvmTMB)
root <- Sys.getenv("GLLVM_TREE_AXIS_RESULTS", "/private/tmp/gllvm-tree-axis-latent-20260830/results")
lines <- readLines("vignettes/articles/where-does-the-tree-go.Rmd")
chunks <- list(); active <- NULL; code <- character()
for (line in lines) {
  if (grepl("^```\\{r", line)) {
    stopifnot(is.null(active))
    active <- sub("^```\\{r +([^,} ]+).*", "\\1", line); code <- character()
  } else if (!is.null(active) && identical(line, "```")) {
    chunks[[active]] <- parse(text = code); active <- NULL
  } else if (!is.null(active)) code <- c(code, line)
}
stopifnot(is.null(active))
## Reject unsupported named arguments in every displayed fit without fitting.
fit_calls <- list()
walk <- function(x) {
  if (!is.call(x) && !is.expression(x) && !is.pairlist(x)) return(invisible(NULL))
  if (is.call(x) && identical(x[[1]], as.name("gllvmTMB"))) {
    match.call(gllvmTMB, x)
    stopifnot(identical(x$control, quote(gllvmTMBcontrol(se = FALSE))))
    fit_calls[[length(fit_calls) + 1L]] <<- x
  }
  for (y in as.list(x)) {
    if (missing(y)) next
    if (is.recursive(y)) walk(y)
  }
}
invisible(lapply(chunks, walk)); stopifnot(length(fit_calls) == 6L)
article <- new.env(parent = globalenv())
for (name in c("setup", "packages", "simulation-helpers", "plot-helper", "morphology-dgp", "community-dgp")) {
  eval(chunks[[name]], envir = article)
}
reference <- new.env(parent = globalenv()); sys.source("dev/tree-axis-latent/fixture.R", reference)
stopifnot(isTRUE(all.equal(article$fixture, reference$make_tree_axis_fixture("target"), tolerance = 0)))
cat("ARTICLE_FIXTURE_IDENTITY_PASS\nARTICLE_SIX_CALL_ARGUMENTS_PASS\n")
article$fit_morphology <- readRDS(file.path(root, "fit-M1.rds"))$fit
out <- file.path(dirname(root), "article-static-figures.pdf")
pdf(out, width = 8, height = 6)
for (name in c("axis-map", "morphology-figure", "morphology-truth-estimate")) {
  result <- eval(chunks[[name]], article)
  if (inherits(result, "ggplot")) print(result)
}
dev.off()
stopifnot(nrow(article$truth_estimate) == 6L, all(is.finite(as.matrix(article$truth_estimate[-1]))))
## Exercise held community coefficient matrix construction, but do not render
## or interpret failed fits. Public coef() only; no fitting or private modes.
iid <- readRDS(file.path(root, "fit-M2.rds"))$fit
curve <- expand.grid(latitude = seq(-2, 2, length.out = 100),
                     pathway = factor(c("C3", "C4"), levels = c("C3", "C4")))
X <- model.matrix(~ 0 + pathway + latitude:pathway, curve)
stopifnot(all(colnames(X) %in% names(coef(iid))), all(is.finite(X %*% coef(iid)[colnames(X)])))
cat("ARTICLE_PUBLIC_OUTPUT_CHECK_PASS\nNo fits or article render executed. Community interpretation remains held.\n")
