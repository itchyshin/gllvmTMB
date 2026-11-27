test_that("I(pkg::fun()) fixed terms evaluate in the formula environment (#1967)", {
  set.seed(7L)
  dd <- expand.grid(
    unit = factor(1:12),
    trait = factor(paste0("t", 1:2))
  )
  dd$x <- rep(stats::runif(12), each = 2)
  dd$value <- stats::rnorm(nrow(dd))
  f <- value ~ 0 + trait + I(splines::ns(x, 2))
  parsed <- gllvmTMB:::parse_multi_formula(f)
  expect_false(is.null(environment(parsed$fixed)))
  expect_no_error(stats::model.frame(parsed$fixed, data = dd, na.action = stats::na.pass))
  fit <- expect_no_error(
    gllvmTMB(
      f,
      data = dd,
      unit = "unit",
      trait = "trait",
      family = gaussian(),
      control = gllvmTMBcontrol(trace = 0)
    )
  )
  expect_s3_class(fit, "gllvmTMB")
})