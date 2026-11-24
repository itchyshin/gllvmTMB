# Coverage gap: small exported and internal helpers. Every case below
# is a direct call; none fits a model.

test_that("Xcoef_fixed normalisation pins zeros and refuses bad input", {
  cols <- c("traita", "traita:x", "traitb", "traitb:x")
  empty <- gllvmTMB:::.normalise_Xcoef_fixed(NULL, cols)
  expect_false(empty$has_fixed)
  expect_identical(empty$status, rep("estimated", 4L))
  expect_identical(empty$terms, character(0))
  expect_identical(
    gllvmTMB:::.gllvmTMB_xcoef_status(list(X_fix_names = cols)),
    rep("estimated", 4L)
  )
  expect_identical(
    gllvmTMB:::.gllvmTMB_xcoef_status(list(
      X_fix_names = cols,
      Xcoef_fixed = list(status = "fixed")
    )),
    rep("estimated", 4L)
  )

  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(c(0), cols),
    "named numeric"
  )
  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(c(a = 0), cols, REML = TRUE),
    "REML = TRUE"
  )
  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(c(`traita:x` = NA_real_), cols),
    "finite"
  )
  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(
      stats::setNames(0, ""),
      cols
    ),
    "non-empty"
  )
  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(
      stats::setNames(c(0, 0), c("traita:x", "traita:x")),
      cols
    ),
    "unique"
  )
  expect_error(
    gllvmTMB:::.normalise_Xcoef_fixed(c(not_a_column = 0), cols),
    "Unknown name"
  )

  pinned <- gllvmTMB:::.normalise_Xcoef_fixed(c(`traitb:x` = 0), cols)
  expect_true(pinned$has_fixed)
  expect_identical(pinned$terms, "traitb:x")
  expect_identical(
    pinned$status,
    c("estimated", "estimated", "estimated", "fixed")
  )
  expect_equal(pinned$init_fixed, c(NA_real_, NA_real_, NA_real_, 0))
  expect_true(is.na(as.integer(pinned$map)[4L]))
  expect_identical(
    gllvmTMB:::.gllvmTMB_xcoef_status(list(
      X_fix_names = cols,
      Xcoef_fixed = pinned
    )),
    pinned$status
  )
})

test_that("packed loading indices and a zero diagonal start are explicit", {
  expect_identical(
    gllvmTMB:::lambda_packed_index(1L, 2L, p = 4L, rank = 2L),
    NA_integer_
  )
  expect_identical(
    gllvmTMB:::lambda_packed_index(1L, 1L, p = 4L, rank = 2L),
    2L
  )
  expect_error(
    gllvmTMB:::lambda_packed_index(5L, 0L, p = 4L, rank = 2L),
    "outside the packed triangle"
  )
  expect_error(
    gllvmTMB:::lambda_packed_map(c(0, 1), n_traits = 2L, rank = 1L, theta_init = 0),
    "must be matrices"
  )

  constraint <- matrix(NA_real_, nrow = 3L, ncol = 2L)
  constraint[1L, 1L] <- 0
  packed <- gllvmTMB:::lambda_packed_map(
    constraint,
    n_traits = 3L,
    rank = 2L,
    theta_init = rep(0, 5L)
  )
  expect_equal(packed$init[1L], 0)
  expect_equal(packed$init[3L], 0.5)
  expect_equal(packed$init[4L], 0.5)
  expect_true(is.na(as.integer(packed$map)[1L]))
})

