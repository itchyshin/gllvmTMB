test_that("select_lv() refuses non-unit likelihood weights before fitting", {
  d <- do.call(rbind, lapply(1:4, function(j) {
    data.frame(
      unit = factor(1:150),
      trait = factor(names(iris)[j], levels = names(iris)[1:4]),
      value = iris[[j]]
    )
  }))
  w5 <- rep(5, nrow(d))
  n_fit <- 0L
  local_mocked_bindings(
    gllvmTMB = function(...) {
      n_fit <<- n_fit + 1L
      stop("gllvmTMB should not run under select_lv() with non-unit weights")
    },
    .package = "gllvmTMB"
  )
  expect_error(
    select_lv(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d,
      unit = "unit",
      trait = "trait",
      weights = w5,
      d_max = 2L
    ),
    "undefined for a non-unit weighted objective",
    class = "gllvmTMB_weighted_objective_no_information_criterion"
  )
  expect_equal(n_fit, 0L)
})
