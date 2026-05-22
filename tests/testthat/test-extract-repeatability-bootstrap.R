make_bootstrap_repeatability_object <- function() {
  R <- c(length = 0.42, mass = 0.58, wing = 0.31)
  boot <- list(
    point_est = list(ICC_site = R),
    ci_lower = list(ICC_site = pmax(0, R - 0.09)),
    ci_upper = list(ICC_site = pmin(1, R + 0.11)),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 30L,
    n_failed = 1L,
    level = c("B", "W"),
    what = "ICC",
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")
  boot
}

test_that("extract_repeatability accepts bootstrap_Sigma interval rows", {
  boot <- make_bootstrap_repeatability_object()
  tbl <- extract_repeatability(boot)

  expect_s3_class(tbl, "data.frame")
  expect_named(tbl, c("trait", "R", "lower", "upper", "method"))
  expect_equal(tbl$trait, c("length", "mass", "wing"))
  expect_equal(unique(tbl$method), "bootstrap")
  expect_equal(tbl$R, as.numeric(boot$point_est$ICC_site))
  expect_equal(tbl$lower, as.numeric(boot$ci_lower$ICC_site))
  expect_equal(tbl$upper, as.numeric(boot$ci_upper$ICC_site))
  expect_equal(attr(tbl, "bootstrap")$n_failed, 1L)
})

test_that("extract_repeatability reports missing bootstrap ICC summaries", {
  boot <- make_bootstrap_repeatability_object()
  boot$point_est$ICC_site <- NULL

  expect_error(
    extract_repeatability(boot),
    regexp = "No repeatability / ICC bootstrap summary"
  )
})