test_that("confirmatory_lambda() checks species, rank, labels, and anchors", {
  expect_error(
    confirmatory_lambda(factor(c("a", "b")), c("A", "B"), 1L, list(A = 1L)),
    "character"
  )
  expect_error(
    confirmatory_lambda(character(), character(), 1L, list()),
    "at least one"
  )
  expect_error(
    confirmatory_lambda("a", "A", 0, list(A = 1L)),
    "positive integer"
  )
  expect_error(
    confirmatory_lambda("a", "A", c(1L, 2L), list(A = 1L)),
    "positive integer"
  )
  expect_error(
    confirmatory_lambda(c("a", "b"), c("A", "B"), 1L, c("A", "B")),
    "named list"
  )
  expect_error(
    confirmatory_lambda(c("a", "b"), c("A", "B"), 1L, c(1, 2)),
    "fully named"
  )
  expect_error(
    confirmatory_lambda(
      c("a", "b"), c("A", "B"), 2L,
      stats::setNames(list(1L, 2L), c("A", ""))
    ),
    "fully named"
  )
  expect_error(
    confirmatory_lambda(
      c("a", "b"), c("A", "B"), 2L,
      list(A = 1L, B = 2L),
      axis_labels = "only"
    ),
    "axis_labels"
  )
  expect_error(
    confirmatory_lambda(
      c("a", "b"), c("A", "B"), 2L,
      list(A = 1L, B = 2L),
      anchors = "a"
    ),
    "anchors"
  )
  expect_warning(
    confirmatory_lambda(
      c("a", "b"), c("A", "B"), 2L,
      list(A = 1L, Z = 2L)
    ),
    "no matching"
  )

  zeros <- confirmatory_lambda(
    c("a", "b"), c("A", "B"), 2L,
    c(A = 1, B = 2)
  )
  expect_equal(colnames(zeros), c("LV1", "LV2"))
  expect_equal(zeros["a", "LV2"], 0)
  expect_equal(zeros["b", "LV1"], 0)
  expect_true(is.na(zeros["a", "LV1"]))
  expect_true(is.na(zeros["b", "LV2"]))

  expect_error(
    confirmatory_lambda(
      c("a", "b"), c("A", "B"), 2L,
      list(A = 1L, B = 2L),
      anchors = c("b", "a")
    ),
    "upper triangle"
  )
})

test_that("block_V() refuses an unnamed rho vector and keeps singleton blocks diagonal", {
  expect_error(
    block_V(
      c("a", "a", "b", "b"),
      c(0.1, 0.1, 0.2, 0.2),
      rho_within = c(0.2, 0.4)
    ),
    "must be named"
  )
  V <- block_V(c("a", "b"), c(0, 0.25), rho_within = 0.3)
  expect_equal(V, diag(c(0, 0.25)))
  expect_equal(diag(V), c(0, 0.25))
})

test_that("pedigree builders refuse a short table, duplicates, and a forward parent", {
  expect_error(pedigree_to_A(data.frame(id = "a", sire = NA)), "at least 3")
  expect_error(pedigree_to_A(matrix(1, 2, 3)), "at least 3")
  expect_error(pedigree_to_Ainv_sparse(data.frame(id = 1)), "at least 3")

  expect_error(
    pedigree_to_A(data.frame(
      id = c("a", "a"),
      sire = c(NA, NA),
      dam = c(NA, NA)
    )),
    "duplicate"
  )
  expect_error(
    pedigree_to_A(data.frame(
      id = c("kid", "mom"),
      sire = c(NA, NA),
      dam = c("mom", NA)
    )),
    "Dam"
  )
  expect_error(
    pedigree_to_A(data.frame(
      id = c("kid", "dad"),
      sire = c("dad", NA),
      dam = c(NA, NA)
    )),
    "Sire"
  )

  expect_message(
    positional <- pedigree_to_A(data.frame(
      x = c("a", "b"),
      y = c(NA, "a"),
      z = c(NA, NA)
    )),
    "positional"
  )
  expect_equal(unname(positional["b", "a"]), 0.5)
  expect_equal(unname(diag(positional)), c(1, 1))

  synonyms <- pedigree_to_A(data.frame(
    animal = c("a", "b", "c"),
    father = c(NA, NA, "a"),
    mother = c(NA, NA, "b"),
    stringsAsFactors = FALSE
  ))
  expect_equal(unname(synonyms["c", "a"]), 0.5)
  expect_equal(unname(synonyms["c", "b"]), 0.5)
  expect_equal(unname(synonyms["a", "b"]), 0)

  coded <- pedigree_to_A(data.frame(
    id = c("a", "b"),
    sire = c("0", "a"),
    dam = c("", NA),
    stringsAsFactors = FALSE
  ))
  expect_equal(unname(coded["a", "a"]), 1)
  expect_equal(unname(coded["b", "a"]), 0.5)
  expect_equal(unname(coded["b", "b"]), 1)
})

test_that("a dense relationship inverse is inverted and a sparse one is kept", {
  A <- matrix(c(2, 0.4, 0.4, 2), 2, 2)
  inverted <- gllvmTMB:::.gllvmTMB_maybe_keep_sparse_ainv(A)
  expect_equal(inverted %*% A, diag(2), tolerance = 1e-8)
  sparse <- Matrix::Matrix(A, sparse = TRUE)
  kept <- gllvmTMB:::.gllvmTMB_maybe_keep_sparse_ainv(sparse)
  expect_s4_class(kept, "sparseMatrix")
  expect_identical(kept, sparse)
})

