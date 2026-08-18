.ridge_path_fixture <- function(n = 24, seed = 1) {
  set.seed(seed)
  data.frame(
    unit = factor(seq_len(n)),
    a = rbinom(n, 1, 0.5),
    b = rbinom(n, 1, 0.5)
  )
}

test_that("ridge_path() returns the expected grid contract on a tiny Bernoulli fixture", {
  skip_on_cran()
  df <- .ridge_path_fixture()

  path <- ridge_path(
    traits(a, b) ~ 1 + latent(1 | unit, d = 1),
    data = df,
    family = binomial(),
    unit = "unit",
    tau = c(2, Inf),
    control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
  )

  expect_s3_class(path, "gllvmTMB_ridge_path")
  expect_true(is.data.frame(path))
  expect_true(all(
    c(
      "tau", "trait", "max_loading", "communality",
      "logLik_at_map", "convergence", "fit_error"
    ) %in% names(path)
  ))
  expect_equal(sort(unique(path$tau)), sort(c(2, Inf)))
  expect_equal(sort(unique(as.character(path$trait))), c("a", "b"))
  expect_equal(nrow(path), 4L)
})

test_that("ridge_path() rejects a non-positive or missing tau grid", {
  df <- .ridge_path_fixture()
  expect_error(
    ridge_path(
      traits(a, b) ~ 1 + latent(1 | unit, d = 1),
      data = df,
      family = binomial(),
      unit = "unit",
      tau = c(0, 2)
    ),
    class = "rlang_error"
  )
})

test_that("print.gllvmTMB_ridge_path() classifies interior vs penalty-determined traits", {
  skip_on_cran()
  df <- .ridge_path_fixture()
  path <- ridge_path(
    traits(a, b) ~ 1 + latent(1 | unit, d = 1),
    data = df,
    family = binomial(),
    unit = "unit",
    tau = c(2, 4, Inf),
    control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
  )
  out <- capture.output(print(path))
  expect_true(any(grepl("interior|penalty-determined|insufficient", out)))
})
