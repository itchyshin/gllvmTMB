test_that("all-zero observation weights are refused before optimization (#1950)", {
  skip_on_cran()
  set.seed(48)
  dat <- data.frame(
    site = rep(1:5, each = 2),
    trait = rep(c("a", "b"), times = 5),
    value = rnorm(10)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      weights = rep(0, nrow(dat)),
      silent = TRUE,
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    ))),
    "zero likelihood weight"
  )
})