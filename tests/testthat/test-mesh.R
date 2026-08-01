test_that("make_mesh validates coordinates and returns the native contract", {
  d <- data.frame(x = c(NA, runif(10)), y = c(NA, runif(10)))
  expect_error(make_mesh(d, c("x", "y"), cutoff = 0.1), "missing")
  expect_error(make_mesh(d, c("x", "z"), cutoff = 0.1), "column")
  expect_error(make_mesh(d, c("x", "x"), cutoff = 0.1), "distinct")

  d <- data.frame(x = seq(0, 1, length.out = 12), y = rep(c(0, 1), 6))
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.1)
  expect_s3_class(mesh, "gllvmTMBmesh")
  expect_false(inherits(mesh, "sdmTMBmesh"))
  expect_named(
    mesh,
    c("loc_xy", "xy_cols", "mesh", "spde", "loc_centers", "A_st")
  )
  expect_equal(nrow(mesh$A_st), nrow(d))
  expect_equal(ncol(mesh$A_st), mesh$mesh$n)
  expect_true(inherits(mesh$A_st, "Matrix"))
  expect_true(all(vapply(
    mesh$spde[c("c0", "g1", "g2")],
    inherits,
    logical(1),
    "Matrix"
  )))
  # FEM and barycentric projection identities are mathematical invariants,
  # not comparisons to a previous implementation.
  expect_equal(
    as.numeric(mesh$A_st %*% rep(1, mesh$mesh$n)),
    rep(1, nrow(d)),
    tolerance = 1e-10
  )
  for (matrix in mesh$spde[c("c0", "g1", "g2")]) {
    expect_equal(as.matrix(matrix), t(as.matrix(matrix)), tolerance = 1e-10)
  }
  expect_true(all(Matrix::diag(mesh$spde$c0) >= 0))
  malformed <- mesh
  malformed$spde$g1 <- malformed$spde$g1[, -1L]
  expect_error(gllvmTMB:::.gllvm_validate_mesh(malformed), "incompatible")
  malformed <- mesh
  malformed$spde$c0 <- as.matrix(malformed$spde$c0)
  expect_error(gllvmTMB:::.gllvm_validate_mesh(malformed), "sparse")
  malformed <- mesh
  malformed$A_st[1L, ] <- 0
  expect_error(gllvmTMB:::.gllvm_validate_mesh(malformed), "sparse projection")
})

test_that("kmeans mesh construction is reproducible without changing caller RNG", {
  d <- data.frame(x = runif(20), y = runif(20))
  set.seed(20260801)
  before <- .Random.seed
  first <- make_mesh(d, c("x", "y"), type = "kmeans", n_knots = 5, seed = 9)
  expect_identical(.Random.seed, before)
  second <- make_mesh(d, c("x", "y"), type = "kmeans", n_knots = 5, seed = 9)
  expect_equal(first$loc_centers, second$loc_centers)
})

test_that("cutoff_search prioritizes a valid projection and finite FEM matrices", {
  d <- expand.grid(
    x = seq(0, 1, length.out = 5),
    y = seq(0, 1, length.out = 5)
  )
  mesh <- make_mesh(d, c("x", "y"), type = "cutoff_search", n_knots = 12)

  expect_s3_class(mesh, "gllvmTMBmesh")
  expect_gt(mesh$mesh$n, 0L)
  expect_equal(
    as.numeric(Matrix::rowSums(mesh$A_st)),
    rep(1, nrow(d)),
    tolerance = 1e-10
  )
  expect_true(all(vapply(
    mesh$spde[c("c0", "g1", "g2")],
    function(x) all(is.finite(x@x)),
    logical(1)
  )))
})

test_that("a supplied fmesher mesh is normalized to the native contract", {
  d <- expand.grid(
    x = seq(0, 1, length.out = 5),
    y = seq(0, 1, length.out = 5)
  )
  supplied <- fmesher::fm_mesh_2d(loc = as.matrix(d), cutoff = 0.2)
  mesh <- make_mesh(d, c("x", "y"), mesh = supplied)

  expect_s3_class(mesh, "gllvmTMBmesh")
  expect_equal(mesh$mesh$n, supplied$n)
  expect_equal(dim(mesh$A_st), c(nrow(d), supplied$n))
  expect_error(
    make_mesh(d, c("x", "y"), mesh = supplied, cutoff = 0.1),
    "Do not supply"
  )
  expect_error(make_mesh(d, c("x", "y"), mesh = list()), "fm_mesh_2d")
})

test_that("mesh construction validates numerical and constructor inputs", {
  d <- expand.grid(
    x = seq(0, 1, length.out = 4),
    y = seq(0, 1, length.out = 4)
  )

  expect_error(make_mesh(d, c("x", "y"), cutoff = NA_real_), "finite number")
  expect_error(make_mesh(d, c("x", "y"), cutoff = -0.1), "at least")
  expect_error(
    make_mesh(d, c("x", "y"), type = "kmeans", n_knots = 0),
    "greater than"
  )
  expect_error(
    make_mesh(d, c("x", "y"), type = "kmeans", n_knots = 2.5),
    "whole number"
  )
  expect_error(
    make_mesh(d, c("x", "y"), cutoff = 0.1, fmesher_func = "not a function"),
    "mesh-construction function"
  )

  line_data <- data.frame(x = seq(0, 1, length.out = 8), y = 0)
  expect_error(
    make_mesh(line_data, c("x", "y"), type = "cutoff_search", n_knots = 4),
    "spanning two dimensions"
  )
})

test_that("legacy mesh normalization warns, changes class, and drops sdm-only fields", {
  d <- data.frame(x = seq(0, 1, length.out = 12), y = rep(c(0, 1), 6))
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.1)
  class(mesh) <- "sdmTMBmesh"
  mesh$sdm_spatial_id <- seq_len(nrow(d))

  expect_warning(
    normalized <- gllvmTMB:::.gllvm_normalize_mesh(mesh),
    "gllvmTMBmesh"
  )
  expect_s3_class(normalized, "gllvmTMBmesh")
  expect_false(inherits(normalized, "sdmTMBmesh"))
  expect_null(normalized$sdm_spatial_id)
})

test_that("legacy mesh objects plot with a lifecycle warning", {
  d <- data.frame(x = seq(0, 1, length.out = 12), y = rep(c(0, 1), 6))
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.1)
  class(mesh) <- "sdmTMBmesh"
  expect_warning(plot(mesh), "deprecated")
})
