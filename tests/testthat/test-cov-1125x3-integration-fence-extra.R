test_that("VA fence passes admitted poisson log cell", {
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", family = "poisson", link = "log", q = 1L, p = 4L, n = 120L
    )
  )
})

test_that("VA fence refuses n below minimum", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", n = 20L
    ),
    "units"
  )
})

test_that("VA fence refuses p above maximum", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", p = 200L
    ),
    "responses"
  )
})

test_that("VA fence broadcasts a single link across traits", {
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va",
      family = c("poisson", "poisson"),
      link = "log",
      q = 1L,
      p = 4L,
      n = 120L
    )
  )
})

test_that("integration fence limits include binomial links", {
  lim <- gllvmTMB:::.gllvmTMB_integration_fence_limits()
  expect_true("binomial" %in% names(lim$links))
  expect_true(all(lim$links[grepl("^binomial", names(lim$links))] %in% c("logit", "probit", "cloglog")))
})

test_that("VA fence broadcasts a single family across links is rejected when invalid", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va",
      family = "binomial",
      link = c("logit", "log")
    ),
    "not admitted"
  )
})