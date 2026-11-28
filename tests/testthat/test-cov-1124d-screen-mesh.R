# Coverage gap: screen_control() threshold checks, and make_mesh()
# argument failures that abort before a triangulation is built.

test_that("screen_control() stores coerced counts and rejects bad thresholds", {
  ok <- screen_control(
    rare_warn_n = 2.9,
    prevalence_warn = c(0, 1),
    phi_warn = 1,
    hamming_rate_warn = 0,
    separation = "fixed",
    separation_tolerance = 1e-6
  )
  expect_s3_class(ok, "gllvmTMB_screen_control")
  expect_identical(ok$rare_warn_n, 2L)
  expect_identical(ok$separation, "fixed")
  expect_identical(ok$phi_warn, 1)
  expect_identical(ok$hamming_rate_warn, 0)
  expect_identical(ok$separation_tolerance, 1e-6)

  expect_error(screen_control(rare_warn_n = -1), "non-negative finite")
  expect_error(screen_control(rare_strong_n = Inf), "non-negative finite")
  expect_error(screen_control(discordant_warn_n = NA_real_), "non-negative finite")
  expect_error(screen_control(phi_warn = 1.1), "between 0 and 1")
  expect_error(screen_control(phi_strong = -0.1), "between 0 and 1")
  expect_error(screen_control(hamming_rate_warn = 2), "between 0 and 1")
  expect_error(
    screen_control(prevalence_warn = c(0.9, 0.1)),
    "length-two increasing"
  )
  expect_error(
    screen_control(prevalence_strong = c(0.2, NA)),
    "length-two increasing"
  )
  expect_error(
    screen_control(prevalence_warn = 0.1),
    "length-two increasing"
  )
  expect_error(screen_control(separation_tolerance = 0), "positive finite")
  expect_error(screen_control(separation_tolerance = NA_real_), "positive finite")
  expect_error(screen_control(module = "gaussian"), "binomial")
  expect_error(screen_control(separation = "banana"), "should be one of")
})

test_that("make_mesh() rejects an empty frame, bad coordinates, and a bad id column", {
  expect_error(
    make_mesh(data.frame(), c("x", "y"), cutoff = 0.1),
    "non-empty"
  )
  expect_error(
    make_mesh(data.frame(x = 1, y = "a"), c("x", "y"), cutoff = 0.1),
    "numeric"
  )
  expect_error(make_mesh(data.frame(x = 0, y = 0), c("x", "y")), "cutoff")
  expect_error(
    make_mesh(data.frame(x = 0, y = 0), c("x", "y"), type = "kmeans"),
    "n_knots"
  )
  expect_error(
    make_mesh(data.frame(x = 0, y = 1), c("x", "y"), cutoff = 0.1, n_knots = 4),
    "not used"
  )
  expect_error(
    make_mesh(
      data.frame(x = 0, y = 0),
      c("x", "y"),
      type = "kmeans",
      n_knots = 3
    ),
    "two distinct"
  )
  expect_error(
    make_mesh(data.frame(x = 0, y = 0), c("x", "y"), cutoff = Inf),
    "finite number"
  )

  d <- data.frame(id = c("a", "b"), x = c(0, 1), y = c(0, 1))
  expect_error(
    make_mesh(d, c("x", "y"), cutoff = 0.1, id_col = 1),
    "non-empty column name"
  )
  expect_error(
    make_mesh(d, c("x", "y"), cutoff = 0.1, id_col = "missing"),
    "column in"
  )
  expect_error(
    make_mesh(
      transform(d, id = c("a", "")),
      c("x", "y"),
      cutoff = 0.1,
      id_col = "id"
    ),
    "non-missing"
  )
  expect_error(
    make_mesh(
      transform(d, id = c("a", NA)),
      c("x", "y"),
      cutoff = 0.1,
      id_col = "id"
    ),
    "non-missing"
  )
  expect_error(
    make_mesh(
      transform(d, id = c("a", "a")),
      c("x", "y"),
      cutoff = 0.1,
      id_col = "id"
    ),
    "uniquely"
  )
})

test_that("mesh validation rejects a hand-built object field by field", {
  fake <- list(
    loc_xy = cbind(c(0, 1), c(0, 1)),
    xy_cols = c("x", "y"),
    mesh = list(),
    spde = list(c0 = NULL, g1 = NULL, g2 = NULL),
    A_st = Matrix::Matrix(diag(2), sparse = TRUE)
  )
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(list(loc_xy = fake$loc_xy)),
    "missing required"
  )

  labelled <- fake
  labelled$id_col <- ""
  labelled$row_labels <- c("a", "b")
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(labelled),
    "row_labels"
  )
  labelled$id_col <- "id"
  labelled$row_labels <- c("a", "a")
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(labelled),
    "row_labels"
  )

  bad_xy <- fake
  bad_xy$xy_cols <- "x"
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(bad_xy),
    "two coordinate"
  )

  dense <- fake
  dense$A_st <- diag(2)
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(dense),
    class = "gllvmTMB_mesh_a_st_not_sparse"
  )

  mismatch <- fake
  mismatch$A_st <- Matrix::Matrix(diag(3), sparse = TRUE)
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(mismatch),
    class = "gllvmTMB_mesh_a_st_row_mismatch"
  )

  nonfinite <- fake
  bad_proj <- Matrix::Matrix(diag(2), sparse = TRUE)
  bad_proj@x[[1L]] <- Inf
  nonfinite$A_st <- bad_proj
  expect_error(
    gllvmTMB:::.gllvm_validate_mesh(nonfinite),
    class = "gllvmTMB_mesh_a_st_nonfinite"
  )

  expect_error(
    gllvmTMB:::.gllvm_normalize_mesh(list(loc_xy = fake$loc_xy)),
    "make_mesh"
  )
  expect_error(
    gllvmTMB:::.gllvm_validate_scalar(c(1, 2), "cutoff"),
    "one finite"
  )
  expect_equal(gllvmTMB:::.gllvm_validate_scalar(0, "cutoff", lower = 0), 0)
  expect_error(
    gllvmTMB:::.gllvm_validate_count(1.2, "n_knots"),
    "whole number"
  )
})

test_that("a small mesh plots and a huge coordinate warns", {
  skip_if_not_installed("fmesher")
  d <- data.frame(
    x = c(0, 1, 0, 1),
    y = c(0, 0, 1, 1)
  )
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.2)
  expect_identical(mesh$loc_centers, NA)
  grDevices::pdf(tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(plot(mesh), mesh)

  centres <- make_mesh(d, c("x", "y"), type = "kmeans", n_knots = 3L, seed = 1L)
  expect_true(is.matrix(centres$loc_centers))
  expect_identical(plot(centres), centres)

  big <- data.frame(
    x = c(0, 20000, 0, 20000),
    y = c(0, 0, 20000, 20000)
  )
  expect_warning(
    make_mesh(big, c("x", "y"), cutoff = 5000),
    "10,000"
  )
})
