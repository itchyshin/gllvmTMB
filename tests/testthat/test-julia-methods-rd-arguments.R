test_that("Julia methods help documents each argument once", {
  skip_if_not(file.exists(test_path("..", "..", "man", "gllvmTMB_julia-methods.Rd")))
  rd <- tools::parse_Rd(test_path("..", "..", "man", "gllvmTMB_julia-methods.Rd"))
  args <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\arguments"), rd)[[1L]]
  items <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\item"), args)
  names <- trimws(unlist(strsplit(vapply(items, function(x) paste(unlist(x[[1L]]), collapse = ""), ""), ",")))
  expect_false(anyDuplicated(names) > 0L, info = paste(names, collapse = ", "))
  expect_true(all(c("object", "x", "effects") %in% names))
})
