test_that("parse_multi_formula handles namespace-qualified fixed-effect calls (#1966)", {
  withr::local_envvar(c("_R_CHECK_LENGTH_1_CONDITION_" = "true"))
  cases <- list(
    splines_ns = value ~ 0 + trait + splines::ns(x, 2),
    stats_poly = value ~ 0 + trait + stats::poly(x, 2),
    base_log1p = value ~ 0 + trait + base::log1p(x)
  )
  for (nm in names(cases)) {
    parsed <- gllvmTMB:::parse_multi_formula(cases[[nm]])
    expect_s3_class(parsed$fixed, "formula")
    expect_true(any(grepl("::", deparse(parsed$fixed[[length(parsed$fixed)]]))))
  }
})

test_that("namespaced fixed-effect calls do not crash gllvmTMB() parse (#1966)", {
  withr::local_envvar(c("_R_CHECK_LENGTH_1_CONDITION_" = "true"))
  set.seed(7L)
  dd <- expand.grid(
    unit = factor(1:12),
    trait = factor(paste0("t", 1:2))
  )
  dd$x <- rep(stats::runif(12), each = 2)
  dd$value <- stats::rnorm(nrow(dd))
  fit <- expect_no_error(
    gllvmTMB(
      value ~ 0 + trait + stats::poly(x, 2),
      data = dd,
      unit = "unit",
      trait = "trait",
      family = gaussian(),
      control = gllvmTMBcontrol(trace = 0)
    )
  )
  expect_s3_class(fit, "gllvmTMB")
})