test_that("traits() wide RHS adds per-trait intercepts under the R implicit-intercept rule (#1757)", {
  skip_if_not_installed("tidyr")

  wide <- data.frame(
    unit = factor(paste0("u", 1:8)),
    trait_1 = rnorm(8),
    trait_2 = rnorm(8),
    trait_3 = rnorm(8),
    x = seq_len(8)
  )

  implicit <- gllvmTMB:::rewrite_traits_lhs(
    traits(trait_1, trait_2, trait_3) ~ x +
      latent(1 | unit, d = 1, unique = TRUE),
    data = wide
  )
  explicit <- gllvmTMB:::rewrite_traits_lhs(
    traits(trait_1, trait_2, trait_3) ~ 1 + x +
      latent(1 | unit, d = 1, unique = TRUE),
    data = wide
  )
  no_int <- gllvmTMB:::rewrite_traits_lhs(
    traits(trait_1, trait_2, trait_3) ~ 0 + x +
      latent(1 | unit, d = 1, unique = TRUE),
    data = wide
  )
  latent_only <- gllvmTMB:::rewrite_traits_lhs(
    traits(trait_1, trait_2, trait_3) ~
      latent(1 | unit, d = 1, unique = TRUE),
    data = wide
  )
  latent_one <- gllvmTMB:::rewrite_traits_lhs(
    traits(trait_1, trait_2, trait_3) ~ 1 +
      latent(1 | unit, d = 1, unique = TRUE),
    data = wide
  )

  imp_rhs <- paste(deparse(implicit$formula_long[[3L]]), collapse = " ")
  exp_rhs <- paste(deparse(explicit$formula_long[[3L]]), collapse = " ")
  no_rhs <- paste(deparse(no_int$formula_long[[3L]]), collapse = " ")
  lat_rhs <- paste(deparse(latent_only$formula_long[[3L]]), collapse = " ")
  lat1_rhs <- paste(deparse(latent_one$formula_long[[3L]]), collapse = " ")

  expect_match(imp_rhs, "0 \\+ trait")
  expect_match(exp_rhs, "0 \\+ trait")
  expect_match(imp_rhs, "\\(0 \\+ trait\\):x")
  expect_match(exp_rhs, "\\(0 \\+ trait\\):x")
  expect_match(imp_rhs, "\\(0 \\+ trait\\):x")
  expect_no_match(no_rhs, "^0 \\+ trait")
  expect_match(lat_rhs, "^0 \\+ trait")
  expect_equal(lat_rhs, lat1_rhs)
})

test_that("traits() ~ x matches ~ 1 + x and differs from ~ 0 + x in coef count (#1757)", {
  skip_if_not_installed("tidyr")

  sim <- simulate_unit_trait(
    n_units = 30,
    n_obs_per_unit = 1,
    n_traits = 3,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), ncol = 1),
    psi_B = c(0.3, 0.3, 0.3)
  )
  wide <- as.data.frame(
    tidyr::pivot_wider(sim$data, names_from = trait, values_from = value)
  )
  wide$x <- as.numeric(scale(seq_len(nrow(wide))))

  f_imp <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(trait_1, trait_2, trait_3) ~ x +
      latent(1 | unit, d = 1, unique = FALSE),
    data = wide,
    unit = "unit",
    silent = TRUE
  )))
  f_1 <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(trait_1, trait_2, trait_3) ~ 1 + x +
      latent(1 | unit, d = 1, unique = FALSE),
    data = wide,
    unit = "unit",
    silent = TRUE
  )))
  f_0 <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(trait_1, trait_2, trait_3) ~ 0 + x +
      latent(1 | unit, d = 1, unique = FALSE),
    data = wide,
    unit = "unit",
    silent = TRUE
  )))

  expect_equal(length(coef(f_imp)), length(coef(f_1)))
  expect_equal(length(coef(f_imp)), 6L)
  expect_equal(length(coef(f_0)), 3L)
  expect_true(isTRUE(all.equal(as.numeric(logLik(f_imp)), as.numeric(logLik(f_1)))))
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(f_imp)),
    as.numeric(logLik(f_0)),
    tolerance = 1e-6
  )))
})