test_that("print.select_lv shows the chosen rank and any failed fits", {
  table <- data.frame(
    d = 1:2,
    npar = c(4L, NA_integer_),
    logLik = c(-10.1234, NA_real_),
    aic = c(28.246, NA_real_),
    bic = c(30.2, NA_real_),
    aicc = c(29.3, NA_real_),
    converged = c(TRUE, NA),
    pd_hessian = c(TRUE, NA),
    error = c(NA_character_, "optimizer did not report convergence"),
    stringsAsFactors = FALSE
  )
  obj <- structure(
    list(criterion = "bic", selected_d = 1L, table = table),
    class = "gllvmTMB_select_lv"
  )
  lines <- utils::capture.output(printed <- print(obj))
  text <- paste(lines, collapse = "\n")
  expect_identical(printed, obj)
  expect_match(text, "criterion = bic, selected d = 1")
  expect_match(text, "Failed fits:")
  expect_match(text, "d = 2: optimizer did not report convergence")

  clean <- obj
  clean$table$error <- NA_character_
  clean_text <- paste(utils::capture.output(print(clean)), collapse = "\n")
  expect_false(grepl("Failed fits:", clean_text, fixed = TRUE))
})

test_that("get_crs() names the southern zone and clamps longitude 180", {
  south <- data.frame(lon = c(151, 151.2), lat = c(-33.8, -33.9))
  expect_message(epsg <- get_crs(south, c("lon", "lat")), "56S")
  expect_identical(epsg, 32756)

  edge <- data.frame(lon = 180, lat = 10)
  expect_message(epsg_edge <- get_crs(edge, c("lon", "lat")), "60N")
  expect_identical(epsg_edge, 32660)

  expect_error(
    get_crs(data.frame(lon = 0, lat = 90.1), c("lon", "lat")),
    "latitude"
  )
  expect_error(
    get_crs(data.frame(lon = "x", lat = 0), c("lon", "lat")),
    "Longitude"
  )
  expect_error(
    get_crs(data.frame(lon = 1, lat = 2), c("lon", "lon")),
    "distinct"
  )
})

test_that("add_utm_columns() rejects non-finite coordinates and a bad units choice", {
  skip_if_not_installed("sf")
  d <- data.frame(lon = c(-130, NA), lat = c(52, 53))
  expect_error(add_utm_columns(d, c("lon", "lat")), "finite")
  expect_error(
    add_utm_columns(
      data.frame(lon = -130, lat = 52),
      c("lon", "lat"),
      utm_names = c("X", "X")
    ),
    "distinct"
  )
  expect_error(
    add_utm_columns(
      data.frame(lon = -130, lat = 52),
      c("lon", "lat"),
      units = "miles"
    ),
    "should be one of"
  )
})

test_that("weight normalisation covers the remaining shape failures", {
  expect_null(gllvmTMB:::normalise_weights(NULL, "long", n_obs = 3))
  expect_error(
    gllvmTMB:::normalise_weights(1, "long", n_obs = -1),
    "non-negative"
  )
  expect_error(
    gllvmTMB:::normalise_weights(1, "long", n_obs = 1, drop_masked = NA),
    "drop_masked"
  )
  expect_error(
    gllvmTMB:::normalise_weights(
      1, "wide_matrix",
      n_obs = 1, n_units = 1, n_traits = 1,
      na_mask = matrix(c(TRUE, FALSE), nrow = 1, ncol = 2)
    ),
    "na_mask"
  )
  expect_error(
    gllvmTMB:::normalise_weights(
      1, "wide_matrix",
      n_obs = 1, n_units = 1, n_traits = 1,
      na_mask = matrix(NA, nrow = 1, ncol = 1)
    ),
    "cannot contain NA"
  )
  expect_equal(
    gllvmTMB:::normalise_weights(
      c(2, 3), "wide_df",
      n_obs = 4, n_units = 2, n_traits = 2
    ),
    c(2, 2, 3, 3)
  )
  mask <- matrix(c(FALSE, TRUE, FALSE, FALSE), nrow = 2, ncol = 2)
  expect_equal(
    gllvmTMB:::normalise_weights(
      c(2, 5), "wide_df",
      n_obs = 3, n_units = 2, n_traits = 2,
      na_mask = mask
    ),
    c(2, 2, 5)
  )
})
