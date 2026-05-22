make_sigma_table_fit <- function(seed = 20260521L) {
  set.seed(seed)
  Tn <- 3L
  Lambda_B <- matrix(c(0.8, 0.3, -0.2), Tn, 1L)
  Lambda_W <- matrix(c(0.4, -0.1, 0.2), Tn, 1L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 35L,
    n_species = 6L,
    n_traits = Tn,
    mean_species_per_site = 4L,
    Lambda_B = Lambda_B,
    psi_B = c(0.30, 0.25, 0.20),
    Lambda_W = Lambda_W,
    psi_W = c(0.20, 0.15, 0.25),
    beta = matrix(0, Tn, 2L),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site) +
      latent(0 + trait | site_species, d = 1) +
      unique(0 + trait | site_species),
    data = sim$data,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

make_bootstrap_sigma_table_object <- function() {
  Sigma <- matrix(
    c(
      1.00,
      0.20,
      -0.10,
      0.20,
      0.80,
      0.30,
      -0.10,
      0.30,
      1.20
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(c("length", "mass", "wing"), c("length", "mass", "wing"))
  )
  R <- stats::cov2cor(Sigma)
  boot <- list(
    point_est = list(Sigma_B = Sigma, R_B = R),
    ci_lower = list(
      Sigma_B = Sigma - 0.05,
      R_B = pmax(R - 0.10, -1)
    ),
    ci_upper = list(
      Sigma_B = Sigma + 0.05,
      R_B = pmin(R + 0.10, 1)
    ),
    ci_method = "percentile",
    link_residual = "auto",
    conf = 0.95,
    n_boot = 20L,
    n_failed = 1L,
    level = "B",
    what = c("Sigma", "R"),
    draws = NULL
  )
  class(boot) <- c("bootstrap_Sigma", "list")
  boot
}

test_that("extract_Sigma_table returns one row per unique covariance entry", {
  fit <- make_sigma_table_fit()
  tbl <- suppressMessages(extract_Sigma_table(fit, level = "unit"))
  mat <- suppressMessages(extract_Sigma(fit, level = "unit"))$Sigma

  expect_s3_class(tbl, "data.frame")
  expect_named(
    tbl,
    c(
      "estimand",
      "trait_i",
      "trait_j",
      "i",
      "j",
      "level",
      "component",
      "matrix",
      "estimate",
      "lower",
      "upper",
      "interval_method",
      "interval_status",
      "scale",
      "validation_row",
      "diagonal",
      "triangle"
    )
  )
  expect_equal(nrow(tbl), fit$n_traits * (fit$n_traits + 1L) / 2L)
  expect_setequal(tbl$triangle, c("diagonal", "upper"))
  expect_equal(unique(tbl$level), "unit")
  expect_equal(unique(tbl$component), "total")
  expect_equal(unique(tbl$matrix), "Sigma")
  expect_equal(unique(tbl$validation_row), "EXT-18")
  expect_equal(tbl$estimate, mat[cbind(tbl$i, tbl$j)])
})

test_that("extract_Sigma_table can return all correlation cells", {
  fit <- make_sigma_table_fit()
  tbl <- suppressMessages(extract_Sigma_table(
    fit,
    level = "unit",
    measure = "correlation",
    entries = "all"
  ))
  R <- suppressMessages(extract_Sigma(fit, level = "unit"))$R

  expect_equal(nrow(tbl), fit$n_traits^2)
  expect_equal(unique(tbl$matrix), "R")
  expect_equal(unique(tbl$scale), "correlation")
  expect_setequal(tbl$triangle, c("diagonal", "lower", "upper"))
  expect_equal(tbl$estimate, R[cbind(tbl$i, tbl$j)])
  expect_equal(tbl$estimate[tbl$diagonal], rep(1, fit$n_traits))
})

test_that("extract_Sigma_table handles unique components and multiple levels", {
  fit <- make_sigma_table_fit()
  tbl <- suppressMessages(extract_Sigma_table(
    fit,
    level = c("unit", "unit_obs"),
    part = "unique",
    entries = "diag"
  ))
  s_unit <- suppressMessages(
    extract_Sigma(fit, level = "unit", part = "unique")
  )$s
  s_obs <- suppressMessages(
    extract_Sigma(fit, level = "unit_obs", part = "unique")
  )$s

  expect_equal(nrow(tbl), 2L * fit$n_traits)
  expect_setequal(tbl$level, c("unit", "unit_obs"))
  expect_equal(unique(tbl$component), "unique")
  expect_equal(unique(tbl$matrix), "Psi")
  expect_equal(
    tbl$estimate[tbl$level == "unit"],
    unname(s_unit)
  )
  expect_equal(
    tbl$estimate[tbl$level == "unit_obs"],
    unname(s_obs)
  )
})

test_that("extract_Sigma_table rejects correlation tables for non-total parts", {
  fit <- make_sigma_table_fit()
  expect_error(
    extract_Sigma_table(fit, part = "shared", measure = "correlation"),
    regexp = "part = \"total\""
  )
})

test_that("extract_Sigma_table preserves mixed-family link-residual Sigma rows", {
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  tbl <- suppressMessages(extract_Sigma_table(
    fit,
    level = "unit",
    link_residual = "auto"
  ))
  mat <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = "auto"
  ))$Sigma

  expect_equal(tbl$estimate, mat[cbind(tbl$i, tbl$j)], tolerance = 1e-10)
  expect_equal(unique(tbl$scale), "latent")
  expect_equal(unique(tbl$validation_row), "EXT-18")
})

