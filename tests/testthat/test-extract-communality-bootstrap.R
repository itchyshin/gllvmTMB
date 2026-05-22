make_bootstrap_communality_object <- function() {
  c2 <- c(length = 0.62, mass = 0.38, wing = 0.71)
  boot <- list(
    point_est = list(communality_B = c2),
    ci_lower = list(communality_B = pmax(0, c2 - 0.10)),
    ci_upper = list(communality_B = pmin(1, c2 + 0.12)),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 30L,
    n_failed = 2L,
    level = "B",
    what = "communality",
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")
  boot
}

test_that("extract_communality accepts bootstrap_Sigma point estimates", {
  boot <- make_bootstrap_communality_object()
  c2 <- extract_communality(boot, level = "unit")

  expect_type(c2, "double")
  expect_named(c2, c("length", "mass", "wing"))
  expect_equal(c2, boot$point_est$communality_B)
})

test_that("extract_communality accepts bootstrap_Sigma interval rows", {
  boot <- make_bootstrap_communality_object()
  tbl <- extract_communality(boot, level = "unit", ci = TRUE)

  expect_s3_class(tbl, "data.frame")
  expect_named(tbl, c("trait", "tier", "c2", "lower", "upper", "method"))
  expect_equal(tbl$trait, c("length", "mass", "wing"))
  expect_equal(unique(tbl$tier), "B")
  expect_equal(unique(tbl$method), "bootstrap")
  expect_equal(tbl$c2, as.numeric(boot$point_est$communality_B))
  expect_equal(tbl$lower, as.numeric(boot$ci_lower$communality_B))
  expect_equal(tbl$upper, as.numeric(boot$ci_upper$communality_B))
  expect_equal(attr(tbl, "bootstrap")$n_failed, 2L)
})

test_that("extract_communality reports missing bootstrap communality levels", {
  boot <- make_bootstrap_communality_object()

  expect_error(
    extract_communality(boot, level = "unit_obs", ci = TRUE),
    regexp = "not present"
  )
  boot$point_est$communality_B <- NULL
  expect_error(
    extract_communality(boot, level = "unit", ci = TRUE),
    regexp = "No communality bootstrap summaries"
  )
})
