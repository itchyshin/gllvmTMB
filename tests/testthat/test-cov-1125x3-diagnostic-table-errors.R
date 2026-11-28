test_that("diagnostic_table() aborts without metadata on a plain data frame", {
  df <- data.frame(x = 1:3)
  expect_error(
    diagnostic_table(df, table = "data"),
    "diagnostic metadata"
  )
})

test_that("diagnostic_table() row_status falls back when status is absent", {
  meta <- list(
    data = data.frame(x = 1:2),
    fit_health_status = data.frame(status = "PASS", n = 1L)
  )
  x <- structure(data.frame(x = 1:2), gllvmTMB_diagnostic = meta)
  out <- diagnostic_table(x, table = "row_status")
  expect_equal(out$status, "not_recorded")
  expect_equal(out$n, 2L)
})

test_that("diagnostic_table() surfaces fit_health_error as ERROR row", {
  meta <- list(
    data = data.frame(x = 1),
    fit_health_error = c(check_gllvmTMB = "sdreport failed")
  )
  x <- structure(list(), gllvmTMB_diagnostic = meta, class = "ggplot")
  out <- diagnostic_table(x, table = "check_gllvmTMB")
  expect_equal(out$status, "ERROR")
  expect_match(out$message, "sdreport failed")
})

test_that("diagnostic_table() aborts when no check table or error is present", {
  meta <- list(data = data.frame(x = 1))
  x <- structure(list(), gllvmTMB_diagnostic = meta)
  expect_error(
    diagnostic_table(x, table = "check_gllvmTMB"),
    "No"
  )
})

test_that("diagnostic_table() match.arg rejects unknown table", {
  meta <- list(
    data = data.frame(x = 1),
    fit_health_status = data.frame(status = "PASS", n = 1L)
  )
  x <- structure(data.frame(x = 1), gllvmTMB_diagnostic = meta)
  expect_error(diagnostic_table(x, table = "not_a_table"), "should be one of")
})