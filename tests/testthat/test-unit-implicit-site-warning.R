test_that("implicit unit = site warning does not claim 0.8.0 removal", {
  withr::local_options(gllvmTMB.warned_unit_implicit_site = NULL)
  data <- data.frame(
    site = factor(c("s1", "s2")),
    trait = factor(c("t1", "t1")),
    value = c(1, 2),
    stringsAsFactors = FALSE
  )
  w <- capture_warnings(
    gllvmTMB:::.gllvmTMB_resolve_unit_staged(NULL, data)
  )
  expect_length(w, 1L)
  expect_false(grepl("0\\.8\\.0", w))
  expect_match(w, "future release", ignore.case = TRUE)
  expect_equal(
    suppressWarnings(gllvmTMB:::.gllvmTMB_resolve_unit_staged(NULL, data)),
    "site"
  )
})
