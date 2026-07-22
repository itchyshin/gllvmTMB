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
    level = "unit",
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
  expect_equal(unique(tbl$validation_row), "Sigma/Psi summary table (point estimates only)")
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

test_that("extract_Sigma_table unique part defaults to genuine Psi diagonals", {
  fit <- make_sigma_table_fit()
  tbl <- suppressMessages(extract_Sigma_table(
    fit,
    level = "unit",
    part = "unique"
  ))
  s_unit <- suppressMessages(
    extract_Sigma(fit, level = "unit", part = "unique")
  )$s

  expect_equal(nrow(tbl), fit$n_traits)
  expect_true(all(tbl$diagonal))
  expect_equal(unique(tbl$triangle), "diagonal")
  expect_equal(unique(tbl$matrix), "Psi")
  expect_equal(tbl$estimate, unname(s_unit))
})

test_that("extract_Sigma_table discovers cluster2 and named kernel tiers", {
  fake_fit <- structure(
    list(
      use = list(diag_cluster2 = TRUE),
      kernel_levels = list(
        name = "known",
        internal_level = "kernel",
        index = 1L,
        rank = 1L,
        has_latent = TRUE,
        has_psi = FALSE
      ),
      data = data.frame(trait = factor(c("a", "b"), levels = c("a", "b"))),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )
  expect_setequal(
    gllvmTMB:::.sigma_available_levels(fake_fit),
    c("cluster2", "known")
  )

  Sigma <- matrix(
    c(1.0, 0.2, 0.2, 1.5),
    2L,
    dimnames = list(c("a", "b"), c("a", "b"))
  )

  with_mocked_bindings(
    extract_Sigma = function(fit, level, part, link_residual, .skip_warn) {
      list(
        Sigma = Sigma,
        R = stats::cov2cor(Sigma),
        s = stats::setNames(diag(Sigma), rownames(Sigma)),
        note = paste("mock", level)
      )
    },
    .package = "gllvmTMB",
    code = {
      all_tbl <- extract_Sigma_table(fake_fit, level = "all")
      kernel_tbl <- extract_Sigma_table(fake_fit, level = "known")
    }
  )

  expect_setequal(all_tbl$level, c("cluster2", "known"))
  expect_equal(unique(kernel_tbl$level), "known")
  expect_equal(nrow(kernel_tbl), 3L)
  expect_equal(kernel_tbl$estimate, Sigma[cbind(kernel_tbl$i, kernel_tbl$j)])
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
  expect_equal(unique(tbl$validation_row), "Sigma/Psi summary table (point estimates only)")
})

test_that("extract_Sigma_table accepts bootstrap_Sigma objects with intervals", {
  boot <- make_bootstrap_sigma_table_object()
  tbl <- extract_Sigma_table(boot, level = "unit", entries = "upper")

  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), 3L)
  expect_equal(unique(tbl$level), "unit")
  expect_equal(unique(tbl$matrix), "Sigma")
  expect_equal(unique(tbl$validation_row), "bootstrap-CI table formatting only (not a new CI)")
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

test_that("compare_Sigma_table joins estimate rows to truth matrices", {
  boot <- make_bootstrap_sigma_table_object()
  rows <- extract_Sigma_table(
    boot,
    level = "unit",
    measure = "correlation",
    entries = "upper"
  )
  truth <- boot$point_est$Sigma_B
  truth[1L, 2L] <- truth[2L, 1L] <- 0.15

  cmp <- compare_Sigma_table(rows, truth, measure = "correlation")

  expect_s3_class(cmp, "data.frame")
  expect_named(
    cmp,
    c(names(rows), "truth", "error", "abs_error", "comparison_status")
  )
  expect_equal(nrow(cmp), nrow(rows))
  expect_equal(unique(cmp$comparison_status), "compared")
  expect_equal(
    cmp$truth,
    stats::cov2cor(truth)[cbind(
      match(cmp$trait_i, rownames(truth)),
      match(cmp$trait_j, colnames(truth))
    )]
  )
  expect_equal(cmp$error, cmp$estimate - cmp$truth)
  expect_match(
    paste(attr(cmp, "notes"), collapse = " "),
    "Compared 3 rows",
    fixed = TRUE
  )
})

test_that("compare_Sigma_table validates truth names", {
  rows <- data.frame(
    trait_i = "length",
    trait_j = "mass",
    estimate = 0.4
  )
  truth <- diag(2)
  rownames(truth) <- colnames(truth) <- c("length", "wing")

  expect_error(
    compare_Sigma_table(rows, truth, measure = "correlation"),
    regexp = "missing trait name"
  )
})