test_that("extract_Sigma_table accepts bootstrap_Sigma objects with intervals", {
  boot <- make_bootstrap_sigma_table_object()
  tbl <- extract_Sigma_table(boot, level = "unit", entries = "upper")

  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), 3L)
  expect_equal(unique(tbl$level), "unit")
  expect_equal(unique(tbl$matrix), "Sigma")
  expect_equal(unique(tbl$validation_row), "EXT-20")
  expect_equal(unique(tbl$interval_method), "bootstrap")
  expect_equal(unique(tbl$interval_status), "provided")
  expect_true(all(is.finite(tbl$lower)))
  expect_true(all(is.finite(tbl$upper)))
  expect_equal(
    tbl$estimate,
    boot$point_est$Sigma_B[cbind(tbl$i, tbl$j)]
  )
  expect_equal(
    tbl$lower,
    boot$ci_lower$Sigma_B[cbind(tbl$i, tbl$j)]
  )
  expect_equal(attr(tbl, "bootstrap")$n_failed, 1L)
})

test_that("extract_Sigma_table returns bootstrap correlation rows", {
  boot <- make_bootstrap_sigma_table_object()
  tbl <- extract_Sigma_table(
    boot,
    level = "unit",
    measure = "correlation",
    entries = "all"
  )

  expect_equal(nrow(tbl), 9L)
  expect_equal(unique(tbl$matrix), "R")
  expect_equal(unique(tbl$scale), "correlation")
  expect_equal(unique(tbl$interval_method), "bootstrap")
  expect_equal(unique(tbl$interval_status), "provided")
  expect_equal(tbl$estimate, boot$point_est$R_B[cbind(tbl$i, tbl$j)])
})

test_that("extract_Sigma_table marks missing bootstrap intervals", {
  boot <- make_bootstrap_sigma_table_object()
  boot$ci_lower$Sigma_B[1L, 2L] <- NA_real_
  tbl <- extract_Sigma_table(boot, level = "unit", entries = "upper")

  expect_equal(
    tbl$interval_status[tbl$trait_i == "length" & tbl$trait_j == "mass"],
    "missing"
  )
  expect_equal(
    tbl$interval_status[tbl$trait_i == "mass" & tbl$trait_j == "wing"],
    "provided"
  )
})

test_that("extract_Sigma_table rejects unsupported bootstrap table requests", {
  boot <- make_bootstrap_sigma_table_object()
  expect_error(
    extract_Sigma_table(boot, level = "unit_obs"),
    regexp = "Available"
  )
  expect_error(
    extract_Sigma_table(boot, part = "shared"),
    regexp = "part = \"total\""
  )
})
