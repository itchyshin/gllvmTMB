## Coverage (cursor-cloud-1125x4g): R/offset.R and R/cv-metrics.R validation paths.

.cov1125x4g_poisson_fit <- function() {
  set.seed(112541)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rpois(n, 2),
    effort = rep(c(1.2, 0.8), length.out = n)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + offset(log(effort)) + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df,
    unit = "unit",
    trait = "trait",
    family = poisson(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that("gll_prepare_offset() returns zeros when offset_expr is NULL", {
  n <- 4L
  df <- data.frame(x = 1:n)
  off <- gllvmTMB:::gll_prepare_offset(
    NULL, df, environment(),
    family_id_vec = rep(2L, n), link_id_vec = rep(0L, n),
    family_per_row = rep(list(poisson()), n), trait_vec = rep("a", n)
  )
  expect_equal(off, rep(0, n))
})

test_that("gll_prepare_offset() rejects non-numeric evaluated offsets", {
  df <- data.frame(x = 1:3)
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(letters[1:3]), df, environment(),
      family_id_vec = rep(2L, 3), link_id_vec = rep(0L, 3),
      family_per_row = rep(list(poisson()), 3), trait_vec = rep("a", 3)
    ),
    "numeric"
  )
})

test_that("gll_prepare_offset() rejects wrong length and non-finite offsets", {
  df <- data.frame(x = 1:3, off = c(1, 2, 3))
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(off[1:2]), df, environment(),
      family_id_vec = rep(2L, 3), link_id_vec = rep(0L, 3),
      family_per_row = rep(list(poisson()), 3), trait_vec = rep("a", 3)
    ),
    "row"
  )
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(c(1, NA, 1)), df, environment(),
      family_id_vec = rep(2L, 3), link_id_vec = rep(0L, 3),
      family_per_row = rep(list(poisson()), 3), trait_vec = rep("a", 3)
    ),
    "non-finite"
  )
})

test_that("gll_prepare_offset() refuses nonzero offsets on gaussian rows", {
  df <- data.frame(x = 1:2)
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(c(1, 1)), df, environment(),
      family_id_vec = c(0L, 0L), link_id_vec = c(0L, 0L),
      family_per_row = rep(list(gaussian()), 2), trait_vec = c("a", "b")
    ),
    "offsets are supported"
  )
})

test_that(".gllvmTMB_offset_vec() and newdata helpers align with a tiny poisson fit", {
  fit <- .cov1125x4g_poisson_fit()
  off <- gllvmTMB:::.gllvmTMB_offset_vec(fit)
  expect_length(off, nrow(fit$tmb_data$X_fix))
  expect_true(any(off != 0))

  nd <- fit$data
  expect_equal(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit, nd),
    off,
    tolerance = 1e-8
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit, nd[, c("unit", "trait"), drop = FALSE]),
    "missing the offset"
  )
})

test_that(".cv_join_truth() validates fit and truth inputs", {
  fit <- .cov1125x4g_poisson_fit()
  expect_error(
    gllvmTMB:::.cv_join_truth(list(), data.frame(), data.frame(), "value"),
    "gllvmTMB_multi"
  )
  pm <- data.frame(original_row = 1L, model_row = 1L)
  expect_error(
    gllvmTMB:::.cv_join_truth(fit, pm, data.frame(), "value"),
    "column named"
  )
  expect_error(
    gllvmTMB:::.cv_join_truth(fit, pm, fit$data, character()),
    "response_col"
  )
})

test_that(".gllvmTMB_check_unique_marginal_cells() enforces unique unit-trait cells", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(1:3, 1:2),
    "equal length"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(
      c(0L, 0L), c(0L, 0L)
    ),
    class = "gllvmTMB_exact_gaussian_duplicate_cell"
  )
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(c(0L, 1L), c(0L, 0L))
  )
})