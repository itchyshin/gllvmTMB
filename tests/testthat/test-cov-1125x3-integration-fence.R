test_that(".gllvmTMB_integration_fence_limits() lists admitted VA families", {
  lim <- gllvmTMB:::.gllvmTMB_integration_fence_limits()
  expect_true(all(c("families", "links", "q_max", "p_max", "n_min") %in% names(lim)))
  expect_equal(lim$q_max, 2L)
  expect_equal(lim$p_max, 80L)
  expect_equal(lim$n_min, 100L)
  expect_true("poisson" %in% lim$families)
})

test_that("laplace integration passes the fence silently", {
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_integration_fence("laplace")
  )
})

test_that("VA fence refuses non-tmb engine", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", engine = "julia"
    ),
    "variational route"
  )
})

test_that("VA fence refuses unique = TRUE Psi model", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", unique = TRUE
    ),
    "diagonal"
  )
})

test_that("VA fence refuses q above evidenced maximum", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", q = 5L
    ),
    "q"
  )
})

test_that("VA fence validates family/link length mismatch", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va",
      family = c("poisson", "binomial"),
      link = c("log", "logit", "probit")
    ),
    "unequal length"
  )
})

test_that("VA fence refuses unknown family", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", family = "not_a_family"
    ),
    "no admitted"
  )
})

test_that("VA fence refuses wrong link for a family", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va", family = "poisson", link = "logit"
    ),
    "not admitted"
  )
})