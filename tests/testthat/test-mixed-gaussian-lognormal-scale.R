make_joint_gaussian_lognormal_scale_mock <- function(
    sigma = c(gaussian = 0.2, lognormal = 0.8)) {
  list(
    tmb_data = list(
      trait_id = c(0L, 1L),
      family_id_vec = c(0L, 3L),
      link_id_vec = c(0L, 0L)
    ),
    report = list(sigma_eps = sigma),
    opt = list(
      par = stats::setNames(log(unname(sigma)), rep("log_sigma_eps", 2L))
    )
  )
}

test_that("continuous residual scale dispatch preserves the scalar contract", {
  gaussian <- list(
    tmb_data = list(family_id_vec = 0L),
    report = list(sigma_eps = 0.35),
    opt = list(par = c(log_sigma_eps = log(0.35)))
  )
  lognormal <- list(
    tmb_data = list(family_id_vec = 3L),
    report = list(sigma_eps = 0.55),
    opt = list(par = c(log_sigma_eps = log(0.55)))
  )

  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(gaussian, 0L),
    0.35
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(lognormal, 3L),
    0.55
  )
})

test_that("joint Gaussian and lognormal rows select different scale slots", {
  fit <- make_joint_gaussian_lognormal_scale_mock()

  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 0L),
    0.2
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 3L),
    0.8
  )
})

test_that("scale fallback reads both repeated TMB parameter names", {
  fit <- make_joint_gaussian_lognormal_scale_mock()
  fit$report$sigma_eps <- numeric(0)

  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 0L),
    0.2
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 3L),
    0.8
  )
})

test_that("row-wise inverse links use the lognormal scale slot", {
  sigma <- c(gaussian = 0.2, lognormal = 0.8)
  eta <- c(0, 0)
  family_id <- c(0L, 3L)
  link_id <- c(0L, 0L)

  expected <- c(0, exp(0.5 * 0.8^2))
  expect_equal(
    gllvmTMB:::.apply_linkinv_per_row(
      eta,
      family_id,
      link_id,
      sigma_eps = sigma
    ),
    expected
  )
  expect_equal(
    gllvmTMB:::.dlinkinv_per_row(
      eta,
      family_id,
      link_id,
      sigma_eps = sigma
    ),
    c(1, expected[[2L]])
  )
})

test_that("family CDF arguments use the matching continuous scale", {
  fit <- make_joint_gaussian_lognormal_scale_mock()
  gaussian <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 1L)
  lognormal <- gllvmTMB:::.gllvmTMB_family_cdf_args(fit, 2L)

  expect_equal(gaussian$args$sd, 0.2)
  expect_equal(lognormal$args$sdlog, 0.8)
  expect_match(gaussian$note, "Gaussian|raw-scale")
  expect_match(lognormal$note, "lognormal|log-scale")
})
