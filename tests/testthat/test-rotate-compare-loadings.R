# Tests for rotate_loadings() and compare_loadings().

# ---- helper --------------------------------------------------------------

make_rrB_fit <- function(seed = 1, d = 2, n_traits = 4) {
  set.seed(seed)
  Lam <- matrix(c(1.0, 0.5, -0.4, 0.3,
                  0.0, 0.8, 0.4, -0.2)[1:(n_traits * d)], n_traits, d)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = n_traits,
    mean_species_per_site = 1,
    Lambda_B = Lam, psi_B = rep(0, n_traits),
    beta = matrix(0, n_traits, 2), seed = seed
  )
  fmla <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | site, d = %d)", d
  ))
  suppressMessages(suppressWarnings(gllvmTMB(fmla, data = sim$data)))
}

# =================== rotate_loadings ====================================

test_that("rotate_loadings(): non-fit input errors", {
  expect_error(rotate_loadings("not-a-fit"), regexp = "gllvmTMB_multi")
})

test_that("rotate_loadings(): unknown method errors via match.arg", {
  fit <- make_rrB_fit(seed = 1, d = 2)
  expect_error(rotate_loadings(fit, "B", method = "oblimin"),
               regexp = "should be one of")
})

test_that("rotate_loadings(): unknown level errors via match.arg", {
  fit <- make_rrB_fit(seed = 1, d = 2)
  expect_error(rotate_loadings(fit, level = "Z"),
               regexp = "should be one of")
})

test_that("rotate_loadings(): errors when level not in fit", {
  fit <- make_rrB_fit(seed = 1, d = 2)
  expect_error(rotate_loadings(fit, "W", "varimax"),
               regexp = "latent.*not active")
})

test_that("rotate_loadings(method='none'): identity rotation", {
  fit <- make_rrB_fit(seed = 1, d = 2)
  rt <- rotate_loadings(fit, "B", "none")
  expect_named(rt, c("Lambda", "scores", "T", "method"))
  expect_equal(rt$method, "none")
  expect_equal(rt$T, diag(2))
  ## Lambda and scores should match the raw extraction
  ord <- suppressMessages(extract_ordination(fit, "B"))
  expect_equal(rt$Lambda, ord$loadings)
  expect_equal(rt$scores, ord$scores)
})

test_that("rotate_loadings(method='varimax'): T is orthogonal", {
  fit <- make_rrB_fit(seed = 7, d = 2)
  rt <- rotate_loadings(fit, "B", "varimax")
  ## T is orthogonal: T %*% t(T) == I
  expect_equal(rt$T %*% t(rt$T), diag(2), tolerance = 1e-8)
  expect_equal(t(rt$T) %*% rt$T, diag(2), tolerance = 1e-8)
})

test_that("rotate_loadings(method='varimax'): preserves Lambda Lambda' (rotation invariance)", {
  fit <- make_rrB_fit(seed = 11, d = 2)
  ord <- suppressMessages(extract_ordination(fit, "B"))
  L_raw <- ord$loadings
  rt <- rotate_loadings(fit, "B", "varimax")
  expect_equal(L_raw %*% t(L_raw),
               rt$Lambda %*% t(rt$Lambda),
               tolerance = 1e-8)
})

test_that("rotate_loadings(method='varimax'): scores rotated by T preserve Lambda %*% z", {
  fit <- make_rrB_fit(seed = 13, d = 2)
  ord <- suppressMessages(extract_ordination(fit, "B"))
  rt <- rotate_loadings(fit, "B", "varimax")
  ## Lambda_rot %*% z_rot' should equal Lambda %*% z' for each site
  L_raw <- ord$loadings
  Z_raw <- ord$scores                        # nrow = n_sites
  pred_raw <- Z_raw %*% t(L_raw)
  pred_rot <- rt$scores %*% t(rt$Lambda)
  expect_equal(pred_raw, pred_rot, tolerance = 1e-8)
})

