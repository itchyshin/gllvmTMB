test_that("safe_deparse() honors collapse argument", {
  x <- quote(a + b + c)
  expect_equal(
    gllvmTMB:::safe_deparse(x, collapse = ""),
    paste(deparse(x, 500L), collapse = "")
  )
})

test_that("extract_call_name() keeps short strings intact", {
  sym <- quote(trait)
  out <- gllvmTMB:::extract_call_name(sym, max_width = 80L)
  expect_equal(out, "trait")
  expect_false(grepl("\\.\\.\\.", out))
})

test_that("integration fence limits links are named by family", {
  lim <- gllvmTMB:::.gllvmTMB_integration_fence_limits()
  expect_true(is.character(names(lim$links)))
  expect_true("poisson" %in% names(lim$links))
  expect_equal(unname(lim$links["poisson"]), "log")
})

test_that("estimator compatibility table has one row per admitted route", {
  tbl <- gllvmTMB:::.gllvmTMB_estimator_compatibility_table()
  expect_gte(nrow(tbl), 6L)
  expect_true(all(tbl$accepted))
  expect_true(any(tbl$public_estimator == "mspl"))
  expect_true(any(tbl$criterion_id == "va_elbo"))
  expect_identical(
    sort(unique(tbl$integration)),
    c("aghq", "laplace", "va")
  )
})