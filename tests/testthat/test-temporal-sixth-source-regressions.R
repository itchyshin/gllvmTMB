test_that("ordinary covariance providers remain ordinary when temporal is absent", {
  dat <- expand.grid(
    series = paste0("s", 1:5), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat)) / 10
  for (term in list(
    quote(dep(0 + trait | series)),
    quote(latent(0 + trait | series, d = 1, unique = FALSE))
  )) {
    form <- as.formula(call("~", quote(value), call("+", quote(0 + trait), term)))
    fit <- suppressWarnings(gllvmTMB(form, data = dat, unit = "series",
      family = gaussian(), silent = TRUE))
    expect_false(isTRUE(fit$temporal$active))
    expect_equal(fit$tmb_data$use_temporal, 0L)
  }
})

test_that("the fixed retained seed plan has two separate 50-fit cells", {
  plan <- rbind(
    data.frame(structure = "ar1", seed = 26091000L + seq_len(50L)),
    data.frame(structure = "ou", seed = 26091100L + seq_len(50L))
  )
  expect_equal(nrow(plan), 100L)
  expect_equal(as.integer(table(plan$structure)), c(50L, 50L))
  expect_equal(anyDuplicated(plan[c("structure", "seed")]), 0L)
})
