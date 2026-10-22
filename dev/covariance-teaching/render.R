args <- commandArgs(trailingOnly = TRUE)
article <- args[[1L]]
expected <- c(`covariance-correlation` = 3L, `cross-family-correlations` = 2L,
              `spatial-models` = 4L)[[article]]
stopifnot(!is.null(expected))
root <- normalizePath(".")
options(sass.cache = file.path(root, "dev/covariance-teaching/cache"))
receipt_dir <- file.path(root, "dev/covariance-teaching/receipts")
fit_log <- file.path(receipt_dir, paste0(article, "-fits.log"))
warning_log <- file.path(receipt_dir, paste0(article, "-warnings.log"))
stopifnot(!file.exists(fit_log), !file.exists(warning_log))
file.create(fit_log, warning_log)
library(gllvmTMB)
cat("Installed package:", find.package("gllvmTMB"), "\n")
.fit_receipt <- new.env(parent = emptyenv())
.fit_receipt$count <- 0L
.fit_receipt$depth <- 0L
.fit_receipt$convergence <- integer()
trace("gllvmTMB", where = as.environment("package:gllvmTMB"), print = FALSE,
      tracer = quote({
        .fit_receipt$depth <- .fit_receipt$depth + 1L
        if (.fit_receipt$depth == 1L) {
          .fit_receipt$count <- .fit_receipt$count + 1L
          cat("START", .fit_receipt$count, format(Sys.time()), "\n", file = fit_log, append = TRUE)
        }
      }),
      exit = quote({
        if (.fit_receipt$depth == 1L) {
          result <- returnValue()
          convergence <- result$opt$convergence
          .fit_receipt$convergence <- c(.fit_receipt$convergence, convergence)
          cat("END", .fit_receipt$count, "convergence", convergence,
              "message", result$opt$message, "\n", file = fit_log, append = TRUE)
        }
        .fit_receipt$depth <- .fit_receipt$depth - 1L
      }))
# Retain suppressed article warnings without changing the executed code or HTML.
# evaluate captures them normally, then knitr receives the original warning policy.
knitr::knit_hooks$set(evaluate = function(...) {
  a <- list(...)
  original <- a$keep_warning
  a$keep_warning <- TRUE
  out <- do.call(evaluate::evaluate, a)
  is_warning <- vapply(out, inherits, logical(1), "warning")
  for (w in out[is_warning]) {
    cat("chunk:", knitr::opts_current$get("label"), "\n", conditionMessage(w),
        "\n", file = warning_log, append = TRUE)
  }
  if (identical(original, FALSE)) out <- out[!is_warning]
  out
})
pkgdown::build_article(paste0("articles/", article), lazy = FALSE,
                       new_process = FALSE, quiet = FALSE)
stopifnot(.fit_receipt$count == expected,
          length(.fit_receipt$convergence) == expected)
cat("ARTICLE_FIT_COUNT", .fit_receipt$count, "\n")
cat("CONVERGENCE", .fit_receipt$convergence, "\n")
if (any(.fit_receipt$convergence != 0L)) stop("Nonzero optimizer convergence; retain and report")
cat("ARTICLE_RENDER_VERIFIED\n")
