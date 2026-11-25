## Coverage (cursor-cloud-1125x5g): kernel cross-matrix and separability internals.

.cor3 <- function() {
  m <- matrix(c(
    1.00, 0.20, 0.10,
    0.20, 1.00, 0.15,
    0.10, 0.15, 1.00
  ), 3, 3)
  rownames(m) <- colnames(m) <- c("a", "b", "c")
  m
}

test_that(".cross_kernel_metadata() and .cross_kernel_rho() read attributes", {
  K <- matrix(0, 2, 2)
  attr(K, "gllvmTMB_cross_kernel") <- list(rho = 0.35, host_levels = c("h1", "h2"))
  meta <- gllvmTMB:::.cross_kernel_metadata(K)
  expect_equal(meta$rho, 0.35)
  expect_equal(gllvmTMB:::.cross_kernel_rho(K), 0.35)
  expect_true(is.na(gllvmTMB:::.cross_kernel_rho(matrix(0, 2, 2))))
  bad_meta <- matrix(0, 2, 2)
  attr(bad_meta, "gllvmTMB_cross_kernel") <- list(rho = c(0.1, 0.2))
  expect_true(is.na(gllvmTMB:::.cross_kernel_rho(bad_meta)))
})

test_that(".cross_kernel_as_matrix() validates numeric square matrices", {
  expect_error(
    gllvmTMB:::.cross_kernel_as_matrix("x", "A"),
    "numeric matrix"
  )
  A <- matrix(c(1, NA, 0, 1), 2, 2)
  expect_error(
    gllvmTMB:::.cross_kernel_as_matrix(A, "A"),
    "finite"
  )
  rect <- matrix(1, 2, 3)
  expect_error(
    gllvmTMB:::.cross_kernel_as_matrix(rect, "A"),
    "square"
  )
  ok <- gllvmTMB:::.cross_kernel_as_matrix(diag(2), "A", square = FALSE)
  expect_equal(ok, diag(2))
})

test_that(".cross_kernel_check_correlation() enforces symmetry and unit diagonal", {
  A <- .cor3()
  expect_invisible(gllvmTMB:::.cross_kernel_check_correlation(A, "A_H", 1e-8))
  asym <- A
  asym[1, 2] <- 0.9
  expect_error(
    gllvmTMB:::.cross_kernel_check_correlation(asym, "A_H", 1e-8),
    "symmetric"
  )
  bad_diag <- A
  diag(bad_diag) <- 2
  expect_error(
    gllvmTMB:::.cross_kernel_check_correlation(bad_diag, "A_H", 1e-8),
    "unit diagonal"
  )
})

test_that(".cross_kernel_names() assigns default prefixes", {
  A <- diag(2)
  expect_equal(gllvmTMB:::.cross_kernel_names(A, "A", "host"), c("host1", "host2"))
  rownames(A) <- colnames(A) <- c("x", "y")
  expect_equal(gllvmTMB:::.cross_kernel_names(A, "A", "h"), c("x", "y"))
  rownames(A) <- c("x", "y")
  colnames(A) <- c("y", "x")
  expect_error(gllvmTMB:::.cross_kernel_names(A, "A", "h"), "match")
})

test_that(".kernel_separability_thresholds() validates named cutoffs", {
  ok <- gllvmTMB:::.kernel_separability_thresholds(
    c(near_orthogonal = 0.15, high = 0.85)
  )
  expect_named(ok, c("near_orthogonal", "high"))
  expect_error(
    gllvmTMB:::.kernel_separability_thresholds(c(a = 1, b = 2)),
    "near_orthogonal"
  )
  expect_error(
    gllvmTMB:::.kernel_separability_thresholds(
      c(near_orthogonal = 0.9, high = 0.5)
    ),
    "0 < near_orthogonal"
  )
})

test_that(".kernel_separability_matrix() normalises square numeric kernels", {
  K <- gllvmTMB:::.kernel_separability_matrix(diag(3), "a")
  expect_equal(K, diag(3))
  expect_error(
    gllvmTMB:::.kernel_separability_matrix(matrix(1, 2, 3), "a"),
    "square"
  )
  expect_error(
    gllvmTMB:::.kernel_separability_matrix(matrix(Inf, 2, 2), "a"),
    "finite"
  )
})

test_that(".kernel_pair_similarity() matches identical off-diagonals", {
  K <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  expect_equal(gllvmTMB:::.kernel_pair_similarity(K, K), 1, tolerance = 1e-10)
  orth <- diag(2)
  sim <- gllvmTMB:::.kernel_pair_similarity(K, orth)
  expect_true(is.finite(sim))
  expect_lt(abs(sim), 1)
})

test_that(".kernel_separability_class() maps similarity to overlap labels", {
  thr <- c(near_orthogonal = 0.1, high = 0.7)
  expect_equal(
    gllvmTMB:::.kernel_separability_class(0.05, thr),
    "near_orthogonal"
  )
  expect_equal(
    gllvmTMB:::.kernel_separability_class(0.5, thr),
    "moderate"
  )
  expect_equal(
    gllvmTMB:::.kernel_separability_class(0.95, thr),
    "high"
  )
})

test_that(".kernel_separability_recommendation() translates overlap class", {
  expect_equal(
    gllvmTMB:::.kernel_separability_recommendation("moderate"),
    "sensitivity_required"
  )
  expect_equal(
    gllvmTMB:::.kernel_separability_recommendation("high"),
    "collapse_or_single_covariance"
  )
})

test_that(".kernel_separability_names() fills missing kernel names", {
  nms <- gllvmTMB:::.kernel_separability_names(list(diag(2), diag(2)))
  expect_equal(nms, c("K1", "K2"))
  expect_error(
    gllvmTMB:::.kernel_separability_names(
      stats::setNames(list(diag(2), diag(2)), c("a", "a"))
    ),
    "unique"
  )
})