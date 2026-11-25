## Coverage (cursor-cloud-1125x7g): R/families.R tweedie helpers and family shells.

test_that("Tweedie p bounds sit inside (1, 2)", {
  b <- gllvmTMB:::.gllvmTMB_tweedie_p_bounds()
  expect_named(b, c("lo", "hi"))
  expect_gt(b[["lo"]], 1)
  expect_lt(b[["hi"]], 2)
  expect_lt(b[["lo"]], b[["hi"]])
})

test_that("Tweedie theta maps interior p back and forth", {
  b <- gllvmTMB:::.gllvmTMB_tweedie_p_bounds()
  p_mid <- mean(unname(b))
  th <- gllvmTMB:::.gllvmTMB_tweedie_theta(p_mid)
  expect_true(is.finite(th))
  p_back <- gllvmTMB:::.gllvmTMB_tweedie_p(th)
  expect_equal(p_back, p_mid, tolerance = 1e-10)
})

test_that("Tweedie theta is non-finite outside open interval", {
  b <- gllvmTMB:::.gllvmTMB_tweedie_p_bounds()
  out <- gllvmTMB:::.gllvmTMB_tweedie_theta(c(1, b[["lo"]], b[["hi"]], 2))
  expect_true(all(!is.finite(out)))
})

test_that("Tweedie bound theta signs match endpoint side", {
  expect_gt(gllvmTMB:::.gllvmTMB_tweedie_bound_theta(TRUE), 0)
  expect_lt(gllvmTMB:::.gllvmTMB_tweedie_bound_theta(FALSE), 0)
})

test_that("Tweedie p_frac is bounded in magnitude", {
  vals <- gllvmTMB:::.gllvmTMB_tweedie_p_frac(c(-3, 0, 0.5, 2, 50))
  expect_true(all(is.finite(vals)))
  expect_true(all(abs(vals) <= 1 + 1e-12))
})

test_that("tweedie() family returns log link by default", {
  fam <- tweedie()
  expect_s3_class(fam, "family")
  expect_equal(fam$link, "log")
})

test_that("count family constructors expose expected links", {
  expect_equal(poisson()$link, "log")
  expect_equal(nbinom2()$link, "log")
  expect_equal(zi_binomial()$link, "logit")
  expect_equal(student()$link, "identity")
  expect_equal(Beta()$link, "logit")
})

test_that("truncated count families keep truncated names", {
  expect_equal(truncated_poisson()$family, "truncated_poisson")
  expect_equal(truncated_nbinom2()$family, "truncated_nbinom2")
})

test_that("tweedie_pinned_theta clamps out-of-range pin with warning", {
  b <- gllvmTMB:::.gllvmTMB_tweedie_p_bounds()
  too_high <- b[["hi"]] + 0.05
  expect_warning(
    th <- gllvmTMB:::.tweedie_pinned_theta(c(NA, too_high)),
    class = "gllvmTMB_tweedie_p_clamp"
  )
  expect_true(is.finite(th[2]))
  expect_equal(gllvmTMB:::.gllvmTMB_tweedie_p(th[2]), b[["hi"]], tolerance = 1e-8)
})

test_that("in-range tweedie pin preserves requested power", {
  b <- gllvmTMB:::.gllvmTMB_tweedie_p_bounds()
  p_req <- mean(unname(b))
  th <- gllvmTMB:::.tweedie_pinned_theta(p_req, warn = FALSE)
  expect_equal(gllvmTMB:::.gllvmTMB_tweedie_p(th), p_req, tolerance = 1e-10)
})

test_that("censored and zi constructors expose family ids", {
  expect_equal(censored_poisson()$family, "censored_poisson")
  expect_equal(zi_poisson()$family, "zi_poisson")
  expect_equal(zi_nbinom2()$family, "zi_nbinom2")
})