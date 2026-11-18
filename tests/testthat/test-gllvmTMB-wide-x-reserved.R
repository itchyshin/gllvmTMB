# Issue #1416: X columns must not collide with long-format pivot names.

test_that("gllvmTMB_wide(): reserved X column names abort before fit", {
  Y <- matrix(
    rnorm(20),
    nrow = 5,
    ncol = 4,
    dimnames = list(
      paste0("u", seq_len(5)),
      paste0("t", seq_len(4))
    )
  )
  reserved <- c("value", "site", "trait", "species", "site_species")
  for (nm in reserved) {
    X <- data.frame(rnorm(5))
    names(X) <- nm
    expect_error(
      suppressWarnings(
        gllvmTMB_wide(
          Y,
          X = X,
          d = 1,
          formula_extra = stats::as.formula(paste("~", nm)),
          silent = TRUE
        )
      ),
      regexp = "reserved",
      label = nm
    )
  }
})