test_that("rotate_loadings(method='promax'): returns matrix Lambda and rotation T", {
  fit <- make_rrB_fit(seed = 17, d = 2)
  rt <- rotate_loadings(fit, "B", "promax")
  expect_equal(rt$method, "promax")
  expect_true(is.matrix(rt$T))
  expect_equal(dim(rt$T), c(2, 2))
  expect_equal(dim(rt$Lambda), c(fit$n_traits, fit$d_B))
})

test_that("rotate_loadings(method='promax'): preserves linear predictor (Lambda %*% z)", {
  ## Promax T is oblique, so Z gets the inverse-transpose transform.
  ## Lambda_rot %*% z_rot' should still equal Lambda %*% z'.
  fit <- make_rrB_fit(seed = 19, d = 2)
  ord <- suppressMessages(extract_ordination(fit, "B"))
  rt <- rotate_loadings(fit, "B", "promax")
  pred_raw <- ord$scores %*% t(ord$loadings)
  pred_rot <- rt$scores  %*% t(rt$Lambda)
  expect_equal(pred_raw, pred_rot, tolerance = 1e-8)
})

# =================== compare_loadings ===================================

test_that("compare_loadings(): non-matrix input errors", {
  L <- matrix(rnorm(8), 4, 2)
  expect_error(compare_loadings(L, "not-a-matrix"), regexp = "matrices")
  expect_error(compare_loadings(1:8, L), regexp = "matrices")
})

test_that("compare_loadings(): mismatched dimensions errors", {
  La <- matrix(rnorm(8), 4, 2)
  Lb <- matrix(rnorm(6), 3, 2)
  expect_error(compare_loadings(La, Lb), regexp = "same dimensions")
})

test_that("compare_loadings(): identical inputs gives R close to identity, frobenius near 0", {
  set.seed(1)
  L <- matrix(rnorm(12), 4, 3)
  out <- compare_loadings(L, L)
  expect_named(out, c("R", "Lambda_a_rot", "frobenius", "cor_per_factor"))
  expect_equal(out$R, diag(3), tolerance = 1e-8)
  expect_equal(out$frobenius, 0, tolerance = 1e-8)
  expect_equal(out$cor_per_factor, rep(1, 3), tolerance = 1e-8)
})

test_that("compare_loadings(): rotated input recovers the rotation R", {
  set.seed(7)
  L <- matrix(rnorm(12), 4, 3)
  ## Build a known orthogonal rotation
  set.seed(11)
  M <- matrix(rnorm(9), 3, 3)
  qr_obj <- qr(M)
  Q <- qr.Q(qr_obj)                      # orthogonal
  L_rot <- L %*% Q
  out <- compare_loadings(L_rot, L)
  ## The recovered rotation R should bring L_rot back to L
  expect_equal(out$Lambda_a_rot, L, tolerance = 1e-7)
  expect_equal(out$frobenius, 0, tolerance = 1e-7)
})

test_that("compare_loadings(): orthogonal vectors give frobenius > 0", {
  ## Two completely unrelated loading matrices: residual must be > 0
  set.seed(13)
  La <- matrix(rnorm(8), 4, 2)
  Lb <- matrix(rnorm(8), 4, 2)
  out <- compare_loadings(La, Lb)
  expect_gt(out$frobenius, 0)
})

test_that("compare_loadings(): R is orthogonal", {
  set.seed(17)
  La <- matrix(rnorm(12), 4, 3)
  Lb <- matrix(rnorm(12), 4, 3)
  out <- compare_loadings(La, Lb)
  expect_equal(out$R %*% t(out$R), diag(3), tolerance = 1e-8)
})

test_that("compare_loadings(): cor_per_factor in [-1, 1]", {
  set.seed(19)
  La <- matrix(rnorm(20), 5, 4)
  Lb <- matrix(rnorm(20), 5, 4)
  out <- compare_loadings(La, Lb)
  expect_true(all(out$cor_per_factor >= -1 - 1e-8 &
                  out$cor_per_factor <= 1 + 1e-8))
})
