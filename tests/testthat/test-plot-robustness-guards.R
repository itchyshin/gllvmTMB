# Robustness guards for plotting helpers (twin-review issues
# #651/#692 rotated-loadings ordering, #691 null_region validation).

test_that(".gtmb_rotated_loadings_trait_order tolerates an all-NA trait (#651/#692)", {
  dat <- data.frame(
    trait       = rep(c("t1", "t2"), each = 2L),
    axis        = rep(c("Axis1", "Axis2"), times = 2L),
    loading     = c(0.5, 0.2, NA_real_, NA_real_),
    abs_loading = c(0.5, 0.2, NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  for (s in c("dominant", "abs_loading")) {
    ord <- expect_no_error(
      gllvmTMB:::.gtmb_rotated_loadings_trait_order(dat, sort = s)
    )
    # The all-NA trait is parked, not dropped: both traits survive.
    expect_setequal(ord, c("t1", "t2"))
  }
})

test_that("plot_loadings_confidence_eye() rejects a malformed null_region (#691)", {
  df <- data.frame(
    trait = "t1", axis = "Axis1", estimate = 0.3, se = 0.1,
    lower = 0.1, upper = 0.5, pinned = FALSE, stringsAsFactors = FALSE
  )
  expect_error(
    plot_loadings_confidence_eye(df, null_region = c(0.1)),
    regexp = "length-2 finite numeric"
  )
  expect_error(
    plot_loadings_confidence_eye(df, null_region = c(-0.1, NA_real_)),
    regexp = "length-2 finite numeric"
  )
  expect_error(
    plot_loadings_confidence_eye(df, null_region = "wide"),
    regexp = "length-2 finite numeric"
  )
})
