## Coverage (2026-11-25): edges of R/reportable-table.R.

test_that(".reportable_table() passes non-data.frames through unchanged", {
  expect_identical(gllvmTMB:::.reportable_table(3), 3)
  expect_identical(gllvmTMB:::.reportable_table("x"), "x")
})

test_that("print.gllvmTMB_reportable_table leaves substantive columns visible", {
  df <- data.frame(
    from = c("a", "b"),
    to = c("b", "c"),
    estimate = c(0.2, 0.5)
  )
  tbl <- gllvmTMB:::.reportable_table(df)
  printed <- capture.output(print(tbl))
  expect_false(any(grepl("validation_row", printed)))
  expect_true(any(grepl("estimate", printed)))
})