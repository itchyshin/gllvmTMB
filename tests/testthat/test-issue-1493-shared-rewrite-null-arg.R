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
