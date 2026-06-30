make_lv_factor_runtime_data <- function(
  counts = rep(60L, 3L),
  seed = 202606284L
) {
  set.seed(seed)
  traits <- paste0("t", 1:3)
  habitat_levels <- c("forest", "grass", "wetland")
  habitat_unit <- factor(rep(habitat_levels, counts), levels = habitat_levels)
  n_units <- length(habitat_unit)
  units <- paste0("u", seq_len(n_units))

  X_lv <- stats::model.matrix(~ 0 + habitat_unit)
  colnames(X_lv) <- sub("^habitat_unit", "habitat", colnames(X_lv))
  alpha <- matrix(c(-0.65, 0.05, 0.72), nrow = length(habitat_levels))
  Lambda <- matrix(c(0.75, -0.55, 0.60), ncol = 1L)
  beta <- c(0.10, -0.05, 0.03)
  psi <- c(0.15, 0.13, 0.14)

  innovation <- matrix(stats::rnorm(n_units), ncol = 1L)
  scores <- X_lv %*% alpha + innovation

  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        habitat = habitat_unit[[i]],
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df$habitat <- factor(df$habitat, levels = habitat_levels)

  trait_i <- as.integer(df$trait)
  unit_i <- as.integer(df$unit)
  eta <- beta[trait_i] + Lambda[trait_i, 1L] * scores[unit_i, 1L]
  df$value <- eta + stats::rnorm(nrow(df), sd = psi[trait_i])

  attr(df, "truth") <- list(
    alpha = alpha,
    Lambda = Lambda,
    B_lv = Lambda %*% t(alpha),
    X_lv_colnames = colnames(X_lv),
    counts = stats::setNames(counts, habitat_levels)
  )
  df
}

fit_lv_factor_runtime <- function(data = make_lv_factor_runtime_data()) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  suppressMessages(gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, lv = ~habitat),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE)
  ))
}

expect_lv_factor_runtime_reports <- function(fit, truth) {
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$lv_B))
  expect_equal(dim(fit$tmb_data$X_lv_B), c(fit$n_sites, 3L))
  expect_equal(colnames(fit$lv$X_lv_B), truth$X_lv_colnames)
  expect_equal(dim(fit$tmb_params$alpha_lv_B), c(3L, fit$d_B))
  expect_equal(dim(fit$report$alpha_lv_B), c(3L, fit$d_B))
  expect_equal(dim(fit$report$U_lv_mean_B), c(fit$n_sites, fit$d_B))
  expect_equal(dim(fit$report$U_B_total), c(fit$n_sites, fit$d_B))
  expect_equal(dim(fit$report$B_lv_unit), c(fit$n_traits, 3L))
  expect_true(all(is.finite(fit$report$alpha_lv_B)))
  expect_true(all(is.finite(fit$report$U_lv_mean_B)))
  expect_true(all(is.finite(fit$report$U_B_total)))
  expect_true(all(is.finite(fit$report$B_lv_unit)))
  expect_equal(
    fit$report$B_lv_unit,
    fit$report$Lambda_B %*% t(fit$report$alpha_lv_B),
    tolerance = 1e-8
  )
}

expect_lv_factor_runtime_recovery <- function(fit, truth, b_tol) {
  effects <- extract_lv_effects(fit)
  expect_equal(unique(effects$validation_row), "EXT-31; LV-01")
  expect_equal(
    unique(effects$uncertainty_status),
    "sdreport_skipped_no_lv_se"
  )
  expect_equal(
    effects$predictor,
    rep(truth$X_lv_colnames, each = fit$n_traits)
  )

  b_hat <- matrix(effects$estimate, nrow = fit$n_traits)
  colnames(b_hat) <- truth$X_lv_colnames
  rownames(b_hat) <- levels(fit$data[[fit$trait_col]])
  b_abs_error <- max(abs(b_hat - truth$B_lv))
  expect_lt(
    b_abs_error,
    b_tol,
    label = sprintf("factor-lv B_lv max absolute error = %.3f", b_abs_error)
  )
}

test_that("latent lv factor predictors fit and recover B_lv", {
  ## Symbol <-> implementation alignment for this LV-04 factor-runtime slice:
  ##   z_i = X_lv,i alpha + e_i, e_i ~ N(0, 1)
  ##   X_lv,i = one-hot habitat indicators from lv = ~habitat
  ##   eta_it = beta_t + lambda_t z_i + q_it, q_it ~ N(0, psi_t^2)
  ##   y_it ~ Gaussian(eta_it, residual scale)
  ##   Formula: value ~ 0 + trait +
  ##     latent(0 + trait | unit, d = 1, lv = ~habitat)
  ##   Recovery target: trait-by-level B_lv = Lambda alpha^T, reported
  ##     by extract_lv_effects(type = "trait_effect").
  data <- make_lv_factor_runtime_data()
  truth <- attr(data, "truth")

  fit <- fit_lv_factor_runtime(data)

  expect_identical(fit$opt$convergence, 0L)
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 3e-3)
  expect_lv_factor_runtime_reports(fit, truth)
  expect_lv_factor_runtime_recovery(fit, truth, b_tol = 0.18)

  total <- extract_ordination(fit, level = "unit", component = "total")
  innovation <- extract_ordination(
    fit,
    level = "unit",
    component = "innovation"
  )
  mean <- extract_ordination(fit, level = "unit", component = "mean")
  expect_equal(
    total$scores,
    innovation$scores + mean$scores,
    tolerance = 1e-8
  )
})

test_that("latent lv accepts rare nonempty factor levels", {
  data <- make_lv_factor_runtime_data(counts = c(86L, 86L, 8L))
  truth <- attr(data, "truth")
  expect_equal(unname(truth$counts), c(86L, 86L, 8L))

  fit <- fit_lv_factor_runtime(data)

  expect_identical(fit$opt$convergence, 0L)
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 3e-3)
  expect_lv_factor_runtime_reports(fit, truth)
  expect_lv_factor_runtime_recovery(fit, truth, b_tol = 0.30)
})

test_that("latent lv rejects empty factor levels before fitting", {
  data <- make_lv_factor_runtime_data(counts = c(30L, 30L, 0L))
  expect_error(
    fit_lv_factor_runtime(data),
    regexp = "rank deficient|empty factor levels"
  )
})
