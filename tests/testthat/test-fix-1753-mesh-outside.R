## #1753: make_mesh() must not blame hand assembly when cutoff leaves
## locations outside the triangulation.

test_that("#1753 make_mesh() reports locations outside the triangulation", {
  set.seed(8)
  n <- 20L
  df <- data.frame(lon = runif(n), lat = runif(n))

  err <- expect_error(
    make_mesh(df, c("lon", "lat"), cutoff = 0.25),
    class = "gllvmTMB_mesh_locations_outside"
  )
  expect_match(conditionMessage(err), "1 location", fixed = TRUE)
  expect_match(conditionMessage(err), "outside", fixed = TRUE)
  expect_match(conditionMessage(err), "triangulation", fixed = TRUE)
  expect_match(conditionMessage(err), "cutoff", fixed = TRUE)
  expect_false(grepl("assembling a", conditionMessage(err), fixed = TRUE))

  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.15)
  expect_s3_class(mesh, "gllvmTMBmesh")
  expect_equal(
    as.numeric(Matrix::rowSums(mesh$A_st)),
    rep(1, n),
    tolerance = 1e-8
  )
})

test_that("#1753 A_st validation keeps separate hand-assembly errors", {
  d <- data.frame(x = seq(0, 1, length.out = 12), y = rep(c(0, 1), 6))
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.1)

  dense <- mesh
  dense$A_st <- as.matrix(dense$A_st)
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(dense),
    class = "gllvmTMB_mesh_a_st_not_sparse"
  )
  expect_match(
    conditionMessage(
      tryCatch(
        gllvmTMB:::.gllvm_validate_mesh(dense),
        error = function(e) e
      )
    ),
    "assembling"
  )

  nrow_mismatch <- mesh
  nrow_mismatch$A_st <- nrow_mismatch$A_st[-1L, , drop = FALSE]
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(nrow_mismatch),
    class = "gllvmTMB_mesh_a_st_row_mismatch"
  )

  nonfinite <- mesh
  nonfinite$A_st@x[[1L]] <- Inf
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(nonfinite),
    class = "gllvmTMB_mesh_a_st_nonfinite"
  )
})
