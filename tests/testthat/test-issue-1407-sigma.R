test_that("sigma() refuses gllvmTMB fits instead of stats::sigma.default (#1407)", {
  fit <- structure(list(logLik = structure(function(...) -10, class = "logLik")),
                   class = "gllvmTMB_multi")
  expect_error(sigma(fit), "not defined for")
  expect_error(stats::sigma(fit), "not defined for")
})

test_that("sigma methods are registered via @exportS3Method so document() keeps NAMESPACE (#1558)", {
  src <- test_path("..", "..", "R", "methods-gllvmTMB.R")
  skip_if_not(file.exists(src), "package source not available")
  lines <- readLines(src)
  for (cls in c("gllvmTMB_multi", "gllvmTMB_julia", "gllvmTMB_va")) {
    def <- grep(paste0("^sigma\\.", cls, " <- "), lines)
    expect_length(def, 1L)
    ## The roxygen block is the contiguous run of #' lines just above the definition.
    k <- def - 1L
    while (k > 0L && grepl("^#'", lines[k])) k <- k - 1L
    block <- lines[(k + 1L):(def - 1L)]
    expect_true(any(block == "#' @exportS3Method stats::sigma"),
                info = paste("sigma method for", cls))
    expect_false(any(block == "#' @export"), info = paste("sigma method for", cls))
  }
})
