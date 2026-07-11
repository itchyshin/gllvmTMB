# The report-ready covariance/correlation tables keep an internal `validation_row`
# provenance column (needed by machinery + tests) but must not surface it when
# printed reader-facing. .reportable_table() tags the object and the print method
# hides the internal columns from display while leaving them in the object.

test_that(".reportable_table tags a data frame without dropping columns", {
  df <- data.frame(
    trait = c("a", "b"),
    estimate = c(1.2, 3.4),
    validation_row = c("EXT-18", "EXT-18"),
    stringsAsFactors = FALSE
  )
  tbl <- gllvmTMB:::.reportable_table(df)

  expect_s3_class(tbl, "gllvmTMB_reportable_table")
  expect_s3_class(tbl, "data.frame")        # still inherits data.frame
  expect_true(is.data.frame(tbl))
  expect_true("validation_row" %in% names(tbl))  # column retained for machinery
  expect_identical(tbl$validation_row, df$validation_row)
})

test_that("print hides internal provenance columns but shows substantive ones", {
  df <- data.frame(
    trait = "a",
    estimate = 1.2,
    validation_row = "EXT-18",
    stringsAsFactors = FALSE
  )
  tbl <- gllvmTMB:::.reportable_table(df)

  printed <- capture.output(print(tbl))
  # register code / internal column name must not appear in printed output
  expect_false(any(grepl("validation_row", printed)))
  expect_false(any(grepl("EXT-18", printed)))
  # substantive columns still shown
  expect_true(any(grepl("estimate", printed)))
  expect_true(any(grepl("trait", printed)))
  # printing returns the object invisibly, unchanged
  expect_identical(print(tbl), tbl)
})

test_that("print is a no-op passthrough when there are no internal columns", {
  df <- data.frame(trait = "a", estimate = 1.2, stringsAsFactors = FALSE)
  tbl <- gllvmTMB:::.reportable_table(df)
  printed <- capture.output(print(tbl))
  expect_true(any(grepl("estimate", printed)))
})
