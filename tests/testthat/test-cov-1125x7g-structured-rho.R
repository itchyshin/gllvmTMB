## Coverage (cursor-cloud-1125x7g): R/structured-rho.R validation and linear algebra.

test_that(".structured_rho_validate accepts NULL and unit rho", {
  expect_null(gllvmTMB:::.structured_rho_validate(NULL))
  expect_invisible(gllvmTMB:::.structured_rho_validate(1))
  expect_invisible(gllvmTMB:::.structured_rho_validate(0))
  expect_invisible(gllvmTMB:::.structured_rho_validate(0.42))
})

test_that(".structured_rho_validate refuses bad rho values", {
  for (bad in list(-0.1, 2, NA, c(0.5, 0.5), "x")) {
    expect_error(
      gllvmTMB:::.structured_rho_validate(bad),
      class = "gllvmTMB_structured_rho_invalid"
    )
  }
})

test_that(".structured_rho_covariance scales off-diagonals only", {
  K <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
  out <- gllvmTMB:::.structured_rho_covariance(K, 0.5)
  expect_equal(diag(out), diag(K))
  expect_equal(out[1, 2], 0.3)
  expect_equal(out[2, 1], 0.3)
  expect_equal(gllvmTMB:::.structured_rho_covariance(K, 1), K)
})

test_that(".structured_rho_covariance errors on NULL rho", {
  expect_error(gllvmTMB:::.structured_rho_covariance(diag(2), NULL), "numerical rho")
})

test_that(".structured_rho_intercept_lhs recognises trait heads", {
  expect_true(gllvmTMB:::.structured_rho_intercept_lhs(quote(1), "trait"))
  expect_true(gllvmTMB:::.structured_rho_intercept_lhs(quote(trait), "trait"))
  expect_true(gllvmTMB:::.structured_rho_intercept_lhs(quote(0 + trait), "trait"))
  expect_false(gllvmTMB:::.structured_rho_intercept_lhs(quote(x), "trait"))
})

test_that(".structured_rho_dispatch_fence passes native Laplace ML", {
  spec <- list(source = "phylo")
  expect_invisible(
    gllvmTMB:::.structured_rho_dispatch_fence(spec, engine = "tmb", integration = "laplace")
  )
  expect_null(gllvmTMB:::.structured_rho_dispatch_fence(NULL))
})

test_that(".structured_rho_dispatch_fence blocks VA engine", {
  expect_error(
    gllvmTMB:::.structured_rho_dispatch_fence(list(x = 1), integration = "va"),
    class = "gllvmTMB_structured_rho_dispatch"
  )
})

test_that(".structured_rho_spectral decomposes a correlation kernel", {
  K <- matrix(c(1, 0.3, 0.3, 1), 2, 2)
  sp <- gllvmTMB:::.structured_rho_spectral(K)
  expect_true(all(sp$values > 0))
  expect_equal(ncol(sp$vectors), 2L)
})

test_that(".structured_rho_assert_source requires contrast", {
  expect_error(
    gllvmTMB:::.structured_rho_assert_source(c(1, 1), 0),
    class = "gllvmTMB_structured_rho_identification"
  )
  expect_invisible(gllvmTMB:::.structured_rho_assert_source(c(1, 0.4), 0.2))
})

test_that(".structured_rho_print is quiet without metadata", {
  expect_invisible(gllvmTMB:::.structured_rho_print(NULL))
})

test_that(".parse_structured_rho_formula leaves ordinary formulas unchanged", {
  f <- y ~ 1 + latent(1 | unit, d = 1)
  out <- gllvmTMB:::.parse_structured_rho_formula(f)
  expect_s3_class(out$formula, "formula")
  expect_null(out$spec)
})