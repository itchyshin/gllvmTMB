.diag_meta_fit <- function() {
  meta <- list(
    data = data.frame(
      trait = c("a", "b"),
      status = c("ok", "warn"),
      residual = c(0.1, -0.2)
    ),
    fit_health_status = data.frame(
      status = c("PASS", "WARN"),
      n = c(3L, 1L)
    ),
    check_gllvmTMB = data.frame(
      component = c("optimizer_convergence", "loading_runaway"),
      status = c("PASS", "PASS"),
      value = c("0", "below"),
      threshold = c(NA_character_, NA_character_),
      message = c("", ""),
      action = c("", ""),
      stringsAsFactors = FALSE
    )
  )
  structure(
    data.frame(x = 1:2),
    gllvmTMB_diagnostic = meta,
    class = "data.frame"
  )
}

test_that("diagnostic_table data strips diagnostic attributes", {
  x <- .diag_meta_fit()
  out <- diagnostic_table(x, table = "data")
  expect_null(attr(out, "gllvmTMB_diagnostic"))
  expect_null(attr(out, "method"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$trait, c("a", "b"))
})

test_that("diagnostic_table row_status tabulates statuses", {
  x <- .diag_meta_fit()
  out <- diagnostic_table(x, table = "row_status")
  expect_equal(out$n, c(1L, 1L))
  expect_true(all(out$status %in% c("ok", "warn")))
})

test_that("diagnostic_table fit_health_status returns attached table", {
  x <- .diag_meta_fit()
  out <- diagnostic_table(x, table = "fit_health_status")
  expect_equal(out$status, c("PASS", "WARN"))
  expect_equal(out$n, c(3L, 1L))
})

test_that("diagnostic_table check_gllvmTMB returns component rows", {
  x <- .diag_meta_fit()
  out <- diagnostic_table(x, table = "check_gllvmTMB")
  expect_equal(out$component, c("optimizer_convergence", "loading_runaway"))
  expect_equal(out$status, c("PASS", "PASS"))
})

test_that(".gllvmTMB_diagnostic_row_status_table fills missing status", {
  meta <- list(data = data.frame(x = 1:3, status = c("ok", NA, "")))
  x <- structure(data.frame(x = 1), gllvmTMB_diagnostic = meta)
  out <- gllvmTMB:::.gllvmTMB_diagnostic_row_status_table(x, meta)
  expect_true("missing" %in% out$status)
})