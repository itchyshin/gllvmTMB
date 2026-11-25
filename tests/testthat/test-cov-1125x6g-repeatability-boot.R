test_that(".repeatability_bootstrap_bound aligns named vectors", {
  traits <- c("a", "b", "c")
  x <- c(a = 0.1, b = 0.2, c = 0.3)
  out <- .repeatability_bootstrap_bound(x, traits, "lower")
  expect_equal(out, c(0.1, 0.2, 0.3))
  expect_equal(
    .repeatability_bootstrap_bound(NULL, traits, "upper"),
    rep(NA_real_, 3L)
  )
})

test_that(".repeatability_bootstrap_bound errors on bad names or type", {
  traits <- c("a", "b")
  expect_error(
    .repeatability_bootstrap_bound(c(x = 1), traits, "lower"),
    "names"
  )
  expect_error(
    .repeatability_bootstrap_bound("bad", traits, "lower"),
    "numeric"
  )
  expect_error(
    .repeatability_bootstrap_bound(c(1, 2, 3), traits, "lower"),
    "length"
  )
})

test_that(".repeatability_from_bootstrap validates bootstrap list", {
  expect_error(.repeatability_from_bootstrap("x"), "list")
  expect_error(.repeatability_from_bootstrap(list()), "ICC")
  bad <- list(point_est = list(ICC_site = c(NA, NA)))
  expect_error(.repeatability_from_bootstrap(bad), "Malformed")
})