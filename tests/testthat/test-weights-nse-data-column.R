test_that("weights = bare column name resolves from data (refs #1920)", {
  skip_if_not_installed("gllvmTMB")

  options(gllvmTMB.warn_unit_default = FALSE)

  set.seed(1126L)
  df <- expand.grid(
    site = factor(1:10),
    trait = c("a", "b"),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- rnorm(nrow(df))
  df$wt <- runif(nrow(df), 0.8, 1.2)

  fit_symbol <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = df,
    unit = "site",
    family = gaussian(),
    weights = wt
  ))
  fit_explicit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = df,
    unit = "site",
    family = gaussian(),
    weights = df$wt
  ))

  expect_equal(coef(fit_symbol), coef(fit_explicit), tolerance = 1e-8)
  expect_equal(
    fit_symbol$tmb_data$weights_i,
    fit_explicit$tmb_data$weights_i,
    tolerance = 1e-8
  )
})