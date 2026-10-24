## #1493: a literal NULL argument in a formula call (e.g. positional
## `spatial_dep(0 + trait | group, NULL, mesh, 0.5)`) made .shared_rewrite()
## drop the element on `out[[i]] <- NULL` and then index past the shortened
## call, failing with "subscript out of bounds".

test_that(".shared_rewrite() keeps a literal NULL argument in place (#1493)", {
  e <- quote(y ~ spatial_dep(0 + trait | group, NULL, mesh, 0.5))
  out <- gllvmTMB:::.shared_rewrite(e, row_vars = "x")
  expect_identical(out, e)
  expect_length(out[[3L]], 5L)
  expect_null(out[[3L]][[3L]])
})

## #1493 (second part): `.warn_spatial_grouping_token()` read `rho` only when
## it was named, so a positional `rho` on a spatial_*() helper (the
## desugar_brms_sugar() path used by screen_gllvmTMB() and
## suggest_lambda_constraint()) was missed and the "token is ignored" notice
## fired although rho is not 1. It now matches positional arguments against
## the wrapper formals, so positional and named rho behave the same.
test_that("positional and named rho give the same grouping-token notice (#1493)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  seen <- getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen
  key <- "spatial-grouping-token-spatial_dep"
  had <- exists(key, envir = seen, inherits = FALSE)
  withr::defer({
    if (had) assign(key, TRUE, envir = seen) else
      if (exists(key, envir = seen, inherits = FALSE)) rm(list = key, envir = seen)
  })
  reset <- function() {
    if (exists(key, envir = seen, inherits = FALSE)) rm(list = key, envir = seen)
  }
  desugar <- function(rhs) {
    gllvmTMB:::desugar_brms_sugar(
      eval(parse(text = sprintf("y ~ 0 + trait + %s", rhs))),
      trait_col = "trait"
    )
  }

  ## Positional rho = 0.5 (with a literal NULL coords) reads the token as a
  ## location column: no notice, and the same rewritten call as named rho.
  reset()
  expect_no_warning(
    pos <- desugar("spatial_dep(0 + trait | group, NULL, mesh, 0.5)"),
    message = "grouping token is ignored"
  )
  reset()
  expect_no_warning(
    named <- desugar("spatial_dep(0 + trait | group, coords = NULL, mesh = mesh, rho = 0.5)"),
    message = "grouping token is ignored"
  )
  expect_identical(pos[[3L]], named[[3L]])

  ## Positional rho = 1 is the default: the notice must still fire.
  reset()
  expect_warning(
    desugar("spatial_dep(0 + trait | group, NULL, mesh, 1)"),
    "grouping token is ignored"
  )
})
