## #1418: confirmatory_lambda() anchors that land in the strict upper
## triangle must be applied (by moving the auto-anchor onto or below
## the diagonal) or refused. No gllvmTMB() fit — the packed map is the
## engine gate.

test_that("auto-anchors stay on or below the diagonal when group B is listed first (#1418)", {
  species <- c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")
  M <- confirmatory_lambda(
    species  = species,
    group    = c("B", "A", "A", "B"),
    d        = 2L,
    loads_on = list(A = 1L, B = 2L)
  )

  ## Axis-2 +1 is no longer row 1 / column 2 (the silent-drop cell).
  expect_false(isTRUE(all.equal(M[1L, 2L], 1)))
  expect_equal(M["Petal.Width", 2L], 1)
  expect_equal(M["Sepal.Width", 1L], 1)

  theta <- rep(0, 7L)
  cm <- gllvmTMB:::lambda_packed_map(M, n_traits = 4L, rank = 2L, theta_init = theta)
  idx_anchor2 <- gllvmTMB:::lambda_packed_index(3L, 1L, p = 4L, rank = 2L)
  expect_true(is.na(cm$map[idx_anchor2]))
  expect_equal(cm$init[idx_anchor2], 1)
})

test_that("an explicit upper-triangle anchor errors in confirmatory_lambda() (#1418)", {
  expect_error(
    confirmatory_lambda(
      species  = c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width"),
      group    = c("B", "A", "A", "B"),
      d        = 2L,
      loads_on = list(A = 1L, B = 2L),
      anchors  = c("Sepal.Width", "Sepal.Length")
    ),
    "upper triangle"
  )
})

test_that("lambda_packed_map() errors on a non-zero upper-triangle pin (#1418)", {
  cnst <- matrix(NA_real_, nrow = 4L, ncol = 2L,
                 dimnames = list(
                   c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width"),
                   c("LV1", "LV2")
                 ))
  cnst[1L, 2L] <- 1
  expect_error(
    gllvmTMB:::lambda_packed_map(cnst, n_traits = 4L, rank = 2L, theta_init = rep(0, 7L)),
    "Sepal.Length"
  )
})

test_that("lambda_packed_map() still accepts an upper-triangle zero pin", {
  cnst <- matrix(NA_real_, nrow = 4L, ncol = 2L)
  cnst[1L, 2L] <- 0
  expect_silent(
    gllvmTMB:::lambda_packed_map(cnst, n_traits = 4L, rank = 2L, theta_init = rep(0, 7L))
  )
})
