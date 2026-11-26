## Coverage (cursor-cloud-1125x8g): init-warmstart.R residual and SVD start helpers.

test_that(".gllvmTMB_default_rr_lambda and pack/unpack round-trip", {
  lam <- gllvmTMB:::.gllvmTMB_default_rr_lambda(p = 4L, rank = 2L, scale = 2)
  expect_equal(dim(lam), c(4L, 2L))
  expect_equal(lam[1, 1], 1)
  expect_equal(lam[2, 2], 1)
  packed <- gllvmTMB:::.gllvmTMB_pack_rr_theta(lam)
  expect_length(packed, 2L + (4 - 1) + (4 - 2))
  expect_equal(packed[1:2], c(1, 1))
})

test_that(".gllvmTMB_lower_triangular_rotation fixes sign on diagonal", {
  L <- matrix(c(-1, 0.2, 0, -0.5), 2, 2)
  Z <- matrix(c(1, 2, 3, 4), 2, 2)
  rot <- gllvmTMB:::.gllvmTMB_lower_triangular_rotation(L, Z)
  expect_gte(rot$loadings[1, 1], 0)
  expect_gte(rot$loadings[2, 2], 0)
  expect_equal(dim(rot$loadings), dim(L))
  expect_equal(dim(rot$scores), dim(Z))
})

test_that(".gllvmTMB_group_trait_residual_matrix aggregates by group and trait", {
  resid <- c(1, 2, 3, 4, 5, 6)
  trait_id <- c(0L, 0L, 1L, 1L, 0L, 1L)
  group_id <- c(0L, 1L, 0L, 1L, 0L, 1L)
  mat <- gllvmTMB:::.gllvmTMB_group_trait_residual_matrix(
    resid, trait_id, group_id, n_traits = 2L, n_groups = 2L
  )
  expect_equal(dim(mat$resid), c(2L, 2L))
  expect_true(all(mat$count >= 0L))
  expect_true(any(mat$count > 0L))
})

test_that(".gllvmTMB_residual_factor_start returns usable starts for simple grid", {
  set.seed(8)
  n_g <- 6L
  n_t <- 3L
  resid <- rnorm(n_g * n_t)
  trait_id <- rep(seq_len(n_t) - 1L, each = n_g)
  group_id <- rep(seq_len(n_g) - 1L, times = n_t)
  out <- gllvmTMB:::.gllvmTMB_residual_factor_start(
    resid, trait_id, group_id, n_traits = n_t, n_groups = n_g, rank = 1L
  )
  expect_type(out, "list")
  expect_true(is.logical(out$usable))
  expect_length(out$theta_diag, n_t)
  expect_true(all(is.finite(out$theta_diag)))
})

test_that(".gllvmTMB_loading_start_scale respects floor and non-finite", {
  expect_equal(gllvmTMB:::.gllvmTMB_loading_start_scale(NA), 1)
  expect_equal(gllvmTMB:::.gllvmTMB_loading_start_scale(c(0, 0, 0)), 1)
  expect_equal(gllvmTMB:::.gllvmTMB_loading_start_scale(c(1, 2, 3), floor = 5), 5)
})

test_that(".gllvmTMB_theta_relative_loading and runaway guard", {
  theta <- c(1, 0.2, 0.05)
  rel <- gllvmTMB:::.gllvmTMB_theta_relative_loading(theta, n_traits = 3L, rank = 1L)
  expect_true(is.finite(rel))
  expect_gt(rel, 0)
  thresh <- gllvmTMB:::.gllvmTMB_runaway_thresh_default()
  expect_true(is.finite(thresh) && thresh > 0)
  guard <- gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    theta_new = theta * 50,
    theta_old = theta,
    n_traits = 3L,
    rank = 1L,
    thresh = thresh
  )
  expect_type(guard$blocked, "logical")
  expect_true(is.finite(guard$rel_new) || is.na(guard$rel_new))
})

test_that(".gllvm_univariate_phi handles gamma moments and unknown families", {
  y_g <- c(1, 2, 3, 4, 5)
  gam <- gllvmTMB:::.gllvm_univariate_phi(y_g, "gamma")
  expect_type(gam, "list")
  expect_true(is.finite(gam$log_phi))
  expect_null(gllvmTMB:::.gllvm_univariate_phi(y_g, "not_a_family"))
})

test_that(".gllvmTMB_apply_start_from rejects non-fits", {
  params <- list(b_fix = c(0, 0))
  expect_error(
    gllvmTMB:::.gllvmTMB_apply_start_from(params, start_from = list()),
    "gllvmTMB"
  )
})

test_that(".gllvmTMB_latent_score_start and svd start on toy residuals", {
  set.seed(3)
  n_g <- 8L
  n_t <- 2L
  resid <- rnorm(n_g * n_t)
  trait_id <- rep(0:1, each = n_g)
  group_id <- rep(0:(n_g - 1L), times = n_t)
  z <- gllvmTMB:::.gllvmTMB_latent_score_start(
    resid, trait_id, group_id, n_traits = n_t, n_groups = n_g, rank = 1L
  )
  if (!is.null(z)) {
    expect_equal(dim(z), c(1L, n_g))
  }
  svd <- gllvmTMB:::.gllvmTMB_svd_latent_start(
    resid, trait_id, group_id, n_traits = n_t, n_groups = n_g, rank = 1L
  )
  if (!is.null(svd)) {
    expect_type(svd$theta, "double")
    expect_equal(nrow(svd$z), 1L)
    expect_equal(ncol(svd$z), n_g)
  }
})